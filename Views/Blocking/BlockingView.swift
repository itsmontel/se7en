import SwiftUI
import FamilyControls
import ManagedSettings

// MARK: - Blocked Apps Manager

/// Manages the list of blocked apps and unblock state
@MainActor
class BlockedAppsManager: ObservableObject {
    static let shared = BlockedAppsManager()
    
    private let appGroupID = "group.com.se7en.app"
    private let store = ManagedSettingsStore()
    
    @Published var blockedSelection: FamilyActivitySelection = FamilyActivitySelection()
    @Published var unblockUntil: Date? = nil
    @Published var unblockDurationMinutes: Int = 15
    
    var isCurrentlyUnblocked: Bool {
        guard let until = unblockUntil else { return false }
        return Date() < until
    }
    
    var timeRemainingString: String {
        guard let until = unblockUntil, Date() < until else { return "" }
        let remaining = until.timeIntervalSince(Date())
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var unblockUntilString: String {
        guard let until = unblockUntil else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: until)
    }
    
    init() {
        loadState()
    }
    
    // MARK: - Persistence
    
    func loadState() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.synchronize()
        
        // Load blocked selection
        if let data = defaults.data(forKey: "blocked_apps_selection"),
           let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            blockedSelection = selection
        }
        
        // Load unblock until time
        let unblockTimestamp = defaults.double(forKey: "unblock_until")
        if unblockTimestamp > 0 {
            let until = Date(timeIntervalSince1970: unblockTimestamp)
            if until > Date() {
                unblockUntil = until
            } else {
                // Expired - clear it
                unblockUntil = nil
                defaults.removeObject(forKey: "unblock_until")
            }
        }
        
        // Load unblock duration setting
        let savedDuration = defaults.integer(forKey: "unblock_duration_minutes")
        if savedDuration > 0 {
            unblockDurationMinutes = savedDuration
        }
        
        // Apply shields if needed
        applyBlockingState()
    }
    
    func saveState() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // Save blocked selection
        if let data = try? PropertyListEncoder().encode(blockedSelection) {
            defaults.set(data, forKey: "blocked_apps_selection")
        }
        
        // Save unblock until time
        if let until = unblockUntil {
            defaults.set(until.timeIntervalSince1970, forKey: "unblock_until")
        } else {
            defaults.removeObject(forKey: "unblock_until")
        }
        
        // Save unblock duration
        defaults.set(unblockDurationMinutes, forKey: "unblock_duration_minutes")
        
        defaults.synchronize()
    }
    
    // MARK: - Blocking Logic
    
    /// Update blocked apps selection - immediately blocks selected apps
    func updateBlockedApps(_ selection: FamilyActivitySelection) {
        blockedSelection = selection
        saveState()
        applyBlockingState()
        
        // Track blocked apps status for streak calculation
        let hasBlockedApps = blockedCount > 0
        CoreDataManager.shared.markBlockedAppsStatus(hasBlockedApps: hasBlockedApps)
    }
    
    /// Apply shields based on current state
    func applyBlockingState() {
        let hasApps = !blockedSelection.applicationTokens.isEmpty || !blockedSelection.categoryTokens.isEmpty
        
        if !hasApps {
            // No apps to block - clear shields
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            print("🔓 No apps selected - shields cleared")
            return
        }
        
        if isCurrentlyUnblocked {
            // Currently in unblock period - remove shields
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            print("🔓 Unblock period active until \(unblockUntilString) - shields removed")
        } else {
            // Block the apps
            store.shield.applications = blockedSelection.applicationTokens
            if !blockedSelection.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(blockedSelection.categoryTokens)
            }
            print("🔒 Apps blocked: \(blockedSelection.applicationTokens.count) apps, \(blockedSelection.categoryTokens.count) categories")
        }
    }
    
    /// Grant temporary unblock after puzzle completion
    func grantUnblock() {
        let duration = TimeInterval(unblockDurationMinutes * 60)
        unblockUntil = Date().addingTimeInterval(duration)
        saveState()
        applyBlockingState()
        
        // Track puzzle solved
        trackPuzzleSolved()
        
        // Schedule re-block
        scheduleReblock()
        
        print("✅ Unblock granted for \(unblockDurationMinutes) minutes until \(unblockUntilString)")
    }
    
    /// Track that a puzzle was solved today
    private func trackPuzzleSolved() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())
        
        // Get existing puzzle history
        var puzzleHistory = defaults.dictionary(forKey: "daily_puzzles_solved") as? [String: Int] ?? [:]
        
        // Increment today's count
        puzzleHistory[todayKey] = (puzzleHistory[todayKey] ?? 0) + 1
        
        // Save updated history
        defaults.set(puzzleHistory, forKey: "daily_puzzles_solved")
        defaults.synchronize()
        
        print("🧩 Puzzle solved! Today's count: \(puzzleHistory[todayKey] ?? 1)")
    }
    
    /// Schedule automatic re-blocking when unblock period expires
    private func scheduleReblock() {
        guard let until = unblockUntil else { return }
        let delay = until.timeIntervalSince(Date())
        guard delay > 0 else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.checkAndReblock()
        }
    }
    
    /// Check if unblock period expired and re-apply blocks
    func checkAndReblock() {
        if let until = unblockUntil, Date() >= until {
            unblockUntil = nil
            saveState()
            applyBlockingState()
            print("⏰ Unblock period expired - apps re-blocked")
        }
    }
    
    /// Set unblock duration preference
    func setUnblockDuration(_ minutes: Int) {
        unblockDurationMinutes = minutes
        saveState()
    }
    
    /// Get count of blocked items
    var blockedCount: Int {
        blockedSelection.applicationTokens.count + blockedSelection.categoryTokens.count
    }
}

// MARK: - Blocking View

struct BlockingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var blockedAppsManager = BlockedAppsManager.shared
    @State private var showingAppPicker = false
    @State private var tempSelection = FamilyActivitySelection()
    @State private var showingPuzzle = false
    @State private var showingSettings = false
    @State private var refreshTimer: Timer?
    @State private var pulseAnimation = false
    @State private var showingRemoveAllConfirmation = false
    
    let unblockDurationOptions = [5, 10, 15, 30, 60]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                backgroundGradient
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Status Card (Hero section)
                        statusCard
                            .padding(.top, 8)
                        
                        // Quick Actions
                        if blockedAppsManager.blockedCount > 0 && !blockedAppsManager.isCurrentlyUnblocked {
                            puzzleButton
                        }
                        
                        // Blocked Apps Section
                        blockedAppsSection
                        
                        // Duration Settings
                        durationSettingsCard
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Focus Mode")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.textPrimary)
                }
            }
            .sheet(isPresented: $showingAppPicker) {
                NavigationStack {
                    FamilyActivityPicker(selection: $tempSelection)
                        .navigationTitle("Select Apps")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    tempSelection = blockedAppsManager.blockedSelection
                                    showingAppPicker = false
                                }
                                .foregroundColor(.textSecondary)
                            }
                            
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    blockedAppsManager.updateBlockedApps(tempSelection)
                                    showingAppPicker = false
                                    HapticFeedback.success.trigger()
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.blue)
                            }
                        }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showingPuzzle) {
                UnblockPuzzleView(
                    onComplete: {
                        blockedAppsManager.grantUnblock()
                        showingPuzzle = false
                        HapticFeedback.success.trigger()
                    },
                    onDismiss: {
                        showingPuzzle = false
                    }
                )
            }
            .onAppear {
                tempSelection = blockedAppsManager.blockedSelection
                startRefreshTimer()
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
            .onDisappear {
                stopRefreshTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                blockedAppsManager.loadState()
                blockedAppsManager.checkAndReblock()
            }
            .alert("Remove All Blocked Apps?", isPresented: $showingRemoveAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove All", role: .destructive) {
                    removeAllBlocks()
                }
            } message: {
                if appState.currentStreak > 0 {
                    Text("If you have no blocked apps by the end of the day, your \(appState.currentStreak)-day streak will be lost.")
                } else {
                    Text("This will unblock all selected apps.")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func removeAllBlocks() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            blockedAppsManager.updateBlockedApps(FamilyActivitySelection())
            tempSelection = FamilyActivitySelection()
        }
        HapticFeedback.medium.trigger()
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            // Subtle gradient overlay
            if blockedAppsManager.isCurrentlyUnblocked {
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            } else if blockedAppsManager.blockedCount > 0 {
                LinearGradient(
                    colors: [
                        Color.red.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Timer
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            blockedAppsManager.objectWillChange.send()
            blockedAppsManager.checkAndReblock()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        VStack(spacing: 0) {
            if blockedAppsManager.blockedCount == 0 {
                emptyStateCard
            } else if blockedAppsManager.isCurrentlyUnblocked {
                unlockedStateCard
            } else {
                lockedStateCard
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
        )
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            // Icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "shield.checkered")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Focus Mode")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("Block distracting apps and stay focused.\nSolve a puzzle when you need a break.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Add apps button
            Button(action: {
                tempSelection = blockedAppsManager.blockedSelection
                showingAppPicker = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                    Text("Select Apps to Block")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .padding(.top, 8)
        }
        .padding(28)
    }
    
    private var unlockedStateCard: some View {
        VStack(spacing: 24) {
            // Animated unlock icon
            ZStack {
                // Pulsing glow
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                Text("Apps Unblocked")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                // Countdown timer
                Text(blockedAppsManager.timeRemainingString)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundColor(.textPrimary)
                
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text("Blocking resumes at \(blockedAppsManager.unblockUntilString)")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.textSecondary)
            }
        }
        .padding(32)
    }
    
    private var lockedStateCard: some View {
        VStack(spacing: 20) {
            // Lock icon with count badge
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.red.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.red)
                }
                
                // Count badge
                Text("\(blockedAppsManager.blockedCount)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.red)
                            .shadow(color: Color.red.opacity(0.4), radius: 4, x: 0, y: 2)
                    )
                    .offset(x: 8, y: -4)
            }
            
            VStack(spacing: 8) {
                Text("Focus Mode Active")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("\(blockedAppsManager.blockedCount) \(blockedAppsManager.blockedCount == 1 ? "app" : "apps") blocked")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(32)
    }
    
    // MARK: - Puzzle Button
    
    private var puzzleButton: some View {
        Button(action: {
            showingPuzzle = true
            HapticFeedback.medium.trigger()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "puzzlepiece.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Need a Break?")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Solve puzzle for \(blockedAppsManager.unblockDurationMinutes) min access")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.4, green: 0.3, blue: 0.9),
                        Color(red: 0.6, green: 0.3, blue: 0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(18)
            .shadow(color: Color(red: 0.5, green: 0.3, blue: 0.85).opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
    
    // MARK: - Blocked Apps Section
    
    private var blockedAppsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("Blocked Apps")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button(action: {
                    tempSelection = blockedAppsManager.blockedSelection
                    showingAppPicker = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: blockedAppsManager.blockedCount > 0 ? "pencil" : "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text(blockedAppsManager.blockedCount > 0 ? "Edit" : "Add")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(20)
                }
            }
            
            if blockedAppsManager.blockedCount == 0 {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "app.badge.checkmark")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.textSecondary.opacity(0.5))
                        
                        Text("No apps blocked yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardBackground)
                )
            } else {
                // Apps list
                VStack(spacing: 1) {
                    // Individual apps (show first 6)
                    ForEach(Array(blockedAppsManager.blockedSelection.applicationTokens.prefix(6)), id: \.self) { token in
                        AppRow(token: token, isCategory: false)
                    }
                    
                    // Categories
                    ForEach(Array(blockedAppsManager.blockedSelection.categoryTokens.prefix(3)), id: \.self) { token in
                        CategoryRow(token: token)
                    }
                    
                    // Show more row
                    let totalVisible = min(6, blockedAppsManager.blockedSelection.applicationTokens.count) +
                                       min(3, blockedAppsManager.blockedSelection.categoryTokens.count)
                    let remaining = blockedAppsManager.blockedCount - totalVisible
                    
                    if remaining > 0 {
                        HStack {
                            Text("+ \(remaining) more")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.cardBackground)
                        .onTapGesture {
                            tempSelection = blockedAppsManager.blockedSelection
                            showingAppPicker = true
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Clear all button
                Button(action: {
                    // Show confirmation if user has a streak
                    if appState.currentStreak > 0 {
                        showingRemoveAllConfirmation = true
                    } else {
                        removeAllBlocks()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 14, weight: .medium))
                        Text("Remove All")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.08))
                    )
                }
            }
        }
    }
    
    // MARK: - Duration Settings
    
    private var durationSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text("Unblock Duration")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            Text("How long apps stay unblocked after completing a puzzle")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textSecondary)
                .lineSpacing(2)
            
            // Duration pills
            HStack(spacing: 10) {
                ForEach(unblockDurationOptions, id: \.self) { minutes in
                    DurationPill(
                        minutes: minutes,
                        isSelected: blockedAppsManager.unblockDurationMinutes == minutes,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                blockedAppsManager.setUnblockDuration(minutes)
                            }
                            HapticFeedback.light.trigger()
                        }
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Supporting Views

struct AppRow: View {
    let token: ApplicationToken
    let isCategory: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            // App icon
            Label(token)
                .labelStyle(.iconOnly)
                .scaleEffect(1.4)
                .frame(width: 40, height: 40)
            
            // App name
            Label(token)
                .labelStyle(.titleOnly)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            // Blocked indicator
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.red.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct CategoryRow: View {
    let token: ActivityCategoryToken
    
    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Label(token)
                    .labelStyle(.iconOnly)
                    .scaleEffect(1.2)
            }
            
            // Category name
            Label(token)
                .labelStyle(.titleOnly)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            // Category badge
            Text("Category")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.12))
                )
            
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.red.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct DurationPill: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(minutes)m")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : .textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        } else {
                            Color.appBackground
                        }
                    }
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color.textSecondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Unblock Puzzle View

struct UnblockPuzzleView: View {
    let onComplete: () -> Void
    let onDismiss: () -> Void
    
    @StateObject private var puzzleManager = PuzzleManager.shared
    @State private var selectedPuzzleType: PuzzleType?
    @State private var showPuzzle = false
    @State private var currentSudokuPuzzle: SudokuPuzzle?
    @State private var currentMemoryGame: MemoryGame?
    @State private var currentPatternSequence: PatternSequence?
    @State private var currentJigsawPuzzle: JigsawPuzzle?
    @State private var appearAnimation = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.92)
                .ignoresSafeArea()
            
            if showPuzzle {
                puzzleView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                startView
                    .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }
    
    private var startView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon and title
            VStack(spacing: 28) {
                ZStack {
                    // Glow rings
                    Circle()
                        .stroke(Color.red.opacity(0.1), lineWidth: 40)
                        .frame(width: 160, height: 160)
                        .scaleEffect(appearAnimation ? 1 : 0.5)
                    
                    Circle()
                        .stroke(Color.red.opacity(0.2), lineWidth: 20)
                        .frame(width: 120, height: 120)
                        .scaleEffect(appearAnimation ? 1 : 0.7)
                    
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
                .opacity(appearAnimation ? 1 : 0)
                
                VStack(spacing: 12) {
                    Text("Apps Are Blocked")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Complete a quick puzzle to\ntemporarily unblock your apps")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
            }
            
            Spacer()
            
            // Buttons
            VStack(spacing: 16) {
                Button(action: {
                    startRandomPuzzle()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.fill")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Start Puzzle")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.3, blue: 0.9),
                                Color(red: 0.6, green: 0.3, blue: 0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color(red: 0.5, green: 0.3, blue: 0.85).opacity(0.5), radius: 20, x: 0, y: 10)
                }
                
                Button(action: {
                    onDismiss()
                }) {
                    Text("Stay Focused")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 50)
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 30)
        }
    }
    
    @ViewBuilder
    private var puzzleView: some View {
        if let puzzleType = selectedPuzzleType {
            Group {
                switch puzzleType {
                case .sudoku:
                    if let puzzle = currentSudokuPuzzle {
                        SudokuView(
                            puzzle: puzzle,
                            onComplete: { handlePuzzleComplete() },
                            onDismiss: { showPuzzle = false }
                        )
                    }
                case .memory:
                    if let game = currentMemoryGame {
                        MemoryGameView(
                            game: game,
                            onComplete: { handlePuzzleComplete() },
                            onDismiss: { showPuzzle = false }
                        )
                    }
                case .pattern:
                    if let sequence = currentPatternSequence {
                        PatternGameView(
                            sequence: sequence,
                            onComplete: { handlePuzzleComplete() },
                            onDismiss: { showPuzzle = false }
                        )
                    }
                case .jigsaw:
                    if let puzzle = currentJigsawPuzzle {
                        JigsawPuzzleView(
                            puzzle: puzzle,
                            onComplete: { handlePuzzleComplete() },
                            onDismiss: { showPuzzle = false }
                        )
                    }
                }
            }
        }
    }
    
    private func startRandomPuzzle() {
        selectedPuzzleType = puzzleManager.selectRandomPuzzle()
        
        if let puzzleType = selectedPuzzleType {
            switch puzzleType {
            case .sudoku:
                currentSudokuPuzzle = SudokuPuzzle.generate()
            case .memory:
                currentMemoryGame = MemoryGame.generate()
            case .pattern:
                currentPatternSequence = PatternSequence.generate(length: 6)
            case .jigsaw:
                currentJigsawPuzzle = JigsawPuzzle.generate()
            }
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showPuzzle = true
        }
    }
    
    private func handlePuzzleComplete() {
        HapticFeedback.success.trigger()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
}

// MARK: - Preview

struct BlockingView_Previews: PreviewProvider {
    static var previews: some View {
        BlockingView()
            .environmentObject(AppState())
    }
}
