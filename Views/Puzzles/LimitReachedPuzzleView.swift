import SwiftUI

struct LimitReachedPuzzleView: View {
    @Binding var isPresented: Bool
    let appName: String
    let bundleID: String
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
                    dismiss()
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
        puzzleManager.grantExtension(for: bundleID, puzzleType: puzzleType)
        
        // Unblock the app temporarily (15 minutes)
        ScreenTimeService.shared.grantTemporaryExtension(for: bundleID, minutes: 15)
        
        // ✅ CRITICAL: Reload app goals to update UI immediately (show 0 of 15 minutes)
        appState.loadAppGoals()
        
        // Show success and dismiss
        HapticFeedback.success.trigger()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}


