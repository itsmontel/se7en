import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

// MARK: - Screen Time Service
// Clean implementation for Screen Time API integration

class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()
    
    // MARK: - Properties
    
    private let authCenter = AuthorizationCenter.shared
    private let deviceActivityCenter = DeviceActivityCenter()
    private let settingsStore = ManagedSettingsStore()
    private let coreDataManager = CoreDataManager.shared
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Token Storage
    // Key: bundle ID or app identifier, Value: FamilyActivitySelection for that app
    private var appSelections: [String: FamilyActivitySelection] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Check current authorization status
        authorizationStatus = authCenter.authorizationStatus
        isAuthorized = authorizationStatus == .approved
        
        // Listen for authorization changes
        authCenter.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.authorizationStatus = status
                self?.isAuthorized = status == .approved
                print("📱 Screen Time authorization status: \(status)")
            }
            .store(in: &cancellables)
        
        // Load saved selections on init
        loadSavedSelections()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        print("🔐 Requesting Screen Time authorization...")
        try await authCenter.requestAuthorization(for: .individual)
        
        await MainActor.run {
            self.isAuthorized = authCenter.authorizationStatus == .approved
            print("🔐 Authorization result: \(self.isAuthorized ? "Approved" : "Denied")")
        }
    }
    
    // MARK: - App Selection Management
    
    /// Add an app for monitoring from FamilyActivitySelection
    /// - Parameters:
    ///   - selection: The FamilyActivitySelection containing the app's token
    ///   - appName: Display name of the app
    ///   - bundleID: Bundle identifier (can be extracted or provided)
    ///   - dailyLimitMinutes: Daily usage limit in minutes
    func addAppForMonitoring(
        selection: FamilyActivitySelection,
        appName: String,
        bundleID: String,
        dailyLimitMinutes: Int
    ) {
        guard isAuthorized else {
            print("❌ Cannot add app - not authorized")
            return
        }
        
        guard !selection.applicationTokens.isEmpty else {
            print("❌ Cannot add app - no tokens in selection")
            return
        }
        
        print("📱 Adding app for monitoring:")
        print("   Name: \(appName)")
        print("   Bundle ID: \(bundleID)")
        print("   Limit: \(dailyLimitMinutes) minutes")
        print("   Tokens: \(selection.applicationTokens.count)")
        
        // Store the selection with the bundle ID
        appSelections[bundleID] = selection
        
        // Save to persistent storage
        saveSelection(selection, forBundleID: bundleID)
        
        // Create app goal in Core Data
        let appGoal = coreDataManager.createAppGoal(
            appName: appName,
            bundleID: bundleID,
            dailyLimitMinutes: dailyLimitMinutes
        )
        
        // Set up monitoring
        setupMonitoring(for: appGoal, selection: selection)
        
        // Verify storage
        if hasSelection(for: bundleID) {
            print("✅ App added successfully: \(appName)")
            print("   Bundle ID stored: \(bundleID)")
            print("   Selection stored: \(appSelections[bundleID] != nil ? "Yes" : "No")")
            print("   Monitoring active: Check DeviceActivityCenter")
        } else {
            print("❌ Failed to store selection for: \(appName)")
            print("   Bundle ID: \(bundleID)")
            print("   Available selections: \(appSelections.keys.joined(separator: ", "))")
        }
    }
    
    /// Check if we have a stored selection for an app
    func hasSelection(for bundleID: String) -> Bool {
        return appSelections[bundleID] != nil
    }
    
    /// Get the selection for an app
    func getSelection(for bundleID: String) -> FamilyActivitySelection? {
        return appSelections[bundleID]
    }
    
    /// Remove an app from monitoring
    func removeApp(bundleID: String) {
        appSelections.removeValue(forKey: bundleID)
        removeSelection(forBundleID: bundleID)
        stopMonitoring(for: bundleID)
        print("🗑️ Removed app: \(bundleID)")
    }
    
    // MARK: - Monitoring Setup
    
    private func setupMonitoring(for goal: AppGoal, selection: FamilyActivitySelection) {
        guard let bundleID = goal.appBundleID else { return }
        
        let limitMinutes = Int(goal.dailyLimitMinutes)
        let warningMinutes = max(1, Int(Double(limitMinutes) * 0.8))
        
        print("🔧 Setting up monitoring for \(goal.appName ?? "Unknown"):")
        print("   Warning at: \(warningMinutes) minutes")
        print("   Limit at: \(limitMinutes) minutes")
        
        // Create schedule (midnight to midnight)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        // Create events
        let warningEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: DateComponents(minute: warningMinutes)
        )
        
        let limitEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: DateComponents(minute: limitMinutes)
        )
        
        // Unique activity name for this app
        let activityName = DeviceActivityName("se7en.\(bundleID.replacingOccurrences(of: ".", with: "_"))")
        
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            DeviceActivityEvent.Name("warning.\(bundleID)"): warningEvent,
            DeviceActivityEvent.Name("limit.\(bundleID)"): limitEvent
        ]
        
        do {
            try deviceActivityCenter.startMonitoring(activityName, during: schedule, events: events)
            print("✅ Started monitoring for \(goal.appName ?? bundleID)")
            print("   Activity Name: \(activityName)")
            print("   Bundle ID: \(bundleID)")
            print("   Tokens in selection: \(selection.applicationTokens.count)")
            print("   Warning threshold: \(warningMinutes) minutes")
            print("   Limit threshold: \(limitMinutes) minutes")
        } catch {
            print("❌ Failed to start monitoring for \(bundleID): \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
    }
    
    private func stopMonitoring(for bundleID: String) {
        let activityName = DeviceActivityName("se7en.\(bundleID.replacingOccurrences(of: ".", with: "_"))")
        deviceActivityCenter.stopMonitoring([activityName])
        print("🛑 Stopped monitoring for \(bundleID)")
    }
    
    func stopAllMonitoring() {
        for bundleID in appSelections.keys {
            stopMonitoring(for: bundleID)
        }
        settingsStore.clearAllSettings()
        print("🛑 Stopped all monitoring")
    }
    
    // MARK: - App Blocking
    
    func blockApp(_ bundleID: String) {
        guard let selection = appSelections[bundleID] else {
            print("❌ No selection found for blocking: \(bundleID)")
            return
        }
        
        // Convert tokens for ManagedSettings
        var blockedApps = settingsStore.shield.applications ?? Set()
        for token in selection.applicationTokens {
            blockedApps.insert(token)
        }
        settingsStore.shield.applications = blockedApps
        
        print("🚫 Blocked app: \(bundleID)")
    }
    
    func unblockApp(_ bundleID: String) {
        guard let selection = appSelections[bundleID] else { return }
        
        var blockedApps = settingsStore.shield.applications ?? Set()
        for token in selection.applicationTokens {
            blockedApps.remove(token)
        }
        settingsStore.shield.applications = blockedApps
        
        print("✅ Unblocked app: \(bundleID)")
    }
    
    func unblockAllApps() {
        settingsStore.shield.applications = nil
        print("✅ Unblocked all apps")
    }
    
    // MARK: - Usage Tracking
    
    /// Get usage minutes for a specific app
    /// First tries to get from Core Data (updated by DeviceActivityMonitor events)
    /// Falls back to checking if app has been used today
    func getUsageMinutes(for bundleID: String) -> Int {
        // Get usage from Core Data (updated by DeviceActivityMonitor)
        if let record = coreDataManager.getTodaysUsageRecord(for: bundleID) {
            return Int(record.actualUsageMinutes)
        }
        
        // If no record exists, check if app is being monitored
        // Usage will be 0 until DeviceActivityMonitor fires an event
        return 0
    }
    
    /// Get total screen time today across all monitored apps
    func getTotalScreenTimeToday() async -> (totalMinutes: Int, appsUsed: Int) {
        let goals = coreDataManager.getActiveAppGoals()
        var totalMinutes = 0
        var appsUsed = 0
        
        for goal in goals {
            guard let bundleID = goal.appBundleID,
                  hasSelection(for: bundleID) else {
                continue
            }
            
            let usage = getUsageMinutes(for: bundleID)
            if usage > 0 {
                totalMinutes += usage
                appsUsed += 1
            }
        }
        
        return (totalMinutes, appsUsed)
    }
    
    /// Get the app with the most usage today
    func getTopAppToday() async -> (name: String, bundleID: String, minutes: Int)? {
        let goals = coreDataManager.getActiveAppGoals()
        var topApp: (name: String, bundleID: String, minutes: Int)?
        var maxUsage = 0
        
        for goal in goals {
            guard let appName = goal.appName,
                  let bundleID = goal.appBundleID,
                  hasSelection(for: bundleID) else {
                continue
            }
            
            let usage = getUsageMinutes(for: bundleID)
            if usage > maxUsage {
                maxUsage = usage
                topApp = (name: appName, bundleID: bundleID, minutes: usage)
            }
        }
        
        return topApp
    }
    
    func updateUsage(for bundleID: String, minutes: Int) {
        let goals = coreDataManager.getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        if let existing = coreDataManager.getTodaysUsageRecord(for: bundleID) {
            existing.actualUsageMinutes = Int32(minutes)
            existing.didExceedLimit = minutes >= Int(goal.dailyLimitMinutes)
        } else {
            _ = coreDataManager.createUsageRecord(
                for: goal,
                date: today,
                actualUsageMinutes: minutes,
                didExceedLimit: minutes >= Int(goal.dailyLimitMinutes)
            )
        }
        
        coreDataManager.save()
    }
    
    // MARK: - Persistence
    
    private let selectionsKey = "se7en.appSelections"
    
    private func saveSelection(_ selection: FamilyActivitySelection, forBundleID bundleID: String) {
        // Save to UserDefaults (selection can be encoded)
        do {
            let data = try PropertyListEncoder().encode(selection)
            var allSelections = UserDefaults.standard.dictionary(forKey: selectionsKey) as? [String: Data] ?? [:]
            allSelections[bundleID] = data
            UserDefaults.standard.set(allSelections, forKey: selectionsKey)
            print("💾 Saved selection for: \(bundleID)")
        } catch {
            print("❌ Failed to save selection: \(error)")
        }
    }
    
    private func removeSelection(forBundleID bundleID: String) {
        var allSelections = UserDefaults.standard.dictionary(forKey: selectionsKey) as? [String: Data] ?? [:]
        allSelections.removeValue(forKey: bundleID)
        UserDefaults.standard.set(allSelections, forKey: selectionsKey)
    }
    
    private func loadSavedSelections() {
        guard let allSelections = UserDefaults.standard.dictionary(forKey: selectionsKey) as? [String: Data] else {
            return
        }
        
        for (bundleID, data) in allSelections {
            do {
                let selection = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
                appSelections[bundleID] = selection
                print("📂 Loaded selection for: \(bundleID)")
            } catch {
                print("❌ Failed to load selection for \(bundleID): \(error)")
            }
        }
        
        print("📂 Loaded \(appSelections.count) app selections")
    }
    
    // MARK: - Debug
    
    func debugPrintState() {
        print("\n" + String(repeating: "=", count: 50))
        print("🔍 SCREEN TIME SERVICE STATE")
        print(String(repeating: "=", count: 50))
        print("Authorization: \(isAuthorized ? "✅ Approved" : "❌ Not Approved")")
        print("Stored Selections: \(appSelections.count)")
        
        for (bundleID, selection) in appSelections {
            print("  • \(bundleID): \(selection.applicationTokens.count) tokens")
        }
        
        let goals = coreDataManager.getActiveAppGoals()
        print("\nApp Goals in Core Data: \(goals.count)")
        for goal in goals {
            let bundleID = goal.appBundleID ?? "nil"
            let hasSelection = hasSelection(for: bundleID)
            print("  • \(goal.appName ?? "Unknown")")
            print("    Bundle: \(bundleID)")
            print("    Connected: \(hasSelection ? "✅" : "❌")")
            print("    Limit: \(goal.dailyLimitMinutes) min")
        }
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    // MARK: - Handle Limit Events
    
    func handleWarning(for bundleID: String) {
        let goals = coreDataManager.getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else { return }
        
        let appName = goal.appName ?? "App"
        let limitMinutes = Int(goal.dailyLimitMinutes)
        let remainingMinutes = Int(Double(limitMinutes) * 0.2)
        
        NotificationService.shared.sendLimitWarningNotification(
            appName: appName,
            timeRemaining: remainingMinutes
        )
        
        // Update usage to 80% of limit
        updateUsage(for: bundleID, minutes: Int(Double(limitMinutes) * 0.8))
        
        print("⚠️ Warning sent for \(appName)")
    }
    
    func handleLimitReached(for bundleID: String) {
        let goals = coreDataManager.getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else { return }
        
        let appName = goal.appName ?? "App"
        let limitMinutes = Int(goal.dailyLimitMinutes)
        
        // Block the app
        blockApp(bundleID)
        
        // Update usage
        updateUsage(for: bundleID, minutes: limitMinutes)
        
        // Send notification
        NotificationService.shared.sendAppBlockedNotification(appName: appName)
        
        // Post notification for UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .appBlocked,
                object: nil,
                userInfo: ["appName": appName, "bundleID": bundleID]
            )
        }
        
        print("🚫 Limit reached - blocked \(appName)")
    }
    
    // MARK: - Additional Methods (for compatibility)
    
    /// Check and update app blocking status
    func checkAndUpdateAppBlocking() {
        // Re-check all apps for blocking status
        let goals = coreDataManager.getActiveAppGoals()
        for goal in goals {
            guard let bundleID = goal.appBundleID else { continue }
            let usage = getUsageMinutes(for: bundleID)
            let limit = Int(goal.dailyLimitMinutes)
            
            if usage >= limit {
                blockApp(bundleID)
            }
        }
    }
    
    /// Get today's usage record for an app
    func getAppUsageToday(for bundleID: String) -> AppUsageRecord? {
        return coreDataManager.getTodaysUsageRecord(for: bundleID)
    }
    
    /// Perform weekly reset
    func performWeeklyReset() {
        // Unblock all apps
        unblockAllApps()
        
        // Complete current weekly plan
        if let currentPlan = coreDataManager.getCurrentWeeklyPlan() {
            currentPlan.isCompleted = true
            currentPlan.paymentAmount = Double(7 - Int(currentPlan.creditsRemaining))
        }
        
        // Create new weekly plan
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? Date()
        _ = coreDataManager.createWeeklyPlan(startDate: startOfWeek, endDate: endOfWeek)
        
        coreDataManager.save()
        print("📅 Weekly reset completed")
    }
    
    /// Refresh all app usage data
    func refreshAllAppUsage() async {
        let goals = coreDataManager.getActiveAppGoals()
        
        for goal in goals {
            guard let bundleID = goal.appBundleID else { continue }
            
            // Usage is tracked by DeviceActivityMonitor
            // This method is mainly for triggering UI updates
            let usage = getUsageMinutes(for: bundleID)
            
            // Check if limit exceeded
            if usage >= Int(goal.dailyLimitMinutes) {
                blockApp(bundleID)
            }
        }
        
        // Notify UI to refresh
        await MainActor.run {
            NotificationCenter.default.post(name: .screenTimeDataUpdated, object: nil)
        }
    }
    
    /// Unblock an app using credits
    @discardableResult
    func unblockAppWithCredit(_ bundleID: String) -> Bool {
        // Check if user has credits
        guard let currentPlan = coreDataManager.getCurrentWeeklyPlan(),
              currentPlan.creditsRemaining > 0 else {
            print("❌ No credits remaining to unblock app")
            return false
        }
        
        // Deduct credit
        currentPlan.creditsRemaining -= 1
        coreDataManager.save()
        
        // Unblock the app
        unblockApp(bundleID)
        
        // Get app name for notification
        let appGoal = coreDataManager.getActiveAppGoals().first { $0.appBundleID == bundleID }
        let appName = appGoal?.appName ?? "App"
        
        print("✅ Unblocked \(appName) using 1 credit. Credits remaining: \(currentPlan.creditsRemaining)")
        
        // Send notification
        NotificationService.shared.sendAppUnblockedNotification(appName: appName)
        
        // Post notification for UI update
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .appUnblocked,
                object: nil,
                userInfo: ["appName": appName, "bundleID": bundleID]
            )
        }
        
        return true
    }
}
