import Foundation
import SwiftUI
import CoreData
import Combine
import FamilyControls

// MARK: - Notification Names

extension Notification.Name {
    static let screenTimeDataUpdated = Notification.Name("screenTimeDataUpdated")
    static let appBlocked = Notification.Name("appBlocked")
}

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
        
        // Listen for Screen Time data updates (removed duplicate)
        NotificationCenter.default.publisher(for: .screenTimeDataUpdated)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
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
    
    private func loadAppGoals() {
        let goals = coreDataManager.getActiveAppGoals()
        print("📊 Loading \(goals.count) app goals from Core Data")
        
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
        monitoredApps = goals.map { goal in
            let appName = goal.appName ?? "Unknown"
            let bundleID = goal.appBundleID ?? ""
            
            // Get effective daily limit (includes extensions for today)
            let effectiveLimit = coreDataManager.getEffectiveDailyLimit(for: bundleID)
            
            print("🔄 Converting \(appName) to MonitoredApp (limit: \(effectiveLimit) minutes)")
            return MonitoredApp(
                name: appName,
                icon: getAppIcon(for: appName),
                dailyLimit: effectiveLimit,
                usedToday: getCurrentUsage(for: goal),
                color: getAppColor(for: appName),
                isEnabled: goal.isActive
            )
        }
        
        print("✅ Loaded \(userGoals.count) user goals and \(monitoredApps.count) monitored apps")
        
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
        // Get today's usage from Screen Time or Core Data
        if let usageRecord = screenTimeService.getAppUsageToday(for: goal.appBundleID ?? "") {
            return Int(usageRecord.actualUsageMinutes)
        }
        
        // If no record exists, try to get from Screen Time service asynchronously
        // For synchronous context, return 0 and let the async refresh handle it
        return 0
    }
    
    private func getAppIcon(for appName: String) -> String {
        let icons: [String: String] = [
            "Instagram": "camera.circle.fill",
            "TikTok": "music.note.circle.fill",
            "X": "bubble.left.circle.fill",
            "Twitter": "bubble.left.circle.fill",
            "Facebook": "person.2.circle.fill",
            "Snapchat": "camera.filters",
            "YouTube": "play.circle.fill",
            "Reddit": "text.bubble.fill"
        ]
        return icons[appName] ?? "app.circle.fill"
    }
    
    private func getAppColor(for appName: String) -> Color {
        let colorMap = [
            "Instagram": Color.pink,
            "X": Color.black,
            "Facebook": Color.blue,
            "TikTok": Color.black,
            "Snapchat": Color.yellow,
            "YouTube": Color.red,
            "Reddit": Color.orange,
            "WhatsApp": Color.green,
            "Telegram": Color.blue,
            "Discord": Color.indigo
        ]
        return colorMap[appName] ?? Color.primary
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
        achievements = Achievement.mockAchievements
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
        
        // Setup monitoring if Screen Time is authorized
        if isScreenTimeAuthorized {
            let goals = coreDataManager.getActiveAppGoals()
            Task {
                screenTimeService.setupMonitoring(for: goals)
            }
        }
        
        checkAchievements()
    }
    
    // MARK: - Screen Time Integration
    
    func requestScreenTimeAuthorization() async throws {
        try await screenTimeService.requestAuthorization()
        
        // After authorization, set up monitoring for existing goals
        if screenTimeService.isAuthorized {
            let goals = coreDataManager.getActiveAppGoals()
            screenTimeService.setupMonitoring(for: goals)
        }
    }
    
    func addAppGoalFromFamilySelection(_ selection: FamilyActivitySelection, appName: String, dailyLimitMinutes: Int) {
        print("🔍 Adding app goal from Family Activity selection: \(appName)")
        
        // Use Screen Time service to handle the selection
        screenTimeService.addAppGoalFromSelection(selection, appName: appName, dailyLimitMinutes: dailyLimitMinutes)
        
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
            
            // Re-setup monitoring with new limits
            if isScreenTimeAuthorized {
                Task {
                    screenTimeService.setupMonitoring(for: coreDataManager.getActiveAppGoals())
                }
            }
        }
    }
    
    func deleteAppGoal(_ goalId: UUID) {
        let goals = coreDataManager.getActiveAppGoals()
        if let goal = goals.first(where: { $0.id == goalId }) {
            coreDataManager.deleteAppGoal(goal)
            loadAppGoals()
            
            // Re-setup monitoring
            if isScreenTimeAuthorized {
                Task {
                    screenTimeService.setupMonitoring(for: coreDataManager.getActiveAppGoals())
                }
            }
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
        // Reset failure count for new week
        coreDataManager.resetWeeklyFailureCount()
        
        Task {
            screenTimeService.performWeeklyReset()
        }
        loadCurrentWeekData()
        loadAppGoals()
        loadDailyHistory() // Reload history after week reset
        updateStreak()
        checkAchievements()
    }
    
    // MARK: - Progressive Penalty System
    
    func getCurrentFailureCount() -> Int {
        return coreDataManager.getCurrentFailureCount()
    }
    
    func getNextFailurePenalty() -> Int {
        // Returns how many credits will be deducted on the next failure
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
                await screenTimeService.refreshAllAppUsage()
                
                // Reload app goals after usage refresh on main thread
                await MainActor.run {
                    self.loadAppGoals()
                }
            }
        }
    }
    
    func syncDataFromBackground() {
        // Called when app returns from background
        // Reload all data to ensure it's up to date
        loadUserPreferences()
        refreshData()
    }
    
    
    // MARK: - Pet Health Management
    
    func updatePetHealth() {
        guard var pet = userPet else { return }
        
        // Update pet health based on current credits
        let newHealthState: PetHealthState
        switch currentCredits {
        case 7:
            newHealthState = .fullHealth
        case 5...6:
            newHealthState = .happy
        case 3...4:
            newHealthState = .content
        case 1...2:
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
    
    func setUserPet(_ pet: Pet) {
        userPet = pet
        saveUserPreferences()
    }
    
    func setUserName(_ name: String) {
        userName = name
        saveUserPreferences()
    }
}