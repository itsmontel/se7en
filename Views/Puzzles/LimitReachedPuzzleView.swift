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
                VStack(spacing: 16) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.primary)
                    
                    Text("Daily Limit Reached")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    Text("You've reached your daily limit for **\(appName)**")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                Divider()
                
                // Puzzle option
                VStack(spacing: 20) {
                    Text("Solve a puzzle to earn 15 more minutes")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .padding(.top, 24)
                    
                    Button(action: {
                        HapticFeedback.medium.trigger()
                        startRandomPuzzle()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "puzzlepiece.fill")
                                .font(.system(size: 20, weight: .semibold))
                            
                            Text("Start Puzzle")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.primary, Color.primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)
                    
                    Text("You can solve puzzles multiple times to extend your limit")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }
                .padding(.bottom, 24)
                
                Divider()
                
                // Cancel button
                Button(action: {
                    HapticFeedback.light.trigger()
                    dismiss()
                }) {
                    Text("I Can Wait Till Tomorrow")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: 600)
            .background(Color.cardBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 40, x: 0, y: 20)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
    
    @ViewBuilder
    private var puzzleView: some View {
        if let puzzleType = selectedPuzzleType {
            Group {
                switch puzzleType {
                case .sudoku:
                    SudokuView(
                        puzzle: SudokuPuzzle.generate(),
                        onComplete: {
                            handlePuzzleComplete(puzzleType: puzzleType)
                        },
                        onDismiss: {
                            showPuzzle = false
                        }
                    )
                case .memory:
                    MemoryGameView(
                        game: MemoryGame.generate(),
                        onComplete: {
                            handlePuzzleComplete(puzzleType: puzzleType)
                        },
                        onDismiss: {
                            showPuzzle = false
                        }
                    )
                case .pattern:
                    PatternGameView(
                        sequence: PatternSequence.generate(length: 6),
                        onComplete: {
                            handlePuzzleComplete(puzzleType: puzzleType)
                        },
                        onDismiss: {
                            showPuzzle = false
                        }
                    )
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func startRandomPuzzle() {
        selectedPuzzleType = puzzleManager.selectRandomPuzzle()
        puzzleStartTime = Date()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showPuzzle = true
        }
    }
    
    private func handlePuzzleComplete(puzzleType: PuzzleType) {
        // Grant extension
        puzzleManager.grantExtension(for: bundleID, puzzleType: puzzleType)
        
        // Unblock the app temporarily (15 minutes)
        ScreenTimeService.shared.grantTemporaryExtension(for: bundleID, minutes: 15)
        
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
