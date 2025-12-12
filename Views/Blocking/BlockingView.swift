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
    @State private var selectedBundleID: String = "" // This will be the encoded token
    @State private var selectedToken: AnyHashable?
    @State private var appToDelete: MonitoredApp?
    @State private var showingDeleteConfirmation = false
    @State private var deletingAppId: UUID? = nil // Track which app is being deleted for animation
    
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
                            
                        // Apps list
                            if appState.monitoredApps.isEmpty {
                            emptyStateView
                        } else {
                            VStack(spacing: 14) {
                                ForEach(appState.monitoredApps.filter { app in
                                    // Filter out app being deleted (for animation)
                                    app.id != deletingAppId
                                }) { app in
                                    appLimitRow(app)
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .leading)),
                                            removal: .opacity.combined(with: .move(edge: .trailing))
                                        ))
                                }
                            }
                            .padding(.horizontal, 20)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: deletingAppId)
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
            .sheet(isPresented: $showingFamilyPicker) {
                if screenTimeService.isAuthorized {
                    FamilyActivityPicker(selection: $familySelection)
                        .onChange(of: familySelection) { newSelection in
                            // ✅ ONLY accept individual apps, NOT categories
                            // Limits page is for individual app limits only
                            if let firstToken = newSelection.applicationTokens.first {
                                selectedToken = firstToken
                                
                                // ✅ Use ENCODED token as identifier (same as ScreenTimeService)
                                // Encode directly using ScreenTimeService (handles ApplicationToken type)
                                let encodedToken = screenTimeService.encodeToken(firstToken) ?? String(firstToken.hashValue)
                                
                                print("🎯 Selected app from picker:")
                                print("   Token hash: \(firstToken.hashValue)")
                                print("   Encoded token (first 30 chars): \(String(encodedToken.prefix(30)))...")
                                print("   App tokens: \(newSelection.applicationTokens.count)")
                                print("   Category tokens: \(newSelection.categoryTokens.count) (ignored for limits)")
                                
                                selectedAppName = ""  // Will be shown via Label(token) in UI
                                selectedBundleID = encodedToken  // Store encoded token as identifier
                                
                                // Close picker and show limit sheet
                                showingFamilyPicker = false
                                showingLimitSheet = true
                            } else {
                                print("❌ No individual app selected - only categories found")
                                print("   App tokens: \(newSelection.applicationTokens.count)")
                                print("   Category tokens: \(newSelection.categoryTokens.count)")
                                print("⚠️ Limits page requires individual app selection, not categories")
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
            .confirmationDialog(
                "Delete Limit",
                isPresented: $showingDeleteConfirmation,
                presenting: appToDelete
            ) { app in
                Button("Delete", role: .destructive) {
                    deleteApp(app)
                }
                Button("Cancel", role: .cancel) {
                    appToDelete = nil
                }
            } message: { app in
                let appDisplayName = app.name.isEmpty ? "this app" : app.name
                Text("Are you sure you want to delete the limit for \(appDisplayName)? This action cannot be undone.")
            }
            .onAppear {
                // Refresh usage data from shared container when Limits page appears
                // This ensures we get the latest data from the report extension
                screenTimeService.syncUsageFromSharedContainer()
                appState.loadAppGoals()  // Reload to update monitoredApps with fresh usage
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Also refresh when app returns from background
                screenTimeService.syncUsageFromSharedContainer()
                appState.loadAppGoals()
            }
        }
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
    
    private func deleteApp(_ app: MonitoredApp) {
        // Find the goal ID for this app
        let goals = CoreDataManager.shared.getActiveAppGoals()
        guard let goal = goals.first(where: { goal in
            // Match by token hash (stored in appBundleID)
            if let tokenHash = app.tokenHash {
                return goal.appBundleID == tokenHash
            }
            // Fallback: match by name
            return goal.appName == app.name
        }), let goalId = goal.id else {
            print("⚠️ Could not find goal to delete for app: \(app.name)")
            appToDelete = nil
            return
        }
        
        // Set the deleting app ID to trigger animation (this filters it out of the list)
        deletingAppId = app.id
        
        // Haptic feedback
        HapticFeedback.light.trigger()
        
        // Wait for animation to complete, then actually delete from CoreData
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // Actually delete the goal (this will update monitoredApps)
            appState.deleteAppGoal(goalId)
            
            // Clear the deleting state after a brief delay to ensure smooth transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                deletingAppId = nil
                appToDelete = nil
            }
        }
    }
    
    @ViewBuilder
    private func appLimitRow(_ app: MonitoredApp) -> some View {
        // ✅ Get selection using token hash to display real app name and icon
        let selection = app.tokenHash.flatMap { screenTimeService.getSelection(for: $0) }
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
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    } else {
                        Text(app.name)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(formatMinutes(app.usedToday))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(progressColor(for: app))
                        
                        Text("of \(formatMinutes(app.dailyLimit))")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
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
                
                // Action buttons
                HStack(spacing: 12) {
                    // Delete button
                    Button(action: {
                        appToDelete = app
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    
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
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: app.percentageUsed)
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
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 6)
        )
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
        guard let tokenHash = app.tokenHash,
              let scheduleData = UserDefaults.standard.data(forKey: "limitSchedule_\(tokenHash)"),
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
        
        let bundleID = "app.name." + app.name.lowercased().replacingOccurrences(of: " ", with: ".")
        let scheduleData = UserDefaults.standard.data(forKey: "limitSchedule_\(bundleID)")
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
                                
                                Image(systemName: app.icon)
                                    .font(.system(size: 52, weight: .semibold))
                                    .foregroundColor(app.color)
                            }
                            .shadow(color: app.color.opacity(0.25), radius: 20, x: 0, y: 10)
                            
                            VStack(spacing: 8) {
                                Text(app.name)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
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
                                withAnimation(.spring(response: 0.3)) {
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
                                withAnimation(.spring(response: 0.3)) {
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
        
        if let goal = goals.first(where: { $0.appName == app.name }) {
            appState.updateAppGoal(goal.id ?? UUID(), dailyLimitMinutes: newLimit)
            
            let bundleID = "app.name." + app.name.lowercased().replacingOccurrences(of: " ", with: ".")
            if let scheduleData = try? JSONEncoder().encode(schedule) {
                UserDefaults.standard.set(scheduleData, forKey: "limitSchedule_\(bundleID)")
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
                                    // Fallback to generic icon if no token available
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 110, weight: .semibold))
                                        .foregroundColor(.textPrimary)
                                        .frame(width: 110, height: 110)  // Match border size exactly
                                }
                            }
                            .shadow(color: Color.primary.opacity(0.25), radius: 20, x: 0, y: 10)
                            
                            VStack(spacing: 8) {
                                // ✅ Use Label(token) to show real app name
                                if let firstToken = fullSelection.applicationTokens.first {
                                    // Token from applicationTokens is already ApplicationToken type
                                    Label(firstToken)
                                        .labelStyle(.titleOnly)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                } else {
                                    Text(appName.isEmpty ? "App" : appName)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                
                                Text("Set a daily time limit")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 28)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Daily Time Limit")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 24)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                                ForEach(limitOptions, id: \.self) { limit in
                                    setLimitOptionButton(limit: limit)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
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
                                        .font(.system(size: 17, weight: .semibold))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 16)
                                        .background(Color.white)
                                        .cornerRadius(14)
                                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                                        .onChange(of: customLimitText) { newValue in
                                            if let minutes = Int(newValue), minutes > 0 {
                                                selectedLimit = minutes
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
                        
                        VStack(alignment: .leading, spacing: 20) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
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
                                setLimitScheduleOptionsView
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button(action: addApp) {
                            HStack(spacing: 14) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                Text("Add Limit")
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
    private func setLimitOptionButton(limit: Int) -> some View {
        let isSelected = selectedLimit == limit && !showingCustomLimit
        
                    Button(action: {
            withAnimation(.spring(response: 0.3)) {
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
    
    private var setLimitScheduleOptionsView: some View {
        VStack(spacing: 24) {
            setLimitDaySelectionView
            setLimitTimeRestrictionView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
    }
    
    private var setLimitDaySelectionView: some View {
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
                    setLimitDaySelectionButton(option: option)
                }
            }
            
            if schedule.daySelection == .custom {
                setLimitCustomDaySelectionView
                    .padding(.top, 8)
                                    }
                            }
    }
    
    @ViewBuilder
    private func setLimitDaySelectionButton(option: DaySelection) -> some View {
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
    
    private var setLimitCustomDaySelectionView: some View {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
            ForEach(0..<7) { dayIndex in
                setLimitCustomDayButton(dayIndex: dayIndex, dayName: dayNames[dayIndex])
    }
        }
    }
    
    @ViewBuilder
    private func setLimitCustomDayButton(dayIndex: Int, dayName: String) -> some View {
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
    
    private var setLimitTimeRestrictionView: some View {
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
                    setLimitTimeRestrictionButton(option: option)
                }
            }
            
            setLimitTimeRestrictionPickers
        }
    }
    
    @ViewBuilder
    private func setLimitTimeRestrictionButton(option: TimeRestrictionType) -> some View {
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
    private var setLimitTimeRestrictionPickers: some View {
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
    
    private func addApp() {
        guard let token = token else {
            print("❌ No token available")
            return
        }
        
        // ✅ bundleID is now the encoded token (same format as ScreenTimeService uses)
        let encodedToken = bundleID
        
        // ✅ FIX: Create selection directly from fullSelection.applicationTokens
        // Use the token from fullSelection directly (it's already ApplicationToken type)
        var appSelection = FamilyActivitySelection()
        
        // ✅ ONLY use app tokens - no category fallback for limits
        // Limits are for individual apps only
        if let firstToken = fullSelection.applicationTokens.first {
            appSelection.applicationTokens = [firstToken]
            print("✅ Created selection with app token from fullSelection")
        } else {
            print("❌ Cannot add limit - no app tokens in selection")
            print("   App tokens: \(fullSelection.applicationTokens.count)")
            print("   Category tokens: \(fullSelection.categoryTokens.count)")
            return
        }
        
        guard !appSelection.applicationTokens.isEmpty else {
            print("❌ Cannot add app - no valid app tokens in selection")
            return
        }
        
        // ✅ CRITICAL: Use custom app name if provided, otherwise use empty string
        // The UI will show the real name via Label(token), but we need a way to match usage data
        // We'll use the bundle ID approach instead of trying to extract names here
        let finalAppName = appName.isEmpty ? "" : appName
        
        print("📱 Adding app with:")
        print("   Encoded token (first 30 chars): \(String(encodedToken.prefix(30)))...")
        print("   App name: '\(finalAppName)'")
        print("   Limit: \(selectedLimit) minutes")
        print("   Tokens: \(appSelection.applicationTokens.count)")
        
        // ✅ Add the app goal using encoded token as identifier
        // This matches what ScreenTimeService expects
        appState.addAppGoalFromFamilySelection(
            appSelection,
            appName: finalAppName,
            dailyLimitMinutes: selectedLimit,
            bundleID: encodedToken  // ✅ Encoded token as identifier
        )
        
        // Save schedule with encoded token
        if let scheduleData = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(scheduleData, forKey: "limitSchedule_\(encodedToken)")
            print("💾 Saved schedule for encoded token: \(String(encodedToken.prefix(30)))...")
        }
        
        // 🔍 DEBUG: App added successfully
        print("\n🔍 DEBUG: App added successfully")
        print("   Encoded token (first 30 chars): \(String(encodedToken.prefix(30)))...")
        print("   Custom name: \(appName)")
        print("   Limit: \(selectedLimit) minutes")
        // Force immediate check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let currentUsage = ScreenTimeService.shared.getUsageMinutes(for: encodedToken)
            print("   Current usage after 2s: \(currentUsage) minutes")
        }
        
        HapticFeedback.success.trigger()
        dismiss()
    }
}

struct BlockingView_Previews: PreviewProvider {
    static var previews: some View {
        BlockingView()
    }
}