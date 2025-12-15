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
    @Published var todayScreenTimeMinutes: Int = 0  // Shared screen time from dashboard (source of truth)
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
        // Don't update pet health here - wait for dashboard to load screen time data first
        // Health will be updated when dashboard sets todayScreenTimeMinutes
        
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
        let tokenHash = goal.appBundleID ?? ""
        
        // Always read fresh from shared container (where monitor extension writes)
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            // Fallback to Core Data if shared container unavailable
            if let usageRecord = screenTimeService.getAppUsageToday(for: tokenHash) {
                return Int(usageRecord.actualUsageMinutes)
            }
            return 0
        }
        
        // Force read fresh data from disk
        sharedDefaults.synchronize()
        
        // Priority 1: Read from monitor extension (by token hash)
        let tokenUsage = sharedDefaults.integer(forKey: "usage_\(tokenHash)")
        if tokenUsage > 0 {
            return tokenUsage
        }
        
        // Priority 2: Try per-app usage from report extension (by name)
        let appName = goal.appName ?? ""
        let normalizedGoalName = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalizedGoalName.isEmpty {
            let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int] ?? [:]
            for (reportAppName, reportUsage) in perAppUsage {
                let normalizedReportName = reportAppName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if normalizedGoalName == normalizedReportName {
                    return reportUsage
                }
            }
        }
        
        // Priority 3: Fallback to Core Data
        if let usageRecord = screenTimeService.getAppUsageToday(for: tokenHash) {
            return Int(usageRecord.actualUsageMinutes)
        }
        
        return 0
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
        
        // Update pet health whenever data refreshes
        updatePetHealth()
        
        // Refresh Screen Time usage data if authorized - move to background
        if isScreenTimeAuthorized {
            Task {
                // Refresh usage for all monitored apps
                await screenTimeService.refreshAllAppUsage()
                
                // Reload app goals after usage refresh on main thread
                await MainActor.run {
                    self.loadAppGoals()
                    self.updatePetHealth() // Update health again after usage refresh
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
        
        // Calculate pet health based on total screen time
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
        
        // Always update health state (even if unchanged) to ensure UI reflects current screen time
        // This ensures the health bar and pet state are always accurate
        let previousState = pet.healthState
        pet.healthState = newHealthState
        userPet = pet
        
        // Only save and notify if state actually changed
        if previousState != newHealthState {
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
    
    /// Calculate pet health percentage based on today's total screen time
    /// Uses todayScreenTimeMinutes which is set by the dashboard (same source as the displayed screen time)
    /// Falls back to reading from shared container if dashboard hasn't set it yet
    /// - Returns: Health percentage from 0-100
    func calculatePetHealthPercentage() -> Int {
        // ✅ Use the same screen time value that the dashboard displays
        // This is set by DashboardView when it loads screen time data
        var totalMinutes = todayScreenTimeMinutes
        
        // ✅ FALLBACK: If dashboard hasn't set it yet, read from shared container (same as dashboard does)
        if totalMinutes == 0 {
            let appGroupID = "group.com.se7en.app"
            if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
                totalMinutes = sharedDefaults.integer(forKey: "total_usage")
                if totalMinutes > 0 {
                    print("🏥 calculatePetHealthPercentage: Using fallback from shared container: \(totalMinutes) minutes")
                }
            }
        }
        
        // Convert to hours for easier calculation
        let totalHours = Double(totalMinutes) / 60.0
        
        print("🏥 calculatePetHealthPercentage: \(totalMinutes) minutes (\(String(format: "%.2f", totalHours)) hours)")
        
        // Calculate health based on screen time ranges
        // 0-2 hours: 100 health
        // 2-3 hours: starts at 100, drops to 80 at 3h (linear)
        // 3-4 hours: starts at 80, drops to 70
        // 4-5 hours: starts at 70, drops to 60
        // 5-6 hours: starts at 60, drops to 40
        // 6-8 hours: starts at 40, drops to 20
        // 8+ hours: starts at 20, anything over 10h makes it 0
        
        let healthPercentage: Int
        
        if totalHours <= 2.0 {
            // 0-2 hours: full health
            healthPercentage = 100
        } else if totalHours <= 3.0 {
            // 2-3 hours: linear from 100 to 80
            let progress = (totalHours - 2.0) / 1.0 // 0.0 to 1.0
            healthPercentage = 100 - Int(progress * 20) // 100 down to 80
        } else if totalHours <= 4.0 {
            // 3-4 hours: linear from 80 to 70
            let progress = (totalHours - 3.0) / 1.0 // 0.0 to 1.0
            healthPercentage = 80 - Int(progress * 10) // 80 down to 70
        } else if totalHours <= 5.0 {
            // 4-5 hours: linear from 70 to 60
            let progress = (totalHours - 4.0) / 1.0 // 0.0 to 1.0
            healthPercentage = 70 - Int(progress * 10) // 70 down to 60
        } else if totalHours <= 6.0 {
            // 5-6 hours: linear from 60 to 40
            let progress = (totalHours - 5.0) / 1.0 // 0.0 to 1.0
            healthPercentage = 60 - Int(progress * 20) // 60 down to 40
        } else if totalHours <= 8.0 {
            // 6-8 hours: linear from 40 to 20
            let progress = (totalHours - 6.0) / 2.0 // 0.0 to 1.0
            healthPercentage = 40 - Int(progress * 20) // 40 down to 20
        } else if totalHours <= 10.0 {
            // 8-10 hours: linear from 20 to 0
            let progress = (totalHours - 8.0) / 2.0 // 0.0 to 1.0
            healthPercentage = 20 - Int(progress * 20) // 20 down to 0
        } else {
            // Over 10 hours: 0 health
            healthPercentage = 0
        }
        
        let finalHealth = max(0, min(100, healthPercentage))
        print("🏥 calculatePetHealthPercentage: Result = \(finalHealth)%")
        return finalHealth
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