import Foundation
import SwiftUI
import CoreData
import Combine

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
    @Published var hasActiveSubscription = false
    @Published var userPet: Pet?
    @Published var downloadMotivations: [DownloadMotivation] = []
    @Published var averageScreenTimeHours: Int = 0
    @Published var userName: String = ""
    
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
        loadInitialData()
        checkOnboardingStatus()
    }
    
    private func setupObservers() {
        // Observe Screen Time authorization status
        screenTimeService.$isAuthorized
            .assign(to: \.isScreenTimeAuthorized, on: self)
            .store(in: &cancellables)
        
        // Setup periodic data refresh
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
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
        checkAchievements()
    }
    
    private func checkOnboardingStatus() {
        // Check if user has completed onboarding by seeing if they have any app goals
        let goals = coreDataManager.getActiveAppGoals()
        isOnboarding = goals.isEmpty
    }
    
    // MARK: - Data Loading Methods
    
    private func loadUserProfile() {
        let userProfile = coreDataManager.getOrCreateUserProfile()
        currentStreak = Int(userProfile.currentStreak)
        longestStreak = Int(userProfile.longestStreak)
        hasActiveSubscription = userProfile.hasActiveSubscription
    }
    
    private func loadCurrentWeekData() {
        let weeklyPlan = coreDataManager.getOrCreateCurrentWeeklyPlan()
        credits = Int(weeklyPlan.creditsRemaining)
        currentCredits = credits // Keep in sync
        updatePetHealth() // Update pet health based on credits
        
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
            print("🔄 Converting \(appName) to MonitoredApp")
            return MonitoredApp(
                name: appName,
                icon: getAppIcon(for: appName),
                dailyLimit: Int(goal.dailyLimitMinutes),
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
        // Get today's usage record for this app goal
        let todaysRecords = coreDataManager.getTodaysUsageRecords()
        if let record = todaysRecords.first(where: { $0.appGoal?.id == goal.id }) {
            return Int(record.actualUsageMinutes)
        }
        
        // If no record exists, try to get live usage from Screen Time API
        // For now, return 0 as placeholder
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
        
        // Trigger haptic feedback
        HapticFeedback.success.trigger()
        
        // Send notification
        if let achievement = achievements.first(where: { $0.id == achievementId }) {
            notificationService.sendAchievementUnlockedNotification(achievementTitle: achievement.title)
            print("🏆 Achievement Unlocked: \(achievement.title)")
        }
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
    
    func deductCredit(for appName: String, reason: String) {
        _ = coreDataManager.deductCredit(reason: reason)
        loadCurrentWeekData()
        checkAchievements()
    }
    
    func addCredits(amount: Int, reason: String) {
        _ = coreDataManager.addCredits(amount: amount, reason: reason)
        loadCurrentWeekData()
    }
    
    // MARK: - Streak Management
    
    func updateStreak() {
        let userProfile = coreDataManager.getOrCreateUserProfile()
        let weeklyPlan = coreDataManager.getCurrentWeeklyPlan()
        
        // If user kept all 7 credits, increment streak
        if weeklyPlan?.creditsRemaining == 7 {
            userProfile.currentStreak += 1
            if userProfile.currentStreak > userProfile.longestStreak {
                userProfile.longestStreak = userProfile.currentStreak
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
    }
    
    // MARK: - Week Management
    
    func resetWeek() {
        Task {
            screenTimeService.performWeeklyReset()
        }
        loadCurrentWeekData()
        loadAppGoals()
        updateStreak()
        checkAchievements()
    }
    
    // MARK: - Screen Time Authorization
    
    func requestScreenTimeAuthorization() async {
        do {
            try await screenTimeService.requestAuthorization()
            
            if screenTimeService.isAuthorized {
                // Setup monitoring for existing goals
                let goals = coreDataManager.getActiveAppGoals()
                Task {
                    screenTimeService.setupMonitoring(for: goals)
                }
            }
        } catch {
            print("Failed to authorize Screen Time: \(error)")
        }
    }
    
    // MARK: - Data Refresh
    
    func refreshData() {
        loadUserProfile()
        loadCurrentWeekData()
        loadAppGoals()
        loadUnlockedAchievements()
        checkAchievements()
    }
    
    // MARK: - Subscription Management
    
    func updateSubscriptionStatus(_ isActive: Bool) {
        let userProfile = coreDataManager.getOrCreateUserProfile()
        userProfile.hasActiveSubscription = isActive
        userProfile.updatedAt = Date()
        coreDataManager.save()
        hasActiveSubscription = isActive
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
            
            // Send notification about pet health change
            if newHealthState == .sick {
                NotificationService.shared.sendPetHealthAlert(
                    petName: pet.name,
                    healthState: newHealthState
                )
            }
        }
    }
}