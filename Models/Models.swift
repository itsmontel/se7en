import SwiftUI
import UIKit
import FamilyControls

// MARK: - Unlock Mode
enum UnlockMode: String, Codable, CaseIterable {
    case extraTime = "Extra Time"
    case oneSession = "One Session"
    
    var description: String {
        switch self {
        case .extraTime:
            return "+15 minutes after solving puzzle"
        case .oneSession:
            return "Unlocks for one session, re-locks on exit"
        }
    }
}

// MARK: - Monitored App
struct MonitoredApp: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var icon: String // SF Symbol name (fallback - real icon shown via Label)
    var dailyLimit: Int // in minutes
    var usedToday: Int // in minutes
    var color: Color
    var isEnabled: Bool = true
    let tokenHash: String?  // ✅ Store token hash for retrieving selection
    
    var remainingMinutes: Int {
        max(0, dailyLimit - usedToday)
    }
    
    var percentageUsed: Double {
        guard dailyLimit > 0 else { return 0 }
        return Double(usedToday) / Double(dailyLimit)
    }
    
    var isOverLimit: Bool {
        usedToday > dailyLimit
    }
    
    var isNearLimit: Bool {
        percentageUsed >= 0.8 && !isOverLimit
    }
    
    var statusColor: Color {
        if isOverLimit {
            return .error
        } else if isNearLimit {
            return .warning
        } else {
            return .success
        }
    }
    
    // Equatable conformance
    static func == (lhs: MonitoredApp, rhs: MonitoredApp) -> Bool {
        return lhs.name == rhs.name &&
               lhs.icon == rhs.icon &&
               lhs.dailyLimit == rhs.dailyLimit &&
               lhs.usedToday == rhs.usedToday &&
               lhs.isEnabled == rhs.isEnabled &&
               lhs.tokenHash == rhs.tokenHash &&
               colorComponentsEqual(lhs.color, rhs.color)
    }
    
    // Helper to compare Color values
    private static func colorComponentsEqual(_ lhs: Color, _ rhs: Color) -> Bool {
        // Convert colors to UIColor and compare components
        let lhsUIColor = UIColor(lhs)
        let rhsUIColor = UIColor(rhs)
        
        var lhsRed: CGFloat = 0
        var lhsGreen: CGFloat = 0
        var lhsBlue: CGFloat = 0
        var lhsAlpha: CGFloat = 0
        
        var rhsRed: CGFloat = 0
        var rhsGreen: CGFloat = 0
        var rhsBlue: CGFloat = 0
        var rhsAlpha: CGFloat = 0
        
        lhsUIColor.getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha)
        rhsUIColor.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha)
        
        return abs(lhsRed - rhsRed) < 0.001 &&
               abs(lhsGreen - rhsGreen) < 0.001 &&
               abs(lhsBlue - rhsBlue) < 0.001 &&
               abs(lhsAlpha - rhsAlpha) < 0.001
    }
}

// MARK: - Daily Record
struct DailyRecord: Identifiable {
    let id = UUID()
    var date: Date
    var screenTimeMinutes: Int // Total screen time for the day
    var puzzlesSolved: Int // Number of puzzles solved that day
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var isSuccess: Bool {
        // Success if screen time under 2 hours
        screenTimeMinutes < 120
    }
}


// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case howItWorks = 1
    case whyItWorks = 2
    case setGoals = 3
    case paywall = 4
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to SE7EN."
        case .howItWorks:
            return "How it works"
        case .whyItWorks:
            return "Why this works"
        case .setGoals:
            return "Set your first goal"
        case .paywall:
            return "Start your focus journey"
        }
    }
}

// MARK: - Achievement
@MainActor
struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let category: AchievementCategory
    let rarity: AchievementRarity
    let isUnlocked: (AppState) -> Bool
    
    static let allAchievements: [Achievement] = [
        // MARK: - Getting Started (Easy)
        Achievement(
            id: "first_day",
            title: "First Step",
            description: "Complete your first day of monitoring",
            icon: "star.fill",
            color: .success,
            category: .gettingStarted,
            rarity: .common,
            isUnlocked: { appState in 
                // Check if user has completed at least one day
                !appState.dailyHistory.isEmpty || appState.monitoredApps.count > 0
            }
        ),
        
        Achievement(
            id: "week_warrior",
            title: "Week Warrior", 
            description: "Complete your first full week",
            icon: "calendar.badge.checkmark",
            color: .primary,
            category: .gettingStarted,
            rarity: .common,
            isUnlocked: { appState in appState.dailyHistory.count >= 7 }
        ),
        
        Achievement(
            id: "goal_setter",
            title: "Block Master",
            description: "Block 3 or more apps",
            icon: "hand.raised.fill",
            color: .secondary,
            category: .gettingStarted,
            rarity: .common,
            isUnlocked: { _ in BlockedAppsManager.shared.blockedCount >= 3 }
        ),
        
        // MARK: - Streak Achievements
        Achievement(
            id: "streak_3",
            title: "On Fire",
            description: "3-day streak",
            icon: "flame.fill",
            color: .warning,
            category: .streaks,
            rarity: .common,
            isUnlocked: { appState in appState.currentStreak >= 3 }
        ),
        
        Achievement(
            id: "streak_7",
            title: "Week Master",
            description: "7-day streak",
            icon: "flame.fill",
            color: .error,
            category: .streaks,
            rarity: .uncommon,
            isUnlocked: { appState in appState.longestStreak >= 7 }
        ),
        
        Achievement(
            id: "streak_14",
            title: "Two Week Champion",
            description: "14-day streak",
            icon: "flame.fill", 
            color: .pink,
            category: .streaks,
            rarity: .rare,
            isUnlocked: { appState in appState.longestStreak >= 14 }
        ),
        
        Achievement(
            id: "streak_30",
            title: "Monthly Master",
            description: "30-day streak",
            icon: "crown.fill",
            color: .yellow,
            category: .streaks,
            rarity: .epic,
            isUnlocked: { appState in appState.longestStreak >= 30 }
        ),
        
        Achievement(
            id: "streak_100",
            title: "Centurion",
            description: "100-day streak - legendary discipline",
            icon: "crown.fill",
            color: .purple,
            category: .streaks,
            rarity: .legendary,
            isUnlocked: { appState in appState.longestStreak >= 100 }
        ),
        
        // MARK: - Blocked Apps Achievements
        Achievement(
            id: "blocker_5",
            title: "Focused Five",
            description: "Block 5 apps",
            icon: "hand.raised.fill",
            color: .blue,
            category: .usage,
            rarity: .common,
            isUnlocked: { _ in BlockedAppsManager.shared.blockedCount >= 5 }
        ),
        
        Achievement(
            id: "blocker_10",
            title: "Digital Defender",
            description: "Block 10 apps",
            icon: "shield.fill",
            color: .secondary,
            category: .usage,
            rarity: .uncommon,
            isUnlocked: { _ in BlockedAppsManager.shared.blockedCount >= 10 }
        ),
        
        Achievement(
            id: "blocker_20",
            title: "Focus Master",
            description: "Block 20 apps",
            icon: "lock.shield.fill",
            color: .primary,
            category: .usage,
            rarity: .rare,
            isUnlocked: { _ in BlockedAppsManager.shared.blockedCount >= 20 }
        ),
        
        Achievement(
            id: "comeback_kid",
            title: "Comeback Kid",
            description: "Recover pet health from sick to full health",
            icon: "arrow.up.circle.fill",
            color: .primary,
            category: .pet,
            rarity: .uncommon,
            isUnlocked: { appState in
                // Check if pet was sick and is now at full health
                guard let pet = appState.userPet else { return false }
                // This would need to track pet health history - for now check current state
                // If pet is at full health and user has a streak, likely recovered
                return pet.healthState == .fullHealth && appState.currentStreak >= 3
            }
        ),
        
        Achievement(
            id: "pet_protector",
            title: "Pet Protector",
            description: "Keep your pet at full health for 30 days",
            icon: "shield.fill",
            color: .success,
            category: .pet,
            rarity: .rare,
            isUnlocked: { appState in
                // Check if pet is at full health and user has 30+ day streak
                guard let pet = appState.userPet else { return false }
                return pet.healthState == .fullHealth && appState.currentStreak >= 30
            }
        ),
        
        // MARK: - Puzzle Solving Achievements
        Achievement(
            id: "puzzle_first",
            title: "Puzzle Solver",
            description: "Solve your first puzzle",
            icon: "puzzlepiece.fill",
            color: .purple,
            category: .habits,
            rarity: .common,
            isUnlocked: { _ in
                guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return false }
                guard let puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] else { return false }
                return puzzleHistory.values.reduce(0, +) >= 1
            }
        ),
        
        Achievement(
            id: "puzzle_10",
            title: "Puzzle Pro",
            description: "Solve 10 puzzles",
            icon: "puzzlepiece.extension.fill",
            color: .purple,
            category: .habits,
            rarity: .uncommon,
            isUnlocked: { _ in
                guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return false }
                guard let puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] else { return false }
                return puzzleHistory.values.reduce(0, +) >= 10
            }
        ),
        
        Achievement(
            id: "puzzle_50",
            title: "Puzzle Master",
            description: "Solve 50 puzzles",
            icon: "puzzlepiece.extension.fill",
            color: .purple,
            category: .habits,
            rarity: .rare,
            isUnlocked: { _ in
                guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return false }
                guard let puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] else { return false }
                return puzzleHistory.values.reduce(0, +) >= 50
            }
        ),
        
        Achievement(
            id: "puzzle_100",
            title: "Puzzle Legend",
            description: "Solve 100 puzzles",
            icon: "puzzlepiece.extension.fill",
            color: .purple,
            category: .habits,
            rarity: .epic,
            isUnlocked: { _ in
                guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return false }
                guard let puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] else { return false }
                return puzzleHistory.values.reduce(0, +) >= 100
            }
        ),
        
        // MARK: - No Puzzle Achievements (Self-Control)
        Achievement(
            id: "no_puzzle_day",
            title: "Self Control",
            description: "Go a full day without solving a puzzle",
            icon: "hand.raised.slash.fill",
            color: .success,
            category: .habits,
            rarity: .uncommon,
            isUnlocked: { _ in
                guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return false }
                guard let puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] else { return false }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                let yesterdayKey = dateFormatter.string(from: yesterday)
                
                return (puzzleHistory[yesterdayKey] ?? 0) == 0
            }
        ),
        
        Achievement(
            id: "no_puzzle_week",
            title: "Discipline Champion",
            description: "Go 7 days without solving any puzzles",
            icon: "hand.raised.slash.fill",
            color: .success,
            category: .habits,
            rarity: .rare,
            isUnlocked: { _ in
                guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return false }
                guard let puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] else { return false }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let calendar = Calendar.current
                
                // Check last 7 days
                for dayOffset in 1...7 {
                    guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { return false }
                    let dateKey = dateFormatter.string(from: date)
                    if (puzzleHistory[dateKey] ?? 0) > 0 {
                        return false
                    }
                }
                return true
            }
        ),
        
        // MARK: - Time-based Achievements
        Achievement(
            id: "early_bird",
            title: "Early Bird",
            description: "Check the app before 8 AM for 7 days",
            icon: "sunrise.fill",
            color: .yellow,
            category: .habits,
            rarity: .common,
            isUnlocked: { appState in
                // Check if user has checked the app before 8 AM for 7 days
                // This requires tracking app open times in CoreData
                // For now, return false - implement when app open tracking is added
                false
            }
        ),
        
        Achievement(
            id: "night_owl",
            title: "Night Owl",
            description: "Check the app after 10 PM for 7 days",
            icon: "moon.fill",
            color: .purple,
            category: .habits,
            rarity: .common,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "weekend_warrior_v2",
            title: "Weekend Warrior",
            description: "Keep apps blocked during weekends for 4 weeks",
            icon: "gamecontroller.fill",
            color: .secondary,
            category: .habits,
            rarity: .rare,
            isUnlocked: { _ in
                // Check if user has blocked apps and maintained streak for 4 weeks
                BlockedAppsManager.shared.blockedCount > 0
            }
        ),
        
        // MARK: - Milestone Achievements
        Achievement(
            id: "one_month",
            title: "One Month Strong",
            description: "Use SE7EN for 30 days",
            icon: "calendar",
            color: .primary,
            category: .milestones,
            rarity: .uncommon,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "three_months",
            title: "Quarter Champion",
            description: "Use SE7EN for 90 days",
            icon: "medal.fill",
            color: .secondary,
            category: .milestones,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "six_months",
            title: "Half Year Hero",
            description: "Use SE7EN for 180 days",
            icon: "star.circle.fill",
            color: .warning,
            category: .milestones,
            rarity: .epic,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "one_year",
            title: "Annual Master",
            description: "Use SE7EN for 365 days",
            icon: "crown.fill",
            color: .purple,
            category: .milestones,
            rarity: .legendary,
            isUnlocked: { _ in false }
        ),
        
        // MARK: - Challenge Achievements
        Achievement(
            id: "app_unlocker",
            title: "App Unlocker",
            description: "Unblock apps 10 times by solving puzzles",
            icon: "lock.open.fill",
            color: .blue,
            category: .challenges,
            rarity: .uncommon,
            isUnlocked: { _ in
                guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return false }
                guard let puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] else { return false }
                return puzzleHistory.values.reduce(0, +) >= 10
            }
        ),
        
        Achievement(
            id: "blocker_streak",
            title: "Committed Blocker",
            description: "Keep at least 5 apps blocked for 30 days straight",
            icon: "lock.shield.fill",
            color: .primary,
            category: .challenges,
            rarity: .rare,
            isUnlocked: { appState in
                BlockedAppsManager.shared.blockedCount >= 5 && appState.longestStreak >= 30
            }
        ),
        
        // MARK: - Special Events
        Achievement(
            id: "new_year_new_me",
            title: "New Year, New Me",
            description: "Start a streak on January 1st",
            icon: "party.popper.fill",
            color: .yellow,
            category: .special,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "spring_cleaner",
            title: "Spring Cleaner",
            description: "Block 10+ apps during spring months",
            icon: "leaf.arrow.circlepath",
            color: .success,
            category: .special,
            rarity: .uncommon,
            isUnlocked: { _ in
                let month = Calendar.current.component(.month, from: Date())
                let isSpring = (3...5).contains(month) // March, April, May
                return isSpring && BlockedAppsManager.shared.blockedCount >= 10
            }
        ),
        
        // MARK: - Meta Achievements
        Achievement(
            id: "achievement_hunter",
            title: "Achievement Hunter",
            description: "Unlock 10 achievements",
            icon: "trophy.fill",
            color: .yellow,
            category: .meta,
            rarity: .uncommon,
            isUnlocked: { appState in appState.unlockedAchievements.count >= 10 }
        ),
        
        Achievement(
            id: "completionist",
            title: "Completionist",
            description: "Unlock 25 achievements",
            icon: "star.square.fill",
            color: .purple,
            category: .meta,
            rarity: .epic,
            isUnlocked: { appState in appState.unlockedAchievements.count >= 25 }
        ),
        
        Achievement(
            id: "legend",
            title: "Legend",
            description: "Unlock 40+ achievements",
            icon: "crown.fill",
            color: .primary,
            category: .meta,
            rarity: .legendary,
            isUnlocked: { appState in appState.unlockedAchievements.count >= 40 }
        ),
        
        // MARK: - Consistency Achievements  
        Achievement(
            id: "consistent_checker",
            title: "Consistent Checker",
            description: "Open SE7EN every day for 2 weeks",
            icon: "checkmark.circle.fill",
            color: .success,
            category: .habits,
            rarity: .uncommon,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "weekly_reviewer",
            title: "Weekly Reviewer", 
            description: "Check your progress every Sunday for 8 weeks",
            icon: "calendar.circle.fill",
            color: .secondary,
            category: .habits,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        // MARK: - Screen Time Achievements
        Achievement(
            id: "low_screen_time",
            title: "Screen Time Warrior",
            description: "Keep daily screen time under 2 hours for a week",
            icon: "chart.line.downtrend.xyaxis",
            color: .success,
            category: .improvement,
            rarity: .rare,
            isUnlocked: { appState in
                // Check if average screen time over last 7 days is under 120 minutes
                let recentHistory = appState.dailyHistory.suffix(7)
                guard recentHistory.count >= 7 else { return false }
                let avgScreenTime = recentHistory.reduce(0) { $0 + $1.screenTimeMinutes } / recentHistory.count
                return avgScreenTime < 120
            }
        ),
        
        Achievement(
            id: "minimal_usage",
            title: "Digital Minimalist",
            description: "Keep daily screen time under 1 hour for 3 days",
            icon: "leaf.fill",
            color: .success,
            category: .improvement,
            rarity: .uncommon,
            isUnlocked: { appState in
                let recentHistory = appState.dailyHistory.suffix(3)
                guard recentHistory.count >= 3 else { return false }
                return recentHistory.allSatisfy { $0.screenTimeMinutes < 60 }
            }
        ),
        
        // MARK: - Seasonal Achievements
        Achievement(
            id: "summer_discipline",
            title: "Summer Discipline", 
            description: "Maintain streaks during summer break",
            icon: "sun.max.fill",
            color: .yellow,
            category: .seasonal,
            rarity: .uncommon,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "winter_focus",
            title: "Winter Focus",
            description: "Stay disciplined during holiday season",
            icon: "snowflake",
            color: .secondary,
            category: .seasonal,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        // MARK: - Fun Achievements
        Achievement(
            id: "midnight_warrior",
            title: "Midnight Warrior",
            description: "Check your blocked apps at exactly midnight",
            icon: "clock.fill",
            color: .purple,
            category: .fun,
            rarity: .uncommon,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "lucky_seven",
            title: "Lucky Seven",
            description: "Maintain 7-day streak for 7 consecutive weeks",
            icon: "dice.fill",
            color: .primary,
            category: .fun,
            rarity: .epic,
            isUnlocked: { appState in
                // Check if user has maintained 7+ day streak for 7 weeks (49 days)
                return appState.longestStreak >= 49 && appState.currentStreak >= 7
            }
        ),
        
        // MARK: - Mastery Achievements
        Achievement(
            id: "self_control_sensei",
            title: "Self-Control Sensei",
            description: "Master all aspects: 50+ day streak, 20+ achievements, 10+ blocked apps",
            icon: "figure.martial.arts",
            color: .purple,
            category: .mastery,
            rarity: .legendary,
            isUnlocked: { appState in 
                appState.longestStreak >= 50 && 
                appState.unlockedAchievements.count >= 20 && 
                BlockedAppsManager.shared.blockedCount >= 10
            }
        ),
        
        // MARK: - Screen Time Achievements
        Achievement(
            id: "low_screen_time_day",
            title: "Low Screen Time Day",
            description: "Use less than 1 hour of screen time in a single day",
            icon: "hourglass",
            color: .success,
            category: .usage,
            rarity: .uncommon,
            isUnlocked: { appState in 
                // Only unlock if it's very late in the day (after 11 PM) and screen time is still low
                // This prevents false unlocks early in the day or when data hasn't loaded (0 minutes)
                let calendar = Calendar.current
                let now = Date()
                let hour = calendar.component(.hour, from: now)
                // Require: very late in day (11 PM+) AND data has loaded (not 0) AND screen time is actually low
                return hour >= 23 && appState.todayScreenTimeMinutes > 0 && appState.todayScreenTimeMinutes < 60
            }
        ),
        
        Achievement(
            id: "ultra_low_day",
            title: "Ultra Low Day",
            description: "Use less than 30 minutes of screen time in a single day",
            icon: "leaf.fill",
            color: .green,
            category: .usage,
            rarity: .rare,
            isUnlocked: { appState in 
                // Only unlock if it's very late in the day (after 11 PM) and screen time is still low
                let calendar = Calendar.current
                let now = Date()
                let hour = calendar.component(.hour, from: now)
                // Require: very late in day (11 PM+) AND data has loaded (not 0) AND screen time is actually low
                return hour >= 23 && appState.todayScreenTimeMinutes > 0 && appState.todayScreenTimeMinutes < 30
            }
        ),
        
        Achievement(
            id: "week_under_5_hours",
            title: "Week Under 5 Hours",
            description: "Average less than 5 hours of screen time per day for a week",
            icon: "calendar.badge.checkmark",
            color: .primary,
            category: .usage,
            rarity: .rare,
            isUnlocked: { appState in
                // Check if user has 7+ day streak and current screen time suggests low weekly average
                // This is a proxy until we have proper weekly historical data
                appState.currentStreak >= 7 && appState.todayScreenTimeMinutes < 60
            }
        ),
        
        Achievement(
            id: "week_under_3_hours",
            title: "Week Under 3 Hours",
            description: "Average less than 3 hours of screen time per day for a week",
            icon: "star.circle.fill",
            color: .success,
            category: .usage,
            rarity: .epic,
            isUnlocked: { appState in
                // Check if user has 7+ day streak and very low current screen time
                appState.currentStreak >= 7 && appState.todayScreenTimeMinutes < 30
            }
        ),
        
        Achievement(
            id: "digital_monk",
            title: "Digital Monk",
            description: "Use less than 1 hour total daily screen time for a week",
            icon: "figure.mind.and.body",
            color: .success,
            category: .mastery,
            rarity: .legendary,
            isUnlocked: { appState in
                // Check if user has 7+ day streak and consistently low screen time
                appState.currentStreak >= 7 && appState.todayScreenTimeMinutes < 60
            }
        ),
        
        Achievement(
            id: "minimal_screen_week",
            title: "Minimal Screen Week",
            description: "Average less than 2 hours of screen time per day for a week",
            icon: "minus.circle.fill",
            color: .green,
            category: .minimalism,
            rarity: .epic,
            isUnlocked: { appState in
                appState.currentStreak >= 7 && appState.todayScreenTimeMinutes < 30
            }
        ),
        
        // MARK: - Bonus Hidden Achievements
        Achievement(
            id: "easter_egg",
            title: "Easter Egg Hunter",
            description: "Found the secret achievement! 🥚",
            icon: "gift.fill",
            color: .pink,
            category: .hidden,
            rarity: .epic,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "beta_tester",
            title: "Beta Tester",
            description: "Helped shape SE7EN during early access",
            icon: "hammer.fill",
            color: .secondary,
            category: .hidden,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "feedback_champion",
            title: "Feedback Champion",
            description: "Provided valuable feedback that improved SE7EN",
            icon: "megaphone.fill", 
            color: .primary,
            category: .hidden,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        // MARK: - Additional Achievements
        Achievement(
            id: "morning_person",
            title: "Morning Person",
            description: "Check your blocked apps before 8 AM for 10 days",
            icon: "sunrise.fill",
            color: .yellow,
            category: .habits,
            rarity: .uncommon,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "puzzle_speed_demon",
            title: "Puzzle Speed Demon",
            description: "Solve 5 puzzles in a single day",
            icon: "bolt.fill",
            color: .yellow,
            category: .precision,
            rarity: .rare,
            isUnlocked: { _ in
                guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return false }
                guard let puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] else { return false }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let todayKey = dateFormatter.string(from: Date())
                return (puzzleHistory[todayKey] ?? 0) >= 5
            }
        ),
        
        Achievement(
            id: "weekend_monk",
            title: "Weekend Monk",
            description: "Use less than 30 minutes total screen time on weekends for 4 weeks",
            icon: "leaf.fill",
            color: .green,
            category: .mastery,
            rarity: .epic,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "consistency_master",
            title: "Consistency Master",
            description: "Maintain a 70-day streak with apps blocked",
            icon: "checkmark.circle.fill",
            color: .green,
            category: .mastery,
            rarity: .epic,
            isUnlocked: { appState in
                appState.longestStreak >= 70 && BlockedAppsManager.shared.blockedCount > 0
            }
        ),
        
        Achievement(
            id: "app_minimalist",
            title: "App Minimalist",
            description: "Block only 1 app for 30 days straight",
            icon: "minus.circle.fill",
            color: .gray,
            category: .minimalism,
            rarity: .uncommon,
            isUnlocked: { appState in
                BlockedAppsManager.shared.blockedCount == 1 && appState.longestStreak >= 30
            }
        ),
        
        Achievement(
            id: "digital_detox_master",
            title: "Digital Detox Master",
            description: "Keep screen time under 30 minutes for 7 days",
            icon: "power.circle.fill",
            color: .red,
            category: .mastery,
            rarity: .legendary,
            isUnlocked: { appState in
                let recentHistory = appState.dailyHistory.suffix(7)
                guard recentHistory.count >= 7 else { return false }
                return recentHistory.allSatisfy { $0.screenTimeMinutes < 30 }
            }
        ),
        
        // MARK: - Pet-Based Achievements
        Achievement(
            id: "pet_owner",
            title: "Pet Owner",
            description: "Choose your first pet companion",
            icon: "pawprint.fill",
            color: .pink,
            category: .pet,
            rarity: .common,
            isUnlocked: { appState in appState.userPet != nil }
        ),
        
        Achievement(
            id: "pet_namer",
            title: "Pet Namer",
            description: "Give your pet a name",
            icon: "pencil.circle.fill",
            color: .blue,
            category: .pet,
            rarity: .common,
            isUnlocked: { appState in 
                guard let pet = appState.userPet else { return false }
                return !pet.name.isEmpty && pet.name != pet.type.rawValue
            }
        ),
        
        Achievement(
            id: "pet_full_health",
            title: "Perfect Caretaker",
            description: "Keep your pet at full health for 3 days",
            icon: "heart.fill",
            color: .green,
            category: .pet,
            rarity: .uncommon,
            isUnlocked: { appState in 
                guard let pet = appState.userPet else { return false }
                return appState.currentStreak >= 3 && pet.healthState == .fullHealth
            }
        ),
        
        Achievement(
            id: "pet_happy_week",
            title: "Happy Companion",
            description: "Maintain a 7-day streak with your pet happy or healthier",
            icon: "face.smiling.fill",
            color: .yellow,
            category: .pet,
            rarity: .uncommon,
            isUnlocked: { appState in 
                guard let pet = appState.userPet else { return false }
                return appState.currentStreak >= 7 && 
                       (pet.healthState == .fullHealth || pet.healthState == .happy)
            }
        ),
        
        Achievement(
            id: "pet_recovery",
            title: "Pet Rescuer",
            description: "Bring your pet back from sick to full health",
            icon: "cross.case.fill",
            color: .red,
            category: .pet,
            rarity: .rare,
            isUnlocked: { appState in 
                guard let pet = appState.userPet else { return false }
                return pet.healthState == .fullHealth && appState.currentStreak >= 3
            }
        ),
        
        Achievement(
            id: "pet_30_days_healthy",
            title: "Dedicated Caretaker",
            description: "Keep your pet healthy for 30 consecutive days",
            icon: "heart.circle.fill",
            color: .green,
            category: .pet,
            rarity: .epic,
            isUnlocked: { appState in 
                guard let pet = appState.userPet else { return false }
                return pet.healthState == .fullHealth && appState.currentStreak >= 30
            }
        ),
        
        Achievement(
            id: "pet_type_collector",
            title: "Pet Collector",
            description: "Try all 5 pet types",
            icon: "square.grid.3x3.fill",
            color: .purple,
            category: .pet,
            rarity: .rare,
            isUnlocked: { _ in false } // Would need to track pet type changes
        ),
        
        Achievement(
            id: "pet_best_friend",
            title: "Best Friend",
            description: "Keep your pet at full health for 7 consecutive weeks",
            icon: "star.circle.fill",
            color: .orange,
            category: .pet,
            rarity: .legendary,
            isUnlocked: { appState in 
                guard let pet = appState.userPet else { return false }
                return pet.healthState == .fullHealth && appState.longestStreak >= 49
            }
        ),
        
        Achievement(
            id: "pet_health_100",
            title: "Perfect Health",
            description: "Achieve 100 health score with your pet",
            icon: "checkmark.seal.fill",
            color: .green,
            category: .pet,
            rarity: .uncommon,
            isUnlocked: { appState in 
                guard let pet = appState.userPet else { return false }
                return pet.healthState == .fullHealth && appState.todayScreenTimeMinutes < 60
            }
        ),
        
        Achievement(
            id: "pet_naming_master",
            title: "Naming Master",
            description: "Rename your pet 3 times",
            icon: "text.cursor",
            color: .blue,
            category: .pet,
            rarity: .rare,
            isUnlocked: { _ in false } // Would need to track rename count
        )
        
        // MARK: - Expansion: Progression (adds up to 100 total)
        ,
        Achievement(
            id: "low_screen_week",
            title: "Low Screen Week",
            description: "Keep screen time under 3 hours per day for a week",
            icon: "chart.line.downtrend.xyaxis",
            color: .success,
            category: .usage,
            rarity: .uncommon,
            isUnlocked: { appState in
                let recentHistory = appState.dailyHistory.suffix(7)
                guard recentHistory.count >= 7 else { return false }
                return recentHistory.allSatisfy { $0.screenTimeMinutes < 180 }
            }
        ),
        Achievement(
            id: "puzzle_marathon",
            title: "Puzzle Marathon",
            description: "Solve 25 puzzles total",
            icon: "puzzlepiece.extension.fill",
            color: .purple,
            category: .usage,
            rarity: .uncommon,
            isUnlocked: { _ in
                guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return false }
                guard let puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] else { return false }
                return puzzleHistory.values.reduce(0, +) >= 25
            }
        ),
        Achievement(
            id: "blocked_category",
            title: "Category Blocker",
            description: "Block an entire app category",
            icon: "folder.fill.badge.minus",
            color: .orange,
            category: .usage,
            rarity: .uncommon,
            isUnlocked: { _ in
                BlockedAppsManager.shared.blockedSelection.categoryTokens.count >= 1
            }
        ),
        Achievement(
            id: "zero_puzzles_month",
            title: "Ultimate Discipline",
            description: "Go 30 days without solving any puzzles",
            icon: "crown.fill",
            color: .yellow,
            category: .usage,
            rarity: .legendary,
            isUnlocked: { appState in
                guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return false }
                guard let puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] else { return false }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let calendar = Calendar.current
                
                // Check last 30 days
                for dayOffset in 1...30 {
                    guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { return false }
                    let dateKey = dateFormatter.string(from: date)
                    if (puzzleHistory[dateKey] ?? 0) > 0 {
                        return false
                    }
                }
                return appState.longestStreak >= 30
            }
        ),
        Achievement(
            id: "screen_time_reducer",
            title: "Screen Time Reducer",
            description: "Reduce weekly average screen time by 50%",
            icon: "chart.line.downtrend.xyaxis",
            color: .success,
            category: .milestones,
            rarity: .rare,
            isUnlocked: { appState in
                let recentHistory = appState.dailyHistory.suffix(7)
                guard recentHistory.count >= 7 else { return false }
                let avgScreenTime = recentHistory.reduce(0) { $0 + $1.screenTimeMinutes } / recentHistory.count
                return avgScreenTime < 90 // Under 1.5 hours average
            }
        ),
        Achievement(
            id: "puzzle_variety",
            title: "Puzzle Variety",
            description: "Solve all 4 types of puzzles",
            icon: "puzzlepiece.extension.fill",
            color: .purple,
            category: .milestones,
            rarity: .uncommon,
            isUnlocked: { _ in false } // Would need to track puzzle types solved
        ),
        Achievement(
            id: "streak_45",
            title: "Month and a Half",
            description: "45-day streak",
            icon: "flame.fill",
            color: .warning,
            category: .streaks,
            rarity: .rare,
            isUnlocked: { appState in appState.longestStreak >= 45 }
        ),
        Achievement(
            id: "streak_60",
            title: "Two Months Strong",
            description: "60-day streak",
            icon: "flame.fill",
            color: .orange,
            category: .streaks,
            rarity: .epic,
            isUnlocked: { appState in appState.longestStreak >= 60 }
        ),
        Achievement(
            id: "streak_75",
            title: "Seventy-Five Alive",
            description: "75-day streak",
            icon: "flame.fill",
            color: .pink,
            category: .streaks,
            rarity: .epic,
            isUnlocked: { appState in appState.longestStreak >= 75 }
        ),
        Achievement(
            id: "streak_90",
            title: "Quarter Year",
            description: "90-day streak",
            icon: "flame.fill",
            color: .purple,
            category: .streaks,
            rarity: .epic,
            isUnlocked: { appState in appState.longestStreak >= 90 }
        ),
        Achievement(
            id: "streak_120",
            title: "Seasoned",
            description: "120-day streak",
            icon: "flame.fill",
            color: .yellow,
            category: .streaks,
            rarity: .legendary,
            isUnlocked: { appState in appState.longestStreak >= 120 }
        ),
        Achievement(
            id: "streak_150",
            title: "Half-Year Hero",
            description: "150-day streak",
            icon: "flame.fill",
            color: .purple,
            category: .streaks,
            rarity: .legendary,
            isUnlocked: { appState in appState.longestStreak >= 150 }
        ),
        Achievement(
            id: "streak_200",
            title: "Double Century",
            description: "200-day streak",
            icon: "flame.fill",
            color: .indigo,
            category: .streaks,
            rarity: .legendary,
            isUnlocked: { appState in appState.longestStreak >= 200 }
        ),
        Achievement(
            id: "streak_365",
            title: "Year One",
            description: "365-day streak",
            icon: "crown.fill",
            color: .yellow,
            category: .mastery,
            rarity: .legendary,
            isUnlocked: { appState in appState.longestStreak >= 365 }
        ),
        Achievement(
            id: "history_14",
            title: "Two-Week Tracker",
            description: "Log 14 days of history",
            icon: "calendar",
            color: .primary,
            category: .habits,
            rarity: .common,
            isUnlocked: { appState in appState.dailyHistory.count >= 14 }
        ),
        Achievement(
            id: "history_21",
            title: "Three-Week Tracker",
            description: "Log 21 days of history",
            icon: "calendar",
            color: .secondary,
            category: .habits,
            rarity: .common,
            isUnlocked: { appState in appState.dailyHistory.count >= 21 }
        ),
        Achievement(
            id: "history_30",
            title: "Month Logger",
            description: "Log 30 days of history",
            icon: "calendar",
            color: .success,
            category: .habits,
            rarity: .uncommon,
            isUnlocked: { appState in appState.dailyHistory.count >= 30 }
        ),
        Achievement(
            id: "history_45",
            title: "Record Keeper",
            description: "Log 45 days of history",
            icon: "calendar",
            color: .warning,
            category: .habits,
            rarity: .rare,
            isUnlocked: { appState in appState.dailyHistory.count >= 45 }
        ),
        Achievement(
            id: "history_60",
            title: "Habit Hero",
            description: "Log 60 days of history",
            icon: "calendar",
            color: .purple,
            category: .habits,
            rarity: .epic,
            isUnlocked: { appState in appState.dailyHistory.count >= 60 }
        ),
        Achievement(
            id: "history_90",
            title: "Quarter Keeper",
            description: "Log 90 days of history",
            icon: "calendar",
            color: .indigo,
            category: .habits,
            rarity: .epic,
            isUnlocked: { appState in appState.dailyHistory.count >= 90 }
        ),
        Achievement(
            id: "history_120",
            title: "Archive Master",
            description: "Log 120 days of history",
            icon: "calendar",
            color: .yellow,
            category: .habits,
            rarity: .legendary,
            isUnlocked: { appState in appState.dailyHistory.count >= 120 }
        ),
        Achievement(
            id: "achievements_5",
            title: "Collector",
            description: "Unlock 5 achievements",
            icon: "medal.fill",
            color: .primary,
            category: .meta,
            rarity: .common,
            isUnlocked: { appState in appState.unlockedAchievements.count >= 5 }
        ),
        Achievement(
            id: "achievements_10",
            title: "Collector II",
            description: "Unlock 10 achievements",
            icon: "medal.fill",
            color: .success,
            category: .meta,
            rarity: .common,
            isUnlocked: { appState in appState.unlockedAchievements.count >= 10 }
        ),
        Achievement(
            id: "achievements_20",
            title: "Collector III",
            description: "Unlock 20 achievements",
            icon: "medal.fill",
            color: .secondary,
            category: .meta,
            rarity: .uncommon,
            isUnlocked: { appState in appState.unlockedAchievements.count >= 20 }
        ),
        Achievement(
            id: "achievements_35",
            title: "Collector IV",
            description: "Unlock 35 achievements",
            icon: "medal.fill",
            color: .warning,
            category: .meta,
            rarity: .rare,
            isUnlocked: { appState in appState.unlockedAchievements.count >= 35 }
        ),
        Achievement(
            id: "achievements_50",
            title: "Collector V",
            description: "Unlock 50 achievements",
            icon: "medal.fill",
            color: .purple,
            category: .meta,
            rarity: .epic,
            isUnlocked: { appState in appState.unlockedAchievements.count >= 50 }
        ),
        Achievement(
            id: "achievements_75",
            title: "Collector VI",
            description: "Unlock 75 achievements",
            icon: "medal.fill",
            color: .yellow,
            category: .meta,
            rarity: .legendary,
            isUnlocked: { appState in appState.unlockedAchievements.count >= 75 }
        ),
        Achievement(
            id: "improvement_7days",
            title: "First Week Reset",
            description: "Keep a streak of 7 with daily history logged",
            icon: "checkmark.seal.fill",
            color: .success,
            category: .improvement,
            rarity: .uncommon,
            isUnlocked: { appState in appState.longestStreak >= 7 && appState.dailyHistory.count >= 7 }
        ),
        Achievement(
            id: "improvement_30days",
            title: "Month Reset",
            description: "Keep a streak of 30 with daily history logged",
            icon: "checkmark.seal.fill",
            color: .secondary,
            category: .improvement,
            rarity: .rare,
            isUnlocked: { appState in appState.longestStreak >= 30 && appState.dailyHistory.count >= 30 }
        ),
        Achievement(
            id: "improvement_90days",
            title: "Quarter Reset",
            description: "Keep a streak of 90 with daily history logged",
            icon: "checkmark.seal.fill",
            color: .purple,
            category: .improvement,
            rarity: .epic,
            isUnlocked: { appState in appState.longestStreak >= 90 && appState.dailyHistory.count >= 90 }
        ),
        Achievement(
            id: "improvement_180days",
            title: "Half-Year Reset",
            description: "Keep a streak of 180 with daily history logged",
            icon: "checkmark.seal.fill",
            color: .yellow,
            category: .improvement,
            rarity: .legendary,
            isUnlocked: { appState in appState.longestStreak >= 180 && appState.dailyHistory.count >= 180 }
        ),
        Achievement(
            id: "apps_used_1",
            title: "One and Done",
            description: "Track at least 1 app with real usage > 0",
            icon: "app.fill",
            color: .primary,
            category: .usage,
            rarity: .common,
            isUnlocked: { appState in appState.monitoredApps.contains { $0.usedToday > 0 } }
        ),
        Achievement(
            id: "apps_used_5",
            title: "Five Alive",
            description: "Track 5 apps with real usage > 0",
            icon: "app.fill",
            color: .success,
            category: .usage,
            rarity: .uncommon,
            isUnlocked: { appState in appState.monitoredApps.filter { $0.usedToday > 0 }.count >= 5 }
        ),
        Achievement(
            id: "apps_used_10",
            title: "Ten Tracked",
            description: "Track 10 apps with real usage > 0",
            icon: "app.fill",
            color: .warning,
            category: .usage,
            rarity: .rare,
            isUnlocked: { appState in appState.monitoredApps.filter { $0.usedToday > 0 }.count >= 10 }
        ),
        Achievement(
            id: "apps_used_15",
            title: "Fifteen Focus",
            description: "Track 15 apps with real usage > 0",
            icon: "app.fill",
            color: .purple,
            category: .usage,
            rarity: .epic,
            isUnlocked: { appState in appState.monitoredApps.filter { $0.usedToday > 0 }.count >= 15 }
        ),
        Achievement(
            id: "apps_used_20",
            title: "Twenty Tracker",
            description: "Track 20 apps with real usage > 0",
            icon: "app.fill",
            color: .yellow,
            category: .usage,
            rarity: .legendary,
            isUnlocked: { appState in appState.monitoredApps.filter { $0.usedToday > 0 }.count >= 20 }
        )
    ]
}

// MARK: - Achievement Categories
enum AchievementCategory: String, CaseIterable {
    case gettingStarted = "Getting Started"
    case streaks = "Streaks"
    case screenTime = "Screen Time"
    case usage = "App Usage"
    case habits = "Daily Habits"
    case milestones = "Milestones"
    case challenges = "Challenges"
    case social = "Social"
    case special = "Special Events"
    case meta = "Meta"
    case improvement = "Self-Improvement"
    case seasonal = "Seasonal"
    case fun = "Just for Fun"
    case mastery = "Mastery"
    case hidden = "Hidden"
    case precision = "Precision"
    case financial = "Financial"
    case minimalism = "Minimalism"
    case pet = "Pet"
    
    var icon: String {
        switch self {
        case .gettingStarted: return "star.fill"
        case .streaks: return "flame.fill"
        case .screenTime: return "clock.fill"
        case .usage: return "apps.iphone"
        case .habits: return "repeat.circle.fill"
        case .milestones: return "flag.fill"
        case .challenges: return "target"
        case .social: return "person.3.fill"
        case .special: return "party.popper.fill"
        case .meta: return "trophy.fill"
        case .improvement: return "chart.line.uptrend.xyaxis"
        case .seasonal: return "calendar.circle.fill"
        case .fun: return "face.smiling.fill"
        case .mastery: return "crown.fill"
        case .hidden: return "eye.slash.fill"
        case .precision: return "target"
        case .financial: return "dollarsign.circle.fill"
        case .minimalism: return "minus.circle.fill"
        case .pet: return "pawprint.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .gettingStarted: return .success
        case .streaks: return .error  
        case .screenTime: return .blue
        case .usage: return .secondary
        case .habits: return .success
        case .milestones: return .warning
        case .challenges: return .error
        case .social: return .secondary
        case .special: return .pink
        case .meta: return .yellow
        case .improvement: return .primary
        case .seasonal: return .secondary
        case .fun: return .pink
        case .mastery: return .purple
        case .hidden: return .gray
        case .precision: return .indigo
        case .financial: return .green
        case .minimalism: return .gray
        case .pet: return .pink
        }
    }
}

// MARK: - Achievement Rarity
enum AchievementRarity: String, CaseIterable {
    case common = "Common"
    case uncommon = "Uncommon" 
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
    
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .success
        case .rare: return .secondary
        case .epic: return .purple
        case .legendary: return .yellow
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .common: return .gray.opacity(0.1)
        case .uncommon: return .success.opacity(0.1)
        case .rare: return .secondary.opacity(0.1)
        case .epic: return .purple.opacity(0.1)
        case .legendary: return .yellow.opacity(0.1)
        }
    }
}

// MARK: - App Usage
struct AppUsage: Identifiable {
    let id: UUID
    let appName: String
    let icon: String
    let timeSpent: Int // in minutes
    let limit: Int // in minutes
    let status: UsageStatus
    
    enum UsageStatus {
        case withinLimit
        case warning
        case exceeded
    }
}

// MARK: - User Goal
struct UserGoal: Identifiable {
    let id: UUID
    let appName: String
    let dailyLimit: Int // in minutes
    let currentUsage: Int // in minutes
    let isActive: Bool
}

// MARK: - Daily History
struct DailyHistory: Identifiable {
    let id: UUID = UUID()
    let date: Date
    let screenTimeMinutes: Int
    let puzzlesSolved: Int
    
    var isSuccess: Bool {
        // Success if screen time under 2 hours
        screenTimeMinutes < 120
    }
}

// MARK: - Pet System

enum PetType: String, CaseIterable, Identifiable, Codable {
    case dog = "Dog"
    case cat = "Cat"
    case bunny = "Bunny"
    case hamster = "Hamster"
    case horse = "Horse"
    
    var id: String { rawValue }
    
    var folderName: String {
        switch self {
        case .dog: return "Dog"
        case .cat: return "Cat"
        case .bunny: return "Bunny"
        case .hamster: return "Hamster"
        case .horse: return "Horse"
        }
    }
    
    var description: String {
        switch self {
        case .dog: return "Loyal, playful, and always ready for adventure"
        case .cat: return "Independent and graceful friend"
        case .bunny: return "Cute and energetic hopping companion"
        case .hamster: return "Small but mighty productivity buddy"
        case .horse: return "Strong and noble companion"
        }
    }
}

enum PetHealthState: String, CaseIterable, Codable {
    case sick = "sick"
    case sad = "sad"
    case content = "content"
    case happy = "happy"
    case fullHealth = "fullhealth"
    
    var displayName: String {
        switch self {
        case .sick: return "Sick"
        case .sad: return "Sad"
        case .content: return "Content"
        case .happy: return "Happy"
        case .fullHealth: return "Full Health"
        }
    }
    
    var color: Color {
        switch self {
        case .sick: return .red
        case .sad: return .orange
        case .content: return .yellow
        case .happy: return Color(red: 0.5, green: 0.85, blue: 0.7) // Watery green
        case .fullHealth: return .green
        }
    }
    
    var description: String {
        switch self {
        case .sick: return "Your pet is very sick and needs immediate attention!"
        case .sad: return "Your pet is feeling down and needs some care."
        case .content: return "Your pet is doing okay but could be happier."
        case .happy: return "Your pet is feeling good and enjoying life!"
        case .fullHealth: return "Your pet is thriving and at perfect health!"
        }
    }
}

struct Pet: Identifiable, Codable {
    let id: UUID
    let type: PetType
    var name: String
    var healthState: PetHealthState
    let createdAt: Date
    
    init(type: PetType, name: String, healthState: PetHealthState = .fullHealth) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.healthState = healthState
        self.createdAt = Date()
    }
}

enum DownloadMotivation: String, CaseIterable, Identifiable {
    case improveFocus = "Improve focus"
    case reduceMindlessScrolling = "Reduce mindless scrolling"
    case sleepBetter = "Sleep better"
    case beMorePresent = "Be more present"
    case beMoreProductive = "Be more productive"
    case justCurious = "Just curious"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .improveFocus: return "target"
        case .reduceMindlessScrolling: return "clock.arrow.circlepath"
        case .sleepBetter: return "moon.zzz.fill"
        case .beMorePresent: return "person.2.fill"
        case .beMoreProductive: return "chart.line.uptrend.xyaxis"
        case .justCurious: return "magnifyingglass"
        }
    }
}

// MARK: - Limit Storage Types (for UUID-based limit tracking)

struct StoredAppLimit: Codable, Identifiable {
    let id: UUID
    let appName: String
    var dailyLimitMinutes: Int
    var usageMinutes: Int
    var isActive: Bool
    let createdAt: Date
    let selectionData: Data
    
    init(id: UUID = UUID(), appName: String, dailyLimitMinutes: Int, selection: FamilyActivitySelection) {
        self.id = id
        self.appName = appName
        self.dailyLimitMinutes = dailyLimitMinutes
        self.usageMinutes = 0
        self.isActive = true
        self.createdAt = Date()
        self.selectionData = (try? PropertyListEncoder().encode(selection)) ?? Data()
    }
    
    func getSelection() -> FamilyActivitySelection? {
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData)
    }
    
    func containsToken(_ token: AnyHashable) -> Bool {
        guard let selection = getSelection() else { return false }
        
        // ✅ Try direct ApplicationToken comparison first
        // Cast AnyHashable to ApplicationToken by trying each token in selection
        for storedToken in selection.applicationTokens {
            if (storedToken as AnyHashable) == token {
                return true
            }
        }
        
        // Fallback for category tokens
        for storedToken in selection.categoryTokens {
            if (storedToken as AnyHashable) == token {
                return true
            }
        }
        
        return false
    }
}

final class LimitStorageManager {
    static let shared = LimitStorageManager()
    
    private let appGroupID = "group.com.se7en.app"
    private let limitsKey = "stored_app_limits_v2"
    private let usagePrefix = "usage_v2_"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    private init() {}
    
    func saveLimits(_ limits: [StoredAppLimit]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(limits) else { return }
        defaults.set(data, forKey: limitsKey)
        defaults.synchronize()
    }
    
    func loadLimits() -> [StoredAppLimit] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: limitsKey),
              let limits = try? JSONDecoder().decode([StoredAppLimit].self, from: data) else {
            return []
        }
        return limits
    }
    
    func addLimit(_ limit: StoredAppLimit) {
        var limits = loadLimits()
        limits.removeAll { $0.appName.lowercased() == limit.appName.lowercased() }
        limits.append(limit)
        saveLimits(limits)
    }
    
    func removeLimit(id: UUID) {
        var limits = loadLimits()
        limits.removeAll { $0.id == id }
        saveLimits(limits)
        sharedDefaults?.removeObject(forKey: usagePrefix + id.uuidString)
        sharedDefaults?.synchronize()
    }
    
    func updateLimit(id: UUID, dailyLimitMinutes: Int? = nil, isActive: Bool? = nil) {
        var limits = loadLimits()
        if let index = limits.firstIndex(where: { $0.id == id }) {
            if let minutes = dailyLimitMinutes {
                limits[index].dailyLimitMinutes = minutes
            }
            if let active = isActive {
                limits[index].isActive = active
            }
            saveLimits(limits)
        }
    }
    
    func setUsage(for limitID: UUID, minutes: Int) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(minutes, forKey: usagePrefix + limitID.uuidString)
        var limits = loadLimits()
        if let index = limits.firstIndex(where: { $0.id == limitID }) {
            limits[index].usageMinutes = minutes
            saveLimits(limits)
        }
        defaults.synchronize()
    }
    
    func getUsage(for limitID: UUID) -> Int {
        guard let defaults = sharedDefaults else { return 0 }
        return defaults.integer(forKey: usagePrefix + limitID.uuidString)
    }
    
    func findLimit(for token: AnyHashable) -> StoredAppLimit? {
        let limits = loadLimits()
        for limit in limits {
            if limit.containsToken(token) {
                return limit
            }
        }
        return nil
    }
    
    func findLimit(byAppName name: String) -> StoredAppLimit? {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return loadLimits().first {
            $0.appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
        }
    }
    
    func getActiveLimits() -> [StoredAppLimit] {
        return loadLimits().filter { $0.isActive }
    }
}
