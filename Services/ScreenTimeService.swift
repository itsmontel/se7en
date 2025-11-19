import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

class ScreenTimeService: ObservableObject {
    nonisolated static let shared = ScreenTimeService()
    
    private let center = AuthorizationCenter.shared
    private let deviceActivityCenter = DeviceActivityCenter()
    private let managedSettingsStore = ManagedSettingsStore()
    private let coreDataManager = CoreDataManager.shared
    
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var isAuthorized = false
    
    private var cancellables = Set<AnyCancellable>()
    
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
        for goal in goals {
            setupAppMonitoring(for: goal)
        }
    }
    
    private func setupAppMonitoring(for goal: AppGoal) {
        guard let bundleID = goal.appBundleID else { return }
        
        // For now, we'll use a simplified approach without actual Screen Time monitoring
        // In a real implementation, you would need proper Screen Time entitlements and setup
        print("Would start monitoring for \(goal.appName ?? "Unknown App") with bundle ID: \(bundleID)")
        print("Daily limit: \(goal.dailyLimitMinutes) minutes")
        
        // Store the goal for reference
        // In a real app, this would integrate with DeviceActivity framework
    }
    
    func stopAllMonitoring() {
        // In a real implementation, this would stop all device activity monitoring
        print("Would stop all monitoring activities")
    }
    
    // MARK: - Usage Data Retrieval
    
    func getCurrentUsage(for bundleID: String) async -> Int {
        // This would require implementing DeviceActivityReport
        // For now, we'll return a placeholder
        // In a real implementation, you'd use DeviceActivityReport to get actual usage
        return 0
    }
    
    // MARK: - App Blocking
    
    func blockApp(_ bundleID: String) {
        guard isAuthorized else { return }
        
        // In a real implementation, this would block the app using ManagedSettings
        print("Would block app with bundle ID: \(bundleID)")
    }
    
    func unblockApp(_ bundleID: String) {
        guard isAuthorized else { return }
        
        // In a real implementation, this would unblock the app using ManagedSettings
        print("Would unblock app with bundle ID: \(bundleID)")
    }
    
    func unblockAllApps() {
        // In a real implementation, this would unblock all apps using ManagedSettings
        print("Would unblock all apps")
    }
    
    // MARK: - Credit Loss Handling
    
    func handleLimitExceeded(for bundleID: String) {
        // Find the app goal for this bundle ID
        let appGoals = coreDataManager.getActiveAppGoals()
        guard let goal = appGoals.first(where: { $0.appBundleID == bundleID }) else { return }
        
        // Create usage record
        let usageRecord = coreDataManager.createUsageRecord(
            for: goal,
            date: Date(),
            actualUsageMinutes: Int(goal.dailyLimitMinutes) + 1, // Exceeded limit
            didExceedLimit: true
        )
        
        // Deduct credit
        _ = coreDataManager.deductCredit(
            reason: "Exceeded \(goal.appName ?? "Unknown App") daily limit",
            for: usageRecord
        )
        
        // Block the app for the rest of the day
        blockApp(bundleID)
        
        // Send notification
        NotificationService.shared.sendCreditLostNotification(
            appName: goal.appName ?? "Unknown App",
            creditsRemaining: Int(coreDataManager.getOrCreateCurrentWeeklyPlan().creditsRemaining)
        )
        
        print("Credit deducted for exceeding \(goal.appName ?? "Unknown App") limit")
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
    
    func getAppUsageToday(for bundleID: String) -> AppUsageRecord? {
        let todaysRecords = coreDataManager.getTodaysUsageRecords()
        return todaysRecords.first { $0.appGoal?.appBundleID == bundleID }
    }
    
    func getRemainingTime(for goal: AppGoal) -> TimeInterval {
        // In a real implementation, this would calculate based on actual usage
        // For now, return the full limit
        return TimeInterval(goal.dailyLimitMinutes * 60)
    }
}
