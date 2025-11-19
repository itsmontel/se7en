import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedWeekOffset: Int = 0 // 0 = current week, -1 = last week, etc.
    
    // Calculate the start of the selected week (Monday)
    private var weekStart: Date {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        
        // Adjust to Monday (weekday 2)
        let weekday = calendar.component(.weekday, from: currentWeekStart)
        let daysToMonday = (weekday + 5) % 7 // Convert to Monday-based week
        let monday = calendar.date(byAdding: .day, value: -daysToMonday + (selectedWeekOffset * 7), to: currentWeekStart) ?? currentWeekStart
        
        return monday
    }
    
    // Check if we can go forward (can't go past current week)
    private var canGoForward: Bool {
        selectedWeekOffset < 0
    }
    
    // Week range string
    private var weekRangeString: String {
        let calendar = Calendar.current
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if calendar.isDate(weekStart, equalTo: endOfWeek, toGranularity: .year) {
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: endOfWeek))"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: endOfWeek))"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with week navigation
                        VStack(spacing: 16) {
                            HStack {
                                Text("Stats")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                            }
                            
                            // Week navigation
                            HStack {
                                Button(action: {
                                    withAnimation {
                                        selectedWeekOffset -= 1
                                    }
                                }) {
                                    Image(systemName: "chevron.left.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                                
                                VStack(spacing: 4) {
                                    Text(weekRangeString)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.textPrimary)
                                    
                                    if selectedWeekOffset == 0 {
                                        Text("This Week")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if canGoForward {
                                        withAnimation {
                                            selectedWeekOffset += 1
                                        }
                                    }
                                }) {
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(canGoForward ? .blue : .gray.opacity(0.3))
                                }
                                .disabled(!canGoForward)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        
                        // Daily Discipline Overview (moved to top)
                        GoalProgressOverview(
                            totalLimit: totalLimit,
                            totalUsed: totalUsed,
                            disciplineScore: disciplineScore,
                            streak: appState.currentStreak,
                            longestStreak: appState.longestStreak
                        )
                        .padding(.horizontal, 20)
                        
                        // Weekly Health Report (redesigned like Brainrot Report)
                        WeeklyHealthReport(weekStart: weekStart, appState: appState)
                            .padding(.horizontal, 20)
                        
                        // App Launches Report (with horizontal bar chart)
                        AppLaunchesReport(weekStart: weekStart, appState: appState)
                            .padding(.horizontal, 20)
                        
                        if !focusApps.isEmpty {
                            FocusAppsCard(apps: Array(focusApps.prefix(3)))
                                .padding(.horizontal, 20)
                        }
                        
                        // Coach Insights (moved to bottom, showing all insights)
                        GoalRecommendationsCard(recommendations: recommendations)
                        .padding(.horizontal, 20)
                        
                        // Monitored Apps
                        VStack(spacing: 12) {
                            ForEach(appState.monitoredApps) { app in
                                GoalCard(app: binding(for: app))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var totalLimit: Int {
        appState.monitoredApps.reduce(0) { $0 + $1.dailyLimit }
    }
    
    private var totalUsed: Int {
        appState.monitoredApps.reduce(0) { $0 + $1.usedToday }
    }
    
    private var disciplineScore: Int {
        guard totalLimit > 0 else { return 0 }
        let ratio = Double(totalUsed) / Double(totalLimit)
        if ratio <= 0.85 {
            return 100
        } else {
            let normalized = min((ratio - 0.85) / 0.15, 1.0)
            return max(0, Int((1.0 - normalized) * 100))
        }
    }
    
    private var focusApps: [MonitoredApp] {
        appState.monitoredApps
            .filter { $0.percentageUsed >= 0.6 }
            .sorted { $0.percentageUsed > $1.percentageUsed }
    }
    
    private var recommendations: [String] {
        guard !appState.monitoredApps.isEmpty else {
            return [
                "Add apps from the Home page to start tracking usage.",
                "Monitor your screen time to maintain healthy habits."
            ]
        }
        
        var tips: [String] = []
        if let highest = appState.monitoredApps.max(by: { $0.percentageUsed < $1.percentageUsed }) {
            if highest.percentageUsed > 0.85 {
                tips.append("Lower \(highest.name)'s limit by 15 mins to stay ahead.")
            }
        }
        if disciplineScore < 60 {
            tips.append("Try a daily review ritual to boost consistency.")
        } else if disciplineScore > 85 {
            tips.append("Great control! Consider tightening any limits by 10%.")
        }
        if tips.isEmpty {
            tips.append("You're balanced. Keep monitoring and fine-tune weekly.")
        }
        return tips
    }
    
    private func binding(for app: MonitoredApp) -> Binding<MonitoredApp> {
        guard let index = appState.monitoredApps.firstIndex(where: { $0.id == app.id }) else {
            fatalError("App not found")
        }
        return $appState.monitoredApps[index]
    }
}

// MARK: - Weekly Health Report (Brainrot Report Style)

struct WeeklyHealthReport: View {
    let weekStart: Date
    let appState: AppState
    
    private var weekDays: [Date] {
        (0..<7).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }
    
    private func getHealthData(for date: Date) -> (score: Int, mood: PetHealthState) {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()
        
        // For future days, return empty state
        if isFuture {
            return (0, .content)
        }
        
        // For today, use actual data
        if isToday {
            let totalUsage = appState.monitoredApps.reduce(0) { $0 + $1.usedToday }
            let totalLimits = appState.monitoredApps.reduce(0) { $0 + $1.dailyLimit }
            
            guard totalLimits > 0 else {
                return (100, .fullHealth)
            }
            
            let usagePercentage = Double(totalUsage) / Double(totalLimits)
            let score: Int
            let mood: PetHealthState
            
            switch usagePercentage {
            case 0...0.5:
                score = 100
                mood = .fullHealth
            case 0.5...0.7:
                score = 80
                mood = .happy
            case 0.7...0.9:
                score = 60
                mood = .content
            case 0.9...1.1:
                score = 40
                mood = .sad
            default:
                score = 20
                mood = .sick
            }
            
            return (score, mood)
        }
        
        // For past days, simulate based on how recent
        let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        let score = max(20, 100 - (daysAgo * 5))
        let mood: PetHealthState = score >= 80 ? .fullHealth : score >= 60 ? .happy : score >= 40 ? .content : score >= 20 ? .sad : .sick
        
        return (score, mood)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.textSecondary)
            
            // Horizontal scrollable row of pet health cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(weekDays, id: \.self) { date in
                        let healthData = getHealthData(for: date)
                        let dayName = dayAbbreviation(for: date)
                        let dayNumber = Calendar.current.component(.day, from: date)
                        let isToday = Calendar.current.isDateInToday(date)
                        let isFuture = date > Date()
                        
                        WeeklyHealthCard(
                            dayName: dayName,
                            dayNumber: dayNumber,
                            healthScore: healthData.score,
                            petMood: healthData.mood,
                            isToday: isToday,
                            isFuture: isFuture,
                            petType: appState.userPet?.type ?? .dog
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
    
    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

struct WeeklyHealthCard: View {
    let dayName: String
    let dayNumber: Int
    let healthScore: Int
    let petMood: PetHealthState
    let isToday: Bool
    let isFuture: Bool
    let petType: PetType
    
    var body: some View {
        VStack(spacing: 8) {
            // Day name and number
            VStack(spacing: 2) {
                Text(dayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isFuture ? .textSecondary.opacity(0.5) : .textPrimary)
                
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isFuture ? .textSecondary.opacity(0.5) : .textPrimary)
            }
            
            // Pet image
            if isFuture {
                // Gray placeholder for future days
                Image("\(petType.folderName.lowercased())content")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .grayscale(1.0)
                    .opacity(0.5)
            } else {
                // Actual pet image based on health state
                let imageName = "\(petType.folderName.lowercased())\(petMood.rawValue)"
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
            }
            
            // Health score
            if !isFuture {
                Text("\(healthScore)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(petMood.color)
            } else {
                Text("-")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.textSecondary.opacity(0.3))
            }
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(isToday ? Color.green.opacity(0.15) : (isFuture ? Color.gray.opacity(0.1) : Color.clear))
        .cornerRadius(12)
    }
}

// MARK: - App Launches Report (Horizontal Bar Chart)

struct AppLaunchesReport: View {
    let weekStart: Date
    let appState: AppState
    
    private var weekDays: [Date] {
        (0..<7).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }
    
    // Get app launches per app for a specific date
    private func getAppLaunches(for app: MonitoredApp, on date: Date) -> Int {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()
        
        if isFuture {
            return 0
        }
        
        if isToday {
            // For today, estimate based on app usage - more usage = more launches
            // Rough estimate: 2 minutes per launch
            return max(1, app.usedToday / 2)
        }
        
        // For past days, simulate based on app usage pattern
        // More active apps have more launches
        let baseLaunches = max(1, app.usedToday / 3)
        let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        return max(1, baseLaunches - (daysAgo * 2))
    }
    
    // Get total launches for a day (sum of all apps)
    private func getTotalLaunches(for date: Date) -> Int {
        appState.monitoredApps.reduce(0) { total, app in
            total + getAppLaunches(for: app, on: date)
        }
    }
    
    // Get total launches for an app across the week
    private func getTotalLaunchesForApp(_ app: MonitoredApp) -> Int {
        weekDays.reduce(0) { total, date in
            total + getAppLaunches(for: app, on: date)
        }
    }
    
    // Get weekly usage (in minutes) for an app
    private func getWeeklyUsage(for app: MonitoredApp) -> Int {
        let calendar = Calendar.current
        var totalMinutes = 0
        
        for date in weekDays {
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > Date()
            
            if isFuture {
                continue
            }
            
            if isToday {
                // Today's usage
                totalMinutes += app.usedToday
            } else {
                // For past days, estimate based on today's usage pattern
                // More active apps have more usage, with some variation
                let baseUsage = app.usedToday
                let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
                // Simulate slightly decreasing usage as days get older
                let estimatedUsage = max(0, baseUsage - (daysAgo * 2))
                totalMinutes += estimatedUsage
            }
        }
        
        return totalMinutes
    }
    
    // Get top 5 apps by weekly usage (hours and minutes)
    private var topApps: [(name: String, weeklyUsageMinutes: Int, icon: String, color: Color)] {
        // Calculate total weekly usage per app
        let sortedApps = appState.monitoredApps
            .map { app in
                (name: app.name, weeklyUsageMinutes: getWeeklyUsage(for: app), icon: app.icon, color: app.color)
            }
            .sorted { $0.weeklyUsageMinutes > $1.weeklyUsageMinutes }
            .prefix(5)
        
        return Array(sortedApps)
    }
    
    private var maxLaunches: Int {
        var maxLaunch = 0
        for app in appState.monitoredApps {
            for date in weekDays {
                let launches = getAppLaunches(for: app, on: date)
                maxLaunch = max(maxLaunch, launches)
            }
        }
        return max(maxLaunch, 50) // Minimum scale of 50
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Launches Per Day")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)
            
            // Show launches per app per day
            VStack(spacing: 12) {
                ForEach(appState.monitoredApps.prefix(5), id: \.id) { app in
                    VStack(alignment: .leading, spacing: 12) {
                        // App header
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(app.color.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: app.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(app.color)
                            }
                            
                            Text(app.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            
                            Spacer()
                            
                            // Total for week
                            Text("\(getTotalLaunchesForApp(app))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.success)
                        }
                        
                        // Daily launches bars
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(weekDays, id: \.self) { date in
                                    let launches = getAppLaunches(for: app, on: date)
                                    let dayName = dayAbbreviation(for: date)
                                    let isToday = Calendar.current.isDateInToday(date)
                                    let isFuture = date > Date()
                                    
                                    VStack(spacing: 6) {
                                        // Day label
                                        Text(dayName)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(isFuture ? .textSecondary.opacity(0.5) : .textSecondary)
                                        
                                        // Bar
                                        if !isFuture && launches > 0 {
                                            VStack(spacing: 4) {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: isToday ? [Color.success, Color.success.opacity(0.8)] : [Color.success.opacity(0.7), Color.success.opacity(0.5)],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                                    .frame(width: 24, height: CGFloat(min(60, max(8, launches * 2))))
                                                
                                                Text("\(launches)")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(isToday ? .success : .textSecondary)
                                            }
                                        } else {
                                            VStack(spacing: 4) {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.gray.opacity(0.1))
                                                    .frame(width: 24, height: 8)
                                                
                                                Text("-")
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundColor(.textSecondary.opacity(0.3))
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.cardBackground.opacity(0.5))
                    .cornerRadius(12)
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Top 5 apps by weekly usage
            VStack(alignment: .leading, spacing: 12) {
                Text("Top 5 Apps")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                ForEach(Array(topApps.enumerated()), id: \.offset) { index, app in
                    HStack(spacing: 12) {
                        // Rank badge
                        ZStack {
                            Circle()
                                .fill(Color.success.opacity(0.2))
                                .frame(width: 28, height: 28)
                            
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.success)
                        }
                        
                        // App icon
                        ZStack {
                            Circle()
                                .fill(app.color.opacity(0.2))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: app.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(app.color)
                        }
                        
                        // App name
                        Text(app.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        // Weekly usage (hours and minutes)
                        Text(formatWeeklyUsage(app.weeklyUsageMinutes))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.success)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
    
    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func formatWeeklyUsage(_ minutes: Int) -> String {
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
}

// MARK: - Existing Components (keeping them)

struct GoalCard: View {
    @Binding var app: MonitoredApp
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                // App Icon
                ZStack {
                    Circle()
                        .fill(app.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: app.icon)
                        .font(.system(size: 22))
                        .foregroundColor(app.color)
                }
                
                // App Name
                Text(app.name)
                    .font(.h4)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                // Enable Toggle
                Toggle("", isOn: $app.isEnabled)
                    .labelsHidden()
                    .tint(.primary)
            }
            
            if app.isEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: min(app.percentageUsed, 1.0))
                        .progressViewStyle(LinearProgressViewStyle(tint: app.statusColor))
                    
                    HStack {
                        Text("Used \(formatMinutes(app.usedToday)) of \(formatMinutes(app.dailyLimit))")
                            .font(.caption)
                            .foregroundColor(.textPrimary.opacity(0.6))
                        
                        Spacer()
                        
                        Text(app.statusColor == .error ? "Over limit" : app.statusColor == .warning ? "Near limit" : "On track")
                            .font(.captionBold)
                            .foregroundColor(app.statusColor)
                    }
                }
                
                Divider()
                
                // Time Limit Picker
                HStack {
                    Text("Daily Limit:")
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary.opacity(0.7))
                    
                    Spacer()
                    
                    Picker("Limit", selection: $app.dailyLimit) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("1 hour").tag(60)
                        Text("1.5 hours").tag(90)
                        Text("2 hours").tag(120)
                        Text("3 hours").tag(180)
                        Text("4 hours").tag(240)
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
            }
        }
        .padding(16)
        .cardStyle()
        .opacity(app.isEnabled ? 1.0 : 0.6)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

struct GoalProgressOverview: View {
    let totalLimit: Int
    let totalUsed: Int
    let disciplineScore: Int
    let streak: Int
    let longestStreak: Int
    
    private var remaining: Int {
        max(0, totalLimit - totalUsed)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Daily Discipline")
                        .font(.h4)
                        .foregroundColor(.textPrimary)
                    
                    Text("Stay below your limits to keep credits.")
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary.opacity(0.6))
                }
                
                Spacer()
                
                DisciplineBadge(score: disciplineScore)
            }
            
            HStack(spacing: 16) {
                MetricPill(title: "Used", value: formatMinutes(totalUsed), color: .error.opacity(0.2), icon: "flame.fill")
                MetricPill(title: "Remaining", value: formatMinutes(remaining), color: .success.opacity(0.2), icon: "leaf.fill")
                MetricPill(title: "Streak", value: "\(streak)d", color: .primary.opacity(0.2), icon: "bolt.fill", subtitle: "Best \(longestStreak)d")
            }
        }
        .padding(20)
        .cardStyle()
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

struct DisciplineBadge: View {
    let score: Int
    
    private var gradient: [Color] {
        switch score {
        case 80...100: return [.success, .secondary]
        case 60..<80: return [.warning, .orange]
        default: return [.error, .pink]
        }
    }
    
    var body: some View {
        VStack {
            Text("\(score)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            Text("Health")
                .font(.captionBold)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: 80, height: 80)
        .background(
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: gradient.last?.opacity(0.4) ?? .black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.textPrimary.opacity(0.7))
                Text(title)
                    .font(.captionBold)
                    .foregroundColor(.textPrimary.opacity(0.7))
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.textPrimary.opacity(0.5))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color)
        .cornerRadius(16)
    }
}

struct FocusAppsCard: View {
    let apps: [MonitoredApp]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Focus Apps")
                    .font(.h4)
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("Needs attention")
                    .font(.captionBold)
                    .foregroundColor(.warning)
            }
            
            ForEach(apps) { app in
                HStack(spacing: 12) {
                    Circle()
                        .fill(app.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: app.icon)
                                .foregroundColor(app.color)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary)
                        Text("Used \(Int(app.percentageUsed * 100))% of today's limit")
                            .font(.caption)
                            .foregroundColor(.textPrimary.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Text(app.percentageUsed >= 1.0 ? "Over" : "Close")
                        .font(.captionBold)
                        .foregroundColor(app.statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(app.statusColor.opacity(0.15))
                        .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .cardStyle()
    }
}

struct GoalRecommendationsCard: View {
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coach Insights")
                .font(.h4)
                .foregroundColor(.textPrimary)
            
            ForEach(recommendations, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        )
                    
                    Text(tip)
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .cardStyle()
    }
}

struct RecommendationSheet: View {
    let recommendations: [String]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(recommendations, id: \.self) { tip in
                    Label {
                        Text(tip)
                            .font(.bodyMedium)
                    } icon: {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Coach Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
