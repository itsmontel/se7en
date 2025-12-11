import SwiftUI

// MARK: - Memory Game View
struct MemoryGameView: View {
    let game: MemoryGame
    let onComplete: () -> Void
    let onDismiss: () -> Void
    
    @State private var cards: [MemoryCard]
    @State private var flippedIndices: [Int] = []
    @State private var matchedPairs: Int = 0
    @State private var canFlip = true
    @State private var showSuccess = false
    @State private var moves: Int = 0
    
    private let totalPairs = 8
    
    init(game: MemoryGame, onComplete: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.game = game
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        _cards = State(initialValue: game.cards)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Memory Match")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Find all 8 pairs to win")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(matchedPairs)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Text("Pairs")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(moves)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        Text("Moves")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.top, 20)
            
            // Cards Grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 12
            ) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    MemoryCardView(
                        card: card,
                        onTap: {
                            if canFlip && !card.isFlipped && !card.isMatched && flippedIndices.count < 2 {
                                flipCard(at: index)
                            }
                        }
                    )
                }
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Cancel Button
            Button(action: onDismiss) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            }
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(
            Group {
                if showSuccess {
                    SuccessOverlay(
                        message: "All Pairs Found!",
                        emoji: "🎉",
                        subtitle: "Completed in \(moves) moves"
                    )
                }
            }
        )
    }
    
    private func flipCard(at index: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            cards[index].isFlipped = true
        }
        flippedIndices.append(index)
        HapticFeedback.light.trigger()
        
        if flippedIndices.count == 2 {
            moves += 1
            canFlip = false
            checkForMatch()
        }
    }
    
    private func checkForMatch() {
        let firstIndex = flippedIndices[0]
        let secondIndex = flippedIndices[1]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if cards[firstIndex].value == cards[secondIndex].value {
                // Match found!
                withAnimation {
                    cards[firstIndex].isMatched = true
                    cards[secondIndex].isMatched = true
                }
                matchedPairs += 1
                HapticFeedback.success.trigger()
                
                // Check if game is complete
                if matchedPairs == totalPairs {
                    showSuccess = true
                    HapticFeedback.success.trigger()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        onComplete()
                    }
                }
            } else {
                // No match - flip back
                withAnimation(.easeInOut(duration: 0.3)) {
                    cards[firstIndex].isFlipped = false
                    cards[secondIndex].isFlipped = false
                }
                HapticFeedback.error.trigger()
            }
            
            flippedIndices = []
            canFlip = true
        }
    }
}

// MARK: - Memory Card View
struct MemoryCardView: View {
    let card: MemoryCard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Card back
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "questionmark")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    )
                    .opacity(card.isFlipped || card.isMatched ? 0 : 1)
                
                // Card front
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        Text(card.value)
                            .font(.system(size: 40))
                    )
                    .opacity(card.isFlipped || card.isMatched ? 1 : 0)
                
                // Matched overlay
                if card.isMatched {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.2))
                        .overlay(
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                        )
                }
            }
            .frame(height: 90)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .rotation3DEffect(
                .degrees(card.isFlipped || card.isMatched ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .scaleEffect(card.isMatched ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: card.isMatched)
        }
        .disabled(card.isMatched)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Success Overlay
struct SuccessOverlay: View {
    let message: String
    let emoji: String
    var subtitle: String? = nil
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text(emoji)
                    .font(.system(size: 80))
                
                Text(message)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Celebration animation
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.random)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 8)
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

// MARK: - Color Extension
extension Color {
    static var random: Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}
