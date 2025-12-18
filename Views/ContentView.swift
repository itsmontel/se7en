import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPuzzleMode = false
    @State private var puzzleAppName = ""
    @State private var puzzleTokenHash = ""
    
    var body: some View {
        ZStack {
            // Main app content (always visible in background)
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingContainerView()
            }
            
            // Puzzle overlay (shown on top when puzzle mode is active)
            if showPuzzleMode {
                FullscreenPuzzleView(
                    appName: puzzleAppName,
                    tokenHash: puzzleTokenHash,
                    onComplete: {
                        handlePuzzleComplete()
                    },
                    onDismiss: {
                        showPuzzleMode = false
                    }
                )
                .environmentObject(appState)
                .transition(.opacity)
            }
        }
        .environment(\.textCase, .none)
        .onAppear {
            checkPuzzleMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // ✅ FIX: Check for puzzle mode when app becomes active (handles shield action opening app)
            checkPuzzleMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // ✅ FIX: Also check when app enters foreground (covers all cases)
            checkPuzzleMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appBlocked)) { notification in
            // Check if this is puzzle mode
            if let userInfo = notification.userInfo,
               userInfo["puzzleMode"] as? Bool == true {
                checkPuzzleMode()
            }
        }
    }
    
    private func checkPuzzleMode() {
        let appGroupID = "group.com.se7en.app"
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // ✅ Check if puzzle mode is requested
        if defaults.bool(forKey: "puzzleMode") {
            if let tokenHash = defaults.string(forKey: "puzzleTokenHash") {
                // Get app name (use stored name or default)
                let appName = defaults.string(forKey: "puzzleAppName_\(tokenHash)") ?? "App"
                
            puzzleAppName = appName
            puzzleTokenHash = tokenHash
            showPuzzleMode = true
            
                // ✅ Clear the puzzle mode flag immediately
            defaults.set(false, forKey: "puzzleMode")
                defaults.removeObject(forKey: "shouldOpenPuzzle")
            defaults.synchronize()
                
                print("✅ ContentView: Entering puzzle mode for \(appName)")
            }
        }
    }
    
    private func handlePuzzleComplete() {
        let appGroupID = "group.com.se7en.app"
        
        // ✅ CRITICAL: Grant extension with proper usage reset
        grantPuzzleExtension(for: puzzleTokenHash, appName: puzzleAppName, minutes: 15)
        
        // ✅ CRITICAL: Reload app goals to update UI immediately
        appState.loadAppGoals()
        
        // Hide puzzle mode
        showPuzzleMode = false
        
        // ✅ Notify the system that data has changed
        NotificationCenter.default.post(name: .screenTimeDataUpdated, object: nil)
        
        // Open the blocked app after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            openBlockedApp()
        }
    }
    
    /// ✅ NEW: Comprehensive extension granting that properly resets usage
    private func grantPuzzleExtension(for tokenHash: String, appName: String, minutes: Int) {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // 1. Calculate extension end time
        let extensionEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        
        // 2. Store extension in shared container (so extensions can see it)
        sharedDefaults.set(extensionEndTime.timeIntervalSince1970, forKey: "extension_end_\(tokenHash)")
        sharedDefaults.set(true, forKey: "hasActiveExtension_\(tokenHash)")
        
        // ✅ 3. CRITICAL: Reset usage to 0 in shared container
        sharedDefaults.set(0, forKey: "usage_\(tokenHash)")
        
        // ✅ 4. CRITICAL: Update per_app_usage to show 0 for this app
        if var perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int] {
            perAppUsage[appName] = 0
            sharedDefaults.set(perAppUsage, forKey: "per_app_usage")
        }
        
        // ✅ 5. CRITICAL: Store the extension limit (15 minutes) as the NEW effective limit
        sharedDefaults.set(minutes, forKey: "extensionLimit_\(tokenHash)")
        
        // ✅ 6. Clear limit reached flag so it doesn't re-block
        sharedDefaults.set(false, forKey: "limitReached_\(tokenHash)")
        sharedDefaults.removeObject(forKey: "needsPuzzle_\(tokenHash)")
        
        // ✅ 7. Store extension grant time for reference
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "extensionGrantTime_\(tokenHash)")
        
        sharedDefaults.synchronize()
        
        print("✅ Extension granted: \(minutes) minutes for \(tokenHash)")
        print("   - Usage reset to 0")
        print("   - Extension ends at \(extensionEndTime)")
        
        // 8. Also call ScreenTimeService to unblock and update CoreData
        ScreenTimeService.shared.grantTemporaryExtension(for: tokenHash, minutes: minutes)
    }
    
    private func openBlockedApp() {
        // Try to open via URL scheme
        let urlSchemes: [String: String] = [
            "YouTube": "youtube://",
            "Instagram": "instagram://",
            "TikTok": "tiktok://",
            "Twitter": "twitter://",
            "X": "twitter://",
            "Snapchat": "snapchat://",
            "Facebook": "fb://",
            "WhatsApp": "whatsapp://",
            "Telegram": "tg://",
            "Reddit": "reddit://",
            "Spotify": "spotify://",
            "Netflix": "nflx://"
        ]
        
        if let scheme = urlSchemes[puzzleAppName],
           let url = URL(string: scheme),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("✅ Opened \(puzzleAppName) after puzzle completion")
                }
            }
        } else {
            print("ℹ️ No URL scheme for \(puzzleAppName), app is unblocked")
        }
    }
}

// MARK: - Fullscreen Puzzle View (inline to avoid target membership issues)

struct FullscreenPuzzleView: View {
    let appName: String
    let tokenHash: String
    let onComplete: () -> Void
    var onDismiss: (() -> Void)? = nil
    
    @EnvironmentObject var appState: AppState
    @StateObject private var puzzleManager = PuzzleManager.shared
    @State private var selectedPuzzleType: PuzzleType?
    @State private var showPuzzle = false
    @State private var puzzleStartTime: Date?
    @State private var currentSudokuPuzzle: SudokuPuzzle?
    @State private var currentMemoryGame: MemoryGame?
    @State private var currentPatternSequence: PatternSequence?
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't allow dismissing by tapping outside
                }
            
            if showPuzzle {
                // Show puzzle
                puzzleView
            } else {
                // Show limit reached message
                limitReachedView
            }
        }
    }
    
    private var limitReachedView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.pink)
                        .padding(.top, 28)
                    
                    Text("Daily Limit Reached")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .textCase(.none)
                    
                    VStack(spacing: 4) {
                        Text("That's okay, it happens 😊")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.textSecondary)
                        
                        Text("You've reached your limit for **\(appName)**")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
                
                Divider()
                    .padding(.horizontal, 0)
                
                // Puzzle option
                VStack(spacing: 16) {
                    Text("Solve a puzzle to earn 15 more minutes")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                        .padding(.horizontal, 24)
                    
                    Button(action: {
                        HapticFeedback.medium.trigger()
                        startRandomPuzzle()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "puzzlepiece.fill")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("Start Puzzle")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.primary, Color.primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.primary.opacity(0.25), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal, 24)
                    
                    Text("You can solve puzzles multiple times")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.textSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)
                }
                .padding(.bottom, 20)
                
                Divider()
                    .padding(.horizontal, 0)
                
                // Cancel button
                Button(action: {
                    HapticFeedback.light.trigger()
                    // Dismiss without granting extension
                    onDismiss?()
                }) {
                    Text("I CAN WAIT TILL TOMORROW")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 500)
            .background(Color.cardBackground)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 15)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
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
                            onComplete: {
                                handlePuzzleComplete(puzzleType: puzzleType)
                            },
                            onDismiss: {
                                showPuzzle = false
                            }
                        )
                    }
                case .memory:
                    if let game = currentMemoryGame {
                        MemoryGameView(
                            game: game,
                            onComplete: {
                                handlePuzzleComplete(puzzleType: puzzleType)
                            },
                            onDismiss: {
                                showPuzzle = false
                            }
                        )
                    }
                case .pattern:
                    if let sequence = currentPatternSequence {
                        PatternGameView(
                            sequence: sequence,
                            onComplete: {
                                handlePuzzleComplete(puzzleType: puzzleType)
                            },
                            onDismiss: {
                                showPuzzle = false
                            }
                        )
                    }
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func startRandomPuzzle() {
        selectedPuzzleType = puzzleManager.selectRandomPuzzle()
        puzzleStartTime = Date()
        
        // Generate puzzles once and store them
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
    
    private func handlePuzzleComplete(puzzleType: PuzzleType) {
        // Grant extension
        puzzleManager.grantExtension(for: tokenHash, puzzleType: puzzleType)
        
        // Unblock the app temporarily (15 minutes)
        ScreenTimeService.shared.grantTemporaryExtension(for: tokenHash, minutes: 15)
        
        // Show success
        HapticFeedback.success.trigger()
        
        // Call completion handler (will open blocked app)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onComplete()
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    VStack {
                        Image(systemName: "house.fill")
                        Text("Home")
                            .textCase(.none)
                    }
                }
                .tag(0)
            
            BlockingView()
                .tabItem {
                    VStack {
                        Image(systemName: "hand.raised.fill")
                        Text("Limits")
                            .textCase(.none)
                    }
                }
                .tag(1)
            
            GoalsView()
                .tabItem {
                    VStack {
                        Image(systemName: "chart.bar.fill")
                        Text("Stats")
                            .textCase(.none)
                    }
                }
                .tag(2)
            
            AchievementsView()
                .tabItem {
                    VStack {
                        Image(systemName: "trophy.fill")
                        Text("Achievements")
                            .textCase(.none)
                    }
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    VStack {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                            .textCase(.none)
                    }
                }
                .tag(4)
        }
        .tint(.primary)
        .environment(\.textCase, .none)
    }
}


