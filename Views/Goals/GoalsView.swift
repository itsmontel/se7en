import SwiftUI

// MARK: - Coach Insight Model
struct CoachInsight: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let type: InsightType
    let priority: Priority

    enum InsightType {
        case warning, info, achievement, motivation, strategy, reminder, optimization, reflection, wellness, balance, encouragement, welcome, setup
    }

    enum Priority: Int {
        case low = 1, medium = 2, high = 3
    }

    var iconColor: Color {
        switch type {
        case .warning: return .error
        case .achievement: return .success
        case .motivation, .encouragement: return .secondary
        case .reminder: return .warning
        case .wellness: return Color(hex: "#8B5CF6") // Purple
        case .welcome, .setup: return .primary
        default: return .textSecondary
        }
    }

    var backgroundColor: Color {
        switch type {
        case .warning: return Color.error.opacity(0.1)
        case .achievement: return Color.success.opacity(0.1)
        case .motivation, .encouragement: return Color.secondary.opacity(0.1)
        case .reminder: return Color.warning.opacity(0.1)
        case .wellness: return Color(hex: "#8B5CF6").opacity(0.1) // Purple
        case .welcome, .setup: return Color.primary.opacity(0.1)
        default: return Color.cardBackground
        }
    }
}

struct GoalsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedWeekOffset: Int = 0 // 0 = current week, -1 = last week, etc.
    
    // Calculate the start of the selected week (Monday)
    private var weekStart: Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2
        
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Get the weekday (1 = Sunday, 2 = Monday, etc)
        let weekday = calendar.component(.weekday, from: today)
        
        // Calculate days since Monday (if today is Monday, daysFromMonday = 0)
        let daysFromMonday = (weekday - 2 + 7) % 7
        
        // Get this week's Monday
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return today
        }
        
        // Apply week offset
        return calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: thisMonday) ?? thisMonday
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
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    HStack {
                        Spacer()
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
                        .padding(.bottom, 32)
                        }
                        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 800 : .infinity)
                        Spacer()
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
    
    private var recommendations: [CoachInsight] {
        guard !appState.monitoredApps.isEmpty else {
            return [
                CoachInsight(
                    title: "Welcome to SE7EN!",
                    message: "Add apps from the Home page to start your digital wellness journey.",
                    icon: "hand.wave.fill",
                    type: .welcome,
                    priority: .high
                ),
                CoachInsight(
                    title: "Set Your Goals",
                    message: "Monitor your screen time to build healthier digital habits and maintain balance.",
                    icon: "target",
                    type: .setup,
                    priority: .high
                )
            ]
        }

        var insights: [CoachInsight] = []

        // Analyze usage patterns
        insights.append(contentsOf: analyzeUsagePatterns())

        // Check discipline and streaks
        insights.append(contentsOf: analyzeDisciplineAndStreaks())

        // Goal achievement insights
        insights.append(contentsOf: analyzeGoalAchievement())

        // Behavioral coaching
        insights.append(contentsOf: analyzeBehavioralPatterns())

        // Time-based insights
        insights.append(contentsOf: analyzeTimePatterns())

        // Sort by priority and limit to most relevant insights
        return insights.sorted { $0.priority.rawValue > $1.priority.rawValue }.prefix(6).map { $0 }
    }

    // MARK: - Insight Analysis Methods

    private func analyzeUsagePatterns() -> [CoachInsight] {
        var insights: [CoachInsight] = []

        // Find app with highest usage
        if let highestUsage = appState.monitoredApps.max(by: { $0.percentageUsed < $1.percentageUsed }) {
            if highestUsage.percentageUsed > 0.9 {
                insights.append(CoachInsight(
                    title: "Heavy \(highestUsage.name) Usage",
                    message: "You're spending \(Int(highestUsage.percentageUsed * 100))% of your \(highestUsage.name) limit. Consider a 10-15 min reduction to create breathing room.",
                    icon: "exclamationmark.triangle.fill",
                    type: .warning,
                    priority: .high
                ))
            } else if highestUsage.percentageUsed > 0.7 {
                insights.append(CoachInsight(
                    title: "\(highestUsage.name) Check",
                    message: "You're at \(Int(highestUsage.percentageUsed * 100))% of your \(highestUsage.name) limit. Good awareness - keep monitoring!",
                    icon: "eye.fill",
                    type: .info,
                    priority: .medium
                ))
            }
        }

        // Check for apps under-utilized
        let underUtilizedApps = appState.monitoredApps.filter { $0.percentageUsed < 0.3 }
        if !underUtilizedApps.isEmpty && underUtilizedApps.count > 1 {
            insights.append(CoachInsight(
                title: "Room for Adjustment",
                message: "\(underUtilizedApps.count) apps are well under their limits. Consider redistributing time to more challenging apps.",
                icon: "arrow.triangle.swap",
                type: .optimization,
                priority: .medium
            ))
        }

        return insights
    }

    private func analyzeDisciplineAndStreaks() -> [CoachInsight] {
        var insights: [CoachInsight] = []

        if disciplineScore < 40 {
            insights.append(CoachInsight(
                title: "Build Consistency",
                message: "Your discipline score is \(disciplineScore)%. Try the 5-minute rule: when tempted, wait just 5 minutes before using an app.",
                icon: "clock.arrow.circlepath",
                type: .motivation,
                priority: .high
            ))
        } else if disciplineScore < 60 {
            insights.append(CoachInsight(
                title: "Steady Progress",
                message: "You're at \(disciplineScore)% discipline. Consider a daily evening review to celebrate wins and plan tomorrow.",
                icon: "chart.line.uptrend.xyaxis",
                type: .motivation,
                priority: .medium
            ))
        } else if disciplineScore > 90 {
            insights.append(CoachInsight(
                title: "Master Level Control",
                message: "Outstanding! Your \(disciplineScore)% discipline shows excellent self-control. Consider mentoring others or tightening limits further.",
                icon: "star.circle.fill",
                type: .achievement,
                priority: .medium
            ))
        }

        // Streak analysis
        if appState.currentStreak == 0 && appState.longestStreak > 2 {
            insights.append(CoachInsight(
                title: "Restart Your Streak",
                message: "You had a \(appState.longestStreak)-day streak! Start fresh today - consistency compounds over time.",
                icon: "flame.fill",
                type: .motivation,
                priority: .high
            ))
        } else if appState.currentStreak > 0 && appState.currentStreak < 3 {
            insights.append(CoachInsight(
                title: "Building Momentum",
                message: "\(appState.currentStreak) day\(appState.currentStreak > 1 ? "s" : "") in! Each day builds the habit stronger.",
                icon: "flame",
                type: .encouragement,
                priority: .medium
            ))
        }

        return insights
    }

    private func analyzeGoalAchievement() -> [CoachInsight] {
        var insights: [CoachInsight] = []

        let successfulApps = appState.monitoredApps.filter { !$0.isOverLimit }
        let totalApps = appState.monitoredApps.count
        let successRate = Double(successfulApps.count) / Double(totalApps)

        if successRate >= 0.8 {
            insights.append(CoachInsight(
                title: "Goal Crusher!",
                message: "You're meeting \(Int(successRate * 100))% of your daily goals. Consider adding 1-2 more challenging apps to track.",
                icon: "checkmark.seal.fill",
                type: .achievement,
                priority: .high
            ))
        } else if successRate < 0.5 {
            insights.append(CoachInsight(
                title: "Focus on High-Impact Apps",
                message: "Only meeting \(Int(successRate * 100))% of goals. Pick your 2-3 most important apps and focus there first.",
                icon: "scope",
                type: .strategy,
                priority: .high
            ))
        }

        // Apps near limit
        let nearLimitApps = appState.monitoredApps.filter { $0.isNearLimit }
        if !nearLimitApps.isEmpty {
            insights.append(CoachInsight(
                title: "Close Calls",
                message: "\(nearLimitApps.count) app\(nearLimitApps.count > 1 ? "s are" : " is") near limit. Set a reminder for later today to check in.",
                icon: "bell.badge",
                type: .reminder,
                priority: .medium
            ))
        }

        return insights
    }

    private func analyzeBehavioralPatterns() -> [CoachInsight] {
        var insights: [CoachInsight] = []

        // Check for very short limits (might be unrealistic)
        let veryShortLimits = appState.monitoredApps.filter { $0.dailyLimit < 30 }
        if !veryShortLimits.isEmpty {
            insights.append(CoachInsight(
                title: "Realistic Goals Matter",
                message: "Some limits are very short (<30 mins). Consider gradual increases - sustainable change beats perfection.",
                icon: "gauge.with.dots.needle.bottom.0percent",
                type: .strategy,
                priority: .medium
            ))
        }

        // Check for balance across apps
        let totalLimit = appState.monitoredApps.reduce(0) { $0 + $1.dailyLimit }
        if totalLimit > 8 * 60 { // More than 8 hours total
            insights.append(CoachInsight(
                title: "Total Screen Time",
                message: "Your combined limits total \(totalLimit/60)h \(totalLimit%60)m. Consider if this aligns with your overall screen time goals.",
                icon: "timer",
                type: .reflection,
                priority: .low
            ))
        }

        return insights
    }

    private func analyzeTimePatterns() -> [CoachInsight] {
        var insights: [CoachInsight] = []

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        // Time-based coaching
        if hour >= 20 || hour <= 6 { // Evening/night
            insights.append(CoachInsight(
                title: "Wind Down Time",
                message: "It's getting late. Consider a 'no screens after 9 PM' rule to improve sleep quality and next-day focus.",
                icon: "moon.stars.fill",
                type: .wellness,
                priority: .medium
            ))
        } else if hour >= 6 && hour <= 9 { // Morning
            insights.append(CoachInsight(
                title: "Fresh Start",
                message: "Morning momentum! Start your day with intention. Check your goals and set a positive tone for screen time.",
                icon: "sunrise.fill",
                type: .motivation,
                priority: .medium
            ))
        }

        // Weekend vs weekday patterns (basic analysis)
        let weekday = calendar.component(.weekday, from: Date())
        let isWeekend = weekday == 1 || weekday == 7 // Sunday or Saturday

        if isWeekend {
            insights.append(CoachInsight(
                title: "Weekend Balance",
                message: "It's the weekend! Consider slightly relaxed limits for social/leisure while maintaining healthy boundaries.",
                icon: "calendar",
                type: .balance,
                priority: .low
            ))
        }

        return insights
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
    
    private let appGroupID = "group.com.se7en.app"
    
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
        
        // For today, use the same screen time-based calculation as the main health system
        if isToday {
            // Use the same calculation as AppState.calculatePetHealthPercentage()
            let healthPercentage = appState.calculatePetHealthPercentage()
            
            // Convert health percentage to PetHealthState (same logic as updatePetHealth)
            let mood: PetHealthState
            switch healthPercentage {
            case 90...100:
                mood = .fullHealth
            case 70..<90:
                mood = .happy
            case 50..<70:
                mood = .content
            case 20..<50:
                mood = .sad
            default:
                mood = .sick
            }
            
            return (healthPercentage, mood)
        }
        
        // For past days, read from stored daily health history
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return (0, .sick)
        }
        
        sharedDefaults.synchronize()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        
        // Load daily health history
        if let dailyHealth = sharedDefaults.dictionary(forKey: "daily_health") as? [String: [String: Any]],
           let dayData = dailyHealth[dateKey] {
            let score = dayData["score"] as? Int ?? 0
            let moodString = dayData["mood"] as? String ?? PetHealthState.sick.rawValue
            let mood = PetHealthState(rawValue: moodString) ?? .sick
            return (score, mood)
        }
        
        // No historical data available
        return (0, .sick)
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
    
    private let appGroupID = "group.com.se7en.app"
    
    private var weekDays: [Date] {
        (0..<7).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }
    
    // Get TOTAL app opens for a specific date (all apps combined)
    // Reads from the shared container populated by DeviceActivityReport extension
    // Note: Tracks unique apps opened rather than actual pickups (iOS limitation)
    private func getTotalLaunches(for date: Date) -> Int {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()
        
        if isFuture {
            return 0
        }
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return 0
        }
        
        sharedDefaults.synchronize()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        
        // For today, try both the daily_app_opens history and the live total_app_opens
        if isToday {
            // First try the live total
            let liveAppOpens = sharedDefaults.integer(forKey: "total_app_opens")
            if liveAppOpens > 0 {
                return liveAppOpens
            }
        }
        
        // Load from daily app opens history
        if let dailyAppOpens = sharedDefaults.dictionary(forKey: "daily_app_opens") as? [String: Int],
           let appOpens = dailyAppOpens[dateKey] {
            return appOpens
        }
        
        return 0
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
                // Today's usage - use real data
                totalMinutes += app.usedToday
            } else {
                // For past days, return 0 (no historical usage data available)
                // In the future, this could load from CoreData if historical usage is stored
                // For now, only count today's usage
            }
        }
        
        return totalMinutes
    }
    
    // Get top 5 apps by weekly usage (hours and minutes)
    private var topApps: [(name: String, weeklyUsageMinutes: Int, icon: String, color: Color)] {
        // Calculate total weekly usage per app - only include apps with actual usage
        let sortedApps = appState.monitoredApps
            .map { app in
                (name: app.name, weeklyUsageMinutes: getWeeklyUsage(for: app), icon: app.icon, color: app.color)
            }
            .filter { $0.weeklyUsageMinutes > 0 } // Only show apps with actual usage
            .sorted { $0.weeklyUsageMinutes > $1.weeklyUsageMinutes }
            .prefix(5)
        
        return Array(sortedApps)
    }
    
    private var maxLaunches: Int {
        let maxLaunch = weekDays.reduce(0) { maxTotal, date in
            max(maxTotal, getTotalLaunches(for: date))
        }
        return max(maxLaunch, 50) // Minimum scale of 50
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Opens Per Day")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)
            
            // Show TOTAL app opens per day (Monday-Sunday) - all apps combined
                    VStack(alignment: .leading, spacing: 12) {
                // Header showing total for week
                HStack {
                    Text("Total App Opens This Week")
                                    .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                            
                            Spacer()
                            
                    let weekTotal = weekDays.reduce(0) { total, date in
                        total + getTotalLaunches(for: date)
                    }
                    Text("\(weekTotal)")
                        .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.success)
                        }
                .padding(.horizontal, 12)
                        
                // Daily app opens bars - showing TOTAL app opens per day
                        ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                                ForEach(weekDays, id: \.self) { date in
                            let totalLaunches = getTotalLaunches(for: date)
                                    let dayName = dayAbbreviation(for: date)
                                    let isToday = Calendar.current.isDateInToday(date)
                                    let isFuture = date > Date()
                                    
                            VStack(spacing: 8) {
                                        // Day label
                                        Text(dayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isFuture ? .textSecondary.opacity(0.5) : (isToday ? .primary : .textSecondary))
                                        
                                // Bar showing total launches for the day
                                if !isFuture {
                                            VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 6)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: isToday ? [Color.success, Color.success.opacity(0.8)] : [Color.success.opacity(0.7), Color.success.opacity(0.5)],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                            .frame(width: 40, height: CGFloat(min(120, max(12, totalLaunches * 2))))
                                                
                                        Text("\(totalLaunches)")
                                            .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(isToday ? .success : .textSecondary)
                                            }
                                        } else {
                                            VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color.gray.opacity(0.1))
                                            .frame(width: 40, height: 12)
                                                
                                                Text("-")
                                            .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(.textSecondary.opacity(0.3))
                                            }
                                        }
                                    }
                                }
                            }
                    .padding(.horizontal, 12)
                        }
                    }
            .padding(.vertical, 12)
                    .background(Color.cardBackground.opacity(0.5))
                    .cornerRadius(12)
            
            Divider()
                .padding(.vertical, 8)
            
            // Top 5 apps by weekly usage
            VStack(alignment: .leading, spacing: 12) {
                Text("Top 5 Apps This Week")
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
    @EnvironmentObject var appState: AppState
    @State private var restrictionPeriod: RestrictionPeriod = .daily
    @State private var hasTimeRestriction: Bool = false
    @State private var blockStartTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var blockEndTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showAdvancedOptions: Bool = false
    @State private var pendingLimitChange: Int? = nil
    
    enum RestrictionPeriod: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case oneTime = "One-time"
    }
    
    private func handleLimitChange(newValue: Int) {
        // Find the app goal in Core Data by name
        let goals = CoreDataManager.shared.getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appName == app.name }) else {
            print("⚠️ Could not find goal for app: \(app.name)")
            return
        }
        
        // Check if we're editing an active day's limit (if app has been used today)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let goalUpdatedDate = calendar.startOfDay(for: goal.updatedAt ?? Date())
        let isToday = calendar.isDate(goalUpdatedDate, inSameDayAs: today)
        
        if isToday && app.usedToday > 0 {
            // Changes take effect tomorrow - store as pending in UserDefaults
            let key = "pendingLimit_\(goal.appBundleID ?? app.name)"
            UserDefaults.standard.set(newValue, forKey: key)
            pendingLimitChange = newValue
            HapticFeedback.light.trigger()
            print("📝 Limit change scheduled for tomorrow: \(newValue) minutes")
            return
        }
        
        // Update the goal in Core Data immediately
        CoreDataManager.shared.updateAppGoal(goal, dailyLimitMinutes: newValue)
        
        // Clear any pending changes
        let key = "pendingLimit_\(goal.appBundleID ?? app.name)"
        UserDefaults.standard.removeObject(forKey: key)
        pendingLimitChange = nil
        
        // If set to 0, immediately block the app
        if newValue == 0 {
            if let bundleID = goal.appBundleID {
                ScreenTimeService.shared.blockApp(bundleID)
                HapticFeedback.medium.trigger()
                print("🚫 App \(app.name) blocked immediately (0 minute limit)")
            }
        } else {
            // If changing from 0 to non-zero, unblock the app (unless in time restriction window)
            if app.dailyLimit == 0 && newValue > 0 {
                if let bundleID = goal.appBundleID {
                    // Check if we're in a time restriction window
                    if hasTimeRestriction && isInTimeRestrictionWindow() {
                        // Keep blocked during time window
                        print("⏰ App \(app.name) remains blocked during time restriction window")
                    } else {
                        ScreenTimeService.shared.unblockApp(bundleID)
                        HapticFeedback.light.trigger()
                        print("✅ App \(app.name) unblocked (limit changed to \(newValue) minutes)")
                    }
                }
            }
        }
        
        // Save restriction period and time restriction settings
        saveRestrictionSettings(for: goal, limit: newValue)
        
        // Reload app goals to reflect changes
        appState.loadAppGoals()
    }
    
    private func isInTimeRestrictionWindow() -> Bool {
        guard hasTimeRestriction else { return false }
        
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeMinutes = currentHour * 60 + currentMinute
        
        let startHour = calendar.component(.hour, from: blockStartTime)
        let startMinute = calendar.component(.minute, from: blockStartTime)
        let startTimeMinutes = startHour * 60 + startMinute
        
        let endHour = calendar.component(.hour, from: blockEndTime)
        let endMinute = calendar.component(.minute, from: blockEndTime)
        let endTimeMinutes = endHour * 60 + endMinute
        
        // Handle overnight blocking (e.g., 9pm to 9am)
        if startTimeMinutes > endTimeMinutes {
            // Overnight window
            return currentTimeMinutes >= startTimeMinutes || currentTimeMinutes < endTimeMinutes
        } else {
            // Same-day window
            return currentTimeMinutes >= startTimeMinutes && currentTimeMinutes < endTimeMinutes
        }
    }
    
    private func saveRestrictionSettings(for goal: AppGoal, limit: Int) {
        let bundleID = goal.appBundleID ?? app.name
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Save restriction period
        UserDefaults.standard.set(restrictionPeriod.rawValue, forKey: "restrictionPeriod_\(bundleID)")
        
        // Calculate and save end date based on restriction period
        let endDate: Date
        switch restrictionPeriod {
        case .daily:
            // Daily restrictions don't expire (they reset daily)
            endDate = Date.distantFuture
        case .weekly:
            // Weekly restrictions last 7 days from today
            endDate = calendar.date(byAdding: .day, value: 7, to: today) ?? Date.distantFuture
        case .oneTime:
            // One-time restrictions expire at end of today
            endDate = calendar.date(byAdding: .day, value: 1, to: today) ?? Date.distantFuture
        }
        
        UserDefaults.standard.set(today, forKey: "restrictionStartDate_\(bundleID)")
        UserDefaults.standard.set(endDate, forKey: "restrictionEndDate_\(bundleID)")
        UserDefaults.standard.set(limit, forKey: "restrictionLimit_\(bundleID)")
        
        // Save time restriction settings
        if hasTimeRestriction {
            UserDefaults.standard.set(true, forKey: "timeRestriction_\(bundleID)")
            UserDefaults.standard.set(blockStartTime, forKey: "blockStartTime_\(bundleID)")
            UserDefaults.standard.set(blockEndTime, forKey: "blockEndTime_\(bundleID)")
        } else {
            UserDefaults.standard.set(false, forKey: "timeRestriction_\(bundleID)")
        }
        
        print("💾 Saved restriction settings: \(restrictionPeriod.rawValue) for \(app.name), expires: \(endDate)")
    }
    
    private func loadTimeRestrictionSettings(for goal: AppGoal) {
        let bundleID = goal.appBundleID ?? app.name
        hasTimeRestriction = UserDefaults.standard.bool(forKey: "timeRestriction_\(bundleID)")
        if let startTime = UserDefaults.standard.object(forKey: "blockStartTime_\(bundleID)") as? Date {
            blockStartTime = startTime
        }
        if let endTime = UserDefaults.standard.object(forKey: "blockEndTime_\(bundleID)") as? Date {
            blockEndTime = endTime
        }
        if let periodString = UserDefaults.standard.string(forKey: "restrictionPeriod_\(bundleID)"),
           let period = RestrictionPeriod(rawValue: periodString) {
            restrictionPeriod = period
        }
        
        // Check for pending limit changes
        pendingLimitChange = UserDefaults.standard.object(forKey: "pendingLimit_\(bundleID)") as? Int
    }
    
    private func isRestrictionActive(for goal: AppGoal) -> Bool {
        let bundleID = goal.appBundleID ?? app.name
        
        // Check if restriction period has expired
        guard let endDate = UserDefaults.standard.object(forKey: "restrictionEndDate_\(bundleID)") as? Date else {
            // No restriction period set, assume daily (always active)
            return true
        }
        
        let now = Date()
        if now >= endDate {
            // Restriction has expired
            print("⏰ Restriction period expired for \(app.name)")
            return false
        }
        
        return true
    }
    
    private func getRestrictionExpirationInfo() -> String? {
        let goals = CoreDataManager.shared.getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appName == app.name }) else { return nil }
        let bundleID = goal.appBundleID ?? app.name
        
        guard let endDate = UserDefaults.standard.object(forKey: "restrictionEndDate_\(bundleID)") as? Date else {
            return nil
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        if restrictionPeriod == .daily {
            return "Resets daily at midnight"
        } else if restrictionPeriod == .weekly {
            let daysRemaining = calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
            if daysRemaining > 0 {
                return "Expires in \(daysRemaining) day\(daysRemaining == 1 ? "" : "s")"
            } else {
                return "Expires today"
            }
        } else if restrictionPeriod == .oneTime {
            if calendar.isDateInToday(endDate) {
                return "Expires at midnight tonight"
            } else {
                return "Expires today"
            }
        }
        
        return nil
    }
    
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
                        if app.dailyLimit == 0 {
                            Text("App is blocked")
                                .font(.caption)
                                .foregroundColor(.error)
                        } else {
                        Text("Used \(formatMinutes(app.usedToday)) of \(formatMinutes(app.dailyLimit))")
                            .font(.caption)
                            .foregroundColor(.textPrimary.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        if app.dailyLimit == 0 {
                            Text("Blocked")
                                .font(.captionBold)
                                .foregroundColor(.error)
                        } else {
                        Text(app.statusColor == .error ? "Over limit" : app.statusColor == .warning ? "Near limit" : "On track")
                            .font(.captionBold)
                            .foregroundColor(app.statusColor)
                        }
                    }
                }
                
                Divider()
                
                // Time Limit Picker
                VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Daily Limit:")
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary.opacity(0.7))
                    
                    Spacer()
                        
                        if let pending = pendingLimitChange {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(.warning)
                                Text("Changes tomorrow")
                                    .font(.caption)
                                    .foregroundColor(.warning)
                            }
                        }
                    
                    Picker("Limit", selection: $app.dailyLimit) {
                            Text("Blocked (0 min)").tag(0)
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
                        .onChange(of: app.dailyLimit) { newValue in
                            handleLimitChange(newValue: newValue)
                        }
                    }
                    
                    // Advanced Options Toggle
                    Button(action: {
                        withAnimation {
                            showAdvancedOptions.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: showAdvancedOptions ? "chevron.down" : "chevron.right")
                                .font(.caption)
                            Text("Advanced Options")
                                .font(.caption)
                            Spacer()
                        }
                        .foregroundColor(.textSecondary)
                    }
                    
                    // Advanced Options
                    if showAdvancedOptions {
                        VStack(alignment: .leading, spacing: 12) {
                            // Restriction Period
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Restriction Period:")
                                    .font(.captionBold)
                                    .foregroundColor(.textPrimary.opacity(0.7))
                                
                                Picker("Period", selection: $restrictionPeriod) {
                                    ForEach(RestrictionPeriod.allCases, id: \.self) { period in
                                        Text(period.rawValue).tag(period)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: restrictionPeriod) { _ in
                                    // When restriction period changes, save settings
                                    let goals = CoreDataManager.shared.getActiveAppGoals()
                                    if let goal = goals.first(where: { $0.appName == app.name }) {
                                        saveRestrictionSettings(for: goal, limit: app.dailyLimit)
                                    }
                                }
                                
                                // Show expiration info
                                if let expirationInfo = getRestrictionExpirationInfo() {
                                    Text(expirationInfo)
                                        .font(.caption2)
                                        .foregroundColor(.textSecondary)
                                        .padding(.top, 4)
                                }
                            }
                            
                            // Time-based Blocking
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Time-based Blocking", isOn: $hasTimeRestriction)
                                    .font(.captionBold)
                                    .tint(.primary)
                                
                                if hasTimeRestriction {
                                    VStack(spacing: 8) {
                                        DatePicker("Block from:", selection: $blockStartTime, displayedComponents: .hourAndMinute)
                                            .font(.caption)
                                        
                                        DatePicker("Block until:", selection: $blockEndTime, displayedComponents: .hourAndMinute)
                                            .font(.caption)
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
        .opacity(app.isEnabled ? 1.0 : 0.6)
        .onAppear {
            let goals = CoreDataManager.shared.getActiveAppGoals()
            if let goal = goals.first(where: { $0.appName == app.name }) {
                loadTimeRestrictionSettings(for: goal)
            }
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes == 0 {
            return "0 min"
        }
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
    let recommendations: [CoachInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Coach Insights")
                    .font(.h4)
                    .foregroundColor(.textPrimary)
            }

            ForEach(recommendations) { insight in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(insight.backgroundColor)
                            .frame(width: 40, height: 40)

                        Image(systemName: insight.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(insight.iconColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        Text(insight.message)
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }

            if recommendations.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 40, height: 40)

                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Getting to know you...")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        Text("Insights will appear as you use the app and build your digital wellness habits.")
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
            }
        }
        .padding(20)
        .cardStyle()
    }
}

struct RecommendationSheet: View {
    let recommendations: [CoachInsight]

    var body: some View {
        NavigationView {
            List {
                ForEach(recommendations) { insight in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(insight.backgroundColor)
                                .frame(width: 36, height: 36)

                            Image(systemName: insight.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(insight.iconColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)

                            Text(insight.message)
                                .font(.bodySmall)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Coach Insights")
            .navigationBarTitleDisplayMode(.inline)
            .textCase(.none)
        }
    }
}
