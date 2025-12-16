import Foundation
import SwiftUI
import UIKit
import CoreData
import Combine
import FamilyControls

// MARK: - Notification Names

extension Notification.Name {
    static let screenTimeDataUpdated = Notification.Name("screenTimeDataUpdated")
    static let appBlocked = Notification.Name("appBlocked")
    static let appUnblocked = Notification.Name("appUnblocked")
}

@MainActor
class AppState: ObservableObject {
    @Published var isOnboarding = true
    @Published var weekProgress: Double = 0.0
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    @Published var achievements: [Achievement] = []
    @Published var unlockedAchievements: [String] = []
    @Published var appUsage: [AppUsage] = []
    @Published var userGoals: [UserGoal] = []
    @Published var dailyHistory: [DailyHistory] = [] // For compatibility
    @Published var monitoredApps: [MonitoredApp] = [] // For compatibility
    @Published var isScreenTimeAuthorized = false
    @Published var userPet: Pet?
    @Published var downloadMotivations: [DownloadMotivation] = []
    @Published var averageScreenTimeHours: Int = 0
    @Published var userName: String = ""
    @Published var hasActiveSubscription = false
    @Published var shouldShowStreakCelebration = false
    @Published var newStreakValue = 0
    @Published var shouldShowAchievementCelebration = false
    @Published var newAchievement: Achievement?
    @Published var todayScreenTimeMinutes: Int = 0
    
    private var previousStreak = 0
    private var isRefreshingPetHealth = false
    
    // Computed property for compatibility
    var hasCompletedOnboarding: Bool {
        get { !isOnboarding }
        set { isOnboarding = !newValue }
    }
    
    private let coreDataManager = CoreDataManager.shared
    private let screenTimeService = ScreenTimeService.shared
    private let notificationService = NotificationService.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastLoadAppGoalsTime: Date = Date.distantPast
    private let loadAppGoalsThrottleInterval: TimeInterval = 2.0 // Minimum 2 seconds between calls
    
    /// Preload screen time from shared container
    private func preloadScreenTimeFromSharedContainer() {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        sharedDefaults.synchronize()
        let totalUsage = sharedDefaults.integer(forKey: "total_usage")
        
        if totalUsage > 0 {
            self.todayScreenTimeMinutes = totalUsage
        }
    }
    
    init() {
        setupObservers()
        coreDataManager.performDailyResetIfNeeded()
        loadInitialData()
        preloadScreenTimeFromSharedContainer()
        loadUserPreferences()
        checkOnboardingStatus()
    }
    
    private func setupObservers() {
        // Observe Screen Time authorization status
        screenTimeService.$isAuthorized
            .assign(to: \.isScreenTimeAuthorized, on: self)
            .store(in: &cancellables)
        
        // Setup periodic data refresh - less frequent to improve performance
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes instead of 1
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
        
        // Refresh usage when app becomes active (simpler than constant polling)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                // Fetch fresh usage data when app becomes active
                ScreenTimeService.shared.refreshUsageForAllApps()
                // Reload app goals to refresh UI
                self?.loadAppGoals()
            }
            .store(in: &cancellables)
        
        // Also sync periodically when app is active (every 30 seconds)
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // Only sync if app is active
                if UIApplication.shared.applicationState == .active {
                    ScreenTimeService.shared.syncUsageFromSharedContainer()
                    self?.loadAppGoals()
                }
            }
            .store(in: &cancellables)
        
        // Listen for Screen Time data updates (removed duplicate)
        NotificationCenter.default.publisher(for: .screenTimeDataUpdated)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        // Clean up mock apps first (before loading)
        coreDataManager.cleanupMockApps()
        
        loadAchievements()
        loadUserProfile()
        loadCurrentWeekData()
        loadAppGoals()
        loadUnlockedAchievements()
        loadDailyHistory()
        checkAchievements()
    }
    
    private func checkOnboardingStatus() {
        // Always respect the saved onboarding status first
        let savedPreferences = coreDataManager.loadUserPreferences()
        
        // If onboarding was completed before, respect that
        if !savedPreferences.isOnboarding {
            isOnboarding = false
            return
        }
        
        // Otherwise, check if user has app goals (secondary check)
        let goals = coreDataManager.getActiveAppGoals()
        isOnboarding = goals.isEmpty
    }
    
    // MARK: - User Preferences Persistence
    
    private func loadUserPreferences() {
        let preferences = coreDataManager.loadUserPreferences()
        
        userName = preferences.userName ?? ""
        userPet = preferences.pet
        // IMPORTANT: Load onboarding status from Core Data first
        // This ensures persistence across app restarts
        isOnboarding = preferences.isOnboarding
        averageScreenTimeHours = preferences.averageScreenTimeHours
        
        // Update pet health based on usage
        if userPet != nil {
            updatePetHealth()
        }
        
        print("📱 Loaded preferences - isOnboarding: \(isOnboarding), userName: \(userName), pet: \(userPet?.name ?? "none")")
    }
    
    func saveUserPreferences() {
        coreDataManager.saveUserPreferences(
            userName: userName.isEmpty ? nil : userName,
            pet: userPet,
            isOnboarding: isOnboarding,
            averageScreenTimeHours: averageScreenTimeHours
        )
    }
    
    // MARK: - Data Loading Methods
    
    private func loadUserProfile() {
        let userProfile = coreDataManager.getOrCreateUserProfile()
        previousStreak = currentStreak // Store previous before updating
        currentStreak = Int(userProfile.currentStreak)
        longestStreak = Int(userProfile.longestStreak)
        hasActiveSubscription = userProfile.hasActiveSubscription
    }
    
    func loadCurrentWeekData() {
        // Perform daily reset check first
        coreDataManager.performDailyResetIfNeeded()
        
        let weeklyPlan = coreDataManager.getOrCreateCurrentWeeklyPlan()
        updatePetHealth() // Update pet health based on usage
        
        // Re-setup monitoring (individual apps will be blocked if limits exceeded)
        if isScreenTimeAuthorized && !isOnboarding {
            screenTimeService.checkAndUpdateAppBlocking()
        }
        
        // Calculate week progress (0.0 to 1.0)
        let startOfWeek = weeklyPlan.startDate ?? Date()
        let endOfWeek = weeklyPlan.endDate ?? Date()
        let now = Date()
        
        if now >= startOfWeek && now <= endOfWeek {
            let totalDuration = endOfWeek.timeIntervalSince(startOfWeek)
            let elapsedDuration = now.timeIntervalSince(startOfWeek)
            weekProgress = totalDuration > 0 ? min(1.0, max(0.0, elapsedDuration / totalDuration)) : 0.0
        } else {
            weekProgress = 0.0
        }
    }
    
    func loadAppGoals() {
        // Throttle rapid calls - prevent calling more than once per 2 seconds
        let now = Date()
        guard now.timeIntervalSince(lastLoadAppGoalsTime) >= loadAppGoalsThrottleInterval else {
            return // Skip if called too recently
        }
        lastLoadAppGoalsTime = now
        
        // ✅ Apply any pending name updates from extension FIRST
        applyPendingGoalNameUpdates()
        
        // Clean up expired restrictions before loading
        cleanupExpiredRestrictions()
        
        // Clean up mock apps that don't have Screen Time tokens
        coreDataManager.cleanupMockApps()
        
        // ✅ Sync usage from shared container (written by monitor extension) BEFORE loading goals
        // This ensures we have the latest usage data when displaying limits
        screenTimeService.syncUsageFromSharedContainer()
        
        // ✅ Ensure extension has our selections
        screenTimeService.saveAllMonitoredSelectionsToSharedContainer()
        
        let goals = coreDataManager.getActiveAppGoals()
        
        userGoals = goals.map { goal in
            UserGoal(
                id: goal.id ?? UUID(),
                appName: goal.appName ?? "",
                dailyLimit: Int(goal.dailyLimitMinutes),
                currentUsage: getCurrentUsage(for: goal),
                isActive: goal.isActive
            )
        }
        
        // ✅ NEW: Load from AppLimitStorage (ApplicationToken-based system)
        let storage = AppLimitStorage.shared
        let appLimits = storage.loadAppLimits()
        
        // Convert AppLimits to MonitoredApp format
        var newMonitoredApps: [MonitoredApp] = []
        
        for limit in appLimits where limit.isEnabled {
            let usageMinutes = storage.getUsageMinutes(limitId: limit.id)
            
            newMonitoredApps.append(MonitoredApp(
                name: limit.appName.isEmpty ? "App" : limit.appName,
                icon: "app.fill",
                dailyLimit: limit.dailyLimitMinutes,
                usedToday: usageMinutes,
                color: getAppColor(for: limit.appName),
                isEnabled: limit.isEnabled,
                tokenHash: limit.id.uuidString,
                limitId: limit.id
            ))
        }
        
        // Also include legacy Core Data goals for backward compatibility
        let screenTimeService = ScreenTimeService.shared
        for goal in goals {
            let identifier = goal.appBundleID ?? ""
            
            // Skip if already loaded from AppLimitStorage
            if UUID(uuidString: identifier) != nil {
                continue
            }
            
            // EXCLUDE "All Categories Tracking"
            if identifier == "com.se7en.allcategories" {
                continue
            }
            
            // ONLY show apps that have Screen Time tokens
            guard !identifier.isEmpty, screenTimeService.hasSelection(for: identifier) else {
                continue
            }
            
            let effectiveLimit = coreDataManager.getEffectiveDailyLimit(for: identifier)
            let customName = goal.appName ?? ""
            
            newMonitoredApps.append(MonitoredApp(
                name: customName.isEmpty ? "App" : customName,
                icon: "app.fill",
                dailyLimit: effectiveLimit,
                usedToday: getCurrentUsage(for: goal),
                color: getAppColor(for: customName),
                isEnabled: goal.isActive,
                tokenHash: identifier
            ))
        }
        
        monitoredApps = newMonitoredApps
        
        // Data loaded
        
        // Convert to AppUsage format for dashboard display
        appUsage = userGoals.map { goal in
            let usage = goal.currentUsage
            let limit = goal.dailyLimit
            let status: AppUsage.UsageStatus
            
            if usage >= limit {
                status = .exceeded
            } else if Double(usage) / Double(limit) >= 0.8 {
                status = .warning
            } else {
                status = .withinLimit
            }
            
            return AppUsage(
                id: goal.id,
                appName: goal.appName,
                icon: getAppIcon(for: goal.appName),
                timeSpent: usage,
                limit: limit,
                status: status
            )
        }
    }
    
    /// Get current usage for a goal - uses AppLimitStorage with ApplicationToken
    private func getCurrentUsage(for goal: AppGoal) -> Int {
        let identifier = goal.appBundleID ?? ""
        guard !identifier.isEmpty else { return 0 }
        
        // ✅ PRIORITY 1: Try to get usage from AppLimitStorage (new system with UUID)
        if let limitId = UUID(uuidString: identifier) {
            let usage = AppLimitStorage.shared.getUsageMinutes(limitId: limitId)
            if usage > 0 { return usage }
        }
        
        // ✅ PRIORITY 2: Fallback to legacy hash-based system
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return 0 }
        
        sharedDefaults.synchronize()
        applyPendingGoalNameUpdates()
        
        // Try direct lookup with stored token hash
        var usage = sharedDefaults.integer(forKey: "usage_\(identifier)")
        if usage > 0 { return usage }
        
        // Try hash mapping
        if let hashMapping = sharedDefaults.dictionary(forKey: "token_hash_mapping") as? [String: String],
           let mappedHash = hashMapping[identifier] {
            usage = sharedDefaults.integer(forKey: "usage_\(mappedHash)")
            if usage > 0 { return usage }
        }
        
        // Try per_token_hash_usage dictionary
        if let perTokenUsage = sharedDefaults.dictionary(forKey: "per_token_hash_usage") as? [String: Int] {
            if let tokenUsage = perTokenUsage[identifier], tokenUsage > 0 {
                return tokenUsage
            }
        }
        
        // ✅ PRIORITY 3: Match by app name (fallback)
        let appName = goal.appName ?? ""
        if !appName.isEmpty {
            let normalizedName = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try name-to-hash mapping
            if let nameToHash = sharedDefaults.dictionary(forKey: "app_name_to_hash") as? [String: String],
               let nameHash = nameToHash[normalizedName] {
                usage = sharedDefaults.integer(forKey: "usage_\(nameHash)")
                if usage > 0 { return usage }
            }
            
            // Try per_app_usage dictionary
            if let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int] {
                for (reportAppName, reportUsage) in perAppUsage {
                    let normalizedReportName = reportAppName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if normalizedReportName == normalizedName || normalizedReportName.contains(normalizedName) || normalizedName.contains(normalizedReportName) {
                        return reportUsage
                    }
                }
            }
        }
        
        // PRIORITY 4: Try to compute hash from stored selection and match
        if let selection = screenTimeService.getSelection(for: identifier),
           let firstToken = selection.applicationTokens.first {
            let computedHash = String(firstToken.hashValue)
            if computedHash != identifier {
                usage = sharedDefaults.integer(forKey: "usage_\(computedHash)")
                if usage > 0 { return usage }
            }
        }
        
        return 0
    }
    
    /// ✅ NEW: Apply pending name updates from extension
    private func applyPendingGoalNameUpdates() {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        guard let pendingUpdates = sharedDefaults.dictionary(forKey: "pending_goal_name_updates") as? [String: String],
              !pendingUpdates.isEmpty else {
            return
        }
        
        let goals = coreDataManager.getActiveAppGoals()
        var applied = false
        
        for (tokenHash, appName) in pendingUpdates {
            if let goal = goals.first(where: { $0.appBundleID == tokenHash }) {
                if goal.appName?.isEmpty ?? true {
                    goal.appName = appName
                    applied = true
                }
            }
        }
        
        if applied {
            coreDataManager.save()
            // Clear pending updates
            sharedDefaults.removeObject(forKey: "pending_goal_name_updates")
            sharedDefaults.synchronize()
        }
    }
    
    private func getAppIcon(for appName: String) -> String {
        // Use generic app icon - Screen Time API provides real app icons
        return "app.circle.fill"
    }
    
    private func cleanupExpiredRestrictions() {
        let goals = coreDataManager.getActiveAppGoals()
        let now = Date()
        
        for goal in goals {
            guard let bundleID = goal.appBundleID else { continue }
            
            // Check if restriction has expired
            if let endDate = UserDefaults.standard.object(forKey: "restrictionEndDate_\(bundleID)") as? Date,
               now >= endDate {
                let restrictionPeriod = UserDefaults.standard.string(forKey: "restrictionPeriod_\(bundleID)") ?? ""
                
                if restrictionPeriod == "One-time" || restrictionPeriod == "Weekly" {
                    // Clean up expired restrictions
                    UserDefaults.standard.removeObject(forKey: "restrictionPeriod_\(bundleID)")
                    UserDefaults.standard.removeObject(forKey: "restrictionLimit_\(bundleID)")
                    UserDefaults.standard.removeObject(forKey: "restrictionStartDate_\(bundleID)")
                    UserDefaults.standard.removeObject(forKey: "restrictionEndDate_\(bundleID)")
                    print("🧹 Cleaned up expired \(restrictionPeriod) restriction for \(goal.appName ?? bundleID)")
                }
            }
        }
    }
    
    private func getAppColor(for appName: String) -> Color {
        // Use generic primary color - Screen Time API provides real app data
        return Color.primary
    }
    
    private func loadUnlockedAchievements() {
        let records = coreDataManager.getUnlockedAchievements()
        unlockedAchievements = records.map { $0.achievementID ?? "" }
    }
    
    private func loadDailyHistory() {
        // Load daily history from current weekly plan
        if let weeklyPlan = coreDataManager.getCurrentWeeklyPlan() {
            dailyHistory = coreDataManager.getDailyHistory(for: weeklyPlan)
        } else {
            dailyHistory = []
        }
    }
    
    func loadAchievements() {
        // Load real achievements - all achievements are defined, unlock status is checked dynamically
        achievements = Achievement.allAchievements
    }
    
    // MARK: - Achievement System
    
    func checkAchievements() {
        for achievement in achievements {
            if !unlockedAchievements.contains(achievement.id) && achievement.isUnlocked(self) {
                unlockAchievement(achievement.id)
            }
        }
    }
    
    func unlockAchievement(_ achievementId: String) {
        guard !unlockedAchievements.contains(achievementId) else { return }
        
        // Save to Core Data
        _ = coreDataManager.unlockAchievement(achievementID: achievementId)
        
        // Update local state
        unlockedAchievements.append(achievementId)
        
        // Trigger celebration
        if let achievement = achievements.first(where: { $0.id == achievementId }) {
            newAchievement = achievement
            shouldShowAchievementCelebration = true
            notificationService.sendAchievementUnlockedNotification(achievementTitle: achievement.title)
            print("🏆 Achievement Unlocked: \(achievement.title)")
        }
        
        // Trigger haptic feedback
        HapticFeedback.success.trigger()
    }
    
    // MARK: - App Goal Management
    
    func addAppGoal(appName: String, bundleID: String, dailyLimitMinutes: Int) {
        print("🔍 Adding app goal: \(appName) with limit: \(dailyLimitMinutes) minutes")
        
        let newGoal = coreDataManager.createAppGoal(
            appName: appName,
            bundleID: bundleID,
            dailyLimitMinutes: dailyLimitMinutes
        )
        
        print("✅ Created app goal with ID: \(newGoal.id?.uuidString ?? "nil")")
        
        // Refresh local data
        loadAppGoals()
        
        print("📱 Total monitored apps after refresh: \(monitoredApps.count)")
        print("🎯 Total user goals after refresh: \(userGoals.count)")
        
        // Update onboarding status if this is the first app
        checkOnboardingStatus()
        
        checkAchievements()
    }
    
    // MARK: - Screen Time Integration
    
    func requestScreenTimeAuthorization() async {
        await screenTimeService.requestAuthorization()
    }
    
    func addAppGoalFromFamilySelection(_ selection: FamilyActivitySelection, appName: String, dailyLimitMinutes: Int, bundleID: String? = nil) {
        print("🎯 Adding app goal from Family Activity selection: \(appName)")
        
        // ✅ Generate stable ID if not provided (using app.name.xxx format)
        let finalBundleID = bundleID ?? "app.name.\(appName.lowercased().replacingOccurrences(of: " ", with: "."))"
        print("📝 Using stable ID: \(finalBundleID)")
        
        // ✅ No validation needed - just add it!
        screenTimeService.addAppForMonitoring(
            selection: selection,
            appName: appName,
            bundleID: finalBundleID,
            dailyLimitMinutes: dailyLimitMinutes
        )
        
        // Refresh local data
        loadAppGoals()
        
        // Update onboarding status
        checkOnboardingStatus()
        
        checkAchievements()
    }
    
    func updateAppGoal(_ goalId: UUID, dailyLimitMinutes: Int) {
        let goals = coreDataManager.getActiveAppGoals()
        if let goal = goals.first(where: { $0.id == goalId }) {
            coreDataManager.updateAppGoal(goal, dailyLimitMinutes: dailyLimitMinutes)
            loadAppGoals()
        }
    }
    
    func deleteAppGoal(_ goalId: UUID) {
        let goals = coreDataManager.getActiveAppGoals()
        if let goal = goals.first(where: { $0.id == goalId }) {
            // Remove from Screen Time service
            if let bundleID = goal.appBundleID {
                screenTimeService.removeApp(bundleID: bundleID)
            }
            coreDataManager.deleteAppGoal(goal)
            loadAppGoals()
        }
    }
    
    // MARK: - Subscription Management
    
    func updateSubscriptionStatus(_ isActive: Bool) {
        let userProfile = coreDataManager.getOrCreateUserProfile()
        userProfile.hasActiveSubscription = isActive
        userProfile.updatedAt = Date()
        coreDataManager.save()
        
        hasActiveSubscription = isActive
        saveUserPreferences() // Also save preferences
    }
    
    
    // MARK: - Streak Management
    
    func updateStreak() {
        // Streak is now updated automatically during daily reset
        // This function is kept for compatibility but just loads the current streak
        let userProfile = coreDataManager.getOrCreateUserProfile()
        previousStreak = currentStreak
        currentStreak = Int(userProfile.currentStreak)
        
        // Check if streak increased (for celebration)
        if currentStreak > previousStreak {
            newStreakValue = currentStreak
            shouldShowStreakCelebration = true
            notificationService.sendStreakMilestoneNotification(streak: currentStreak)
        }
        
        loadUserProfile()
    }
    
    // MARK: - Onboarding
    
    func completeOnboarding() {
        isOnboarding = false
        saveUserPreferences() // Persist onboarding completion
        print("✅ Onboarding completed - saved isOnboarding = false")
    }
    
    // MARK: - Week Management
    
    func resetWeek() {
        // Weekly reset
        Task {
            screenTimeService.performWeeklyReset()
        }
        loadCurrentWeekData()
        loadAppGoals()
        loadDailyHistory() // Reload history after week reset
        updateStreak()
        checkAchievements()
    }
    
    // MARK: - Screen Time Authorization
    // (Authorization method moved to Screen Time Integration section above)
    
    // MARK: - Data Refresh
    
    func refreshData() {
        // Skip refresh during onboarding to prevent performance issues
        guard !isOnboarding else { return }
        
        // Perform refresh operations more efficiently
        loadUserProfile()
        loadCurrentWeekData()
        loadAppGoals()
        loadUnlockedAchievements()
        loadDailyHistory()
        checkAchievements()
        
        // Refresh Screen Time usage data if authorized - move to background
        if isScreenTimeAuthorized {
            Task {
                // Refresh usage for all monitored apps
                await screenTimeService.refreshAllAppUsage()
                
                // Reload app goals after usage refresh on main thread
                await MainActor.run {
                    self.loadAppGoals()
                }
            }
        }
    }
    
    // Refresh screen time data specifically (for dashboard)
    func refreshScreenTimeData() {
        guard isScreenTimeAuthorized else { return }
        
        Task {
            await screenTimeService.refreshAllAppUsage()
            await MainActor.run {
                self.loadAppGoals()
            }
        }
    }
    
    func syncDataFromBackground() {
        // Called when app returns from background
        // Reload all data to ensure it's up to date
        loadUserPreferences()
        refreshData()
        
        // Refresh screen time data
        refreshScreenTimeData()
    }
    
    
    // MARK: - Pet Health Management
    
    func updatePetHealth() {
        guard var pet = userPet else { return }
        
        // ⚠️ CRITICAL: If shared container is empty, trigger a refresh from report extension
        // This ensures we have the latest data before calculating health
        let appGroupID = "group.com.se7en.app"
        if let sharedDefaults = UserDefaults(suiteName: appGroupID), !isRefreshingPetHealth {
            sharedDefaults.synchronize()
            let totalUsage = sharedDefaults.integer(forKey: "total_usage")
            let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int]
            
            // If both are empty, trigger async refresh (but don't wait - calculate with what we have)
            if totalUsage == 0 && (perAppUsage?.isEmpty ?? true) && isScreenTimeAuthorized {
                isRefreshingPetHealth = true
                Task {
                    // Trigger report extension to refresh data
                    await screenTimeService.updateUsageFromReport()
                    // Small delay for extension to write to shared container
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    // Recalculate health after data is refreshed
                    await MainActor.run {
                        self.isRefreshingPetHealth = false
                        self.updatePetHealth()
                    }
                }
                // Return early - will recalculate after refresh
                return
            }
        }
        
        // Calculate pet health based on app usage percentages
        let healthPercentage = calculatePetHealthPercentage()
        
        // Convert health percentage to PetHealthState
        let newHealthState: PetHealthState
        switch healthPercentage {
        case 90...100:
            newHealthState = .fullHealth
        case 70..<90:
            newHealthState = .happy
        case 50..<70:
            newHealthState = .content
        case 20..<50:
            newHealthState = .sad
        default:
            newHealthState = .sick
        }
        
        // Only update if health state changed
        if pet.healthState != newHealthState {
            pet.healthState = newHealthState
            userPet = pet
            saveUserPreferences() // Persist pet health state
            
            // Send notification about pet health change
            if newHealthState == .sick {
                NotificationService.shared.sendPetHealthAlert(
                    petName: pet.name,
                    healthState: newHealthState
                )
            }
        }
    }
    
    /// Calculate pet health based on daily screen time
    func calculatePetHealthPercentage() -> Int {
        var totalMinutes = todayScreenTimeMinutes
        
        if totalMinutes == 0 {
            let appGroupID = "group.com.se7en.app"
            if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
                sharedDefaults.synchronize()
                totalMinutes = sharedDefaults.integer(forKey: "total_usage")
                if totalMinutes > 0 {
                    self.todayScreenTimeMinutes = totalMinutes
                }
            }
        }
        
        let totalHours = Double(totalMinutes) / 60.0
        
        let healthPercentage: Int
        switch totalHours {
        case 0..<2: healthPercentage = 100
        case 2..<3: healthPercentage = Int(100.0 - (20.0 * (totalHours - 2.0)))
        case 3..<4: healthPercentage = Int(80.0 - (10.0 * (totalHours - 3.0)))
        case 4..<5: healthPercentage = Int(70.0 - (10.0 * (totalHours - 4.0)))
        case 5..<6: healthPercentage = Int(60.0 - (20.0 * (totalHours - 5.0)))
        case 6..<8: healthPercentage = Int(40.0 - (10.0 * (totalHours - 6.0)))
        case 8..<10: healthPercentage = Int(20.0 - (10.0 * (totalHours - 8.0)))
        default: healthPercentage = 0
        }
        
        return max(0, min(100, healthPercentage))
    }
    
    /// Helper function for linear interpolation between ranges
    private func linearInterpolate(
        value: Double,
        fromRange: (Double, Double),
        toRange: (Double, Double)
    ) -> Double {
        let (fromMin, fromMax) = fromRange
        let (toMin, toMax) = toRange
        let ratio = (value - fromMin) / (fromMax - fromMin)
        return toMin + (toMax - toMin) * ratio
    }
    
    /// Get total screen time from the shared container (populated by DeviceActivityReport extension)
    /// This is the same source the dashboard uses for total screen time display
    /// Handles both individual apps AND category-based selections by summing all usage
    private func getTotalScreenTimeFromSharedContainer() -> Int {
        let appGroupID = "group.com.se7en.app"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ Pet health: Failed to access shared container, falling back to monitored apps")
            // Fallback to monitored apps if shared container unavailable
            return monitoredApps
                .filter { $0.isEnabled }
                .reduce(0) { $0 + $1.usedToday }
        }
        
        // Force synchronize to get latest data (same as dashboard does)
        sharedDefaults.synchronize()
        
        // Read total usage from shared container (same key as DashboardView)
        let totalUsage = sharedDefaults.integer(forKey: "total_usage")
        
        if totalUsage > 0 {
            print("📊 Pet health using total_usage from shared container: \(totalUsage) minutes")
            return totalUsage
        }
        
        // ⚠️ CRITICAL FIX: If total_usage is 0 but per_app_usage exists, sum it
        // This handles cases where the extension wrote per-app data but total_usage wasn't set
        // This is especially important for category-based selections where all apps are tracked
        if let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int] {
            let sumFromPerApp = perAppUsage.values.reduce(0, +)
            if sumFromPerApp > 0 {
                print("📊 Pet health using per_app_usage sum: \(sumFromPerApp) minutes (total_usage was 0)")
                // Also update total_usage for future reads
                sharedDefaults.set(sumFromPerApp, forKey: "total_usage")
                sharedDefaults.synchronize()
                return sumFromPerApp
            }
        }
        
        // Fallback to monitored apps if shared container has no data
        let monitoredTotal = monitoredApps
            .filter { $0.isEnabled }
            .reduce(0) { $0 + $1.usedToday }
        
        if monitoredTotal > 0 {
            print("📊 Pet health falling back to monitored apps: \(monitoredTotal) minutes")
        } else {
            print("⚠️ Pet health: No screen time data found (shared container empty, no monitored apps)")
        }
        
        return monitoredTotal
    }
    
    func setUserPet(_ pet: Pet) {
        userPet = pet
        saveUserPreferences()
    }
    
    func setUserName(_ name: String) {
        userName = name
        saveUserPreferences()
    }
}