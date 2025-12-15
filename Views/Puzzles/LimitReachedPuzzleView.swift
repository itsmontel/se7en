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
        .environment(\.textCase, .none)
    }
    
    private var limitReachedView: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Header with icon
                    VStack(spacing: 14) {
                        // Icon with subtle background
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.primary.opacity(0.1),
                                            Color.primary.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.primary.opacity(0.85))
                        }
                        
                        Text("You've Reached Your Daily Limit")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .textCase(.none)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        VStack(spacing: 6) {
                            Text("That's okay it happens 😊")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.textSecondary)
                                .textCase(.none)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Don't worry, you can solve a puzzle for more time or wait until tomorrow.")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.textSecondary)
                                .textCase(.none)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 20)
                    
                    // Subtle divider
                    Divider()
                        .padding(.horizontal, 0)
                    
                    // Puzzle option
                    VStack(spacing: 16) {
                        Text("Solve a puzzle to earn 15 more minutes")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .textCase(.none)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
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
                                    .textCase(.none)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.primary, Color.primary.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.primary.opacity(0.25), radius: 6, x: 0, y: 3)
                        }
                        .padding(.horizontal, 24)
                        
                        Text("Or wait until tomorrow")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.textSecondary.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .textCase(.none)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 20)
                    
                    // Subtle divider
                    Divider()
                        .padding(.horizontal, 0)
                    
                    // Cancel button
                    Button(action: {
                        HapticFeedback.light.trigger()
                        dismiss()
                    }) {
                        Text("I'll Wait Until Tomorrow")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.textSecondary)
                            .textCase(.none)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: min(geometry.size.width - 40, 520))
                .background(Color.cardBackground)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
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


