import SwiftUI

// MARK: - Game State
enum GameState {
    case showing
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
    @State private var currentShowIndex = 0
    @State private var showElement: PatternElement? = nil
    @State private var userInput: [PatternElement] = []
    @State private var attemptsLeft = 3
    @State private var currentSequence: [PatternElement] = []
    
    private let sequenceLength = 6
    
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
                    VStack(spacing: 8) {
                        Text("\(userInput.count) / \(sequenceLength) correct")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.blue)
                        
                        HStack(spacing: 16) {
                            Text("Attempts:")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { index in
                                    Circle()
                                        .fill(index < attemptsLeft ? Color.green : Color.red.opacity(0.3))
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Content Area
            if gameState == .showing {
                showingView
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
                        attemptsLeft: attemptsLeft,
                        onRetry: {
                            restartGame()
                        },
                        onDismiss: onDismiss
                    )
                }
            }
        )
        .onAppear {
            currentSequence = Array(sequence.elements.prefix(sequenceLength))
            startSequenceDisplay()
        }
    }
    
    private var headerText: String {
        switch gameState {
        case .showing:
            return "Watch carefully as each symbol appears..."
        case .input:
            return "Tap the symbols in the correct order"
        case .success:
            return "You did it!"
        case .failure:
            return attemptsLeft > 0 ? "Wrong! Try again" : "Out of attempts"
        }
    }
    
    // MARK: - Showing View
    private var showingView: some View {
        VStack(spacing: 30) {
            if let element = showElement {
                PatternElementView(
                    element: element,
                    isHighlighted: true,
                    size: 120
                )
                .transition(.scale.combined(with: .opacity))
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text("?")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.gray.opacity(0.3))
                    )
            }
            
            Text("Item \(min(currentShowIndex + 1, sequenceLength)) of \(sequenceLength)")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
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
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(userInput.enumerated()), id: \.offset) { index, element in
                                PatternElementView(
                                    element: element,
                                    isHighlighted: false,
                                    size: 50
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 70)
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
                        .buttonStyle(PlainButtonStyle())
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
        currentShowIndex = 0
        showElement = nil
        
        // Show first element after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showNextElement()
        }
    }
    
    private func showNextElement() {
        guard currentShowIndex < currentSequence.count else {
            // Finished showing all elements
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    gameState = .input
                }
            }
            return
        }
        
        // Show element
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            showElement = currentSequence[currentShowIndex]
        }
        HapticFeedback.light.trigger()
        
        // Hide element after 1.5 seconds and show next
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.25)) {
                showElement = nil
            }
            
            currentShowIndex += 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showNextElement()
            }
        }
    }
    
    private func addElement(_ element: PatternElement) {
        let currentIndex = userInput.count
        
        // Check if this is the correct element
        if currentIndex < currentSequence.count && element == currentSequence[currentIndex] {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                userInput.append(element)
            }
            HapticFeedback.success.trigger()
            
            // Check if sequence is complete
            if userInput.count == currentSequence.count {
                gameState = .success
                HapticFeedback.success.trigger()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    onComplete()
                }
            }
        } else {
            // Wrong element
            HapticFeedback.error.trigger()
            attemptsLeft -= 1
            
            if attemptsLeft > 0 {
                // Show error and reset input
                withAnimation {
                    gameState = .failure
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        userInput = []
                        gameState = .input
                    }
                }
            } else {
                // Out of attempts
                withAnimation {
                    gameState = .failure
                }
            }
        }
    }
    
    private func restartGame() {
        // Generate new sequence
        currentSequence = PatternElement.allCases.shuffled().prefix(sequenceLength).map { $0 }
        userInput = []
        attemptsLeft = 3
        currentShowIndex = 0
        showElement = nil
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
            .scaleEffect(isHighlighted ? 1.1 : 1.0)
            .shadow(color: isHighlighted ? element.color.opacity(0.5) : Color.clear, radius: 8, x: 0, y: 4)
    }
}

// MARK: - Failure Overlay
struct FailureOverlay: View {
    let attemptsLeft: Int
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("❌")
                    .font(.system(size: 80))
                
                Text(attemptsLeft > 0 ? "Wrong Order!" : "Out of Attempts!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if attemptsLeft > 0 {
                    Text("You have \(attemptsLeft) attempt\(attemptsLeft == 1 ? "" : "s") left")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("Try a new pattern")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                HStack(spacing: 16) {
                    Button(action: onRetry) {
                        Text(attemptsLeft > 0 ? "Continue" : "New Pattern")
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


