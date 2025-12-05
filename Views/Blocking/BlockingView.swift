import SwiftUI
import FamilyControls

struct BlockingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @State private var showingAddAppSheet = false
    @State private var selectedApp: BlockedApp?
    @State private var showingAppDetail = false
    @State private var refreshID = UUID()
    
    // Get apps that are actually connected to Screen Time API
    private var connectedApps: [BlockedApp] {
        let goals = CoreDataManager.shared.getActiveAppGoals()
        
        let connected = goals.compactMap { goal -> BlockedApp? in
            guard let appName = goal.appName,
                  let bundleID = goal.appBundleID else {
                return nil
            }
            
            // Check if we have a selection stored for this app
            let hasSelection = screenTimeService.hasSelection(for: bundleID)
            
            guard hasSelection else {
                return nil
            }
            
            let currentUsage = screenTimeService.getUsageMinutes(for: bundleID)
            let dailyLimit = Int(goal.dailyLimitMinutes)
            
            return BlockedApp(
                id: goal.id ?? UUID(),
                name: appName,
                bundleID: bundleID,
                dailyLimit: dailyLimit,
                usedToday: currentUsage,
                isActive: goal.isActive,
                isBlocked: false
            )
        }
        
        return connected
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        headerSection
                        
                        if connectedApps.isEmpty {
                            emptyStateView
                        } else {
                            appsListSection
                        }
                        
                        addAppButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refreshData()
            }
            .sheet(isPresented: $showingAddAppSheet) {
                CategoryAppSelectionView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingAppDetail) {
                if let app = selectedApp {
                    AppBlockingDetailView(app: app)
                        .environmentObject(appState)
                }
            }
            .onAppear {
                // Debug current state
                screenTimeService.debugPrintState()
                
                Task {
                    await refreshData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .screenTimeDataUpdated)) { _ in
                Task {
                    await refreshData()
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
                    HStack {
                            VStack(alignment: .leading, spacing: 4) {
                    Text("App Blocking")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                
                    Text("Manage your app limits and blocking")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textSecondary)
                            }
                
                Spacer()
                
                // Screen Time authorization status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(connectionStatusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(connectionStatusText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.cardBackground)
                .cornerRadius(20)
            }
            
            if !screenTimeService.isAuthorized {
                WarningBanner(
                    title: "Screen Time Access Required",
                    message: "Enable Screen Time permissions in Settings to block apps.",
                    action: {
                        Task {
                            try? await appState.requestScreenTimeAuthorization()
                            await refreshData()
                        }
                    }
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
                                    Image(systemName: "apps.iphone")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.textPrimary.opacity(0.4))
                                    
                                    VStack(spacing: 8) {
                Text("No Apps Being Monitored")
                    .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.textPrimary)
                                        
                Text("Add apps to set time limits and enable blocking when you exceed your daily goals.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textSecondary)
                                            .multilineTextAlignment(.center)
                    .lineLimit(3)
                                    }
                                }
        .padding(40)
                                .background(Color.cardBackground)
                                .cornerRadius(16)
    }
    
    private var appsListSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(connectedApps) { app in
                AppBlockingCard(app: app) {
                    selectedApp = app
                    showingAppDetail = true
                }
                                    }
                                }
        .id(refreshID)
                            }
                            
    private var addAppButton: some View {
                            Button(action: {
                                showingAddAppSheet = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                    .foregroundColor(.white)
                                    
                Text("Add App to Monitor")
                                        .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                                    
                                    Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
            .background(Color.blue)
                                .cornerRadius(12)
                            }
    }
    
    // MARK: - Connection Status
    
    private var connectionStatusColor: Color {
        if !screenTimeService.isAuthorized {
            return .red
        }
        
        // Check if we have any monitored apps
        let goals = CoreDataManager.shared.getActiveAppGoals()
        let connectedApps = goals.filter { goal in
            guard let bundleID = goal.appBundleID else { return false }
            return screenTimeService.hasSelection(for: bundleID)
        }
        
        if connectedApps.isEmpty {
            return .orange
        }
        
        return .green
    }
    
    private var connectionStatusText: String {
        if !screenTimeService.isAuthorized {
            return "Not Authorized"
        }
        
        // Check if we have any monitored apps
        let goals = CoreDataManager.shared.getActiveAppGoals()
        let connectedApps = goals.filter { goal in
            guard let bundleID = goal.appBundleID else { return false }
            return screenTimeService.hasSelection(for: bundleID)
        }
        
        if connectedApps.isEmpty {
            return "No Apps Connected"
        }
        
        return "Connected (\(connectedApps.count))"
    }
    
    @MainActor
    private func refreshData() async {
        await screenTimeService.refreshAllAppUsage()
        appState.loadAppGoals()
        refreshID = UUID()
    }
}

// MARK: - Supporting Models

struct BlockedApp: Identifiable, Equatable {
    let id: UUID
    let name: String
    let bundleID: String
    var dailyLimit: Int
    var usedToday: Int
    let isActive: Bool
    let isBlocked: Bool
    
    var remainingTime: Int {
        max(0, dailyLimit - usedToday)
    }
    
    var progressPercentage: Double {
        guard dailyLimit > 0 else { return 0 }
        return min(1.0, Double(usedToday) / Double(dailyLimit))
    }
    
    var isOverLimit: Bool {
        dailyLimit > 0 && usedToday >= dailyLimit
    }
    
    var statusColor: Color {
        if !isActive { return .gray }
        if dailyLimit == 0 { return .red }
        if isOverLimit { return .red }
        if progressPercentage >= 0.8 { return .orange }
        return .green
    }
    
    var statusText: String {
        if !isActive { return "Disabled" }
        if dailyLimit == 0 { return "Completely Blocked" }
        if isBlocked { return "Blocked" }
        if isOverLimit { return "Time's Up" }
        if progressPercentage >= 0.8 { return "Almost There" }
        return "On Track"
    }
}

// MARK: - App Blocking Card

struct AppBlockingCard: View {
    let app: BlockedApp
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
        VStack(alignment: .leading, spacing: 16) {
                // Header with app info and status
                HStack(spacing: 16) {
                    // App icon placeholder (generic since we can't get real icons easily)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(app.statusColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(app.statusColor)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                            .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        
                        Text(app.statusText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(app.statusColor)
                    }
                
                Spacer()
                
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatTime(app.usedToday))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("of \(formatTime(app.dailyLimit))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                        }
                    }
                
                // Progress bar
                if app.dailyLimit > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: app.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: app.statusColor))
                            .frame(height: 6)
                    
                    HStack {
                            Text("\(Int(app.progressPercentage * 100))% used")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.textSecondary)
                        
                        Spacer()
                        
                            if app.remainingTime > 0 {
                                Text("\(formatTime(app.remainingTime)) remaining")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.textSecondary)
                            } else if app.dailyLimit > 0 {
                                Text("Limit reached")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // Quick actions
                HStack(spacing: 12) {
                    if app.isBlocked {
                        QuickActionButton(
                            title: "Unblock (1 Credit)",
                            icon: "lock.open.fill",
                            color: .orange,
                            action: {
                                unblockApp(app)
                            }
                        )
                    } else if app.isOverLimit && app.dailyLimit > 0 {
                        QuickActionButton(
                            title: "Extend +15 min",
                            icon: "plus.circle.fill",
                            color: .blue,
                            action: {
                                extendLimit(app)
                            }
                        )
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSecondary.opacity(0.5))
                }
            }
            .padding(20)
            .background(Color.cardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTime(_ minutes: Int) -> String {
        if minutes == 0 {
            return "0m"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
    
    private func unblockApp(_ app: BlockedApp) {
        let success = ScreenTimeService.shared.unblockAppWithCredit(app.bundleID)
        if success {
            HapticFeedback.success.trigger()
        } else {
            HapticFeedback.error.trigger()
        }
    }
    
    private func extendLimit(_ app: BlockedApp) {
        // This would extend the limit by 15 minutes
        // Implementation would depend on how limits are stored and updated
        HapticFeedback.light.trigger()
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
                    }
                }
                
// MARK: - Warning Banner

struct WarningBanner: View {
    let title: String
    let message: String
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }
                        
                        Spacer()
                        
            Button("Enable", action: action)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
                            }
                        }
                        
// MARK: - App Detail View

struct AppBlockingDetailView: View {
    let app: BlockedApp
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var newLimit: Int
    @State private var showingCustomLimit = false
    @State private var customLimitText = ""
    
    init(app: BlockedApp) {
        self.app = app
        _newLimit = State(initialValue: app.dailyLimit)
    }
    
    private let limitOptions = [0, 15, 30, 45, 60, 90, 120, 180, 240, 300]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Header
                    VStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(app.statusColor.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "app.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(app.statusColor)
                            )
                        
                        VStack(spacing: 4) {
                            Text(app.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.textPrimary)
                            
                            Text(app.statusText)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(app.statusColor)
                        }
                    }
                    
                    // Usage Stats
                    VStack(spacing: 16) {
                        HStack {
                            AppStatCard(
                                title: "Used Today",
                                value: formatTime(app.usedToday),
                                color: .blue
                            )
                            
                            AppStatCard(
                                title: "Daily Limit",
                                value: app.dailyLimit > 0 ? formatTime(app.dailyLimit) : "Blocked",
                                color: app.dailyLimit > 0 ? .green : .red
                            )
                        }
                        
                        if app.dailyLimit > 0 {
                            ProgressView(value: app.progressPercentage)
                                .progressViewStyle(LinearProgressViewStyle(tint: app.statusColor))
                                .frame(height: 8)
                        }
                    }
                    .padding(20)
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    
                    // Limit Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily Time Limit")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(limitOptions, id: \.self) { limit in
                                LimitOptionButton(
                                    limit: limit,
                                    isSelected: newLimit == limit && !showingCustomLimit,
                                    onTap: {
                                        newLimit = limit
                                        showingCustomLimit = false
                                    }
                                )
                            }
                        }
                        
                        // Custom limit option
                        Button(action: {
                            showingCustomLimit = true
                            customLimitText = "\(newLimit)"
                        }) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Custom Limit")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(showingCustomLimit ? .white : .blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(showingCustomLimit ? Color.blue : Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        if showingCustomLimit {
                            HStack {
                                TextField("Minutes", text: $customLimitText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: customLimitText) { value in
                                        if let minutes = Int(value), minutes >= 0 {
                                            newLimit = minutes
                                        }
                                    }
                                
                                Text("minutes")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textSecondary)
                }
            }
        }
                    .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
                    
                    // Actions
                    VStack(spacing: 12) {
                        if app.isBlocked {
                            Button("Unblock App (1 Credit)") {
                                unblockApp()
                            }
                            .buttonStyle(AppPrimaryButtonStyle(color: .orange))
                        }
                        
                        if newLimit != app.dailyLimit {
                            Button("Update Limit") {
                                updateLimit()
                            }
                            .buttonStyle(AppPrimaryButtonStyle())
                        }
                        
                        Button("Remove App") {
                            removeApp()
                        }
                        .buttonStyle(AppSecondaryButtonStyle(color: .red))
                    }
                }
                .padding(20)
            }
            .navigationTitle("App Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatTime(_ minutes: Int) -> String {
        if minutes == 0 {
            return "0m"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
            }
    
    private func unblockApp() {
        let success = ScreenTimeService.shared.unblockAppWithCredit(app.bundleID)
        if success {
            HapticFeedback.success.trigger()
            dismiss()
        } else {
            HapticFeedback.error.trigger()
        }
    }
    
    private func updateLimit() {
        appState.updateAppGoal(app.id, dailyLimitMinutes: newLimit)
        HapticFeedback.success.trigger()
        dismiss()
    }
    
    private func removeApp() {
        // Remove app from monitoring
        appState.deleteAppGoal(app.id)
        HapticFeedback.success.trigger()
        dismiss()
    }
}

// MARK: - Supporting Views

struct AppStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.appBackground)
        .cornerRadius(12)
    }
}

struct LimitOptionButton: View {
    let limit: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                if limit == 0 {
                    Text("Blocked")
                        .font(.system(size: 14, weight: .bold))
                } else if limit < 60 {
                    Text("\(limit)")
                        .font(.system(size: 18, weight: .bold))
                    Text("min")
                        .font(.system(size: 12, weight: .medium))
                } else {
                    let hours = limit / 60
                    let mins = limit % 60
                    Text("\(hours)\(mins > 0 ? ".5" : "")")
                        .font(.system(size: 18, weight: .bold))
                    Text("hr\(hours == 1 && mins == 0 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(isSelected ? .white : .textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(isSelected ? Color.blue : Color.appBackground)
            .cornerRadius(12)
        }
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    init(color: Color = .blue) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1.0))
            .cornerRadius(12)
        }
    }
    
struct AppSecondaryButtonStyle: ButtonStyle {
    let color: Color
    
    init(color: Color = .gray) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(configuration.isPressed ? 0.2 : 0.1))
            .cornerRadius(12)
    }
}

#Preview {
    BlockingView()
        .environmentObject(AppState())
}