import SwiftUI
import UIKit

// MARK: - Monitored App
struct MonitoredApp: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var icon: String // SF Symbol name
    var dailyLimit: Int // in minutes
    var usedToday: Int // in minutes
    var color: Color
    var isEnabled: Bool = true
    
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
    var creditChange: Int // -1 if lost, 0 if kept
    
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
        creditChange == 0
    }
}

// MARK: - Credit Package
struct CreditPackage: Identifiable {
    let id = UUID()
    let credits: Int
    let price: Double
    
    var priceString: String {
        // Use localized currency formatting
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
    }
    
    var perCreditPrice: Double {
        price / Double(credits)
    }
    
    static let packages: [CreditPackage] = [
        CreditPackage(credits: 1, price: 0.99),
        CreditPackage(credits: 2, price: 1.99),
        CreditPackage(credits: 3, price: 2.99),
        CreditPackage(credits: 4, price: 3.99),
        CreditPackage(credits: 5, price: 4.99),
        CreditPackage(credits: 6, price: 5.99),
        CreditPackage(credits: 7, price: 6.99)
    ]
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
            return "Start with 7 credits today"
        }
    }
}

// MARK: - Achievement
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
            title: "Goal Setter",
            description: "Set limits for 3 or more apps",
            icon: "target",
            color: .secondary,
            category: .gettingStarted,
            rarity: .common,
            isUnlocked: { appState in appState.monitoredApps.count >= 3 }
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
        
        // MARK: - Credit Management
        Achievement(
            id: "perfect_week",
            title: "Perfect Week",
            description: "Finish a week with all 7 credits",
            icon: "checkmark.seal.fill",
            color: .success,
            category: .credits,
            rarity: .uncommon,
            isUnlocked: { appState in appState.currentCredits == 7 }
        ),
        
        Achievement(
            id: "comeback_kid",
            title: "Comeback Kid",
            description: "Recover from 1 credit to 7 credits",
            icon: "arrow.up.circle.fill",
            color: .primary,
            category: .credits,
            rarity: .uncommon,
            isUnlocked: { _ in false } // Complex logic needed
        ),
        
        Achievement(
            id: "credit_saver",
            title: "Credit Saver",
            description: "Never drop below 5 credits for a month",
            icon: "shield.fill",
            color: .success,
            category: .credits,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        // MARK: - App Usage
        Achievement(
            id: "social_detox",
            title: "Social Detox",
            description: "Stay under limits on all social apps for 7 days",
            icon: "person.slash.fill",
            color: .secondary,
            category: .usage,
            rarity: .uncommon,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "minimalist",
            title: "Digital Minimalist",
            description: "Use less than 50% of daily limits for a week",
            icon: "leaf.fill",
            color: .success,
            category: .usage,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "efficiency_expert",
            title: "Efficiency Expert", 
            description: "Use less than 25% of daily limits for a week",
            icon: "speedometer",
            color: .primary,
            category: .usage,
            rarity: .epic,
            isUnlocked: { _ in false }
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
            description: "Check limits after 10 PM for 7 days",
            icon: "moon.fill",
            color: .purple,
            category: .habits,
            rarity: .common,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "weekend_warrior_v2",
            title: "Weekend Warrior",
            description: "Maintain limits during weekends for 4 weeks",
            icon: "gamecontroller.fill",
            color: .secondary,
            category: .habits,
            rarity: .rare,
            isUnlocked: { _ in false }
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
            id: "zero_tolerance",
            title: "Zero Tolerance",
            description: "Go 30 days without losing any credits",
            icon: "shield.righthalf.fill",
            color: .success,
            category: .challenges,
            rarity: .epic,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "recovery_master",
            title: "Recovery Master", 
            description: "Bounce back from 0 credits 5 times",
            icon: "arrow.clockwise.circle.fill",
            color: .primary,
            category: .challenges,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "app_destroyer",
            title: "App Destroyer",
            description: "Remove an app from monitoring after 30 days under limit",
            icon: "trash.circle.fill",
            color: .error,
            category: .challenges,
            rarity: .uncommon,
            isUnlocked: { _ in false }
        ),
        
        // MARK: - Social Features (Future)
        Achievement(
            id: "trendsetter",
            title: "Trendsetter",
            description: "Be the first among friends to reach 50-day streak",
            icon: "chart.line.uptrend.xyaxis",
            color: .secondary,
            category: .social,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "supportive_friend",
            title: "Supportive Friend",
            description: "Help 5 friends set up their goals",
            icon: "hand.raised.fill",
            color: .success,
            category: .social,
            rarity: .uncommon,
            isUnlocked: { _ in false }
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
            description: "Reduce all app limits during spring",
            icon: "leaf.arrow.circlepath",
            color: .success,
            category: .special,
            rarity: .uncommon,
            isUnlocked: { _ in false }
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
        
        // MARK: - Improvement Achievements
        Achievement(
            id: "gradual_improver",
            title: "Gradual Improver",
            description: "Reduce total daily limits by 2+ hours over a month",
            icon: "chart.line.downtrend.xyaxis",
            color: .primary,
            category: .improvement,
            rarity: .rare,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "goal_adjuster",
            title: "Goal Adjuster",
            description: "Fine-tune your limits 10 times",
            icon: "slider.horizontal.3",
            color: .secondary,
            category: .improvement,
            rarity: .common,
            isUnlocked: { _ in false }
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
            description: "Successfully transition day limits at exactly midnight",
            icon: "clock.fill",
            color: .purple,
            category: .fun,
            rarity: .uncommon,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "lucky_seven",
            title: "Lucky Seven",
            description: "Maintain exactly 7 credits for 7 consecutive weeks",
            icon: "dice.fill",
            color: .primary,
            category: .fun,
            rarity: .epic,
            isUnlocked: { _ in false }
        ),
        
        // MARK: - Mastery Achievements
        Achievement(
            id: "self_control_sensei",
            title: "Self-Control Sensei",
            description: "Master all aspects: 50+ day streak, 20+ achievements, perfect week",
            icon: "figure.martial.arts",
            color: .purple,
            category: .mastery,
            rarity: .legendary,
            isUnlocked: { appState in 
                appState.longestStreak >= 50 && 
                appState.unlockedAchievements.count >= 20 && 
                appState.currentCredits == 7
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
            isUnlocked: { _ in false }
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
            description: "Check your limits before 8 AM for 10 days",
            icon: "sunrise.fill",
            color: .yellow,
            category: .habits,
            rarity: .uncommon,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "limit_ninja",
            title: "Limit Ninja",
            description: "Stay exactly at your limit (within 5 minutes) for 5 apps",
            icon: "figure.martial.arts",
            color: .indigo,
            category: .precision,
            rarity: .rare,
            isUnlocked: { _ in false }
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
            id: "credit_saver",
            title: "Credit Saver",
            description: "End 10 weeks in a row with all 7 credits intact",
            icon: "banknote.fill",
            color: .green,
            category: .financial,
            rarity: .epic,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "app_minimalist",
            title: "App Minimalist",
            description: "Successfully monitor only 1 app for 30 days",
            icon: "minus.circle.fill",
            color: .gray,
            category: .minimalism,
            rarity: .uncommon,
            isUnlocked: { _ in false }
        ),
        
        Achievement(
            id: "digital_detox_master",
            title: "Digital Detox Master",
            description: "Go 7 days without opening any monitored apps",
            icon: "power.circle.fill",
            color: .red,
            category: .mastery,
            rarity: .legendary,
            isUnlocked: { _ in false }
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
                // Check if pet has been at full health (this would need tracking)
                return pet.healthState == .fullHealth && appState.currentCredits == 7
            }
        ),
        
        Achievement(
            id: "pet_happy_week",
            title: "Happy Companion",
            description: "Keep your pet happy or healthier for a full week",
            icon: "face.smiling.fill",
            color: .yellow,
            category: .pet,
            rarity: .uncommon,
            isUnlocked: { appState in 
                guard let pet = appState.userPet else { return false }
                return (pet.healthState == .fullHealth || pet.healthState == .happy) && 
                       appState.currentCredits >= 5
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
                // This would need to track if pet was sick and is now healthy
                return pet.healthState == .fullHealth && appState.currentCredits == 7
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
                // Health score of 100 means perfect usage
                let totalUsage = appState.monitoredApps.reduce(0) { $0 + $1.usedToday }
                let totalLimits = appState.monitoredApps.reduce(0) { $0 + $1.dailyLimit }
                guard totalLimits > 0 else { return false }
                let usagePercentage = Double(totalUsage) / Double(totalLimits)
                return usagePercentage <= 0.5 && pet.healthState == .fullHealth
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
    ]
}

// MARK: - Achievement Categories
enum AchievementCategory: String, CaseIterable {
    case gettingStarted = "Getting Started"
    case streaks = "Streaks"
    case credits = "Credit Management"
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
        case .credits: return "creditcard.fill"
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
        case .credits: return .primary
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
    let creditChange: Int
    
    var isSuccess: Bool {
        creditChange >= 0
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


