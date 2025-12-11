import SwiftUI

// MARK: - Game State
enum GameState {
    case showing
    case memorizing
    case input
    case success
    case failure
}

// MARK: - Pattern Game View
struct PatternGameView: View {
    let sequence: PatternSequence
    let onComplete: () -> Void
    let onDismiss: () -> Void
    
    @State private var gameState: GameState = .showing
    @State private var currentShowIndex = -1
    @State private var userInput: [PatternElement] = []
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Memory Challenge")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(headerText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if gameState == .input {
                    Text("\(userInput.count) / \(sequence.length) correct")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Content Area
            if gameState == .showing || gameState == .memorizing {
                sequenceDisplayView
            } else if gameState == .input {
                inputView
            }
            
            Spacer()
            
            // Cancel Button
            if gameState != .success {
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(
            Group {
                if gameState == .success {
                    SuccessOverlay(message: "Perfect Memory!", emoji: "🧠")
                } else if gameState == .failure {
                    FailureOverlay(
                        onRetry: {
                            restartGame()
                        },
                        onDismiss: onDismiss
                    )
                }
            }
        )
        .onAppear {
            startSequenceDisplay()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private var headerText: String {
        switch gameState {
        case .showing:
            return "Watch the sequence carefully..."
        case .memorizing:
            return "Memorize the pattern!"
        case .input:
            return "Now repeat the sequence"
        case .success:
            return "You did it!"
        case .failure:
            return "Try again!"
        }
    }
    
    // MARK: - Sequence Display View
    private var sequenceDisplayView: some View {
        VStack(spacing: 30) {
            // Sequence display
            HStack(spacing: 12) {
                ForEach(Array(sequence.elements.enumerated()), id: \.offset) { index, element in
                    PatternElementView(
                        element: element,
                        isHighlighted: index == currentShowIndex,
                        size: 60
                    )
                }
            }
            .padding(24)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            
            if gameState == .memorizing {
                Text("Get ready...")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Input View
    private var inputView: some View {
        VStack(spacing: 30) {
            // User's input display
            if !userInput.isEmpty {
                VStack(spacing: 16) {
                    Text("Your Sequence")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(Array(userInput.enumerated()), id: \.offset) { index, element in
                            PatternElementView(
                                element: element,
                                isHighlighted: false,
                                size: 50
                            )
                        }
                    }
                    .padding(20)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
            
            // Input buttons
            VStack(spacing: 16) {
                Text("Tap the symbols in order")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(PatternElement.allCases, id: \.self) { element in
                        Button(action: {
                            addElement(element)
                        }) {
                            PatternElementView(
                                element: element,
                                isHighlighted: false,
                                size: 60
                            )
                        }
                    }
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Game Logic
    private func startSequenceDisplay() {
        gameState = .showing
        currentShowIndex = -1
        
        var index = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { timer in
            if index < sequence.length {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentShowIndex = index
                }
                HapticFeedback.light.trigger()
                index += 1
            } else {
                timer.invalidate()
                currentShowIndex = -1
                gameState = .memorizing
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        gameState = .input
                    }
                }
            }
        }
    }
    
    private func addElement(_ element: PatternElement) {
        let currentIndex = userInput.count
        
        // Check if this is the correct element
        if currentIndex < sequence.elements.count && element == sequence.elements[currentIndex] {
            userInput.append(element)
            HapticFeedback.success.trigger()
            
            // Check if sequence is complete
            if userInput.count == sequence.length {
                gameState = .success
                HapticFeedback.success.trigger()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    onComplete()
                }
            }
        } else {
            // Wrong element
            HapticFeedback.error.trigger()
            gameState = .failure
        }
    }
    
    private func restartGame() {
        userInput = []
        gameState = .showing
        startSequenceDisplay()
    }
}

// MARK: - Pattern Element View
struct PatternElementView: View {
    let element: PatternElement
    let isHighlighted: Bool
    var size: CGFloat = 70
    
    var body: some View {
        Image(systemName: element.rawValue)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundColor(isHighlighted ? .white : element.color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHighlighted ? element.color : Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(element.color, lineWidth: isHighlighted ? 0 : 2)
            )
            .scaleEffect(isHighlighted ? 1.15 : 1.0)
            .shadow(color: isHighlighted ? element.color.opacity(0.5) : Color.clear, radius: 8, x: 0, y: 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHighlighted)
    }
}

// MARK: - Failure Overlay
struct FailureOverlay: View {
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("❌")
                    .font(.system(size: 80))
                
                Text("Wrong Sequence!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Don't worry, try again!")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(spacing: 16) {
                    Button(action: onRetry) {
                        Text("Try Again")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Button(action: onDismiss) {
                        Text("Cancel")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.gray)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground))
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20)
            .padding(40)
        }
    }
}
