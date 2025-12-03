import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

// DeviceActivity extensions moved to Extensions/DeviceActivityExtensions.swift

// MARK: - ApplicationToken Bridge Extension
// Note: Tokens from FamilyActivitySelection can be used directly with ManagedSettings
// as they share the same underlying Token<Application> type

// MARK: - Helper Functions

/// Converts FamilyActivitySelection tokens to ManagedSettings.Application tokens  
/// Uses unsafeBitCast to bridge between compatible Token<Application> types
@inline(never) // Prevent inlining to help compiler avoid type inference issues
private func convertTokenSet(_ selection: FamilyActivitySelection) -> Set<ManagedSettings.Application> {
    var result: Set<ManagedSettings.Application> = []
    let tokens = selection.applicationTokens
    result.reserveCapacity(tokens.count)
    
    // Explicit iteration to avoid complex map/closure type inference
    for token in tokens {
        let app = unsafeBitCast(token, to: ManagedSettings.Application.self)
        result.insert(app)
    }
    
    return result
}

// MARK: - DeviceActivity Names (duplicate removed above)

class ScreenTimeService: ObservableObject {
    nonisolated static let shared = ScreenTimeService()
    
    private let center = AuthorizationCenter.shared
    internal let deviceActivityCenter = DeviceActivityCenter()
    internal let managedSettingsStore = ManagedSettingsStore()
    internal let coreDataManager = CoreDataManager.shared
    
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var isAuthorized = false
    
    private var cancellables = Set<AnyCancellable>()
    internal var activeSchedules: [DeviceActivityName] = []
    
    // Store current app selections for monitoring
    internal var monitoredAppSelections: [String: FamilyActivitySelection] = [:]
    
    private init() {
        authorizationStatus = center.authorizationStatus
        isAuthorized = authorizationStatus == .approved
        
        // Monitor authorization status changes
        center.$authorizationStatus
            .sink { [weak self] status in
                self?.authorizationStatus = status
                self?.isAuthorized = status == .approved
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        try await center.requestAuthorization(for: .individual)
    }
    
    // MARK: - App Monitoring Setup
    
    func setupMonitoring(for goals: [AppGoal]) {
        guard isAuthorized else {
            print("Not authorized for Screen Time access")
            return
        }
        
        // Stop existing monitoring
        stopAllMonitoring()
        
        // Set up monitoring for each app goal
        // Individual apps will be blocked only if they exceed their limits
        for goal in goals {
            setupAppMonitoring(for: goal)
        }
    }
    
    func checkAndUpdateAppBlocking() {
        // Called to check if apps should be blocked/unblocked based on credits
        // Note: We don't block all apps based on credits anymore
        // Only individual apps that exceed their limits are blocked
        let goals = coreDataManager.getActiveAppGoals()
        
        // Re-setup monitoring normally (individual apps will be blocked if limits exceeded)
        setupMonitoring(for: goals)
    }
    
    private func unblockAllMonitoredApps(goals: [AppGoal]) {
        guard isAuthorized else { return }
        
        print("🔓 Unblocking monitored apps")
        
        // Get current blocked apps
        var blockedApps = managedSettingsStore.application.blockedApplications ?? Set<ManagedSettings.Application>()
        
        // Remove only monitored apps from blocked list
        for goal in goals {
            if let selection = monitoredAppSelections[goal.appBundleID ?? ""] {
                let appsToRemove = convertTokenSet(selection)
                for app in appsToRemove {
                    blockedApps.remove(app)
                }
            }
        }
        
        // Update blocked applications (only monitored apps removed)
        managedSettingsStore.application.blockedApplications = blockedApps
        
        print("✅ Successfully unblocked monitored apps")
    }
    
    private func setupAppMonitoring(for goal: AppGoal) {
        guard let bundleID = goal.appBundleID else { return }
        
        print("🔧 Setting up monitoring for \(goal.appName ?? "Unknown App") with bundle ID: \(bundleID)")
        print("📊 Daily limit: \(goal.dailyLimitMinutes) minutes")
        
        // Check if we already have a selection for this app
        // Tokens can only come from FamilyActivityPicker user selection
        if let existingSelection = monitoredAppSelections[bundleID] {
            // Set up device activity monitoring with existing selection
            setupDeviceActivitySchedule(for: goal, with: existingSelection)
        } else {
            print("⚠️ No token selection found for \(bundleID) - app must be selected via FamilyActivityPicker first")
            print("ℹ️  Use addAppGoalFromSelection() to add apps with tokens from FamilyActivityPicker")
        }
    }
    
    private func setupDeviceActivitySchedule(for goal: AppGoal, with selection: FamilyActivitySelection) {
        guard let bundleID = goal.appBundleID else { return }
        
        // Create daily schedule (reset at midnight)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        // Create warning event (80% of limit reached)
        let warningThreshold = Double(goal.dailyLimitMinutes) * 0.8
        let warningEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: DateComponents(minute: Int(warningThreshold))
        )
        
        // Create limit event (100% of limit reached)
        let limitEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: DateComponents(minute: Int(goal.dailyLimitMinutes))
        )
        
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            .warningEvent(for: bundleID): warningEvent,
            .limitEvent(for: bundleID): limitEvent
        ]
        
        do {
            // Start monitoring with the schedule and events
            try deviceActivityCenter.startMonitoring(.se7enDaily, during: schedule, events: events)
            activeSchedules.append(.se7enDaily)
            print("✅ Started monitoring for \(goal.appName ?? bundleID)")
        } catch {
            print("❌ Failed to start monitoring for \(bundleID): \(error)")
        }
    }
    
    func stopAllMonitoring() {
        print("🛑 Stopping all monitoring activities")
        
        // Stop all active device activity schedules
        for scheduleName in activeSchedules {
            deviceActivityCenter.stopMonitoring([scheduleName])
            print("🛑 Stopped monitoring schedule: \(scheduleName)")
        }
        
        activeSchedules.removeAll()
        
        // Clear managed settings (unblock all apps)
        managedSettingsStore.clearAllSettings()
        print("✅ Cleared all managed settings")
        
        // Clear stored selections
        monitoredAppSelections.removeAll()
    }
    
    // MARK: - Usage Data Retrieval
    
    func getCurrentUsage(for bundleID: String) async -> Int {
        // Check if we have a stored usage record for today
        if let todaysRecord = getAppUsageToday(for: bundleID) {
            return Int(todaysRecord.actualUsageMinutes)
        }
        
        // If no stored record, try to get from DeviceActivityReport
        return await fetchUsageFromDeviceActivity(for: bundleID)
    }
    
    private func fetchUsageFromDeviceActivity(for bundleID: String) async -> Int {
        // In a real implementation, you would:
        // 1. Create a DeviceActivityReport context
        // 2. Request usage data for the specific app
        // 3. Parse the results to get minutes used
        
        print("📊 Fetching usage data for \(bundleID)")
        print("ℹ️  In production, implement DeviceActivityReport to get real usage")
        
        // For now, return 0 as we need DeviceActivityReport implementation
        // This requires additional setup and potentially an App Extension
        return 0
    }
    
    // Helper to get today's usage from Core Data
    func getAppUsageToday(for bundleID: String) -> AppUsageRecord? {
        let usageRecords = coreDataManager.getTodaysUsageRecords()
        return usageRecords.first { $0.appGoal?.appBundleID == bundleID }
    }
    
    // MARK: - Real-time Data Updates
    
    func refreshAllAppUsage() async {
        print("🔄 Refreshing usage data for all monitored apps")
        
        let goals = coreDataManager.getActiveAppGoals()
        
        for goal in goals {
            guard let bundleID = goal.appBundleID else { continue }
            
            // Get current usage
            let currentUsage = await getCurrentUsage(for: bundleID)
            
            // Update or create usage record for today
            updateUsageRecord(for: goal, currentUsage: currentUsage)
            
            // Get effective limit (respects restriction periods)
            let effectiveLimit = coreDataManager.getEffectiveDailyLimit(for: bundleID)
            
            // Check time-based blocking first
            if shouldBlockBasedOnTimeWindow(bundleID: bundleID) {
                blockApp(bundleID)
                continue
            }
            
            // Check if limit is exceeded and handle accordingly (using effective limit)
            if currentUsage > effectiveLimit {
                handleLimitExceeded(for: bundleID)
            }
            
            // Check if limit is 0 (completely blocked)
            if effectiveLimit == 0 {
                blockApp(bundleID)
            }
        }
        
        // Notify AppState to refresh its data
        await MainActor.run {
            NotificationCenter.default.post(name: .screenTimeDataUpdated, object: nil)
        }
    }
    
    private func updateUsageRecord(for goal: AppGoal, currentUsage: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if we already have a record for today
        if let existingRecord = getAppUsageToday(for: goal.appBundleID ?? "") {
            // Update existing record
            existingRecord.actualUsageMinutes = Int32(currentUsage)
            existingRecord.didExceedLimit = currentUsage > Int(goal.dailyLimitMinutes)
        } else {
            // Create new record
            _ = coreDataManager.createUsageRecord(
                for: goal,
                date: today,
                actualUsageMinutes: currentUsage,
                didExceedLimit: currentUsage > Int(goal.dailyLimitMinutes)
            )
        }
        
        coreDataManager.save()
    }
    
    // MARK: - App Selection Management
    
    func addAppGoalFromSelection(_ selection: FamilyActivitySelection, appName: String, dailyLimitMinutes: Int) {
        // Store the selection with a generated identifier
        let identifier = UUID().uuidString
        monitoredAppSelections[identifier] = selection
        
        // Create app goal in Core Data with identifier as bundle ID
        // (since we can't extract real bundle ID from ApplicationToken)
        let appGoal = coreDataManager.createAppGoal(
            appName: appName,
            bundleID: identifier,
            dailyLimitMinutes: dailyLimitMinutes
        )
        
        print("✅ Created app goal for \(appName) with identifier: \(identifier)")
        
        // Set up monitoring for this specific app
        if isAuthorized {
            setupMonitoringForApp(goal: appGoal, selection: selection)
        }
    }
    
    private func setupMonitoringForApp(goal: AppGoal, selection: FamilyActivitySelection) {
        guard let bundleID = goal.appBundleID else { return }
        
        // Create individual schedule for this app
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        // Warning at 80% of limit
        let warningMinutes = Int(Double(goal.dailyLimitMinutes) * 0.8)
        
        let warningEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: DateComponents(minute: warningMinutes)
        )
        
        let limitEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: DateComponents(minute: Int(goal.dailyLimitMinutes))
        )
        
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            .warningEvent(for: bundleID): warningEvent,
            .limitEvent(for: bundleID): limitEvent
        ]
        
        do {
            let activityName = DeviceActivityName("se7en.app.\(bundleID)")
            try deviceActivityCenter.startMonitoring(activityName, during: schedule, events: events)
            activeSchedules.append(activityName)
            
            print("✅ Started individual monitoring for \(goal.appName ?? "Unknown")")
        } catch {
            print("❌ Failed to start monitoring for \(bundleID): \(error)")
        }
    }
    
    // MARK: - App Blocking
    
    func blockApp(_ bundleID: String) {
        guard isAuthorized else {
            print("❌ Not authorized to block apps")
            return
        }
        
        guard let selection = monitoredAppSelections[bundleID] else {
            print("❌ No selection found for \(bundleID)")
            return
        }
        
        print("🚫 Blocking app: \(bundleID)")
        
        // Block the application using ManagedSettings
        // Convert tokens using isolated helper function
        let applications = convertTokenSet(selection)
        managedSettingsStore.application.blockedApplications = applications
        
        // Optionally, you can also shield the app instead of completely blocking it
        // managedSettingsStore.application.applicationRestrictions = 
        //     ManagedSettingsStore.Application.Restrictions(level: .age(4))
        
        print("✅ Successfully blocked \(bundleID)")
    }
    
    func unblockApp(_ bundleID: String) {
        guard isAuthorized else {
            print("❌ Not authorized to unblock apps")
            return
        }
        
        print("✅ Unblocking app: \(bundleID)")
        
        // Remove this app's tokens from blocked list
        if let selection = monitoredAppSelections[bundleID] {
            // Get current blocked apps
            var blockedApps = managedSettingsStore.application.blockedApplications ?? Set<ManagedSettings.Application>()
            
            // Remove applications for this app
            // Convert tokens using isolated helper function
            let appsToRemove = convertTokenSet(selection)
            for app in appsToRemove {
                blockedApps.remove(app)
            }
            
            // Update the blocked applications
            managedSettingsStore.application.blockedApplications = blockedApps
        }
        
        print("✅ Successfully unblocked \(bundleID)")
    }
    
    func unblockAllApps() {
        guard isAuthorized else {
            print("❌ Not authorized to unblock apps")
            return
        }
        
        print("🔓 Unblocking all apps")
        
        // Clear all application restrictions
        managedSettingsStore.application.blockedApplications = Set()
        managedSettingsStore.clearAllSettings()
        
        print("✅ Successfully unblocked all apps")
    }
    
    // MARK: - Time-based Blocking
    
    func shouldBlockBasedOnTimeWindow(bundleID: String) -> Bool {
        let hasTimeRestriction = UserDefaults.standard.bool(forKey: "timeRestriction_\(bundleID)")
        guard hasTimeRestriction else { return false }
        
        guard let startTime = UserDefaults.standard.object(forKey: "blockStartTime_\(bundleID)") as? Date,
              let endTime = UserDefaults.standard.object(forKey: "blockEndTime_\(bundleID)") as? Date else {
            return false
        }
        
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeMinutes = currentHour * 60 + currentMinute
        
        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let startTimeMinutes = startHour * 60 + startMinute
        
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)
        let endTimeMinutes = endHour * 60 + endMinute
        
        // Handle overnight blocking (e.g., 9pm to 9am)
        if startTimeMinutes > endTimeMinutes {
            // Overnight window
            return currentTimeMinutes >= startTimeMinutes || currentTimeMinutes < endTimeMinutes
        } else {
            // Same-day window
            return currentTimeMinutes >= startTimeMinutes && currentTimeMinutes < endTimeMinutes
        }
    }
    
    // MARK: - Limit Handling (No Auto Credit Loss)
    
    func handleLimitExceeded(for bundleID: String) {
        // Find the app goal for this bundle ID
        let appGoals = coreDataManager.getActiveAppGoals()
        guard let goal = appGoals.first(where: { $0.appBundleID == bundleID }) else { return }
        
        let appName = goal.appName ?? "Unknown App"
        print("⚠️ Limit exceeded for \(appName) - blocking app")
        
        // Create usage record
        let usageRecord = coreDataManager.createUsageRecord(
            for: goal,
            date: Date(),
            actualUsageMinutes: Int(goal.dailyLimitMinutes) + 1, // Exceeded limit
            didExceedLimit: true
        )
        
        // Check if accountability fee has been paid today
        let weeklyPlan = coreDataManager.getOrCreateCurrentWeeklyPlan()
        let today = Calendar.current.startOfDay(for: Date())
        let accountabilityFeePaidDate = weeklyPlan.accountabilityFeePaidDate.map { Calendar.current.startOfDay(for: $0) }
        let hasPaidAccountabilityFeeToday = accountabilityFeePaidDate == today
        
        // Only deduct credits if this is the first failure of the day (accountability fee not paid)
        if !hasPaidAccountabilityFeeToday {
            // Deduct all credits (user must pay 99 cents or wait till tomorrow)
            let transaction = coreDataManager.deductCredit(
                reason: "Exceeded daily limit for \(appName)",
                for: usageRecord
            )
            
            let remainingCredits = Int(weeklyPlan.creditsRemaining)
            print("💳 Daily limit exceeded: Credits set to 0. User must pay 99¢ to renew for today or wait till tomorrow. Remaining: \(remainingCredits)")
        } else {
            // Accountability fee already paid today - no credit deduction
            print("💳 Accountability fee already paid today - no credit deduction. App will still be blocked.")
        }
        
        // Always block the specific app that exceeded its limit
        print("🚫 Blocking \(appName) (bundleID: \(bundleID))")
        blockApp(bundleID)
        
        // Send notification that app is blocked with unblock option
        NotificationService.shared.sendAppBlockedNotification(appName: appName)
        
        // Post notification to show blocked app modal (on main thread)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .appBlocked,
                object: nil,
                userInfo: ["appName": appName, "bundleID": bundleID]
            )
        }
        
        print("🚫 App blocked - user can wait until midnight or pay 1 credit to unblock")
    }
    
    // MARK: - Manual Unblock with Credit
    
    func unblockAppWithCredit(_ bundleID: String) -> Bool {
        // Find the app goal for this bundle ID
        let appGoals = coreDataManager.getActiveAppGoals()
        guard let goal = appGoals.first(where: { $0.appBundleID == bundleID }) else { 
            print("❌ No goal found for bundle ID: \(bundleID)")
            return false 
        }
        
        // Get current weekly plan
        let currentPlan = coreDataManager.getOrCreateCurrentWeeklyPlan()
        
        // User must have exactly 7 credits to unblock (accountability fee)
        guard currentPlan.creditsRemaining >= 7 else {
            let creditsNeeded = 7 - Int(currentPlan.creditsRemaining)
            print("⚠️ Need \(creditsNeeded) more credit\(creditsNeeded == 1 ? "" : "s") to reach 7 credits required for unblock")
            return false
        }
        
        // Check if accountability fee already paid today
        let today = Calendar.current.startOfDay(for: Date())
        let accountabilityFeePaidDate = currentPlan.accountabilityFeePaidDate.map { Calendar.current.startOfDay(for: $0) }
        let hasPaidAccountabilityFeeToday = accountabilityFeePaidDate == today
        
        // If not already paid, mark it as paid
        if !hasPaidAccountabilityFeeToday {
            currentPlan.accountabilityFeePaidDate = today
            print("✅ Marking accountability fee as paid for today")
        }
        
        // Unblock the app (no credit deduction - they already have 7 credits)
        print("✅ Unblocking \(goal.appName ?? "Unknown App") - user has 7 credits")
        unblockApp(bundleID)
        
        coreDataManager.save()
        
        // Send notification about unblock
        NotificationService.shared.sendCreditUsedForUnblockNotification(
            appName: goal.appName ?? "Unknown App",
            creditsRemaining: Int(currentPlan.creditsRemaining)
        )
        
        return true
    }
    
    // MARK: - Weekly Reset
    
    func performWeeklyReset() {
        // Unblock all apps
        unblockAllApps()
        
        // Complete current weekly plan
        let currentPlan = coreDataManager.getCurrentWeeklyPlan()
        currentPlan?.isCompleted = true
        currentPlan?.paymentAmount = Double(7 - Int(currentPlan?.creditsRemaining ?? 7))
        
        // Create new weekly plan
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? Date()
        _ = coreDataManager.createWeeklyPlan(startDate: startOfWeek, endDate: endOfWeek)
        
        // Update user streak
        updateUserStreak()
        
        // Re-setup monitoring with fresh limits
        let goals = coreDataManager.getActiveAppGoals()
        setupMonitoring(for: goals)
        
        print("Weekly reset completed")
    }
    
    private func updateUserStreak() {
        let userProfile = coreDataManager.getOrCreateUserProfile()
        let currentPlan = coreDataManager.getCurrentWeeklyPlan()
        
        // If user kept all 7 credits, increment streak
        if currentPlan?.creditsRemaining == 7 {
            userProfile.currentStreak += 1
            if userProfile.currentStreak > userProfile.longestStreak {
                userProfile.longestStreak = userProfile.currentStreak
            }
        } else {
            // Reset streak if credits were lost
            userProfile.currentStreak = 0
        }
        
        userProfile.updatedAt = Date()
        coreDataManager.save()
    }
    
    // MARK: - Helper Methods
    
    func getRemainingTime(for goal: AppGoal) -> TimeInterval {
        // In a real implementation, this would calculate based on actual usage
        // For now, return the full limit
        return TimeInterval(goal.dailyLimitMinutes * 60)
    }
}
