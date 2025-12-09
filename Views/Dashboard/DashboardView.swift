import SwiftUI
import UIKit
import FamilyControls
import DeviceActivity

// Define the report context (must match extension)
// These contexts are used by the main app to reference reports defined in the extension
extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let todayOverview = Self("todayOverview")
}

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    private let screenTimeService = ScreenTimeService.shared
    @State private var showingCreditLossAlert = false
    @State private var showingSuccessToast = false
    @State private var creditsLostInAlert = 0
    @State private var showingAddAppSheet = false
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var showingUnblockConfirmation = false
    @State private var appToUnblock: MonitoredApp?
    @State private var showingBlockedAppModal = false
    @State private var blockedAppName: String = ""
    @State private var blockedAppBundleID: String? = nil
    @State private var showingExtendLimitSheet = false
    @State private var appToExtend: MonitoredApp? = nil
    @State private var showingSelectAllApps = false
    @State private var allAppsSelection = FamilyActivitySelection()
    @State private var topDistractionTokens: [String: AnyHashable] = [:] // Store tokens by bundleID (as AnyHashable to avoid ApplicationToken type)
    @State private var topAppToken: AnyHashable? = nil // Store token for top app
    
    private var healthScore: Int {
        // Calculate health based on actual app usage
        // For new users with no apps or no usage, return 100 (start at full health)
        guard !appState.monitoredApps.isEmpty else { return 100 }
        
        let totalUsageToday = appState.monitoredApps.reduce(0) { $0 + $1.usedToday }
        let totalLimits = appState.monitoredApps.reduce(0) { $0 + $1.dailyLimit }
        
        guard totalLimits > 0 else { return 100 }
        
        // If no usage yet today, return 100 (start at full health)
        guard totalUsageToday > 0 else { return 100 }
        
        let usagePercentage = Double(totalUsageToday) / Double(totalLimits)
        
        // Convert usage percentage to health score (inverse relationship)
        switch usagePercentage {
        case 0...0.5: return 100 // Under 50% usage = perfect health
        case 0.5...0.7: return 80 // 50-70% usage = good health
        case 0.7...0.9: return 60 // 70-90% usage = okay health
        case 0.9...1.1: return 40 // 90-110% usage = poor health
        default: return 20 // Over 110% usage = very poor health
        }
    }
    
    @State private var totalScreenTimeMinutes: Int = 0
    @State private var appsUsedToday: Int = 0
    @State private var topAppToday: TopAppData?
    @State private var isLoadingScreenTime = false
    @State private var screenTimeError: String?
    
    
    
    // Calculate total screen time today (all apps combined)
    private var totalScreenTimeToday: Int {
        totalScreenTimeMinutes
    }
    
    // Load comprehensive screen time data from Screen Time API
    private func loadScreenTimeData() {
        guard !isLoadingScreenTime else { return }
        
        // Check synchronously if we have allAppsSelection before showing loading state
        // This prevents flickering of "Select All Apps" button
        let hasAllApps = screenTimeService.allAppsSelection != nil && 
                        (!(screenTimeService.allAppsSelection?.applicationTokens.isEmpty ?? true) || 
                         !(screenTimeService.allAppsSelection?.categoryTokens.isEmpty ?? true))
        
        print("🔍 DashboardView.loadScreenTimeData: hasAllApps = \(hasAllApps)")
        if let allApps = screenTimeService.allAppsSelection {
            print("📱 allAppsSelection has \(allApps.applicationTokens.count) apps and \(allApps.categoryTokens.count) categories")
        } else {
            print("⚠️ allAppsSelection is nil")
        }
        
        let goals = CoreDataManager.shared.getActiveAppGoals()
        let connectedGoals = goals.filter { goal in
            guard let bundleID = goal.appBundleID else { return false }
            return screenTimeService.hasSelection(for: bundleID)
        }
        
        // If no all apps selection, check if onboarding was completed
        // If onboarding was completed, allAppsSelection should exist
        // Only show prompt if onboarding wasn't completed yet
        if !hasAllApps && connectedGoals.isEmpty {
            // Check if onboarding was completed
            let isOnboardingComplete = !appState.isOnboarding
            
            if isOnboardingComplete {
                // Onboarding was completed but allAppsSelection is missing - this shouldn't happen
                // Try to load it or show a different message
                print("⚠️ Onboarding completed but allAppsSelection is missing")
            }
            
            // Only show "Select All Apps" prompt if still in onboarding
            // Otherwise, just show loading/empty state
            self.totalScreenTimeMinutes = 0
            self.appsUsedToday = 0
            self.topAppToday = nil
            self.isLoadingScreenTime = false
            // Don't show error if onboarding is complete - just show empty state
            self.screenTimeError = isOnboardingComplete ? nil : "Select all apps to view your total screen time"
            return
        }
        
        // Only show loading if we have apps to load data for
        isLoadingScreenTime = true
        screenTimeError = nil
        
        Task {
            print("🔍 Loading Screen Time data from API...")
            print("📊 Authorization status: \(screenTimeService.isAuthorized)")
            
            // Check authorization first
            guard screenTimeService.isAuthorized else {
                await MainActor.run {
                    self.totalScreenTimeMinutes = 0
                    self.appsUsedToday = 0
                    self.topAppToday = nil
                    self.isLoadingScreenTime = false
                    self.screenTimeError = "Screen Time not authorized. Please enable Screen Time access in Settings."
                }
                return
            }
            
            print("📊 All apps selection: \(hasAllApps ? "Yes" : "No"), Monitored apps: \(connectedGoals.count)")
            
            // First, ensure allAppsSelection is properly set up with goals and records
            if hasAllApps, let allApps = screenTimeService.allAppsSelection {
                print("📱 Ensuring all apps in selection have goals and records...")
                // This will be handled by updateUsageFromReport, but we can also ensure setup here
            }
            
            // First, try to fetch latest usage data from reports
            // This will create goals/records for all apps if needed
            await screenTimeService.updateUsageFromReport()
            
            // Small delay to ensure data is saved
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Try to read from shared container (updated by DeviceActivityReport extension)
            // ⚠️ CRITICAL: This is the source of truth - prioritize it over ScreenTimeService
            let sharedUsage = readUsageFromSharedContainer()
            let sharedAppsCount = readAppsCountFromSharedContainer()
            
            // Get total screen time and apps used from ScreenTimeService (fallback)
            var (totalMinutes, appsUsed) = await screenTimeService.getTotalScreenTimeToday()
            
            // ⚠️ CRITICAL FIX: ALWAYS prioritize shared container data when available
            // The report extension is the authoritative source for usage data
            if sharedUsage > 0 {
                let previousTotal = totalMinutes
                totalMinutes = sharedUsage
                print("📊 Using shared container usage: \(totalMinutes) minutes (overriding ScreenTimeService: \(previousTotal))")
            } else if totalMinutes > 0 {
                print("📊 Using ScreenTimeService data: \(totalMinutes) minutes (shared container empty)")
            } else {
                print("⚠️ No usage data found in shared container or ScreenTimeService")
            }
            
            // Always prioritize shared container apps count when available
            if sharedAppsCount > 0 {
                appsUsed = sharedAppsCount
                print("📊 Using shared container apps count: \(appsUsed) apps")
            } else if appsUsed > 0 {
                print("📊 Using ScreenTimeService apps count: \(appsUsed) apps")
            } else {
                print("⚠️ No apps count found in shared container or ScreenTimeService")
            }
            
            print("📊 After update: Total minutes: \(totalMinutes), Apps used: \(appsUsed)")
            
            // Get top app
            let topAppResult = await screenTimeService.getTopAppToday()
            
            // Convert top app result to TopAppData if available
            var topAppData: TopAppData? = nil
            var topToken: AnyHashable? = nil
            if let topApp = topAppResult {
                // Try to find goal for limit, but don't require it
                let goal = connectedGoals.first(where: { $0.appBundleID == topApp.bundleID })
                topAppData = TopAppData(
                    name: topApp.name,
                    bundleID: topApp.bundleID,
                    minutesUsed: topApp.minutes,
                    dailyLimit: goal != nil ? Int(goal!.dailyLimitMinutes) : 0
                )
                
                // Token will be found on-demand in topAppCard
                topToken = nil
            }
            
            await MainActor.run {
                self.totalScreenTimeMinutes = totalMinutes
                self.appsUsedToday = appsUsed
                self.topAppToday = topAppData
                self.topAppToken = topToken
                self.isLoadingScreenTime = false
                
                // Only show informational message if we have connected apps but no usage yet
                // Usage records are initialized immediately, so 0 means no usage yet (which is normal)
                if totalMinutes == 0 && appsUsed == 0 && !connectedGoals.isEmpty {
                    self.screenTimeError = nil // Don't show error - 0 usage is normal at start of day
                } else {
                    self.screenTimeError = nil
                }
                
                print("✅ Loaded Screen Time data: \(totalMinutes) minutes, \(appsUsed) apps")
                if let top = topAppData {
                    print("📱 Top app: \(top.name) - \(top.minutesUsed) minutes")
                }
            }
        }
    }
    
    // MARK: - Shared Container Reading
    
    /// Read usage data from the shared container (populated by DeviceActivityReport extension)
    private func readUsageFromSharedContainer() -> Int {
        let appGroupID = "group.com.se7en.app"
        
        // Create a serial queue for thread-safe UserDefaults access
        let queue = DispatchQueue(label: "com.se7en.sharedDefaults.read", qos: .userInitiated)
        
        return queue.sync {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
                print("❌ Failed to access shared container")
                return 0
            }
            
            // Force refresh from disk before reading
            // This ensures we get the latest data written by the extension
            sharedDefaults.synchronize()
            
            let totalUsage = sharedDefaults.integer(forKey: "total_usage")
            let lastUpdated = sharedDefaults.double(forKey: "last_updated")
            
            if lastUpdated > 0 {
                let lastUpdateDate = Date(timeIntervalSince1970: lastUpdated)
                let timeSinceUpdate = Date().timeIntervalSince(lastUpdateDate)
                print("📊 Shared container last updated: \(Int(timeSinceUpdate)) seconds ago")
            }
            
            if totalUsage > 0 {
                print("📊 Found total_usage in shared container: \(totalUsage) minutes")
            } else {
                print("⚠️ total_usage is 0 in shared container")
                
                // Debug: List all keys in shared defaults
                if let allKeys = sharedDefaults.dictionaryRepresentation().keys as? [String] {
                    print("📊 Available keys in shared container: \(allKeys.joined(separator: ", "))")
                }
            }
            
            return totalUsage
        }
    }
    
    /// Read apps count from the shared container
    private func readAppsCountFromSharedContainer() -> Int {
        let appGroupID = "group.com.se7en.app"
        
        let queue = DispatchQueue(label: "com.se7en.sharedDefaults.read", qos: .userInitiated)
        
        return queue.sync {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
                return 0
            }
            
            // Force refresh from disk
            sharedDefaults.synchronize()
            
            let appsCount = sharedDefaults.integer(forKey: "apps_count")
            if appsCount > 0 {
                print("📊 Found apps_count in shared container: \(appsCount)")
            } else {
                print("⚠️ apps_count is 0 or missing in shared container")
            }
            return appsCount
        }
    }
    
    /// Read last updated timestamp from the shared container for debugging
    private func readSharedLastUpdated() -> String {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return "n/a"
        }
        let lastUpdated = sharedDefaults.double(forKey: "last_updated")
        guard lastUpdated > 0 else { return "n/a" }
        let date = Date(timeIntervalSince1970: lastUpdated)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    
    // Format screen time as "Xh Ym"
    private func formatScreenTime(_ minutes: Int) -> String {
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
    
    // Get top 10 apps by usage today - ONLY apps with usage > 0
    private var topDistractions: [MonitoredApp] {
        // ALWAYS try to read from shared container first (filtered by report extension)
        // This is the source of truth for top apps
        if let topAppsFromShared = readTopAppsFromSharedContainer(), !topAppsFromShared.isEmpty {
            print("📊 Using top apps from shared container: \(topAppsFromShared.count) apps")
            return topAppsFromShared
        }
        
        print("⚠️ No top apps in shared container, computing from tracked usage...")
        
        // Fallback: Compute from tracked usage (only apps with usage > 0)
        guard let allApps = screenTimeService.allAppsSelection,
              !allApps.applicationTokens.isEmpty else {
            print("⚠️ No allAppsSelection available")
            return []
        }
        
        return getTopAppsFromAllApps(allApps)
    }
    
    /// Read top apps from shared container (filtered by report extension, excludes placeholder apps)
    private func readTopAppsFromSharedContainer() -> [MonitoredApp]? {
        let appGroupID = "group.com.se7en.app"
        
        let queue = DispatchQueue(label: "com.se7en.sharedDefaults.read", qos: .userInitiated)
        
        return queue.sync {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
                print("❌ Failed to access shared container for top apps")
                return nil
            }
            
            // Force refresh from disk
            sharedDefaults.synchronize()
            
            guard let topAppsPayload = sharedDefaults.array(forKey: "top_apps") as? [[String: Any]] else {
                print("⚠️ No top_apps key in shared container")
                return nil
            }
            
            print("📊 Found \(topAppsPayload.count) top apps in shared container")
            
            let realAppDiscovery = RealAppDiscoveryService.shared
            var topApps: [MonitoredApp] = []
            
            for appData in topAppsPayload {
                guard let name = appData["name"] as? String,
                      let minutes = appData["minutes"] as? Int else {
                    print("⚠️ Skipping invalid app data: \(appData)")
                    continue
                }
                
                // Filter out placeholder names (should already be filtered by extension, but double-check)
                if isPlaceholderAppName(name) {
                    print("⚠️ Filtering out placeholder: \(name)")
                    continue
                }
                
                // ⚠️ CRITICAL: Only include apps with minutes > 0
                guard minutes > 0 else {
                    print("⏭️ Skipping \(name): 0 minutes")
                    continue
                }
                
                print("✅ Including from shared container: \(name) - \(minutes) minutes")
                
                // Find token for this app name
                var token: AnyHashable? = nil
                if let allApps = screenTimeService.allAppsSelection {
                    for appToken in allApps.applicationTokens {
                        let tokenName = realAppDiscovery.extractDisplayName(from: appToken)
                        if tokenName == name {
                            token = appToken as AnyHashable
                            break
                        }
                    }
                }
                
                // ✅ Use .application token type for categorization
                let category = AppCategory.category(for: .application)
                
                topApps.append(MonitoredApp(
                    name: name,
                    icon: category.icon,
                    dailyLimit: 0,
                    usedToday: minutes,
                    color: Color(category.color),
                    isEnabled: false
                ))
            }
            
            print("📊 Returning \(topApps.count) top apps from shared container")
            return topApps  // ✅ Always return array, never nil
        }
    }
    
    /// Check if an app name is a placeholder (e.g., "app 902388", "Unknown")
    private func isPlaceholderAppName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "unknown" || trimmed.isEmpty {
            return true
        }
        
        // Match patterns like "app 902388" or "app902388"
        if let regex = try? NSRegularExpression(pattern: #"^app\s*\d{2,}$"#, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: name.utf16.count)
            if regex.firstMatch(in: name, options: [], range: range) != nil {
                return true
            }
        }
        
        return false
    }
    
    // Helper function to find token for a bundleID - used throughout DashboardView
    private func findTokenForBundleID(_ bundleID: String) -> AnyHashable? {
        guard let allApps = screenTimeService.allAppsSelection else {
            return nil
        }
        let realAppDiscovery = RealAppDiscoveryService.shared
        for token in allApps.applicationTokens {
            guard let tokenBundleID = realAppDiscovery.extractBundleID(from: token),
                  realAppDiscovery.isValidBundleID(tokenBundleID) else {
                continue
            }
            if tokenBundleID == bundleID {
                return token as AnyHashable
            }
        }
        return nil
    }
    
    // Helper function to find token for an app
    private func findTokenForApp(_ app: MonitoredApp) -> AnyHashable? {
        let coreDataManager = CoreDataManager.shared
        let goals = coreDataManager.getActiveAppGoals()
        guard let bundleID = goals.first(where: { $0.appName == app.name })?.appBundleID else {
            return nil
        }
        return findTokenForBundleID(bundleID)
    }
    
    private func getTopAppsFromAllApps(_ selection: FamilyActivitySelection) -> [MonitoredApp] {
        let realAppDiscovery = RealAppDiscoveryService.shared
        var appsWithUsage: [(name: String, minutes: Int, icon: String, color: Color, bundleID: String, token: AnyHashable?)] = []
        
        // Handle individual app tokens
        for token in selection.applicationTokens {
            // Extract bundle ID - skip if extraction fails
            guard let bundleID = realAppDiscovery.extractBundleID(from: token),
                  realAppDiscovery.isValidBundleID(bundleID) else {
                continue
            }
            
            let appName = realAppDiscovery.extractDisplayName(from: token)
            
            // Filter out placeholder app names
            if isPlaceholderAppName(appName) {
                continue
            }
            
            let usage = screenTimeService.getUsageMinutes(for: bundleID)
            
            // ⚠️ CRITICAL: Only include apps with usage > 0
            guard usage > 0 else {
                print("⏭️ Skipping \(appName): 0 minutes usage")
                continue
            }
            
            print("✅ Including \(appName): \(usage) minutes usage")
            
            // ✅ Use .application token type for categorization (bundleID is not used for category anymore)
            let category = AppCategory.category(for: .application)
            appsWithUsage.append((
                name: appName,
                minutes: usage,
                icon: category.icon,
                color: Color(category.color),
                bundleID: bundleID,
                token: token as AnyHashable
            ))
        }
        
        // Handle category tokens - when only categories are selected, we can't show individual apps
        // DeviceActivityReport doesn't provide individual app breakdown for categories
        if !selection.categoryTokens.isEmpty && selection.applicationTokens.isEmpty {
            print("📊 Categories selected but no individual apps available for top distractions")
        }
        
        // Sort by usage and take top 10
        let topApps = appsWithUsage
            .sorted { $0.minutes > $1.minutes }
            .prefix(10)
        
        print("📊 getTopAppsFromAllApps: Returning \(topApps.count) apps with usage")
        
        // Store tokens for later use in UI
        Task { @MainActor in
            var tokenDict: [String: AnyHashable] = [:]
            for app in topApps {
                if let token = app.token {
                    tokenDict[app.bundleID] = token
                }
            }
            topDistractionTokens = tokenDict
        }
        
        // Convert to MonitoredApp format
        return topApps.map { app in
            MonitoredApp(
                name: app.name,
                icon: app.icon,
                dailyLimit: 0, // No limit for all apps view
                usedToday: app.minutes,
                color: app.color,
                isEnabled: false // Not actively monitored
            )
        }
    }
    
    private var healthColor: Color {
        switch healthScore {
        case 0..<25: return .red
        case 25..<50: return .orange
        case 50..<75: return .yellow
        case 75...100: return .green
        default: return .green
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
                        VStack(spacing: 0) {
                            headerSection
                            petAndCreditsSection
                            petImageSection
                            healthSection
                            screenTimeSection
                            topDistractionsSection
                        }
                        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 800 : .infinity)
                        Spacer()
                    }
                }
                
                // Overlays
                if showingCreditLossAlert {
                    CreditLossAlert(
                        isPresented: $showingCreditLossAlert,
                        creditsLost: creditsLostInAlert,
                        creditsRemaining: appState.currentCredits
                    )
                }
                
                // Streak Celebration Overlay
                if appState.shouldShowStreakCelebration {
                    StreakCelebrationView(
                        streak: appState.newStreakValue,
                        pet: appState.userPet,
                        onDismiss: {
                            appState.shouldShowStreakCelebration = false
                        }
                    )
                }
                
                // Achievement Celebration Overlay
                if appState.shouldShowAchievementCelebration {
                    if let achievement = appState.newAchievement {
                        AchievementCelebrationView(
                            achievement: achievement,
                            onDismiss: {
                                appState.shouldShowAchievementCelebration = false
                            }
                        )
                    }
                }
                
                if showingSuccessToast {
                    SuccessToast(
                        message: "Great job staying on track!",
                        isPresented: $showingSuccessToast
                    )
                }
                
                if showingBlockedAppModal {
                    BlockedAppModal(
                        isPresented: $showingBlockedAppModal,
                        appName: blockedAppName,
                        bundleID: blockedAppBundleID
                    )
                    .environmentObject(appState)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .alert("Unblock App", isPresented: $showingUnblockConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Spend 1 Credit") {
                    handleConfirmUnblock()
                }
            } message: {
                if let app = appToUnblock {
                    Text("Spend 1 credit to unblock \(app.name) now? You have \(appState.currentCredits) credits remaining.")
                }
            }
            .sheet(isPresented: $showingExtendLimitSheet) {
                if let app = appToExtend {
                    ExtendLimitSheet(app: app)
                        .environmentObject(appState)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .appBlocked)) { notification in
                if let userInfo = notification.userInfo,
                   let appName = userInfo["appName"] as? String,
                   let bundleID = userInfo["bundleID"] as? String {
                    showBlockedAppModal(appName: appName, bundleID: bundleID)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingDatePicker = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                            Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.appBackground)
                        .cornerRadius(8)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cardBackground.opacity(0.8))
                        .cornerRadius(16)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    CompactStreakView(streak: appState.currentStreak)
                }
            }
            .sheet(isPresented: $showingAddAppSheet) {
                CategoryAppSelectionView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingSelectAllApps) {
                SelectAllAppsView(selection: $allAppsSelection)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingDatePicker) {
                DateHistoryPicker(
                    selectedDate: $selectedDate,
                    isPresented: $showingDatePicker,
                    appState: appState
                )
            }
            .onAppear {
                print("📱 DashboardView.onAppear: Starting data load")
                
                // Ensure Screen Time is authorized
                if !screenTimeService.isAuthorized {
                    Task {
                        await screenTimeService.requestAuthorization()
                        // Wait a moment for authorization to complete
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        // Then refresh monitoring
                        screenTimeService.refreshAllMonitoring()
                    }
                } else {
                    // ⚠️ CRITICAL: Refresh monitoring immediately
                    screenTimeService.refreshAllMonitoring()
                }
                
                // Small delay before loading data to ensure monitoring is active
                // Then refresh periodically to catch report extension updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    loadScreenTimeData()
                    appState.refreshScreenTimeData()
                }
                
                // Periodic refresh to catch report extension updates (every 3 seconds for first 15 seconds)
                for delay in [3.0, 6.0, 9.0, 12.0, 15.0] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        print("🔄 Periodic refresh: Re-reading shared container...")
                        let sharedUsage = readUsageFromSharedContainer()
                        let sharedApps = readAppsCountFromSharedContainer()
                        if sharedUsage > 0 || sharedApps > 0 {
                            print("✅ Periodic refresh found data: \(sharedUsage) minutes, \(sharedApps) apps")
                            totalScreenTimeMinutes = sharedUsage
                            appsUsedToday = sharedApps
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh monitoring and data when app enters foreground
                print("📱 App entered foreground - refreshing monitoring")
                screenTimeService.refreshAllMonitoring()
                loadScreenTimeData()
            }
            .onChange(of: screenTimeService.allAppsSelection) { _ in
                // Refresh when allAppsSelection changes (e.g., after onboarding)
                loadScreenTimeData()
            }
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
                            VStack(alignment: .leading, spacing: 12) {
                            Text(timeBasedGreeting(userName: appState.userName))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
    }
                        
    private var petAndCreditsSection: some View {
                        HStack(alignment: .center) {
                            if let pet = appState.userPet {
                                Text(pet.name)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                            }
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                
                                VStack(spacing: 2) {
                                    Text("\(appState.currentCredits)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("credits")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
    }
    
    private var petImageSection: some View {
        Group {
            if let pet = appState.userPet {
                let petImageName = "\(pet.type.folderName.lowercased())fullhealth"
                            Image(petImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
            }
        }
                        }
                        
    private var healthSection: some View {
        VStack(spacing: 0) {
                        Text("\(healthScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .padding(.bottom, 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(healthColor)
                            .frame(height: 6)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 10)
                        
                        Text("Health")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .padding(.bottom, 24)
                        
                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
        }
    }
                        
    private var screenTimeSection: some View {
        VStack(spacing: 16) {
            // Today's Screen Time Card
                        VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    
                    Text("Today's Dashboard")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    // Screen Time API Status
                    HStack(spacing: 6) {
                        let goals = CoreDataManager.shared.getActiveAppGoals()
                        let connectedCount = goals.filter { goal in
                            guard let bundleID = goal.appBundleID else { return false }
                            return ScreenTimeService.shared.hasSelection(for: bundleID)
                        }.count
                        
                        let statusColor: Color = {
                            if !ScreenTimeService.shared.isAuthorized {
                                return .red
                            } else if connectedCount == 0 {
                                return .orange
                            } else {
                                return .green
                            }
                        }()
                        
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                    }
                }
                                .padding(.horizontal, 20)
                            
                if isLoadingScreenTime {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading Screen Time data...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else if let error = screenTimeError, error.contains("Select all apps") {
                    // Show "Select All Apps" button when no all apps selection exists
                    VStack(spacing: 12) {
                        Text("View All Your Apps")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Select all your apps to see total screen time and top distractions")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button(action: {
                            showingSelectAllApps = true
                        }) {
                            Text("Select All Apps")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else if let error = screenTimeError {
                    // Show error or informational message
                    let isError = error.contains("not authorized") || error.contains("Failed")
                            
                            VStack(spacing: 8) {
                        Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(isError ? .orange : .blue)
                        
                        Text(error)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        
                        if isError {
                            Button("Retry") {
                                loadScreenTimeData()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    // Show actual usage data
                    VStack(spacing: 16) {
                        // Show DeviceActivityReport for today's overview
                        // This displays the TodayOverviewView with total time, apps used, and top 10 apps
                        if screenTimeService.isAuthorized {
                            todayOverviewReportView
                            hiddenTotalActivityReportView
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 8) // Minimal padding to maximize width
                }
            }
            .background(Color.appBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cardBackground, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
            
            // Top App Today Card
            if let topApp = topAppToday, topApp.minutesUsed > 0 {
                topAppCard(topApp)
            }
                        }
                        .padding(.bottom, 24)
    }
                        
    // MARK: - DeviceActivityReport Helpers
    
    @ViewBuilder
    private var todayOverviewReportView: some View {
        // ⚠️ CRITICAL: Use the EXACT same date interval that monitoring uses
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        
        let dateInterval = DateInterval(start: startOfDay, end: endOfDay)
        
        let filter = DeviceActivityFilter(
            segment: .daily(during: dateInterval),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
        
        DeviceActivityReport(.todayOverview, filter: filter)
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(minHeight: 620) // Height to fit all 10 items without scrolling
            .background(Color.appBackground)
            .cornerRadius(12)
            .padding(.horizontal, 4) // Minimal padding to maximize width
            .onAppear {
                print("📊 DeviceActivityReport view appeared")
                screenTimeService.refreshAllMonitoring()
                
                // ⚠️ Give extension time to save data, then refresh
                // Try multiple times to catch the data
                for delay in [1.0, 2.0, 3.0] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        print("🔄 Refreshing shared container data after report loaded (attempt at \(delay)s)...")
                        
                        // Force re-read from shared container
                        let sharedUsage = readUsageFromSharedContainer()
                        let sharedApps = readAppsCountFromSharedContainer()
                        
                        if sharedUsage > 0 || sharedApps > 0 {
                            print("✅ Got updated data from shared container: \(sharedUsage) minutes, \(sharedApps) apps")
                            totalScreenTimeMinutes = sharedUsage
                            appsUsedToday = sharedApps
                        } else {
                            print("⚠️ Still no data in shared container after \(delay) seconds")
                        }
                    }
                }
            }
    }
    
    @ViewBuilder
    private var hiddenTotalActivityReportView: some View {
        let dateInterval = DateInterval(
            start: Calendar.current.startOfDay(for: Date()),
            end: Date()
        )
        let filter = DeviceActivityFilter(
            segment: .daily(during: dateInterval),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
        
        DeviceActivityReport(.totalActivity, filter: filter)
            .frame(width: 1, height: 1)
            .opacity(0)
            .allowsHitTesting(false)
    }
    
    private func topAppCard(_ topApp: TopAppData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Most Used App Today")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if topApp.dailyLimit > 0 {
                    Text("Limit: \(formatScreenTime(topApp.dailyLimit))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                // App Icon - use Label directly with token
                if let allApps = screenTimeService.allAppsSelection {
                    let realAppDiscovery = RealAppDiscoveryService.shared
                    if let matchingToken = allApps.applicationTokens.first(where: { token in
                        guard let tokenBundleID = realAppDiscovery.extractBundleID(from: token),
                              realAppDiscovery.isValidBundleID(tokenBundleID) else {
                            return false
                        }
                        return tokenBundleID == topApp.bundleID
                    }) {
                        Label(matchingToken)
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 20))
                            .frame(width: 50, height: 50)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(topApp.statusColor.opacity(0.1))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "app.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(topApp.statusColor)
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(topApp.statusColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(topApp.statusColor)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(topApp.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(formatScreenTime(topApp.minutesUsed)) used today")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(topApp.statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(topApp.statusColor)
                    
                    if topApp.dailyLimit > 0 {
                        Text("\(Int(topApp.progressPercentage * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(topApp.statusColor)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Progress bar for app with limit
            if topApp.dailyLimit > 0 {
                ProgressView(value: min(1.0, topApp.progressPercentage))
                    .progressViewStyle(LinearProgressViewStyle(tint: topApp.statusColor))
                    .frame(height: 4)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }
    
    private var topDistractionsSection: some View {
        Group {
                        if !topDistractions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Top Distractions")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 20)
                                
                                VStack(spacing: 8) {
                                    ForEach(Array(topDistractions.enumerated()), id: \.element.id) { index, app in
                            distractionRow(app: app, index: index)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color.appBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cardBackground, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
        }
    }
    
    private func distractionRow(app: MonitoredApp, index: Int) -> some View {
        // Find token directly from allAppsSelection
        let coreDataManager = CoreDataManager.shared
        let goals = coreDataManager.getActiveAppGoals()
        let bundleID = goals.first(where: { $0.appName == app.name })?.appBundleID
        
        return VStack(spacing: 0) {
                                        HStack(spacing: 12) {
                                            Text("\(index + 1)")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.textSecondary)
                                                .frame(width: 24)
                                            
                // Use Label directly with token if available, otherwise fallback to icon
                if let bundleID = bundleID,
                   let allApps = screenTimeService.allAppsSelection {
                    let realAppDiscovery = RealAppDiscoveryService.shared
                    if let matchingToken = allApps.applicationTokens.first(where: { token in
                        guard let tokenBundleID = realAppDiscovery.extractBundleID(from: token),
                              realAppDiscovery.isValidBundleID(tokenBundleID) else {
                            return false
                        }
                        return tokenBundleID == bundleID
                    }) {
                        Label(matchingToken)
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                    } else {
                                            Image(systemName: app.icon)
                                                .font(.system(size: 20))
                                                .foregroundColor(app.color)
                                                .frame(width: 32)
                    }
                } else {
                    Image(systemName: app.icon)
                        .font(.system(size: 20))
                        .foregroundColor(app.color)
                        .frame(width: 32)
                }
                
                                            Text(app.name)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.textPrimary)
                                            
                                            Spacer()
                                            
                                            Text(formatScreenTime(app.usedToday))
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.textPrimary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.cardBackground)
                                        .cornerRadius(12)
                                        
                                        if index < topDistractions.count - 1 {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
    
    // MARK: - Supporting Data Models
    
    struct TopAppData {
        let name: String
        let bundleID: String
        let minutesUsed: Int
        let dailyLimit: Int
        
        var progressPercentage: Double {
            guard dailyLimit > 0 else { return 0 }
            return Double(minutesUsed) / Double(dailyLimit)
                }
                
        var isOverLimit: Bool {
            dailyLimit > 0 && minutesUsed >= dailyLimit
        }
        
        var statusColor: Color {
            if dailyLimit == 0 { return .blue }
            if isOverLimit { return .red }
            if progressPercentage >= 0.8 { return .orange }
            return .green
        }
        
        var statusText: String {
            if dailyLimit == 0 { return "No limit set" }
            if isOverLimit { return "Over limit" }
            if progressPercentage >= 0.8 { return "Almost there" }
            return "On track"
        }
    }
    
    // Helper function to generate time-based greeting
    private func timeBasedGreeting(userName: String) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let displayName = userName.isEmpty ? "there" : userName
        
        switch hour {
        case 5..<12:
            return "Good Morning, \(displayName)"
        case 12..<17:
            return "Good Afternoon, \(displayName)"
        case 17..<21:
            return "Good Evening, \(displayName)"
        default:
            return "Good Night, \(displayName)"
        }
    }
    
    // Helper function to format minutes
    func formatMinutes(_ minutes: Int) -> String {
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
    
    // MARK: - App Blocking/Unblocking Methods
    
    private func handleUnblockApp(_ app: MonitoredApp) {
        appToUnblock = app
        showingUnblockConfirmation = true
    }
    
    private func handleConfirmUnblock() {
        guard let app = appToUnblock else { return }
        
        // Get bundleID from Core Data using app name
        let coreDataManager = CoreDataManager.shared
        let goals = coreDataManager.getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appName == app.name }),
              let bundleID = goal.appBundleID else {
            print("❌ Could not find bundle ID for app: \(app.name)")
            appToUnblock = nil
            showingUnblockConfirmation = false
            return
        }
        
        // Use ScreenTimeService to unblock with credit
        let success = ScreenTimeService.shared.unblockAppWithCredit(bundleID)
        
        if success {
            // Refresh app state
            appState.refreshData()
            HapticFeedback.success.trigger()
        } else {
            HapticFeedback.error.trigger()
        }
        
        // Reset state
        appToUnblock = nil
        showingUnblockConfirmation = false
    }
    
    private func showBlockedAppModal(appName: String, bundleID: String) {
        blockedAppName = appName
        blockedAppBundleID = bundleID
        withAnimation {
            showingBlockedAppModal = true
        }
    }
}

struct EmptyAppsView: View {
    let onAddApp: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.textPrimary.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("No apps being monitored")
                    .font(.h4)
                    .foregroundColor(.textPrimary)
                
                Text("Add apps to start tracking your usage")
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onAddApp) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Your First App")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.primary)
                .cornerRadius(25)
            }
        }
        .padding(32)
        .cardStyle()
    }
}

struct AddAppSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @State private var familySelection = FamilyActivitySelection()
    @State private var showingFamilyPicker = false
    @State private var selectedToken: AnyHashable?
    @State private var dailyLimit: Int = 60
    @State private var customLimit: String = ""
    @State private var showingCustomLimit = false
    @State private var showingConfirmation = false
    
    // Helper methods
    private func isLimitSelected(_ limit: Int) -> Bool {
        return dailyLimit == limit && !showingCustomLimit
    }
    
    // Computed properties for button styling
    private var customButtonTextColor: Color {
        showingCustomLimit ? .white : .primary
    }
    
    private var customButtonBackgroundColor: Color {
        showingCustomLimit ? Color.primary : Color.primary.opacity(0.1)
    }
    
    // Computed property for confirmation message
    private var confirmationMessage: String {
        // Get app name from token if available, otherwise use generic name
        let appName = selectedToken != nil ? "Selected App" : ""
        return "Are you sure you want to monitor \(appName)? This setting cannot be changed today once set."
    }
    
    // Computed property for add button text
    private var addButtonText: String {
        if selectedToken != nil {
            return "Add Selected App"
        } else {
            return "Select an App"
        }
    }
    
    let limitOptions = [30, 60, 90, 120, 180]
    
    // Helper view for token label - use Label(token) for real app icons
    @ViewBuilder
    private func tokenLabelView(token: AnyHashable) -> some View {
        // Try to cast token back to use with Label
        // Tokens from FamilyActivitySelection.applicationTokens work directly with Label
        if let allApps = screenTimeService.allAppsSelection {
            let realAppDiscovery = RealAppDiscoveryService.shared
            // Find matching token in selection
            if let matchingToken = allApps.applicationTokens.first(where: { t in
                guard let tokenBundleID = realAppDiscovery.extractBundleID(from: t),
                      let storedBundleID = realAppDiscovery.extractBundleID(from: token),
                      realAppDiscovery.isValidBundleID(tokenBundleID),
                      realAppDiscovery.isValidBundleID(storedBundleID) else {
                    return false
                }
                return tokenBundleID == storedBundleID
            }) {
                Label(matchingToken)
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 20, weight: .medium))
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
            }
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.blue)
        }
    }
    
    // Helper view for app token button to avoid type-checking timeout
    @ViewBuilder
    private func appTokenButton(token: AnyHashable) -> some View {
        let isSelected = selectedToken?.hashValue == token.hashValue
        let backgroundColor = isSelected ? Color.blue.opacity(0.1) : Color.cardBackground
        let strokeColor = isSelected ? Color.blue : Color.clear
        
        Button(action: {
            selectedToken = token
            HapticFeedback.light.trigger()
        }) {
            VStack(spacing: 12) {
                // Use token directly - tokens from FamilyActivitySelection are ApplicationToken
                // Cast to AnyHashable first, then back to ApplicationToken for Label
                tokenLabelView(token: token)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(strokeColor, lineWidth: 2)
            )
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Add App to Monitor")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    Text("Choose an app from your device and set a daily time limit")
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // App Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Select App")
                                .font(.h4)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 16) {
                                if !screenTimeService.isAuthorized {
                                    VStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.orange)
                                        
                                        Text("Screen Time authorization required")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.textPrimary)
                                        
                                        Text("Please authorize Screen Time access in Settings to add apps")
                                            .font(.system(size: 14))
                                            .foregroundColor(.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                } else if selectedToken == nil {
                                    VStack(spacing: 12) {
                                        Image(systemName: "apps.iphone")
                                            .font(.system(size: 32))
                                            .foregroundColor(.textSecondary.opacity(0.5))
                                        
                                        Text("No app selected")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.textPrimary)
                                        
                                        Text("Tap the button below to select an app from your device")
                                            .font(.system(size: 14))
                                            .foregroundColor(.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                } else if let token = selectedToken {
                                    // Show single selected app
                                    appTokenButton(token: token)
                                        .padding(.horizontal, 20)
                                }
                                
                                // Select App Button
                                Button(action: {
                                    showingFamilyPicker = true
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedToken == nil ? "plus.circle.fill" : "pencil.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                        
                                        Text(selectedToken == nil ? "Select App from Device" : "Change Selection")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                                .disabled(!screenTimeService.isAuthorized)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Time Limit Selection
                        if selectedToken != nil {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Daily Time Limit")
                                    .font(.h4)
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 20)
                                
                                VStack(spacing: 12) {
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                        ForEach(limitOptions, id: \.self) { limit in
                                            TimeLimitCard(
                                                minutes: limit,
                                                isSelected: isLimitSelected(limit)
                                            ) {
                                                dailyLimit = limit
                                                showingCustomLimit = false
                                                HapticFeedback.light.trigger()
                                            }
                                        }
                                    }
                                    
                                    // Custom limit option
                                    Button(action: {
                                        showingCustomLimit = true
                                        customLimit = "\(dailyLimit)"
                                    }) {
                                        HStack {
                                            Image(systemName: "slider.horizontal.3")
                                                .font(.system(size: 16, weight: .medium))
                                            Text("Custom Limit")
                                                .font(.system(size: 16, weight: .medium))
                                        }
                                        .foregroundColor(customButtonTextColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(customButtonBackgroundColor)
                                        .cornerRadius(12)
                                    }
                                    
                                    if showingCustomLimit {
                                        HStack {
                                            TextField("Minutes", text: $customLimit)
                                                .keyboardType(.numberPad)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .onChange(of: customLimit) { newValue in
                                                    if let minutes = Int(newValue), minutes > 0 {
                                                        dailyLimit = minutes
                                                    }
                                                }
                                            
                                            Text("minutes")
                                                .font(.bodyMedium)
                                                .foregroundColor(.textPrimary.opacity(0.7))
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
                
                // Add Button
                if selectedToken != nil {
                    VStack {
                        Button(action: { showingConfirmation = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(addButtonText)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary)
                            .cornerRadius(25)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(Color.appBackground)
                }
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFamilyPicker) {
                if screenTimeService.isAuthorized {
                    FamilyActivityPicker(selection: $familySelection)
                        .onChange(of: familySelection) { newSelection in
                            // Only take the FIRST app from selection (single app only)
                            if let firstToken = newSelection.applicationTokens.first {
                                selectedToken = firstToken as AnyHashable
                                // Close picker immediately after selecting one app
                            showingFamilyPicker = false
                            }
                        }
                }
            }
            .confirmationDialog("Confirm App Monitoring", isPresented: $showingConfirmation) {
                Button("Add App") {
                    addApp()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(confirmationMessage)
            }
        }
    }
    
    private func addApp() {
        guard let token = selectedToken else { return }
        
        // Create a selection with just this token
        // Find the matching token in familySelection (the one just selected)
        var appSelection = FamilyActivitySelection()
        for existingToken in familySelection.applicationTokens {
            if existingToken.hashValue == token.hashValue {
                appSelection.applicationTokens = [existingToken]
                break
            }
        }
        
        // If not found in familySelection, try allAppsSelection as fallback
        if appSelection.applicationTokens.isEmpty,
           let currentSelection = screenTimeService.allAppsSelection {
            for existingToken in currentSelection.applicationTokens {
                if existingToken.hashValue == token.hashValue {
                    appSelection.applicationTokens = [existingToken]
                    break
                }
            }
        }
        
        // Get display name from token (this always works)
        // We don't need bundle ID - we'll use a stable internal ID
        let realAppDiscovery = RealAppDiscoveryService.shared
        let displayName = realAppDiscovery.extractDisplayName(from: token)
        
        // Generate stable internal ID from app name (not from bundle ID)
        // This is what we'll use for storage and monitoring
        let stableID = "app.name.\(displayName.lowercased().replacingOccurrences(of: " ", with: "."))"
        
        // Use addAppGoalFromFamilySelection which handles tokens properly
        appState.addAppGoalFromFamilySelection(
            appSelection,
            appName: displayName,
            dailyLimitMinutes: dailyLimit,
            bundleID: stableID
        )
        
        print("✅ Added app with \(dailyLimit) minute limit")
        
        HapticFeedback.success.trigger()
        dismiss()
    }
}

struct RealAppSelectionCard: View {
    let app: InstalledApp
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(app.color).opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    if let icon = app.icon {
                        Image(uiImage: icon)
                            .resizable()
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Image(systemName: app.iconName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(app.color))
                    }
                }
                
                Text(app.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.primary.opacity(0.1) : Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct AppSelectionCard: View {
    let appName: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(appName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.primary.opacity(0.1) : Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct TimeLimitCard: View {
    let minutes: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? .white : .textPrimary)
                
                Text("min")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .textPrimary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.primary : Color.cardBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Compact Streak View for Toolbar

struct CompactStreakView: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(streakColor.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Image(systemName: streakIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(streakColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("\(streak)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                Text("streak")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.appBackground)
        .cornerRadius(8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground.opacity(0.8))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private var streakColor: Color {
        switch streak {
        case 0:
            return .gray
        case 1...2:
            return .green
        case 3...6:
            return .orange
        case 7...13:
            return .red
        case 14...29:
            return .purple
        case 30...99:
            return .blue
        default:
            return .yellow
        }
    }
    
    private var streakIcon: String {
        switch streak {
        case 0:
            return "minus.circle.fill"
        case 1...2:
            return "checkmark.circle.fill"
        case 3...6:
            return "flame.fill"
        case 7...13:
            return "flame.fill"
        case 14...29:
            return "crown.fill"
        case 30...99:
            return "star.circle.fill"
        default:
            return "trophy.fill"
        }
    }
}

// MARK: - Date History Picker

struct DateHistoryPicker: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    let appState: AppState
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Health History")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Text("View your pet's health on different days")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            // Show last 30 days
                            ForEach((0..<30).reversed(), id: \.self) { daysAgo in
                                let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
                                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                                let healthData = getHealthData(for: date)
                                
                                Button(action: {
                                    selectedDate = date
                                    isPresented = false
                                }) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.textPrimary)
                                            
                                            Text(dayName(date))
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Health indicator
                                        VStack(alignment: .trailing, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "heart.fill")
                                                    .font(.system(size: 12, weight: .semibold))
                                                Text("\(healthData.score)")
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            .foregroundColor(healthData.color)
                                            
                                            Text(healthData.status)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.textSecondary)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.textSecondary.opacity(0.5))
                                    }
                                    .padding(16)
                                    .background(isSelected ? Color.blue.opacity(0.1) : Color.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    
                    // Close button
                    Button(action: { isPresented = false }) {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func getHealthData(for date: Date) -> (score: Int, color: Color, status: String) {
        // Calculate health score based on actual pet health data
        let isToday = Calendar.current.isDateInToday(date)
        
        if isToday {
            // Use current pet health for today
            if let pet = appState.userPet {
                let healthPercentage = appState.calculatePetHealthPercentage()
                let healthState = pet.healthState
                
                let score: Int
                let color: Color
                let status: String
                
                switch healthState {
                case .fullHealth:
                    score = healthPercentage
                    color = .green
                    status = "Full Health"
                case .happy:
                    score = healthPercentage
                    color = Color(red: 0.5, green: 0.85, blue: 0.7)
                    status = "Happy"
                case .content:
                    score = healthPercentage
                    color = .yellow
                    status = "Content"
                case .sad:
                    score = healthPercentage
                    color = .orange
                    status = "Sad"
                case .sick:
                    score = healthPercentage
                    color = .red
                    status = "Sick"
                }
                
                return (score, color, status)
            }
        }
        
        // For past dates, we don't have historical health data
        // Return "No data" indication
        return (0, .gray, "No data")
    }
    
}


