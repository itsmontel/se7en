import Foundation
import UserNotifications
import UIKit

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private init() {}
    
    // MARK: - Authorization
    
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    // MARK: - App Blocking Notifications
    
    func sendAppBlockedNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🚫 App Blocked"
        content.body = "\(appName) has been blocked for exceeding your daily limit. Wait until tomorrow or spend 1 credit to unblock now."
        content.sound = .default
        content.categoryIdentifier = "APP_BLOCKED"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "app_blocked_\(appName)_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule app blocked notification: \(error)")
            }
        }
    }
    
    func sendCreditUsedForUnblockNotification(appName: String, creditsRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "💳 Credit Used"
        
        if creditsRemaining > 0 {
            content.body = "You spent 1 credit to unblock \(appName). \(creditsRemaining) credits remaining this week."
        } else {
            content.body = "You spent your last credit to unblock \(appName). You'll be charged $7 at the end of the week."
        }
        
        content.sound = .default
        content.categoryIdentifier = "CREDIT_USED"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "credit_used_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule credit used notification: \(error)")
            }
        }
    }
    
    // MARK: - Credit Loss Notifications (Legacy)
    
    func sendCreditLostNotification(appName: String, creditsRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Credit Lost! 💳"
        
        if creditsRemaining > 0 {
            content.body = "You exceeded your \(appName) limit and lost 1 credit. \(creditsRemaining) credits remaining this week."
        } else {
            content.body = "You exceeded your \(appName) limit and lost your last credit. You'll be charged $7 at the end of the week."
        }
        
        content.sound = .default
        content.categoryIdentifier = "CREDIT_LOSS"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "credit_loss_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule credit loss notification: \(error)")
            }
        }
    }
    
    // MARK: - Warning Notifications
    
    func sendLimitWarningNotification(appName: String, timeRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Limit Warning"
        content.body = "You have \(timeRemaining) minutes left on \(appName) before losing a credit."
        content.sound = .default
        content.categoryIdentifier = "LIMIT_WARNING"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "warning_\(appName)_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule warning notification: \(error)")
            }
        }
    }
    
    // MARK: - Achievement Notifications
    
    func sendAchievementUnlockedNotification(achievementTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "🏆 Achievement Unlocked!"
        content.body = "You earned: \(achievementTitle)"
        content.sound = .default
        content.categoryIdentifier = "ACHIEVEMENT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "achievement_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule achievement notification: \(error)")
            }
        }
    }
    
    // MARK: - Weekly Summary Notifications
    
    func scheduleWeeklySummaryNotification() {
        let content = UNMutableNotificationContent()
        content.title = "📊 Weekly Summary"
        content.body = "Check your SE7EN app to see how you did this week and settle your payment."
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_SUMMARY"
        
        // Schedule for Sunday at 8 PM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 20 // 8 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_summary", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule weekly summary notification: \(error)")
            }
        }
    }
    
    // MARK: - Daily Reminder Notifications
    
    func scheduleDailyReminderNotification(at hour: Int, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "🎯 Daily Check-in"
        content.body = "How are your digital habits today? Check your progress in SE7EN."
        content.sound = .default
        content.categoryIdentifier = "DAILY_REMINDER"
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder notification: \(error)")
            }
        }
    }
    
    // MARK: - Streak Notifications
    
    func sendStreakMilestoneNotification(streak: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🔥 Streak Milestone!"
        
        let message: String
        switch streak {
        case 1:
            message = "Great start! You kept all 7 credits for your first week."
        case 2:
            message = "Two weeks strong! You're building great habits."
        case 4:
            message = "One month of perfect weeks! You're on fire! 🔥"
        case 8:
            message = "Two months of discipline! You're a digital wellness master!"
        case 12:
            message = "Three months perfect! This is incredible consistency! 🏆"
        default:
            message = "\(streak) perfect weeks in a row! Your discipline is inspiring! 💪"
        }
        
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "STREAK_MILESTONE"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "streak_\(streak)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule streak milestone notification: \(error)")
            }
        }
    }
    
    // MARK: - Clear Notifications
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func clearNotificationsByCategory(_ category: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.content.categoryIdentifier == category }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
    
    // MARK: - Setup Notification Categories
    
    func setupNotificationCategories() {
        let creditLossCategory = UNNotificationCategory(
            identifier: "CREDIT_LOSS",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let warningCategory = UNNotificationCategory(
            identifier: "LIMIT_WARNING",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let achievementCategory = UNNotificationCategory(
            identifier: "ACHIEVEMENT",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let weeklySummaryCategory = UNNotificationCategory(
            identifier: "WEEKLY_SUMMARY",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let dailyReminderCategory = UNNotificationCategory(
            identifier: "DAILY_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let streakMilestoneCategory = UNNotificationCategory(
            identifier: "STREAK_MILESTONE",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let petHealthCategory = UNNotificationCategory(
            identifier: "PET_HEALTH",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let appBlockedCategory = UNNotificationCategory(
            identifier: "APP_BLOCKED",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let creditUsedCategory = UNNotificationCategory(
            identifier: "CREDIT_USED",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            creditLossCategory,
            warningCategory,
            achievementCategory,
            weeklySummaryCategory,
            dailyReminderCategory,
            streakMilestoneCategory,
            petHealthCategory,
            appBlockedCategory,
            creditUsedCategory
        ])
    }
    
    // MARK: - Pet Health Notifications
    
    func sendPetHealthAlert(petName: String, healthState: PetHealthState) {
        let content = UNMutableNotificationContent()
        
        switch healthState {
        case .sick:
            content.title = "⚠️ \(petName) Needs Help!"
            content.body = "\(petName) is sick! Your credits are at 0. Time to top up and restore your pet's health."
        case .sad:
            content.title = "😟 \(petName) is Struggling"
            content.body = "\(petName) is sad because your credits are running low. Be careful not to lose more!"
        case .content:
            content.title = "😐 \(petName) is Okay"
            content.body = "\(petName) is doing okay, but needs more attention to stay healthy."
        case .happy:
            content.title = "😊 \(petName) is Happy"
            content.body = "\(petName) is feeling good! Keep up the great work!"
        case .fullHealth:
            content.title = "🌟 \(petName) is Thriving!"
            content.body = "\(petName) is at full health! You're doing an amazing job!"
        }
        
        content.sound = .default
        content.categoryIdentifier = "PET_HEALTH"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "pet_health_\(healthState.rawValue)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule pet health notification: \(error)")
            }
        }
    }
}

