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
    static let petChanged = Notification.Name("petChanged")
}

// MARK: - Performance Optimization Data Structures

private struct CombinedAppData {
    let currentStreak: Int
    let longestStreak: Int
    let hasActiveSubscription: Bool
    let weekProgress: Double
    let userGoals: [UserGoal]
    let monitoredApps: [MonitoredApp]
    let unlockedAchievements: [String]
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
    
    /// Preload screen time from shared container (called on app launch and foreground)
    func preloadScreenTimeFromSharedContainer() {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // CRITICAL: Force synchronize to read fresh data from disk
        sharedDefaults.synchronize()
        
        let previousValue = self.todayScreenTimeMinutes
        var newValue = 0
        
        // Source 1: total_usage key (primary)
        let totalUsage = sharedDefaults.integer(forKey: "total_usage")
        if totalUsage > 0 {
            newValue = totalUsage
            #if DEBUG
            print("📱 AppState: Using total_usage: \(totalUsage) minutes")
            #endif
        }
        
        // Source 2: Sum from per_app_usage (fallback)
        if newValue == 0 {
            if let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") {
                let sumFromPerApp = perAppUsage.values.reduce(0) { partial, value in
                    if let intValue = value as? Int { return partial + intValue }
                    if let numberValue = value as? NSNumber { return partial + numberValue.intValue }
                    if let doubleValue = value as? Double { return partial + Int(doubleValue) }
                    return partial
                }
                if sumFromPerApp > 0 {
                    newValue = sumFromPerApp
                    #if DEBUG
                    print("📱 AppState: Using per_app_usage sum: \(sumFromPerApp) minutes")
                    #endif
                }
            }
        }
        
        // Source 3: JSON backup file (second fallback)
        if newValue == 0 {
            let fileUsage = readTotalUsageFromSharedFileBackup(appGroupID: appGroupID)
            if fileUsage > 0 {
                newValue = fileUsage
                #if DEBUG
                print("📱 AppState: Using JSON file backup: \(fileUsage) minutes")
                #endif
            }
        }
        
        // Update only if we have data
        if newValue > 0 && newValue != previousValue {
            #if DEBUG
            print("📱 AppState: Updating todayScreenTimeMinutes from \(previousValue) to \(newValue)")
            #endif
            self.todayScreenTimeMinutes = newValue
            
            // CRITICAL: Update pet health when screen time changes
            updatePetHealth()
        } else if newValue == 0 {
            #if DEBUG
            print("📱 AppState: No screen time data found - pet health will show 100%")
            #endif
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
    
    // MARK: - Performance Optimization Variables
    private var lastDataRefresh: Date = Date.distantPast
    private var lastUIUpdate: Date = Date.distantPast
    private var isRefreshing = false
    private let minRefreshInterval: TimeInterval = 10.0 // Minimum 10 seconds between refreshes
    private let minUIUpdateInterval: TimeInterval = 2.0 // Minimum 2 seconds between UI updates
    
    private func setupObservers() {
        // Observe Screen Time authorization status
        screenTimeService.$isAuthorized
            .assign(to: \.isScreenTimeAuthorized, on: self)
            .store(in: &cancellables)
        
        // 🚀 OPTIMIZED: Much less frequent background refresh (every 10 minutes)
        Timer.publish(every: 600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performThrottledRefresh()
            }
            .store(in: &cancellables)
        
        // 🚀 OPTIMIZED: Only refresh on app foreground with throttling
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performForegroundRefresh()
            }
            .store(in: &cancellables)
        
        // 🚀 OPTIMIZED: Debounced Screen Time data updates
        NotificationCenter.default.publisher(for: .screenTimeDataUpdated)
            .debounce(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performLightweightUpdate()
            }
            .store(in: &cancellables)
    }
    
    // 🚀 OPTIMIZED: Throttled refresh that prevents excessive calls
    private func performThrottledRefresh() {
        let now = Date()
        guard !isRefreshing && now.timeIntervalSince(lastDataRefresh) >= minRefreshInterval else {
            return
        }
        
        lastDataRefresh = now
        isRefreshing = true
        
        // Perform lightweight background refresh
        Task {
            await performBackgroundDataSync()
            await MainActor.run {
                self.isRefreshing = false
            }
        }
    }
    
    // 🚀 OPTIMIZED: Foreground refresh with intelligent caching
    private func performForegroundRefresh() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        Task {
            // First, sync critical data quickly
            await performCriticalDataSync()
            
            // Then, update UI if needed
            await MainActor.run {
                self.updateCriticalUIElements()
                self.isRefreshing = false
            }
        }
    }
    
    // 🚀 OPTIMIZED: Lightweight update for real-time changes
    private func performLightweightUpdate() {
        let now = Date()
        guard now.timeIntervalSince(lastUIUpdate) >= minUIUpdateInterval else {
            return
        }
        
        lastUIUpdate = now
        
        // Only update essential UI elements
        Task {
            await performUsageDataSync()
            await MainActor.run {
                self.updateCriticalUIElements()
            }
        }
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
    
    /// Check for pending puzzles from shield action and show them
    func checkForPendingPuzzles() {
        let appGroupID = "group.com.se7en.app"
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // ✅ First check: Direct puzzleMode flag (set by shield action)
        if defaults.bool(forKey: "puzzleMode") || defaults.bool(forKey: "shouldOpenPuzzle") {
            if let tokenHash = defaults.string(forKey: "puzzleTokenHash") {
                let appName = defaults.string(forKey: "puzzleAppName_\(tokenHash)") ?? "App"
                
                print("🎯 AppState: Found pending puzzle via puzzleMode flag")
                print("   - tokenHash: \(tokenHash.prefix(8))...")
                print("   - appName: \(appName)")
                
                // Post notification to show puzzle (ContentView listens to this)
                NotificationCenter.default.post(
                    name: .appBlocked,
                    object: nil,
                    userInfo: [
                        "appName": appName,
                        "bundleID": tokenHash,
                        "puzzleMode": true
                    ]
                )
                return
            }
        }
        
        // ✅ Second check: needsPuzzle_ flags (legacy/fallback)
        var pendingTokenHashes: [String] = []
        let allKeys = Array(defaults.dictionaryRepresentation().keys)
        for key in allKeys where key.hasPrefix("needsPuzzle_") {
            if defaults.bool(forKey: key) {
                let tokenHash = String(key.dropFirst("needsPuzzle_".count))
                pendingTokenHashes.append(tokenHash)
            }
        }
        
        guard !pendingTokenHashes.isEmpty else { return }
        
        // Find the first pending puzzle and show it
        for tokenHash in pendingTokenHashes {
            // Try to get app name from stored value
            let storedName = defaults.string(forKey: "puzzleAppName_\(tokenHash)") ?? "App"
            
            // ✅ Set puzzleMode flags so ContentView can detect it
            defaults.set(true, forKey: "puzzleMode")
            defaults.set(tokenHash, forKey: "puzzleTokenHash")
            defaults.set(storedName, forKey: "puzzleAppName_\(tokenHash)")
            defaults.synchronize()
            
            // Post notification to show puzzle
            NotificationCenter.default.post(
                name: .appBlocked,
                object: nil,
                userInfo: [
                    "appName": storedName,
                    "bundleID": tokenHash,
                    "puzzleMode": true
                ]
            )
            
            // Clear the needsPuzzle flag (puzzleMode will be cleared by ContentView)
            defaults.removeObject(forKey: "needsPuzzle_\(tokenHash)")
            defaults.synchronize()
            
            print("🎯 AppState: Showing puzzle for \(storedName) (from needsPuzzle flag)")
            return
        }
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
        
        // Save pet info to shared container for report extensions (critical for "This Week" view)
        if let pet = userPet {
            let appGroupID = "group.com.se7en.app"
            if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
                sharedDefaults.set(pet.type.rawValue, forKey: "user_pet_type")
                sharedDefaults.set(pet.name, forKey: "user_pet_name")
                sharedDefaults.set(pet.healthState.rawValue, forKey: "user_pet_health_state")
                sharedDefaults.synchronize()
                print("💾 AppState: Loaded and synced pet type '\(pet.type.rawValue)' to shared container")
            }
        }
        
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
        
        // Save pet info to shared container for report extensions
        if let pet = userPet {
            let appGroupID = "group.com.se7en.app"
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
            sharedDefaults.set(pet.type.rawValue, forKey: "user_pet_type")
            sharedDefaults.set(pet.name, forKey: "user_pet_name")
            sharedDefaults.set(pet.healthState.rawValue, forKey: "user_pet_health_state")
            sharedDefaults.synchronize()
            print("💾 AppState: Saved pet type '\(pet.type.rawValue)' to shared container")
        }
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
    
    // 🚀 OPTIMIZED: Dramatically improved loadAppGoals with intelligent caching
    private var lastGoalsHash: Int = 0
    private var cachedGoals: [AppGoal] = []
    private var lastUsageSync: Date = Date.distantPast
    
    func loadAppGoals() {
        // 🚀 PERFORMANCE: Much more aggressive throttling
        let now = Date()
        guard now.timeIntervalSince(lastLoadAppGoalsTime) >= loadAppGoalsThrottleInterval else {
            return
        }
        lastLoadAppGoalsTime = now
        
        // 🚀 OPTIMIZATION: Only do expensive operations if really needed
        performOptimizedGoalsLoading()
    }
    
    private func performOptimizedGoalsLoading() {
        // 🚀 FAST PATH: Only sync usage if it's been more than 30 seconds
        let now = Date()
        let shouldSyncUsage = now.timeIntervalSince(lastUsageSync) >= 30.0
        
        if shouldSyncUsage {
        screenTimeService.syncUsageFromSharedContainer()
            lastUsageSync = now
        }
        
        // 🚀 FAST PATH: Use cached goals if they haven't changed
        let goals = coreDataManager.getActiveAppGoals()
        let currentGoalsHash = calculateGoalsHash(goals)
        
        let goalsChanged = currentGoalsHash != lastGoalsHash
        if goalsChanged {
            lastGoalsHash = currentGoalsHash
            cachedGoals = goals
            
            // Only do expensive operations if goals actually changed
            performExpensiveGoalsOperations()
        }
        
        // 🚀 ALWAYS UPDATE: Usage data (fast operation)
        updateGoalsUsageData(goals: cachedGoals)
        
        // 🚀 CONDITIONAL: Only do cleanup operations occasionally
        if goalsChanged {
            performPeriodicMaintenance()
        }
    }
    
    private func performExpensiveGoalsOperations() {
        // These operations only run when goals actually change
        applyPendingGoalNameUpdates()
        screenTimeService.saveAllMonitoredSelectionsToSharedContainer()
    }
    
    private func updateGoalsUsageData(goals: [AppGoal]) {
        // 🚀 FAST: Only update usage-related data
        userGoals = convertGoalsToUserGoals(goals)
        monitoredApps = convertGoalsToMonitoredApps(goals)
        
        // 🚀 FAST: Update app usage array
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
        
        // 🚀 PERFORMANCE: Async blocking update to avoid blocking UI
        _ = Task.detached(priority: .utility) {
            await self.updateAppBlockingIfNeededAsync(goals: goals)
        }
    }
    
    private func performPeriodicMaintenance() {
        // 🚀 BACKGROUND: Move expensive cleanup to background queue
        _ = Task.detached(priority: .utility) {
            await MainActor.run {
                self.cleanupExpiredRestrictions()
                self.coreDataManager.cleanupMockApps()
            }
        }
    }
    
    // 🚀 PERFORMANCE: Fast hash calculation to detect goals changes
    private func calculateGoalsHash(_ goals: [AppGoal]) -> Int {
        var hasher = Hasher()
        for goal in goals {
            hasher.combine(goal.id)
            hasher.combine(goal.appName)
            hasher.combine(goal.dailyLimitMinutes)
            hasher.combine(goal.isActive)
        }
        return hasher.finalize()
    }
    
    // 🚀 PERFORMANCE: Async version of blocking update
    private func updateAppBlockingIfNeededAsync(goals: [AppGoal]) async {
        // This runs in background to avoid blocking UI
        await MainActor.run {
            self.updateAppBlockingIfNeeded(goals: goals)
        }
    }
    
    // 🚀 OPTIMIZED: Update app blocking status efficiently
    private func updateAppBlockingIfNeeded(goals: [AppGoal]) {
        // Delegate to ScreenTimeService for actual blocking logic
        screenTimeService.checkAndUpdateAppBlocking()
    }
    
    /// Get current usage for a goal - bulletproof matching with multiple fallbacks
    /// ✅ FIXED: Prioritize per_app_usage (same source as dashboard) for consistency
    private func getCurrentUsage(for goal: AppGoal) -> Int {
        let tokenHash = goal.appBundleID ?? ""
        let appName = goal.appName ?? ""
        guard !tokenHash.isEmpty else { return 0 }
        
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return 0 }
        
        sharedDefaults.synchronize()
        applyPendingGoalNameUpdates()
        
        var usage: Int = 0
        
        // ✅ PRIORITY 1 (NEW): Direct lookup from per_app_usage by app name
        // This is the SAME source the dashboard uses, so it ensures consistency
        // The DeviceActivityReport extension writes usage keyed by app display name
        if !appName.isEmpty {
            let normalizedName = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int] {
                // Try exact match first
                if let exactMatch = perAppUsage[appName], exactMatch > 0 {
                    return exactMatch
                }
                
                // Try normalized/fuzzy match
                for (reportAppName, reportUsage) in perAppUsage {
                    let normalizedReportName = reportAppName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if normalizedReportName == normalizedName ||
                       normalizedReportName.contains(normalizedName) ||
                       normalizedName.contains(normalizedReportName) {
                        if reportUsage > 0 {
                            return reportUsage
                        }
                    }
                }
            }
        }
        
        // PRIORITY 2: Check if token hash is actually a UUID (limit UUID system)
        // Extension writes usage_v2_<UUID> when it matches tokens to limits
        if UUID(uuidString: tokenHash) != nil {
            usage = sharedDefaults.integer(forKey: "usage_v2_\(tokenHash)")
            if usage > 0 { return usage }
        }
        
        // PRIORITY 3: Direct lookup with stored token hash
        usage = sharedDefaults.integer(forKey: "usage_\(tokenHash)")
        if usage > 0 { return usage }
        
        // PRIORITY 4: Check token_hash_to_limit_uuid mapping (extension maps hashes to UUIDs)
        if let hashToUUID = sharedDefaults.dictionary(forKey: "token_hash_to_limit_uuid") as? [String: String],
           let limitUUID = hashToUUID[tokenHash] {
            usage = sharedDefaults.integer(forKey: "usage_v2_\(limitUUID)")
            if usage > 0 { return usage }
        }
        
        // PRIORITY 5: Match by app name using limit_id_to_app_name mapping
        if !appName.isEmpty {
            let normalizedName = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Get name-to-limit mapping from extension
            if let limitIdToName = sharedDefaults.dictionary(forKey: "limit_id_to_app_name") as? [String: String] {
                for (limitUUID, realName) in limitIdToName {
                    let normalizedRealName = realName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if normalizedRealName == normalizedName ||
                       normalizedRealName.contains(normalizedName) ||
                       normalizedName.contains(normalizedRealName) {
                        usage = sharedDefaults.integer(forKey: "usage_v2_\(limitUUID)")
                if usage > 0 { return usage }
                    }
                }
            }
        }
        
        // PRIORITY 6: Try to compute hash from stored selection and match
        if let selection = screenTimeService.getSelection(for: tokenHash),
           let firstToken = selection.applicationTokens.first {
            let computedHash = String(firstToken.hashValue)
            if computedHash != tokenHash {
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
    
    // Public method to refresh daily history (for stats page)
    func refreshDailyHistory() {
        loadDailyHistory()
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
    
    /// Add app goal using the reliable method with user-typed name
    func addAppGoalReliable(
        selection: FamilyActivitySelection,
        appName: String,
        dailyLimitMinutes: Int
    ) {
        addAppGoalFromFamilySelection(
            selection,
            appName: appName,
            dailyLimitMinutes: dailyLimitMinutes
        )
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
    
    // 🚀 LEGACY: Keep for compatibility but mark as deprecated
    func refreshData() {
        performThrottledRefresh()
    }
    
    // 🚀 OPTIMIZED: Background data sync with minimal UI impact
    private func performBackgroundDataSync() async {
        guard !isOnboarding && isScreenTimeAuthorized else { return }
        
        // Only sync usage data from shared container (fast)
        screenTimeService.syncUsageFromSharedContainer()
        
        // Update pet health if needed (lightweight calculation)
        await MainActor.run {
            self.updatePetHealthIfNeeded()
        }
    }
    
    // 🚀 OPTIMIZED: Critical data sync for app foreground
    private func performCriticalDataSync() async {
        guard !isOnboarding else { return }
        
        // Batch all Core Data operations
        let combinedData = await loadCombinedData()
        
        await MainActor.run {
            // Apply all updates at once to minimize UI churn
            self.applyCombinedDataUpdates(combinedData)
        }
        
        // Background Screen Time sync (don't block UI)
        if isScreenTimeAuthorized {
            _ = Task.detached(priority: .utility) {
                await self.screenTimeService.updateUsageFromReport()
            }
        }
    }
    
    // 🚀 OPTIMIZED: Usage data sync without full refresh
    private func performUsageDataSync() async {
        guard isScreenTimeAuthorized else { return }
        
        // Quick sync from shared container only
        screenTimeService.syncUsageFromSharedContainer()
        
                await MainActor.run {
            self.updateUsageRelatedUI()
        }
    }
    
    // 🚀 OPTIMIZED: Combined data loading to reduce Core Data queries
    private func loadCombinedData() async -> CombinedAppData {
        return await Task.detached(priority: .userInitiated) {
            return await MainActor.run {
                let coreDataManager = CoreDataManager.shared
                let profile = coreDataManager.getOrCreateUserProfile()
                let weeklyPlan = coreDataManager.getOrCreateCurrentWeeklyPlan()
                let goals = coreDataManager.getActiveAppGoals()
                let achievements = coreDataManager.getUnlockedAchievements().map { $0.achievementID ?? "" }.filter { !$0.isEmpty }
                
                return CombinedAppData(
                    currentStreak: Int(profile.currentStreak),
                    longestStreak: Int(profile.longestStreak),
                    hasActiveSubscription: profile.hasActiveSubscription,
                    weekProgress: self.calculateWeekProgress(from: weeklyPlan),
                    userGoals: self.convertGoalsToUserGoals(goals),
                    monitoredApps: self.convertGoalsToMonitoredApps(goals),
                    unlockedAchievements: achievements
                )
            }
        }.value
    }
    
    // 🚀 OPTIMIZED: Apply all data updates in one batch
    private func applyCombinedDataUpdates(_ data: CombinedAppData) {
        // Update all properties at once to trigger single UI update
        self.currentStreak = data.currentStreak
        self.longestStreak = data.longestStreak
        self.hasActiveSubscription = data.hasActiveSubscription
        self.weekProgress = data.weekProgress
        self.userGoals = data.userGoals
        self.monitoredApps = data.monitoredApps
        self.unlockedAchievements = data.unlockedAchievements
        
        // Check achievements only if streak changed
        if data.currentStreak != previousStreak {
            checkAchievements()
            previousStreak = data.currentStreak
        }
    }
    
    // 🚀 OPTIMIZED: Update only usage-related UI elements
    private func updateUsageRelatedUI() {
        // Only update monitored apps usage data (fast)
        let goals = coreDataManager.getActiveAppGoals()
        let updatedApps = convertGoalsToMonitoredApps(goals)
        
        // Only update if actually changed
        if !areMonitoredAppsEqual(monitoredApps, updatedApps) {
            monitoredApps = updatedApps
        }
    }
    
    // 🚀 OPTIMIZED: Update only critical UI elements
    private func updateCriticalUIElements() {
        // First sync today's screen time from the shared container so pet health reflects
        // the same "Today" value shown on the dashboard.
        preloadScreenTimeFromSharedContainer()
        
        // Then update pet health (lightweight)
        updatePetHealthIfNeeded()
    }
    
    // 🚀 OPTIMIZED: Only update pet health if data actually changed
    private func updatePetHealthIfNeeded() {
        let newHealthPercentage = calculatePetHealthPercentage()
        
        // Only update if health percentage changed significantly (>5%)
        guard userPet != nil,
              abs(newHealthPercentage - (getPreviousHealthPercentage() ?? 0)) > 5 else {
            return
        }
        
        updatePetHealth()
    }
    
    // Helper to check if monitored apps changed
    private func areMonitoredAppsEqual(_ apps1: [MonitoredApp], _ apps2: [MonitoredApp]) -> Bool {
        guard apps1.count == apps2.count else { return false }
        
        for (app1, app2) in zip(apps1, apps2) {
            if app1.name != app2.name || app1.usedToday != app2.usedToday || app1.dailyLimit != app2.dailyLimit {
                return false
            }
        }
        return true
    }
    
    private var previousHealthPercentage: Int?
    private func getPreviousHealthPercentage() -> Int? {
        return previousHealthPercentage
    }
    
    // MARK: - Optimized Helper Methods
    
    // 🚀 OPTIMIZED: Calculate week progress without creating objects
    private func calculateWeekProgress(from weeklyPlan: WeeklyPlan) -> Double {
        let startOfWeek = weeklyPlan.startDate ?? Date()
        let endOfWeek = weeklyPlan.endDate ?? Date()
        let now = Date()
        
        guard now >= startOfWeek && now <= endOfWeek else { return 0.0 }
        
        let totalDuration = endOfWeek.timeIntervalSince(startOfWeek)
        let elapsedDuration = now.timeIntervalSince(startOfWeek)
        return totalDuration > 0 ? min(1.0, max(0.0, elapsedDuration / totalDuration)) : 0.0
    }
    
    // 🚀 OPTIMIZED: Convert goals to user goals efficiently
    private func convertGoalsToUserGoals(_ goals: [AppGoal]) -> [UserGoal] {
        return goals.map { goal in
            UserGoal(
                id: goal.id ?? UUID(),
                appName: goal.appName ?? "",
                dailyLimit: Int(goal.dailyLimitMinutes),
                currentUsage: getCurrentUsage(for: goal),
                isActive: goal.isActive
            )
        }
    }
    
    // 🚀 OPTIMIZED: Convert goals to monitored apps efficiently
    private func convertGoalsToMonitoredApps(_ goals: [AppGoal]) -> [MonitoredApp] {
        let screenTimeService = ScreenTimeService.shared
        
        return goals.compactMap { goal in
            let tokenHash = goal.appBundleID ?? ""
            
            // EXCLUDE "All Categories Tracking"
            if tokenHash == "com.se7en.allcategories" {
                return nil
            }
            
            // ONLY show apps that have Screen Time tokens
            guard !tokenHash.isEmpty, screenTimeService.hasSelection(for: tokenHash) else {
                return nil
            }
            
            let effectiveLimit = coreDataManager.getEffectiveDailyLimit(for: tokenHash)
            let customName = goal.appName ?? ""
            
            return MonitoredApp(
                name: customName.isEmpty ? "App" : customName,
                icon: "app.fill",
                dailyLimit: effectiveLimit,
                usedToday: getCurrentUsage(for: goal),
                color: getAppColor(for: customName),
                isEnabled: goal.isActive,
                tokenHash: tokenHash
            )
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
        // Track last known health percentage for throttling decisions
        previousHealthPercentage = healthPercentage
        
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
        
        // Save daily health snapshot for stats page
        saveDailyHealthSnapshot(healthPercentage: healthPercentage, mood: newHealthState)
    }
    
    /// Save daily pet health snapshot for weekly stats
    private func saveDailyHealthSnapshot(healthPercentage: Int, mood: PetHealthState) {
            let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // Get today's date key
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())
        
        // Load existing daily health history
        var dailyHealth = sharedDefaults.dictionary(forKey: "daily_health") as? [String: [String: Any]] ?? [:]
        
        // Update today's health
        dailyHealth[todayKey] = [
            "score": healthPercentage,
            "mood": mood.rawValue
        ]
        
        // Keep only last 30 days
        let calendar = Calendar.current
        if let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) {
            let cutoffKey = dateFormatter.string(from: thirtyDaysAgo)
            dailyHealth = dailyHealth.filter { key, _ in
                key >= cutoffKey
            }
        }
        
        // Save back
        sharedDefaults.set(dailyHealth, forKey: "daily_health")
        sharedDefaults.synchronize()
    }
    
    /// Calculate pet health based on daily screen time
    func calculatePetHealthPercentage() -> Int {
        // ALWAYS sync from shared container first to get latest data
        let appGroupID = "group.com.se7en.app"
        var freshTotalMinutes = 0
        
        // Source 1: UserDefaults total_usage
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.synchronize()
            freshTotalMinutes = sharedDefaults.integer(forKey: "total_usage")
            
            #if DEBUG
            print("📱 Health: UserDefaults total_usage = \(freshTotalMinutes)")
            #endif
        }
        
        // Source 2: Sum per_app_usage
        if freshTotalMinutes == 0 {
            if let sharedDefaults = UserDefaults(suiteName: appGroupID),
               let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") {
                freshTotalMinutes = perAppUsage.values.reduce(0) { partial, value in
                    if let intValue = value as? Int { return partial + intValue }
                    if let numberValue = value as? NSNumber { return partial + numberValue.intValue }
                    if let doubleValue = value as? Double { return partial + Int(doubleValue) }
                    return partial
                }
                #if DEBUG
                print("📱 Health: per_app_usage sum = \(freshTotalMinutes)")
                #endif
            }
        }
        
        // Source 3: JSON file backup
        if freshTotalMinutes == 0 {
            freshTotalMinutes = readTotalUsageFromSharedFileBackup(appGroupID: appGroupID)
            #if DEBUG
            print("📱 Health: File backup total_usage = \(freshTotalMinutes)")
            #endif
        }
        
        // ALWAYS update todayScreenTimeMinutes with fresh data
        if freshTotalMinutes > 0 {
            todayScreenTimeMinutes = freshTotalMinutes
        }
        
        let totalMinutes = freshTotalMinutes > 0 ? freshTotalMinutes : todayScreenTimeMinutes
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
        
        #if DEBUG
        print("📱 AppState: calculatePetHealthPercentage - totalMinutes=\(totalMinutes), hours=\(String(format: "%.1f", totalHours)), health=\(healthPercentage)%")
        #endif
        
        return max(0, min(100, healthPercentage))
    }
    
    private func readTotalUsageFromSharedFileBackup(appGroupID: String) -> Int {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return 0
        }
        
        let fileURL = containerURL.appendingPathComponent("screen_time_data.json")
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return 0
        }
        
        if let usage = json["total_usage"] as? Int { return usage }
        if let usage = json["total_usage"] as? NSNumber { return usage.intValue }
        if let usage = json["total_usage"] as? Double { return Int(usage) }
        return 0
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
        
        // Post notification to refresh all views showing the pet
        NotificationCenter.default.post(name: .petChanged, object: nil)
        print("🐾 Pet changed to \(pet.type.rawValue), notification posted")
    }
    
    func setUserName(_ name: String) {
        userName = name
        saveUserPreferences()
    }
}