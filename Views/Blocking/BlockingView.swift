import SwiftUI
import FamilyControls

// MARK: - Scheduling Models

enum DaySelection: String, CaseIterable, Codable {
    case allDays = "All Days"
    case weekdays = "Weekdays"
    case weekends = "Weekends"
    case custom = "Custom"
    
    var description: String {
        switch self {
        case .allDays: return "Every day"
        case .weekdays: return "Monday - Friday"
        case .weekends: return "Saturday - Sunday"
        case .custom: return "Select days"
        }
    }
}

enum TimeRestrictionType: String, CaseIterable, Codable {
    case none = "None"
    case timeRange = "Time Range"
    case afterTime = "After Time"
    case beforeTime = "Before Time"
    
    var description: String {
        switch self {
        case .none: return "All day"
        case .timeRange: return "Between times"
        case .afterTime: return "After time"
        case .beforeTime: return "Before time"
        }
    }
}

struct LimitSchedule: Codable {
    var daySelection: DaySelection = .allDays
    var selectedDays: Set<Int> = [] // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
    var timeRestriction: TimeRestrictionType = .none
    var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var endTime: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    var afterTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    var beforeTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
}

struct BlockingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @State private var showingEditSheet = false
    @State private var appToEdit: MonitoredApp?
    @State private var editedLimit: Int = 60
    @State private var showingFamilyPicker = false
    @State private var familySelection = FamilyActivitySelection()
    @State private var showingLimitSheet = false
    @State private var selectedAppName: String = ""
    @State private var selectedBundleID: String = "" // This will be the stable internal ID, not a real bundle ID
    @State private var selectedToken: AnyHashable?
    @State private var appToDelete: MonitoredApp?
    @State private var showingDeleteConfirmation = false
    @State private var showingUnlockModeConfirmation = false
    @State private var pendingUnlockMode: UnlockMode = .extraTime
    @State private var currentDisplayedMode: UnlockMode = .extraTime
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                        VStack(spacing: 24) {
                        // Header section
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.primary.opacity(0.15),
                                                    Color.primary.opacity(0.05)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: "timer")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                
                            VStack(alignment: .leading, spacing: 4) {
                                    Text("App Limits")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                    Text("Set personalized limits with custom schedules")
                                        .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.textSecondary)
                            }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        }
                            
                        // Global Unlock Mode Toggle
                        VStack(spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Unlock Mode")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    
                                    Text(getGlobalUnlockModeDescription())
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineLimit(nil)
                                }
                                
                                Spacer(minLength: 8)
                                
                                Picker("", selection: Binding(
                                    get: { currentDisplayedMode },
                                    set: { newMode in
                                        // Only show confirmation if mode is actually changing
                                        if newMode != getGlobalUnlockMode() {
                                            pendingUnlockMode = newMode
                                            showingUnlockModeConfirmation = true
                                        }
                                    }
                                )) {
                                    ForEach(UnlockMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 160)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.cardBackground)
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .onAppear {
                            currentDisplayedMode = getGlobalUnlockMode()
                        }
                        
                        // Apps list
                            if appState.monitoredApps.isEmpty {
                            emptyStateView
                        } else {
                            VStack(spacing: 14) {
                                ForEach(appState.monitoredApps) { app in
                                    appLimitRow(app)
                                        .id(app.id)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Elegant Add App button
                        Button(action: {
                            if screenTimeService.isAuthorized {
                                showingFamilyPicker = true
                            }
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                Text("Add New Limit")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.primary, Color.primary.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(18)
                            .shadow(color: Color.primary.opacity(0.2), radius: 16, x: 0, y: 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Limits")
            .navigationBarTitleDisplayMode(.inline)
            .textCase(.none)
            .sheet(isPresented: $showingFamilyPicker) {
                if screenTimeService.isAuthorized {
                    FamilyActivityPicker(selection: $familySelection)
                        .onChange(of: familySelection) { newSelection in
                            // Only allow individual app selection (no categories for limits)
                            if newSelection.applicationTokens.count == 1 && newSelection.categoryTokens.isEmpty {
                                if let firstToken = newSelection.applicationTokens.first {
                                    selectedToken = firstToken
                                    let tokenHash = String(firstToken.hashValue)
                                    selectedBundleID = tokenHash
                                    selectedAppName = "" // Name will be set by extension
                                    
                                    showingFamilyPicker = false
                                    showingLimitSheet = true
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingLimitSheet) {
                SetLimitSheet(
                    appName: selectedAppName,
                    bundleID: selectedBundleID,
                    token: selectedToken,
                    fullSelection: familySelection
                )
                .environmentObject(appState)
            }
            .sheet(isPresented: $showingEditSheet) {
                if let app = appToEdit {
                    EditLimitSheet(app: app, currentLimit: editedLimit)
                        .environmentObject(appState)
                }
            }
            .onAppear {
                // Keep this light: AppState.loadAppGoals() already handles syncing usage
                Task { @MainActor in
                        appState.loadAppGoals()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh limits when app returns from background without extra sync work
                Task { @MainActor in
                        appState.loadAppGoals()
                }
            }
            .alert("Delete Limit", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    appToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let app = appToDelete {
                        deleteLimit(app)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this limit? This action can't be undone.")
            }
            .alert(getUnlockModeAlertTitle(), isPresented: $showingUnlockModeConfirmation) {
                Button("Cancel", role: .cancel) {
                    // Reset picker to current value
                    currentDisplayedMode = getGlobalUnlockMode()
                }
                Button("Switch Mode", role: .none) {
                    // Actually apply the mode change
                    setGlobalUnlockMode(mode: pendingUnlockMode)
                    currentDisplayedMode = pendingUnlockMode
                    HapticFeedback.success.trigger()
                }
            } message: {
                Text(getUnlockModeAlertMessage())
            }
        }
    }
    
    // MARK: - Unlock Mode Alert Helpers
    
    private func getUnlockModeAlertTitle() -> String {
        switch pendingUnlockMode {
        case .extraTime:
            return "Switch to Extra Time Mode?"
        case .oneSession:
            return "Switch to One Session Mode?"
        }
    }
    
    private func getUnlockModeAlertMessage() -> String {
        switch pendingUnlockMode {
        case .extraTime:
            return "Extra Time Mode gives you +15 minutes after solving a puzzle. Your usage continues from where you left off, and you get bonus time added to your daily limit.\n\nExample: If you used 60 of 60 minutes, after solving you'll have 60 of 75 minutes."
        case .oneSession:
            return "One Session Mode unlocks the app until you leave it. Once you close or switch away from the app, it will be blocked again until tomorrow.\n\nThis is great for finishing a specific task without time pressure."
        }
    }
    
    private func deleteLimit(_ app: MonitoredApp) {
        // Find the matching Core Data goal using the token hash (our stable identifier)
        let coreDataManager = CoreDataManager.shared
        let goals = coreDataManager.getActiveAppGoals()
        
        let identifier = app.tokenHash ?? ""
        if !identifier.isEmpty,
           let goal = goals.first(where: { $0.appBundleID == identifier }) {
            
            // Provide haptic feedback
            HapticFeedback.medium.trigger()
            
            // Animate the deletion with a smooth fade and slide animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if let goalId = goal.id {
                    // Use AppState helper so Screen Time monitoring is also cleaned up
                    appState.deleteAppGoal(goalId)
                } else {
                    // Fallback: delete directly if goal has no id for some reason
                    coreDataManager.deleteAppGoal(goal)
                    appState.loadAppGoals()
                }
            }
        }
        
        // Clear the delete state
        appToDelete = nil
    }

    /// Strip debug/hash parts from old placeholder names so alerts don't show hashes
    private func cleanAppName(_ rawName: String) -> String {
        if let range = rawName.range(of: " (hash:") {
            return String(rawName[..<range.lowerBound])
        }
        return rawName.isEmpty ? "this app" : rawName
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "timer")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundColor(.textSecondary.opacity(0.4))
                                    
                                    VStack(spacing: 8) {
                Text("No Limits Set")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                            .foregroundColor(.textPrimary)
                                        
                Text("Add apps to set daily time limits and track your usage")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.textSecondary)
                                            .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }
    
    @ViewBuilder
    private func appLimitRow(_ app: MonitoredApp) -> some View {
        // ✅ Get selection using token hash to display real app name and icon
                            let identifier = app.tokenHash ?? ""
                            let selection = screenTimeService.getSelection(for: identifier)
        // applicationTokens.first is already ApplicationToken type, no cast needed
        let firstToken = selection?.applicationTokens.first
        
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                // ✅ Use Label(token) to show real app icon and name
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    app.color.opacity(0.15),
                                    app.color.opacity(0.08)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)
                    
                    // ✅ Use Label(token) for real app icon, fallback to system icon
                    if let token = firstToken {
                        // Token from applicationTokens is already ApplicationToken type - no cast needed
                        Label(token)
                            .labelStyle(.iconOnly)
                            .scaleEffect(2.5)  // ✅ Scale up to fill 62x62 border
                            .frame(width: 62, height: 62)  // Match border size exactly
                    } else {
                        Image(systemName: app.icon)
                            .font(.system(size: 62, weight: .semibold))
                            .foregroundColor(app.color)
                            .frame(width: 62, height: 62)  // Match border size exactly
                    }
                }
                .shadow(color: app.color.opacity(0.15), radius: 8, x: 0, y: 4)
                
                // App info
                VStack(alignment: .leading, spacing: 8) {
                    // ✅ Use Label(token) for real app name, fallback to stored name
                    if let token = firstToken {
                        // Token from applicationTokens is already ApplicationToken type - no cast needed
                        Label(token)
                            .labelStyle(.titleOnly)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(Color(uiColor: .label))
                            .lineLimit(1)
                    } else {
                        Text(app.name)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(Color(uiColor: .label))
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(formatMinutes(app.usedToday))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(progressColor(for: app))
                        
                        Text("of \(formatMinutes(app.dailyLimit))")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        // Show One-Session indicator
                        if let tokenHash = app.tokenHash,
                           screenTimeService.isOneSessionActive(for: tokenHash) {
                            Text("(One Session)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                    
                    // Schedule info
                    if let scheduleInfo = getScheduleInfo(for: app) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.8))
                            Text(scheduleInfo)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.9))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // Edit and Delete buttons in same row
                HStack(spacing: 12) {
                    // Edit button
                    Button(action: {
                        appToEdit = app
                        editedLimit = app.dailyLimit
                        showingEditSheet = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                    
                    // Delete button
                    Button(action: {
                        appToDelete = app
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }
            .padding(22)
            
            // Refined Progress bar
            if app.dailyLimit > 0 {
                VStack(spacing: 10) {
                    HStack {
                        Text("Time Remaining")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(formatMinutes(max(0, app.dailyLimit - app.usedToday)))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(progressColor(for: app))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 10)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            progressColor(for: app),
                                            progressColor(for: app).opacity(0.8)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width * min(1.0, app.percentageUsed),
                                    height: 10
                                )
                                .animation(.easeOut(duration: 0.25), value: app.percentageUsed)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
            
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.cardBackground)
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 6)
        )
    }
    
    // MARK: - Global Unlock Mode Helpers
    
    private func getGlobalUnlockMode() -> UnlockMode {
        let appGroupID = "group.com.se7en.app"
        if let defaults = UserDefaults(suiteName: appGroupID),
           let modeString = defaults.string(forKey: "globalUnlockMode"),
           let mode = UnlockMode(rawValue: modeString) {
            return mode
        }
        return .extraTime // Default to Extra Time Mode
    }
    
    private func setGlobalUnlockMode(mode: UnlockMode) {
        let appGroupID = "group.com.se7en.app"
        
        // Save to shared defaults (for extensions)
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(mode.rawValue, forKey: "globalUnlockMode")
            defaults.synchronize()
            print("✅ Global unlock mode set to: \(mode.rawValue)")
        }
        
        // Also save to standard UserDefaults (for main app)
        UserDefaults.standard.set(mode.rawValue, forKey: "globalUnlockMode")
        UserDefaults.standard.synchronize()
        
        // Update the displayed mode
        currentDisplayedMode = mode
    }
    
    private func getGlobalUnlockModeDescription() -> String {
        let mode = getGlobalUnlockMode()
        return mode.description
    }
    
    private func progressColor(for app: MonitoredApp) -> Color {
        if app.dailyLimit == 0 {
            return .secondary
        }
        
        if app.dailyLimit == 0 {
            return .textSecondary
        }
        
        if app.usedToday >= app.dailyLimit {
            return .error
        }
        
        if app.percentageUsed >= 0.8 {
            return .warning
        }
        
        if app.percentageUsed >= 0.5 {
            return Color.warning.opacity(0.7)
        }
        
        return .success
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
    
    private func getScheduleInfo(for app: MonitoredApp) -> String? {
        // ✅ Use token hash as identifier (stored in appBundleID field)
        let identifier = app.tokenHash ?? ""
        guard !identifier.isEmpty,
              let scheduleData = UserDefaults.standard.data(forKey: "limitSchedule_\(identifier)"),
              let schedule = try? JSONDecoder().decode(LimitSchedule.self, from: scheduleData) else {
            return nil
        }
        
        var parts: [String] = []
        
        switch schedule.daySelection {
        case .allDays:
            break
        case .weekdays:
            parts.append("Weekdays")
        case .weekends:
            parts.append("Weekends")
        case .custom:
            if !schedule.selectedDays.isEmpty {
                let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                let selectedDayNames = schedule.selectedDays.sorted().map { dayNames[$0] }
                parts.append(selectedDayNames.joined(separator: ", "))
            }
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        switch schedule.timeRestriction {
        case .none:
            break
        case .timeRange:
            parts.append("\(formatter.string(from: schedule.startTime))-\(formatter.string(from: schedule.endTime))")
        case .afterTime:
            parts.append("After \(formatter.string(from: schedule.afterTime))")
        case .beforeTime:
            parts.append("Before \(formatter.string(from: schedule.beforeTime))")
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

// MARK: - Edit Limit Sheet

struct EditLimitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var screenTimeService = ScreenTimeService.shared
    let app: MonitoredApp
    @State var currentLimit: Int
    @State private var newLimit: Int
    @State private var showingCustomLimit = false
    @State private var customLimitText: String = ""
    @State private var schedule: LimitSchedule
    @State private var showingScheduleOptions = false
    
    init(app: MonitoredApp, currentLimit: Int) {
        self.app = app
        self._currentLimit = State(initialValue: currentLimit)
        self._newLimit = State(initialValue: currentLimit)
        
        // ✅ Use limitID as identifier (stored in appBundleID field)
        let identifier = app.tokenHash ?? ""
        let scheduleData = UserDefaults.standard.data(forKey: "limitSchedule_\(identifier)")
        if let data = scheduleData,
           let decoded = try? JSONDecoder().decode(LimitSchedule.self, from: data) {
            self._schedule = State(initialValue: decoded)
        } else {
            self._schedule = State(initialValue: LimitSchedule())
        }
    }
    
    let limitOptions = [30, 60, 90, 120, 180, 240]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.appBackground,
                        Color.appBackground
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Elegant Header
                        VStack(spacing: 18) {
                            // ✅ Get selection using token hash to display real app name and icon
                            let identifier = app.tokenHash ?? ""
            let selection = screenTimeService.getSelection(for: identifier)
                            let firstToken = selection?.applicationTokens.first
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                app.color.opacity(0.2),
                                                app.color.opacity(0.1)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 110, height: 110)
                                
                                // ✅ Use Label(token) for real app icon, fallback to system icon
                                if let token = firstToken {
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .scaleEffect(4.5)  // ✅ Scale up to fill 110x110 border
                                        .frame(width: 110, height: 110)  // Match border size exactly
                                } else {
                                    Image(systemName: app.icon)
                                        .font(.system(size: 52, weight: .semibold))
                                        .foregroundColor(app.color)
                                }
                            }
                            .shadow(color: app.color.opacity(0.25), radius: 20, x: 0, y: 10)
                            
                            VStack(spacing: 8) {
                                // ✅ Use Label(token) for real app name, fallback to stored name
                                if let token = firstToken {
                                    Label(token)
                                        .labelStyle(.titleOnly)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                } else {
                                    Text(app.name)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                
                                Text("Used \(formatMinutes(app.usedToday)) today")
                                                .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 28)
                        
                        // Limit selection
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Daily Time Limit")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                        .padding(.horizontal, 24)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                                ForEach(limitOptions, id: \.self) { limit in
                                    limitOptionButton(limit: limit)
                                    }
                                }
                                .padding(.horizontal, 20)
                            
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showingCustomLimit.toggle()
                                    if showingCustomLimit {
                                        customLimitText = "\(newLimit)"
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Custom Limit")
                                        .font(.system(size: 17, weight: .bold))
                                }
                                .foregroundColor(showingCustomLimit ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Group {
                                        if showingCustomLimit {
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.primary, Color.primary.opacity(0.8)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                            } else {
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.white, Color.white]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        }
                                    }
                                )
                                .cornerRadius(16)
                                .shadow(color: showingCustomLimit ? Color.primary.opacity(0.3) : Color.black.opacity(0.06), radius: showingCustomLimit ? 12 : 8, x: 0, y: showingCustomLimit ? 6 : 4)
                                }
                                .padding(.horizontal, 20)
                            
                            if showingCustomLimit {
                                HStack(spacing: 12) {
                                    TextField("Minutes", text: $customLimitText)
                                        .keyboardType(.numberPad)
                                        .font(.system(size: 17, weight: .semibold))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 16)
                                        .background(Color.white)
                                        .cornerRadius(14)
                                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                                        .onChange(of: customLimitText) { newValue in
                                            if let minutes = Int(newValue), minutes > 0 {
                                                newLimit = minutes
                                            }
                                        }
                                    
                                    Text("min")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        // Refined Scheduling Options
                        VStack(alignment: .leading, spacing: 20) {
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showingScheduleOptions.toggle()
                                }
                            }) {
                                HStack(spacing: 14) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("Schedule Options")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                    Spacer()
                                    Image(systemName: showingScheduleOptions ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                        .font(.system(size: 22))
                                }
                                .foregroundColor(showingScheduleOptions ? .white : .primary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .background(
                                    Group {
                                        if showingScheduleOptions {
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.primary, Color.primary.opacity(0.8)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        } else {
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.white, Color.white]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        }
                                    }
                                )
                                .cornerRadius(18)
                                .shadow(color: showingScheduleOptions ? Color.primary.opacity(0.3) : Color.black.opacity(0.06), radius: showingScheduleOptions ? 12 : 8, x: 0, y: showingScheduleOptions ? 6 : 4)
                            }
                            .padding(.horizontal, 20)
                            
                            if showingScheduleOptions {
                                scheduleOptionsView
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button(action: saveLimit) {
                            HStack(spacing: 14) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                Text("Save Changes")
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                        }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.primary, Color.primary.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(18)
                            .shadow(color: Color.primary.opacity(0.4), radius: 16, x: 0, y: 8)
            }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .font(.system(size: 17, weight: .semibold))
            }
        }
    }
    }
    
    @ViewBuilder
    private func limitOptionButton(limit: Int) -> some View {
        let isSelected = newLimit == limit && !showingCustomLimit
        
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                newLimit = limit
                showingCustomLimit = false
            }
        }) {
            VStack(spacing: 8) {
                Text("\(limit)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("min")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.primary, Color.primary.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white, Color.white]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
    }
}
            )
            .cornerRadius(18)
            .shadow(color: isSelected ? Color.primary.opacity(0.35) : Color.black.opacity(0.06), radius: isSelected ? 12 : 8, x: 0, y: isSelected ? 6 : 4)
        }
    }
    
    private var scheduleOptionsView: some View {
        VStack(spacing: 24) {
            daySelectionView
            timeRestrictionView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
    
    private var daySelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("Active Days")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 10) {
                ForEach([DaySelection.allDays, .weekdays, .weekends, .custom], id: \.self) { option in
                    daySelectionButton(option: option)
                }
            }
            
            if schedule.daySelection == .custom {
                customDaySelectionView
                    .padding(.top, 8)
            }
        }
    }
    
    @ViewBuilder
    private func daySelectionButton(option: DaySelection) -> some View {
        let isSelected = schedule.daySelection == option
        
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                schedule.daySelection = option
                if option != .custom {
                    schedule.selectedDays = []
                }
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text(option.description)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.primary, Color.primary.opacity(0.85)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.cardBackground
                    }
                }
            )
            .cornerRadius(14)
        }
    }
    
    private var customDaySelectionView: some View {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
            ForEach(0..<7) { dayIndex in
                customDayButton(dayIndex: dayIndex, dayName: dayNames[dayIndex])
            }
        }
    }
    
    @ViewBuilder
    private func customDayButton(dayIndex: Int, dayName: String) -> some View {
        let isSelected = schedule.selectedDays.contains(dayIndex)
        
        Button(action: {
            withAnimation(.spring(response: 0.2)) {
                if isSelected {
                    schedule.selectedDays.remove(dayIndex)
                } else {
                    schedule.selectedDays.insert(dayIndex)
                }
            }
        }) {
            Text(dayName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 42, height: 42)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                gradient: Gradient(colors: [Color.primary, Color.primary.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            Color.cardBackground
                        }
                    }
                )
                    .cornerRadius(10)
        }
    }
    
    private var timeRestrictionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text("Time Restriction")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 10) {
                ForEach([TimeRestrictionType.none, .timeRange, .afterTime, .beforeTime], id: \.self) { option in
                    timeRestrictionButton(option: option)
                }
            }
            
            timeRestrictionPickers
        }
    }
    
    @ViewBuilder
    private func timeRestrictionButton(option: TimeRestrictionType) -> some View {
        let isSelected = schedule.timeRestriction == option
        
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                schedule.timeRestriction = option
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text(option.description)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.primary, Color.primary.opacity(0.85)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.cardBackground
                    }
                }
            )
            .cornerRadius(14)
        }
    }
    
    @ViewBuilder
    private var timeRestrictionPickers: some View {
        if schedule.timeRestriction == .timeRange {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $schedule.startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                        .datePickerStyle(.compact)
                }
                .padding(14)
                .background(Color.cardBackground)
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("End Time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $schedule.endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                .padding(14)
                .background(Color.cardBackground)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        } else if schedule.timeRestriction == .afterTime {
            VStack(alignment: .leading, spacing: 8) {
                Text("After Time")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                DatePicker("", selection: $schedule.afterTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            .padding(14)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .padding(.top, 8)
        } else if schedule.timeRestriction == .beforeTime {
            VStack(alignment: .leading, spacing: 8) {
                Text("Before Time")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                DatePicker("", selection: $schedule.beforeTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            .padding(14)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .padding(.top, 8)
        }
    }
    
    private func saveLimit() {
        let coreDataManager = CoreDataManager.shared
        let goals = coreDataManager.getActiveAppGoals()
        
        // ✅ Use token hash as identifier (stored in appBundleID field)
        let identifier = app.tokenHash ?? ""
        guard !identifier.isEmpty else {
            print("❌ Cannot save limit - no token hash for app")
            dismiss()
            return
        }
        
        if let goal = goals.first(where: { $0.appBundleID == identifier }) {
            appState.updateAppGoal(goal.id ?? UUID(), dailyLimitMinutes: newLimit)
            
            // ✅ Save schedule using identifier
            if let scheduleData = try? JSONEncoder().encode(schedule) {
                UserDefaults.standard.set(scheduleData, forKey: "limitSchedule_\(identifier)")
            }
            
            HapticFeedback.success.trigger()
        }
        
        dismiss()
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
}

// MARK: - Set Limit Sheet

struct SetLimitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    let appName: String
    let bundleID: String
    let token: AnyHashable?
    let fullSelection: FamilyActivitySelection
    
    @State private var selectedLimit: Int = 60
    @State private var showingCustomLimit = false
    @State private var customLimitText: String = "60"
    @State private var schedule: LimitSchedule = LimitSchedule()
    @State private var showingScheduleOptions = false
    
    // ✅ NEW: State for user-typed app name
    @State private var userAppName: String = ""
    @FocusState private var isAppNameFocused: Bool
    
    let limitOptions = [30, 60, 90, 120, 180, 240]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.appBackground,
                        Color.appBackground
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 18) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.primary.opacity(0.2),
                                                Color.primary.opacity(0.1)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 110, height: 110)
                                
                                // ✅ Use Label(token) to show real app icon instead of generic icon
                                if let firstToken = fullSelection.applicationTokens.first {
                                    // Token from applicationTokens is already ApplicationToken type - no cast needed
                                    Label(firstToken)
                                        .labelStyle(.iconOnly)
                                        .scaleEffect(4.5)  // ✅ Scale up to fill 110x110 border
                                        .frame(width: 110, height: 110)  // Match border size exactly
                                } else {
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 65, weight: .light))
                                        .foregroundColor(.primary.opacity(0.7))
                                }
                            }
                            .shadow(color: Color.primary.opacity(0.25), radius: 20, x: 0, y: 10)
                            
                            Text("Set App Limit")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                            
                            // ✅ NEW: App name input field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("App Name")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.textSecondary)
                                    .padding(.leading, 4)
                                
                                TextField("Enter app name (e.g., Instagram, TikTok)", text: $userAppName)
                                    .font(.system(size: 17, weight: .medium))
                                    .padding(16)
                                    .background(Color.cardBackground)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(isAppNameFocused ? Color.primary : Color.clear, lineWidth: 2)
                                    )
                                    .focused($isAppNameFocused)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled(false)
                                
                                Text("💡 Tip: Type the exact app name to track usage")
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary.opacity(0.8))
                                    .padding(.leading, 4)
                                    .padding(.top, 4)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }
                        .padding(.top, 28)
                        
                        // Limit selection
                        VStack(spacing: 18) {
                            HStack {
                                Image(systemName: "timer")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Daily Limit")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 14) {
                                ForEach(limitOptions, id: \.self) { limit in
                                    setLimitOptionButton(limit: limit)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showingCustomLimit.toggle()
                                    if showingCustomLimit {
                                        customLimitText = "\(selectedLimit)"
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Custom Limit")
                                        .font(.system(size: 17, weight: .bold))
                                }
                                .foregroundColor(showingCustomLimit ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Group {
                                        if showingCustomLimit {
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.primary, Color.primary.opacity(0.8)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                        } else {
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.white, Color.white]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        }
                                    }
                                )
                                .cornerRadius(16)
                                .shadow(color: showingCustomLimit ? Color.primary.opacity(0.3) : Color.black.opacity(0.06), radius: showingCustomLimit ? 12 : 8, x: 0, y: showingCustomLimit ? 6 : 4)
                            }
                            .padding(.horizontal, 20)
                            
                            if showingCustomLimit {
                                HStack(spacing: 12) {
                                    TextField("Minutes", text: $customLimitText)
                                        .keyboardType(.numberPad)
                                        .font(.system(size: 17, weight: .medium))
                                        .padding(16)
                                        .background(Color.cardBackground)
                                        .cornerRadius(14)
                                        .onChange(of: customLimitText) { value in
                                            if let minutes = Int(value), minutes > 0 {
                                                selectedLimit = minutes
                                            }
                                        }
                                    
                                    Text("minutes")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.textSecondary)
                                }
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        // Schedule options (keep existing code)
                        VStack(spacing: 18) {
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showingScheduleOptions.toggle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("Schedule Options")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    Spacer()
                                    Image(systemName: showingScheduleOptions ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.textPrimary)
                                .padding(18)
                                .background(Color.cardBackground)
                                .cornerRadius(16)
                                .shadow(color: showingScheduleOptions ? Color.primary.opacity(0.3) : Color.black.opacity(0.06), radius: showingScheduleOptions ? 12 : 8, x: 0, y: showingScheduleOptions ? 6 : 4)
                            }
                            .padding(.horizontal, 20)
                            
                            if showingScheduleOptions {
                                setLimitScheduleOptionsView
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        Spacer(minLength: 20)
                        
                        // Add button
                        Button(action: addLimit) {
                            HStack(spacing: 14) {
                                Image(systemName: userAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "exclamationmark.circle.fill" : "plus.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                Text(userAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter App Name First" : "Add Limit")
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: userAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                        [Color.gray, Color.gray.opacity(0.8)] : 
                                        [Color.primary, Color.primary.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(18)
                            .shadow(color: Color.primary.opacity(0.4), radius: 16, x: 0, y: 8)
                        }
                        .disabled(userAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .font(.system(size: 17, weight: .semibold))
                        }
                    }
        }
    }
    
    @ViewBuilder
    private func setLimitOptionButton(limit: Int) -> some View {
        let isSelected = selectedLimit == limit && !showingCustomLimit
        
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                selectedLimit = limit
                showingCustomLimit = false
                        }
                    }) {
            VStack(spacing: 8) {
                Text("\(limit)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("min")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.primary, Color.primary.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white, Color.white]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        }
                }
            )
            .cornerRadius(18)
            .shadow(color: isSelected ? Color.primary.opacity(0.35) : Color.black.opacity(0.06), radius: isSelected ? 12 : 8, x: 0, y: isSelected ? 6 : 4)
                    }
    }
    
    @ViewBuilder
    private var setLimitScheduleOptionsView: some View {
        VStack(spacing: 16) {
            // Day selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Active Days")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                ForEach(DaySelection.allCases, id: \.self) { option in
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            schedule.daySelection = option
                        }
                    }) {
                        HStack {
                            Image(systemName: schedule.daySelection == option ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(schedule.daySelection == option ? .primary : .textSecondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textPrimary)
                                Text(option.description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(schedule.daySelection == option ? Color.primary.opacity(0.1) : Color.cardBackground)
                        .cornerRadius(12)
                    }
                }
                
                if schedule.daySelection == .custom {
                    customDayPickerView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            // Time restriction
            VStack(alignment: .leading, spacing: 12) {
                Text("Time Restriction")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                ForEach(TimeRestrictionType.allCases, id: \.self) { option in
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            schedule.timeRestriction = option
                        }
                    }) {
                        HStack {
                            Image(systemName: schedule.timeRestriction == option ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(schedule.timeRestriction == option ? .primary : .textSecondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textPrimary)
                                Text(option.description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(schedule.timeRestriction == option ? Color.primary.opacity(0.1) : Color.cardBackground)
                        .cornerRadius(12)
                    }
                }
                
                if schedule.timeRestriction == .timeRange {
                    timeRangePickerView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if schedule.timeRestriction == .afterTime {
                    afterTimePickerView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if schedule.timeRestriction == .beforeTime {
                    beforeTimePickerView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(18)
        .background(Color.cardBackground.opacity(0.5))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var customDayPickerView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(0..<7) { day in
                let dayName = Calendar.current.shortWeekdaySymbols[day]
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if schedule.selectedDays.contains(day) {
                            schedule.selectedDays.remove(day)
                        } else {
                            schedule.selectedDays.insert(day)
                        }
                    }
                }) {
                    Text(dayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(schedule.selectedDays.contains(day) ? .white : .textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(schedule.selectedDays.contains(day) ? Color.primary : Color.cardBackground)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var timeRangePickerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $schedule.startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("End Time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $schedule.endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
            }
            .padding(14)
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var afterTimePickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("After Time")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            DatePicker("", selection: $schedule.afterTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var beforeTimePickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before Time")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            DatePicker("", selection: $schedule.beforeTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .padding(.top, 8)
    }
    
    // ✅ MODIFIED: Use user-typed app name instead of placeholder
    private func addLimit() {
        // ✅ Use the user-typed name
        let finalAppName = userAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't allow empty names
        guard !finalAppName.isEmpty else {
                // App name is required to track usage correctly
            print("❌ App name is required")
            return
        }
        
        print("\n" + String(repeating: "=", count: 60))
        print("📱 ADDING LIMIT WITH USER-TYPED NAME")
        print("   User typed name: '\(finalAppName)'")
        print("   Limit: \(selectedLimit) minutes")
        print(String(repeating: "=", count: 60))
        
        // Create selection with just the first app token
        var appSelection = FamilyActivitySelection()
        if let firstToken = fullSelection.applicationTokens.first {
            appSelection.applicationTokens = [firstToken]
        } else if !fullSelection.categoryTokens.isEmpty {
            appSelection.categoryTokens = fullSelection.categoryTokens
        } else {
            appSelection = fullSelection
        }
        
        guard !appSelection.applicationTokens.isEmpty || !appSelection.categoryTokens.isEmpty else {
            print("❌ Cannot add app - no valid tokens")
            return
        }
        
        // ✅ Use the new reliable method with user-typed name
        appState.addAppGoalReliable(
            selection: appSelection,
            appName: finalAppName,  // ✅ User-typed name!
            dailyLimitMinutes: selectedLimit
        )
        
        HapticFeedback.success.trigger()
        dismiss()
    }
}

struct BlockingView_Previews: PreviewProvider {
    static var previews: some View {
        BlockingView()
    }
}