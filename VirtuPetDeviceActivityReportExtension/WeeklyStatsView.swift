//
//  WeeklyStatsView.swift
//  SE7ENDeviceActivityReportExtension
//
//  View for displaying weekly statistics with Focus Score
//

import SwiftUI
import FamilyControls

struct WeeklyStatsView: View {
    let stats: WeeklyStatsData
    
    @Environment(\.colorScheme) var colorScheme
    
    // Use same colors as the main app
    private var cardBackground: Color {
        if colorScheme == .dark {
            return Color(red: 0.22, green: 0.22, blue: 0.23) // Same as main app cardBackground
        } else {
            return Color(red: 1.0, green: 0.988, blue: 0.941) // Light yellow tint
        }
    }
    
    // Calculate focus score based on multiple factors
    private var focusScore: Int {
        var score = 50 // Base score
        
        // Streak bonus (up to +20)
        score += min(stats.currentStreak * 3, 20)
        
        // Blocked apps bonus (up to +15)
        score += min(stats.blockedAppsCount * 3, 15)
        
        // Low screen time bonus (up to +15) - use average screen time
        let avgScreenTimeHours = Double(stats.averageScreenTimeMinutes) / 60.0
        if avgScreenTimeHours < 2 {
            score += 15
        } else if avgScreenTimeHours < 4 {
            score += 10
        } else if avgScreenTimeHours < 6 {
            score += 5
        }
        
        return min(100, max(0, score))
    }
    
    private var focusGrade: String {
        switch focusScore {
        case 90...100: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        case 50..<60: return "D"
        default: return "F"
        }
    }
    
    private var gradeColor: Color {
        switch focusScore {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private var screenTimeHours: Int {
        Int(Double(stats.averageScreenTimeMinutes) / 60.0)
    }
    
    private var screenTimeDisplayText: String {
        let hours = screenTimeHours
        let mins = stats.averageScreenTimeMinutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // This Week Section (Daily Health Cards)
            if !stats.dailyHealthData.isEmpty {
                ThisWeekSection(stats: stats)
            }
            
            // Best Day & Average Screen Time (top section)
            HStack(spacing: 12) {
                // Best Day Card
                StatCard(
                    icon: "star.fill",
                    iconColor: .orange,
                    title: "Best Day",
                    value: stats.bestDay,
                    subtitle: stats.bestDayMinutes > 0 ? formatMinutes(stats.bestDayMinutes) : "No data",
                    gradientColors: [.orange.opacity(0.15), .yellow.opacity(0.1)],
                    cardBackground: cardBackground
                )
                
                // Average Screen Time Card
                StatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .blue,
                    title: "Avg Screen",
                    value: formatMinutes(stats.averageScreenTimeMinutes),
                    subtitle: "This week",
                    gradientColors: [.blue.opacity(0.15), .cyan.opacity(0.1)],
                    cardBackground: cardBackground
                )
            }
            .padding(.horizontal, 4)
            
            // Focus Score Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Focus Score")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Based on your habits this week")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Grade badge
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [gradeColor, gradeColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Text(focusGrade)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: gradeColor.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                
                // Score breakdown
                VStack(spacing: 10) {
                    FocusScoreBar(
                        title: "Streak",
                        actualValue: stats.currentStreak,
                        maxValue: 10,
                        displayText: "\(stats.currentStreak) days",
                        color: .orange,
                        icon: "flame.fill"
                    )
                    FocusScoreBar(
                        title: "App Blocking",
                        actualValue: stats.blockedAppsCount,
                        maxValue: 10,
                        displayText: "\(stats.blockedAppsCount) apps",
                        color: .green,
                        icon: "hand.raised.fill"
                    )
                    FocusScoreBar(
                        title: "Screen Time",
                        actualValue: screenTimeHours,
                        maxValue: 8,
                        displayText: screenTimeDisplayText,
                        color: .blue,
                        icon: "iphone"
                    )
                }
                .padding(12)
                .background(cardBackground.opacity(0.5))
                .cornerRadius(10)
            }
            .padding(16)
            .background(cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 4)
            
            // Top 5 Apps Section
            if !stats.topApps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top 5 Most Used Apps")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 8) {
                        ForEach(Array(stats.topApps.enumerated()), id: \.offset) { index, app in
                            HStack(spacing: 12) {
                                // Rank number
                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                
                                // App icon (if available)
                                if let application = app.application,
                                   let token = application.token {
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .frame(width: 32, height: 32)
                                } else {
                                    // Fallback icon
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(rankColor(index).opacity(0.2))
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "app.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(rankColor(index))
                                    }
                                }
                                
                                // App name
                                Text(app.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // Usage time
                                Text(formatMinutes(app.minutes))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(cardBackground)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Coach Insights Section
            CoachInsightsView(stats: stats, cardBackground: cardBackground)
        }
        .padding(.vertical, 16)
    }
    
    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return .gray
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if mins > 0 {
            return "\(mins)m"
        } else {
            return "0m"
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    let gradientColors: [Color]
    let cardBackground: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Focus Score Bar
struct FocusScoreBar: View {
    let title: String
    let actualValue: Int
    let maxValue: Int
    let displayText: String
    let color: Color
    let icon: String
    
    private var fillPercentage: Double {
        Double(min(actualValue, maxValue)) / Double(maxValue)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(displayText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * fillPercentage, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

// MARK: - Coach Insights View
struct CoachInsightsView: View {
    let stats: WeeklyStatsData
    let cardBackground: Color
    
    private var insights: [Insight] {
        var insights: [Insight] = []
        
        // Screen time trending analysis
        if stats.isIncreasing {
            insights.append(Insight(
                icon: "arrow.up.circle.fill",
                iconColor: .red,
                title: "Screen Time Increasing",
                message: "Your screen time is trending upward this week. Try setting stricter limits.",
                type: .warning
            ))
        } else if stats.averageScreenTimeMinutes < 180 { // Less than 3 hours
            insights.append(Insight(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "Excellent Control",
                message: "You're averaging under 3 hours per day. Keep up the great work!",
                type: .achievement
            ))
        }
        
        // Top app analysis
        if let topApp = stats.topApps.first, stats.totalScreenTimeMinutes > 0 {
            let percentage = (Double(topApp.minutes) / Double(stats.totalScreenTimeMinutes)) * 100
            if percentage > 40 {
                insights.append(Insight(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    title: "\(topApp.name) Dominates",
                    message: "\(topApp.name) accounts for \(Int(percentage))% of your screen time. Consider setting a limit.",
                    type: .info
                ))
            }
        }
        
        // Best vs worst day comparison
        if stats.worstDayMinutes > 0 && stats.bestDayMinutes > 0 {
            let difference = stats.worstDayMinutes - stats.bestDayMinutes
            if difference > 180 { // More than 3 hours difference
                insights.append(Insight(
                    icon: "calendar.circle.fill",
                    iconColor: .blue,
                    title: "Inconsistent Usage",
                    message: "\(stats.worstDay) (\(formatMinutes(stats.worstDayMinutes))) had \(formatMinutes(difference)) more screen time than \(stats.bestDay). Try to stay consistent.",
                    type: .info
                ))
            }
        }
        
        // Peak hour analysis
        if let peakHour = stats.peakUsageHour {
            let timeStr = formatHour(peakHour)
            if peakHour >= 22 || peakHour <= 6 {
                insights.append(Insight(
                    icon: "moon.fill",
                    iconColor: .purple,
                    title: "Late Night Usage",
                    message: "Most of your screen time is around \(timeStr). This may affect your sleep quality.",
                    type: .warning
                ))
            } else {
                insights.append(Insight(
                    icon: "clock.fill",
                    iconColor: .blue,
                    title: "Peak Usage: \(timeStr)",
                    message: "Your screen time peaks around \(timeStr). Plan activities during this time to reduce usage.",
                    type: .info
                ))
            }
        }
        
        // Streak encouragement
        if stats.currentStreak >= 7 {
            insights.append(Insight(
                icon: "flame.fill",
                iconColor: .orange,
                title: "\(stats.currentStreak) Day Streak! 🔥",
                message: "Amazing consistency! You're building a strong habit of daily check-ins.",
                type: .achievement
            ))
        } else if stats.currentStreak < 3 {
            insights.append(Insight(
                icon: "target",
                iconColor: .blue,
                title: "Build Your Streak",
                message: "Check in daily to build your streak. Consistency is key to forming better habits!",
                type: .motivation
            ))
        }
        
        // Average screen time context
        if stats.averageScreenTimeMinutes > 360 { // Over 6 hours
            insights.append(Insight(
                icon: "hourglass.circle.fill",
                iconColor: .red,
                title: "High Screen Time",
                message: "You're averaging \(formatMinutes(stats.averageScreenTimeMinutes)) per day. Consider blocking more distracting apps.",
                type: .warning
            ))
        }
        
        // If very few insights, add encouraging message
        if insights.count < 2 {
            insights.append(Insight(
                icon: "hands.sparkles.fill",
                iconColor: .green,
                title: "You're Doing Great!",
                message: "Your screen time habits are looking healthy. Keep monitoring and adjusting as needed.",
                type: .achievement
            ))
        }
        
        return insights
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header (matching original design)
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Coach Insights")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 4)
            
            // Insights list (matching original GoalRecommendationsCard style)
            ForEach(Array(insights.prefix(4).enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(insight.type.backgroundColor)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: insight.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(insight.iconColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(insight.message)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            if insights.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Getting to know you...")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Insights will appear as you use the app and build your digital wellness habits.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 4)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let calendar = Calendar.current
        if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) {
            return formatter.string(from: date).lowercased()
        }
        return "\(hour):00"
    }
}

// MARK: - Insight Model
struct Insight {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let type: InsightType
    
    enum InsightType {
        case warning, info, achievement, motivation
        
        var backgroundColor: Color {
            switch self {
            case .warning: return .red.opacity(0.1)
            case .achievement: return .green.opacity(0.1)
            case .motivation: return .blue.opacity(0.1)
            case .info: return .orange.opacity(0.1)
            }
        }
    }
}

// MARK: - This Week Section
struct ThisWeekSection: View {
    let stats: WeeklyStatsData
    
    @Environment(\.colorScheme) var colorScheme
    
    private var petType: PetType {
        PetType(rawValue: stats.userPetType) ?? .dog
    }
    
    private var cardBackground: Color {
        if colorScheme == .dark {
            return Color(red: 0.22, green: 0.22, blue: 0.23)
        } else {
            return Color(red: 1.0, green: 0.988, blue: 0.941)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(UIColor.label))
                    
                    Text("Daily screen time overview")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            
            // Horizontal scrollable row of pet health cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(stats.dailyHealthData, id: \.date) { dayData in
                        WeeklyHealthCardView(
                            dayName: dayData.dayName,
                            dayNumber: dayData.dayNumber,
                            healthScore: dayData.healthScore,
                            screenTimeMinutes: dayData.screenTimeMinutes,
                            petMood: PetHealthState(rawValue: dayData.petMood) ?? .sick,
                            isToday: dayData.isToday,
                            isFuture: dayData.isFuture,
                            isBeforeInstall: dayData.isBeforeInstall,
                            petType: petType
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
        .padding(20)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Weekly Health Card
struct WeeklyHealthCardView: View {
    let dayName: String
    let dayNumber: Int
    let healthScore: Int
    let screenTimeMinutes: Int  // Add screen time
    let petMood: PetHealthState
    let isToday: Bool
    let isFuture: Bool
    let isBeforeInstall: Bool
    let petType: PetType
    
    @Environment(\.colorScheme) var colorScheme
    
    private var isInactive: Bool {
        isFuture || isBeforeInstall
    }
    
    // Card background matching app background
    private var cardBackground: Color {
        if colorScheme == .dark {
            return Color(red: 0.18, green: 0.18, blue: 0.19) // Same as appBackground in dark mode
        } else {
            return Color(red: 1.0, green: 0.98, blue: 0.9) // Same as appBackground in light mode
        }
    }
    
    // Format screen time
    private var screenTimeText: String {
        let hours = screenTimeMinutes / 60
        let mins = screenTimeMinutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Day name and number with subtle background
            VStack(spacing: 3) {
                Text(dayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isInactive ? .secondary.opacity(0.5) : .secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text("\(dayNumber)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isInactive ? .secondary.opacity(0.5) : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isToday ? Color.green.opacity(0.12) : Color.clear)
            )
            
            // Pet image with shadow
            ZStack {
                if isInactive {
                    // Gray placeholder for future days or before install
                    Image("\(petType.folderName.lowercased())content")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 58, height: 58)
                        .grayscale(1.0)
                        .opacity(0.35)
                } else {
                    // Actual pet image based on health state
                    let imageName = "\(petType.folderName.lowercased())\(petMood.rawValue)"
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 58, height: 58)
                        .shadow(color: petMood.color.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
            .frame(height: 58)
            
            // Screen time with background pill
            Group {
                if isBeforeInstall {
                    Text("N/A")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.4))
                } else if isFuture {
                    Text("-")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.3))
                } else {
                    Text(screenTimeText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(petMood.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isInactive ? Color.clear : petMood.color.opacity(0.12))
            )
        }
        .frame(width: 90)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isToday ? Color.green.opacity(0.5) : Color.primary.opacity(0.08),
                    lineWidth: isToday ? 2 : 1
                )
        )
        .shadow(color: Color.black.opacity(isInactive ? 0.03 : 0.08), radius: 8, x: 0, y: 3)
    }
}


