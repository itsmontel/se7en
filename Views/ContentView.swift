import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPuzzleMode = false
    @State private var puzzleAppName = ""
    @State private var puzzleTokenHash = ""
    
    var body: some View {
        Group {
            if showPuzzleMode {
                // Puzzle mode - show puzzle fullscreen
                FullscreenPuzzleView(
                    appName: puzzleAppName,
                    tokenHash: puzzleTokenHash,
                    onComplete: {
                        handlePuzzleComplete()
                    }
                )
                .environmentObject(appState)
            } else if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingContainerView()
            }
        }
        .environment(\.textCase, .none)
        .onAppear {
            checkPuzzleMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
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
        
        if defaults.bool(forKey: "puzzleMode"),
           let tokenHash = defaults.string(forKey: "puzzleTokenHash"),
           let appName = defaults.string(forKey: "puzzleAppName_\(tokenHash)") {
            puzzleAppName = appName
            puzzleTokenHash = tokenHash
            showPuzzleMode = true
            
            // Clear the flag
            defaults.set(false, forKey: "puzzleMode")
            defaults.synchronize()
        }
    }
    
    private func handlePuzzleComplete() {
        // Unblock the app
        ScreenTimeService.shared.grantTemporaryExtension(for: puzzleTokenHash, minutes: 15)
        
        // Hide puzzle mode first
        showPuzzleMode = false
        
        // Open the blocked app (this will naturally put SE7EN in background)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            openBlockedApp()
        }
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
    
    @EnvironmentObject var appState: AppState
    @StateObject private var puzzleManager = PuzzleManager.shared
    @State private var selectedPuzzleType: PuzzleType?
    @State private var showPuzzle = false
    @State private var currentSudokuPuzzle: SudokuPuzzle?
    @State private var currentMemoryGame: MemoryGame?
    @State private var currentPatternSequence: PatternSequence?
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
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
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                // Icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.pink)
                
                // Title
                Text("Daily Limit Reached")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Subtitle
                VStack(spacing: 4) {
                    Text("That's okay, it happens 😊")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                    
                    Text("You've reached your limit for **\(appName)**")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                
                // Puzzle button
                Button(action: startRandomPuzzle) {
                    HStack {
                        Image(systemName: "puzzlepiece.fill")
                        Text("Solve a puzzle to earn 15 more minutes")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .padding(.vertical, 32)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var puzzleView: some View {
        if let puzzleType = selectedPuzzleType {
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
    }
    
    private func startRandomPuzzle() {
        selectedPuzzleType = puzzleManager.selectRandomPuzzle()
        
        // Generate puzzles
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


