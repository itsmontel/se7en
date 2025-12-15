import SwiftUI

// MARK: - Memory Game View
struct MemoryGameView: View {
    let game: MemoryGame
    let onComplete: () -> Void
    let onDismiss: () -> Void
    
    @State private var cards: [MemoryCard]
    @State private var firstFlippedIndex: Int? = nil
    @State private var secondFlippedIndex: Int? = nil
    @State private var matchedPairs: Int = 0
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var moves: Int = 0
    @State private var refreshID = UUID() // Force refresh when cards update
    
    private let totalPairs = 8 // 8 pairs = 16 cards in 4x4 grid
    
    init(game: MemoryGame, onComplete: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.game = game
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        _cards = State(initialValue: game.cards)
    }
    
    var body: some View {
        VStack(spacing: 20) {
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
            
            // Cards Grid - 4x4
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(cards) { card in
                    let index = cards.firstIndex(where: { $0.id == card.id })!
                    MemoryCardView(
                        card: cards[index],
                        isFlipped: cards[index].isMatched || firstFlippedIndex == index || secondFlippedIndex == index,
                        onTap: {
                            handleCardTap(at: index)
                        }
                    )
                    .id("\(card.id)-\(cards[index].isMatched)-\(firstFlippedIndex == index)-\(secondFlippedIndex == index)-\(refreshID)") // Force re-render when state changes
                    .aspectRatio(1.0, contentMode: .fit)
                }
            }
            .padding(16)
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
    
    // Check if a card should appear flipped
    private func isCardFlipped(at index: Int) -> Bool {
        // If matched, always show as flipped
        if cards[index].isMatched {
            return true
        }
        // Otherwise check if it's currently flipped
        return firstFlippedIndex == index || secondFlippedIndex == index
    }
    
    private func handleCardTap(at index: Int) {
        // Don't allow tap if processing or card is already matched
        guard !isProcessing else { 
            print("🚫 Tap blocked - processing")
            return 
        }
        guard !cards[index].isMatched else { 
            print("🚫 Tap blocked - card already matched")
            return 
        }
        
        // Don't allow tapping the same card that's already flipped
        guard firstFlippedIndex != index else { 
            print("🚫 Tap blocked - same card already flipped")
            return 
        }
        guard secondFlippedIndex != index else { 
            print("🚫 Tap blocked - same card already flipped (second)")
            return 
        }
        
        HapticFeedback.light.trigger()
        print("👆 Card tapped at index: \(index), value: \(cards[index].value)")
        
        if firstFlippedIndex == nil {
            // First card flip
            print("🃏 Flipping first card at index: \(index)")
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                firstFlippedIndex = index
            }
        } else if secondFlippedIndex == nil {
            // Second card flip
            print("🃏 Flipping second card at index: \(index)")
            moves += 1
            isProcessing = true
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                secondFlippedIndex = index
            }
            
            // Check for match after a shorter delay for better responsiveness
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            checkForMatch()
            }
        }
    }
    
    private func checkForMatch() {
        guard let first = firstFlippedIndex, let second = secondFlippedIndex else {
            print("❌ checkForMatch: Missing indices")
            isProcessing = false
            return
        }
        
        let firstCard = cards[first]
        let secondCard = cards[second]
        print("🔍 Checking match: '\(firstCard.value)' vs '\(secondCard.value)'")
        
        if firstCard.value == secondCard.value {
                // Match found!
            print("✅ MATCH FOUND! Pair \(matchedPairs + 1)")
                matchedPairs += 1
                HapticFeedback.success.trigger()
                
            // CRITICAL: Update cards by modifying structs in place
            // Create a new array reference to ensure SwiftUI detects the change
            var updatedCards = cards
            // Modify the matched cards (preserving their IDs)
            updatedCards[first].isMatched = true
            updatedCards[second].isMatched = true
            
            // Verify BEFORE assignment
            print("📊 Updated matched pairs: \(matchedPairs)/\(totalPairs)")
            print("🔍 Updated array - Card \(first) matched: \(updatedCards[first].isMatched), Card \(second) matched: \(updatedCards[second].isMatched)")
            
            // Update state with smooth animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                cards = updatedCards
                refreshID = UUID() // Force view refresh
            }
            
            // Verify AFTER assignment
            print("🔍 State array - Card \(first) matched: \(cards[first].isMatched), Card \(second) matched: \(cards[second].isMatched)")
            
            // Keep the cards flipped for a moment to show the match
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    firstFlippedIndex = nil
                    secondFlippedIndex = nil
                }
                isProcessing = false
                
                // Check if game is complete
                if matchedPairs == totalPairs {
                    print("🎉 GAME COMPLETE!")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showSuccess = true
                    HapticFeedback.success.trigger()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        onComplete()
                        }
                    }
                    }
                }
            } else {
                // No match - flip cards back
            print("❌ No match")
                HapticFeedback.error.trigger()
                
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                firstFlippedIndex = nil
                secondFlippedIndex = nil
            }
            isProcessing = false
        }
    }
}

// MARK: - Memory Card View
struct MemoryCardView: View {
    let card: MemoryCard
    let isFlipped: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Card back (question mark side)
                CardBackView()
                    .opacity((isFlipped || card.isMatched) ? 0 : 1)
                
                // Card front (emoji side)
                CardFrontView(value: card.value, isMatched: card.isMatched)
                    .opacity((isFlipped || card.isMatched) ? 1 : 0)
            }
            .scaleEffect(card.isMatched ? 0.95 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFlipped)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: card.isMatched)
        }
        .disabled(card.isMatched)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Card Front View
struct CardFrontView: View {
    let value: String
    let isMatched: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isMatched ? Color.green.opacity(0.2) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            Text(value)
                .font(.system(size: 36))
            
            // Matched checkmark overlay
            if isMatched {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Card Back View
struct CardBackView: View {
    var body: some View {
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
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Success Overlay
struct SuccessOverlay: View {
    let message: String
    let emoji: String
    var subtitle: String? = nil
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text(emoji)
                    .font(.system(size: 80))
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
                
                Text(message)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                // Celebration animation
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(celebrationColors[index % celebrationColors.count])
                            .frame(width: 12, height: 12)
                            .offset(y: isAnimating ? -5 : 5)
                            .animation(
                                .easeInOut(duration: 0.4)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.1),
                                value: isAnimating
                            )
                    }
                }
                .padding(.top, 8)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20)
            .padding(40)
        }
        .onAppear {
            isAnimating = true
    }
    }
    
    private let celebrationColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]
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