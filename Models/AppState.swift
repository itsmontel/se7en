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
    @Published var credits = 7
    @Published var currentCredits = 7 // Alias for compatibility
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
    
    private var previousStreak = 0
    
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
    
    // ✅ PERFORMANCE / CORRECTNESS: Cache usage data to avoid repeated UserDefaults lookups
    // Cache by normalized app name (per_app_usage from report extension) and by token hash (usage_<tokenHash>)
    private var nameUsageCache: [String: Int] = [:]
    private var tokenUsageCache: [String: Int] = [:]
    private var usageCacheTimestamp: Date = Date.distantPast
    private let usageCacheTimeout: TimeInterval = 60 // Cache for 60 seconds
    
    init() {
        setupObservers()
        // Perform daily reset check on app launch
        coreDataManager.performDailyResetIfNeeded()
        loadInitialData()
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
        
        // ✅ PERFORMANCE: Reduced frequency from 30 seconds to 2 minutes to reduce CPU/memory pressure
        Timer.publish(every: 120, on: .main, in: .common) // Every 2 minutes instead of 30 seconds
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
        
        // If pet exists, update its health based on current credits
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
        credits = Int(weeklyPlan.creditsRemaining)
        currentCredits = credits // Keep in sync
        updatePetHealth() // Update pet health based on credits
        
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
        
        // Clean up expired restrictions before loading
        cleanupExpiredRestrictions()
        
        // Clean up mock apps that don't have Screen Time tokens
        coreDataManager.cleanupMockApps()
        
        // ✅ Sync usage from shared container (written by monitor extension) BEFORE loading goals
        // This ensures we have the latest usage data when displaying limits
        screenTimeService.syncUsageFromSharedContainer()
        
        // ✅ PERFORMANCE: Refresh usage cache when loading goals
        let goals = coreDataManager.getActiveAppGoals()
        refreshUsageCache(with: goals)
        
        
        userGoals = goals.map { goal in
            UserGoal(
                id: goal.id ?? UUID(),
                appName: goal.appName ?? "",
                dailyLimit: Int(goal.dailyLimitMinutes),
                currentUsage: getCurrentUsage(for: goal),
                isActive: goal.isActive
            )
        }
        
        // Convert to MonitoredApp format for dashboard compatibility
        // ONLY include apps that have Screen Time tokens (are actually connected via Screen Time API)
        // EXCLUDE category-based tracking (All Categories Tracking) - limits are only for individual apps
        // ✅ Now using token hash as identifier (stored in appBundleID field)
        let screenTimeService = ScreenTimeService.shared
        monitoredApps = goals.compactMap { goal in
            let tokenHash = goal.appBundleID ?? "" // ✅ This is now the token hash
            
            // EXCLUDE "All Categories Tracking" - limits are only for individual apps
            if tokenHash == "com.se7en.allcategories" {
                return nil
            }
            
            // ONLY show apps that have Screen Time tokens (are connected via FamilyActivityPicker)
            // We check by token hash
            guard !tokenHash.isEmpty, screenTimeService.hasSelection(for: tokenHash) else {
                return nil
            }
            
            // Get effective daily limit (includes extensions for today)
            let effectiveLimit = coreDataManager.getEffectiveDailyLimit(for: tokenHash)
            
            // ✅ Use custom name if provided, otherwise will be shown via Label(token) in UI
            let customName = goal.appName ?? ""
            
            return MonitoredApp(
                name: customName.isEmpty ? "App" : customName,  // Fallback name (real name shown via Label)
                icon: "app.fill",  // Fallback icon (real icon shown via Label)
                dailyLimit: effectiveLimit,
                usedToday: getCurrentUsage(for: goal),
                color: getAppColor(for: customName),
                isEnabled: goal.isActive,
                tokenHash: tokenHash  // ✅ Store token hash for retrieving selection
            )
        }
        
        // Only log summary, not per-app details
        print("📊 Loaded \(userGoals.count) goals, \(monitoredApps.count) monitored apps")
        
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
    
    private func getCurrentUsage(for goal: AppGoal) -> Int {
        guard let appName = goal.appName else { return 0 }
        let normalizedGoalName = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tokenHash = goal.appBundleID ?? ""
        
        // ✅ PERFORMANCE/CORRECTNESS: If cache is stale, refresh it with current goals
        if Date().timeIntervalSince(usageCacheTimestamp) >= usageCacheTimeout {
            let goals = coreDataManager.getActiveAppGoals()
            refreshUsageCache(with: goals)
        }
        
        // ✅ Check name-based cache (per_app_usage from report extension)
        if let cachedByName = nameUsageCache[normalizedGoalName] {
            return cachedByName
        }
        
        // ✅ Check token-based cache (usage_<tokenHash> from monitor extension)
        if let cachedByToken = tokenUsageCache[tokenHash], cachedByToken > 0 {
            return cachedByToken
        }
        
        // Fallback: Get from Core Data (synced elsewhere)
        if let usageRecord = screenTimeService.getAppUsageToday(for: tokenHash) {
            let usage = Int(usageRecord.actualUsageMinutes)
            // Update caches
            nameUsageCache[normalizedGoalName] = usage
            tokenUsageCache[tokenHash] = usage
            return usage
        }
        
        // If no record exists, return 0
        return 0
    }
    
    // ✅ PERFORMANCE: Refresh usage cache from shared container for a given set of goals
    private func refreshUsageCache(with goals: [AppGoal]) {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        // ✅ PERFORMANCE: Don't call synchronize() - UserDefaults auto-syncs
        let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int] ?? [:]
        
        // Build normalized name cache
        nameUsageCache.removeAll()
        for (reportAppName, reportUsage) in perAppUsage {
            let normalizedName = reportAppName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            nameUsageCache[normalizedName] = reportUsage
        }
        
        // Build token cache from monitor extension usage_<tokenHash> for current goals
        tokenUsageCache.removeAll()
        for goal in goals {
            guard let tokenHash = goal.appBundleID else { continue }
            let tokenUsage = sharedDefaults.integer(forKey: "usage_\(tokenHash)")
            if tokenUsage > 0 {
                tokenUsageCache[tokenHash] = tokenUsage
            }
        }
        
        usageCacheTimestamp = Date()
        print("📊 Refreshed usage cache with \(nameUsageCache.count) name entries, \(tokenUsageCache.count) token entries")
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
    
    // MARK: - Credit System
    
    var hasPaidAccountabilityFeeToday: Bool {
        let weeklyPlan = coreDataManager.getOrCreateCurrentWeeklyPlan()
        let today = Calendar.current.startOfDay(for: Date())
        let accountabilityFeePaidDate = weeklyPlan.accountabilityFeePaidDate.map { Calendar.current.startOfDay(for: $0) }
        return accountabilityFeePaidDate == today
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
    
    func deductCredit(for appName: String, reason: String) {
        _ = coreDataManager.deductCredit(reason: reason)
        loadCurrentWeekData()
        loadDailyHistory() // Reload history after credit change
        
        // Re-setup monitoring (only the app that exceeded limit is blocked)
        if isScreenTimeAuthorized {
            screenTimeService.checkAndUpdateAppBlocking()
        }
        
        checkAchievements()
    }
    
    func addCredits(amount: Int, reason: String) {
        _ = coreDataManager.addCredits(amount: amount, reason: reason)
        loadCurrentWeekData()
        loadDailyHistory() // Reload history after credit change
        
        // Re-setup monitoring (individual apps remain blocked if they exceeded limits)
        if isScreenTimeAuthorized {
            screenTimeService.checkAndUpdateAppBlocking()
        }
    }
    
    // MARK: - Streak Management
    
    func updateStreak() {
        let userProfile = coreDataManager.getOrCreateUserProfile()
        let weeklyPlan = coreDataManager.getCurrentWeeklyPlan()
        
        // Store previous streak before updating
        previousStreak = Int(userProfile.currentStreak)
        
        // If user kept all 7 credits, increment streak
        if weeklyPlan?.creditsRemaining == 7 {
            userProfile.currentStreak += 1
            if userProfile.currentStreak > userProfile.longestStreak {
                userProfile.longestStreak = userProfile.currentStreak
            }
            
            // Check if streak increased (not just maintained)
            let newStreak = Int(userProfile.currentStreak)
            if newStreak > previousStreak {
                // Trigger celebration animation
                newStreakValue = newStreak
                shouldShowStreakCelebration = true
            }
            
            // Send streak milestone notification
            notificationService.sendStreakMilestoneNotification(streak: Int(userProfile.currentStreak))
        } else {
            // Reset streak if credits were lost
            userProfile.currentStreak = 0
        }
        
        userProfile.updatedAt = Date()
        coreDataManager.save()
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
        // Weekly reset - credits reset to 7 daily at midnight
        Task {
            screenTimeService.performWeeklyReset()
        }
        loadCurrentWeekData()
        loadAppGoals()
        loadDailyHistory() // Reload history after week reset
        updateStreak()
        checkAchievements()
    }
    
    // MARK: - Accountability Fee System
    
    func getCurrentFailureCount() -> Int {
        // No longer using progressive failure count - always returns 0
        return coreDataManager.getCurrentFailureCount()
    }
    
    func getNextFailurePenalty() -> Int {
        // Always 7 credits (99 cents) - simple accountability fee
        return coreDataManager.getNextFailurePenalty()
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
    
    /// Calculate pet health percentage based on the lowest app's remaining time percentage
    /// - Returns: Health percentage from 0-100
    func calculatePetHealthPercentage() -> Int {
        // If no monitored apps, pet is at full health
        guard !monitoredApps.isEmpty else { return 100 }
        
        // Find the lowest percentage of time remaining across all apps
        var lowestPercentRemaining: Double = 100
        
        for app in monitoredApps where app.isEnabled && app.dailyLimit > 0 {
            // Calculate percentage of time remaining (not used)
            let percentUsed = app.percentageUsed * 100 // Convert to 0-100 scale
            let percentRemaining = max(0, 100 - percentUsed)
            
            if percentRemaining < lowestPercentRemaining {
                lowestPercentRemaining = percentRemaining
            }
        }
        
        // Calculate health based on the lowest percentage remaining
        // Formula:
        // - If 60%+ remaining: health = 100 (full health)
        // - If 40-60% remaining: health decreases by 1 per percent below 60
        // - If below 40% remaining: health decreases by 2 per percent below 40
        
        let healthPercentage: Int
        
        if lowestPercentRemaining >= 60 {
            // Over 60% time remaining = perfect health
            healthPercentage = 100
        } else if lowestPercentRemaining >= 40 {
            // Between 40-60%: health = 40 + percentRemaining (linear decrease of 1 per %)
            // At 60%: health = 40 + 60 = 100
            // At 40%: health = 40 + 40 = 80
            healthPercentage = 40 + Int(lowestPercentRemaining)
        } else {
            // Below 40%: health = 2 * percentRemaining (steeper decrease of 2 per %)
            // At 40%: health = 80
            // At 30%: health = 60
            // At 10%: health = 20
            // At 0%: health = 0
            healthPercentage = Int(lowestPercentRemaining * 2)
        }
        
        return max(0, min(100, healthPercentage))
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