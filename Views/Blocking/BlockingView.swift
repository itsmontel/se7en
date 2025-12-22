import SwiftUI
import FamilyControls
import ManagedSettings

// MARK: - Blocked Apps Manager

/// Manages the list of blocked apps and unblock state
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
        
        // Schedule re-block
        scheduleReblock()
        
        print("✅ Unblock granted for \(unblockDurationMinutes) minutes until \(unblockUntilString)")
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
    
    let unblockDurationOptions = [5, 10, 15, 30, 60]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Current Status Card
                        statusCard
                        
                        // Blocked Apps Section
                        blockedAppsSection
                        
                        // Settings Section
                        settingsSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Limits")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAppPicker) {
                NavigationStack {
                    FamilyActivityPicker(selection: $tempSelection)
                        .navigationTitle("Select Apps to Block")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    // Reset to original selection
                                    tempSelection = blockedAppsManager.blockedSelection
                                    showingAppPicker = false
                                }
                                .foregroundColor(.primary)
                            }
                            
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    // Save the selection
                                    if !tempSelection.applicationTokens.isEmpty || !tempSelection.categoryTokens.isEmpty {
                                        blockedAppsManager.updateBlockedApps(tempSelection)
                                        HapticFeedback.success.trigger()
                                    }
                                    showingAppPicker = false
                                }
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                            }
                        }
                }
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
            }
            .onDisappear {
                stopRefreshTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                blockedAppsManager.loadState()
                blockedAppsManager.checkAndReblock()
            }
        }
    }
    
    // MARK: - Timer for UI Updates
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Force UI refresh for countdown
            blockedAppsManager.objectWillChange.send()
            
            // Check if unblock period expired
            blockedAppsManager.checkAndReblock()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.2), Color.red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("App Blocking")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("Select apps to block • Solve puzzles to unblock")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        VStack(spacing: 16) {
            if blockedAppsManager.blockedCount == 0 {
                // No apps blocked
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.green)
                    
                    Text("No Apps Blocked")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text("Select apps below to start blocking them")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
            } else if blockedAppsManager.isCurrentlyUnblocked {
                // Currently unblocked
                VStack(spacing: 12) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.green)
                    
                    Text("Apps Unblocked")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("Until \(blockedAppsManager.unblockUntilString)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    // Countdown
                    Text(blockedAppsManager.timeRemainingString)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    
                    Text("remaining")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding(.vertical, 24)
            } else {
                // Apps are blocked
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.red)
                    
                    Text("\(blockedAppsManager.blockedCount) Apps Blocked")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text("Solve a puzzle to temporarily unblock")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                    
                    // Unblock Button
                    Button(action: {
                        showingPuzzle = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "puzzlepiece.fill")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("Solve Puzzle to Unblock")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Blocked Apps Section
    
    private var blockedAppsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Blocked Apps")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if blockedAppsManager.blockedCount > 0 {
                    Text("\(blockedAppsManager.blockedCount) selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            
            // App selection button
            Button(action: {
                tempSelection = blockedAppsManager.blockedSelection
                showingAppPicker = true
            }) {
                HStack(spacing: 14) {
                    Image(systemName: blockedAppsManager.blockedCount > 0 ? "pencil.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                    
                    Text(blockedAppsManager.blockedCount > 0 ? "Edit Blocked Apps" : "Select Apps to Block")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.red, .red.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            
            // Show selected apps preview
            if blockedAppsManager.blockedCount > 0 {
                VStack(spacing: 12) {
                    // Apps
                    ForEach(Array(blockedAppsManager.blockedSelection.applicationTokens.prefix(5)), id: \.self) { token in
                        HStack(spacing: 12) {
                            Label(token)
                                .labelStyle(.iconOnly)
                                .scaleEffect(1.5)
                                .frame(width: 40, height: 40)
                            
                            Label(token)
                                .labelStyle(.titleOnly)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textPrimary)
                            
                            Spacer()
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                    }
                    
                    // Categories
                    ForEach(Array(blockedAppsManager.blockedSelection.categoryTokens.prefix(3)), id: \.self) { token in
                        HStack(spacing: 12) {
                            Label(token)
                                .labelStyle(.iconOnly)
                                .scaleEffect(1.5)
                                .frame(width: 40, height: 40)
                            
                            Label(token)
                                .labelStyle(.titleOnly)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textPrimary)
                            
                            Spacer()
                            
                            Text("Category")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(6)
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                    }
                    
                    // Show more indicator
                    let totalCount = blockedAppsManager.blockedSelection.applicationTokens.count + blockedAppsManager.blockedSelection.categoryTokens.count
                    if totalCount > 8 {
                        Text("+ \(totalCount - 8) more")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Clear all button
            if blockedAppsManager.blockedCount > 0 {
                Button(action: {
                    withAnimation {
                        blockedAppsManager.updateBlockedApps(FamilyActivitySelection())
                        tempSelection = FamilyActivitySelection()
                    }
                    HapticFeedback.medium.trigger()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 16, weight: .medium))
                        Text("Clear All Blocked Apps")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Unblock Duration Setting
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text("Unblock Duration")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text("\(blockedAppsManager.unblockDurationMinutes) min")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    Text("How long apps stay unblocked after solving a puzzle")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                    
                    // Duration options
                    HStack(spacing: 8) {
                        ForEach(unblockDurationOptions, id: \.self) { minutes in
                            Button(action: {
                                blockedAppsManager.setUnblockDuration(minutes)
                                HapticFeedback.light.trigger()
                            }) {
                                Text("\(minutes)m")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(blockedAppsManager.unblockDurationMinutes == minutes ? .white : .textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        blockedAppsManager.unblockDurationMinutes == minutes ?
                                        Color.blue :
                                        Color.cardBackground
                                    )
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appBackground)
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                )
            }
            .padding(.horizontal, 20)
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
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            if showPuzzle {
                puzzleView
            } else {
                startView
            }
        }
    }
    
    private var startView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(.red)
                
                Text("Apps Are Blocked")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Solve a puzzle to temporarily unblock your apps")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
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
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
                
                Button(action: {
                    onDismiss()
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
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
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
