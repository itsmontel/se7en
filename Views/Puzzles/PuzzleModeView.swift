//
//  PuzzleModeView.swift
//  SE7EN
//
//  Fullscreen puzzle view for shield action (no main app UI visible)
//

import SwiftUI

struct PuzzleModeView: View {
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
    
    private var puzzleView: some View {
        Group {
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
        .transition(.move(edge: .bottom).combined(with: .opacity))
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

