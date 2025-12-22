import SwiftUI

// MARK: - Jigsaw Puzzle View
struct JigsawPuzzleView: View {
    let puzzle: JigsawPuzzle
    let onComplete: () -> Void
    let onDismiss: () -> Void
    
    @State private var placedPieces: [Int: UUID] = [:] // slot index -> piece ID
    @State private var selectedPieceID: UUID? = nil
    @State private var showSuccess = false
    @State private var moves: Int = 0
    @State private var showReference = true
    @State private var wrongPlacements: Set<Int> = [] // Track slots with wrong pieces for feedback
    
    private let gridSize = 3
    private let totalPieces = 9
    
    var correctCount: Int {
        placedPieces.filter { slotIndex, pieceID in
            puzzle.shuffledPieces.first { $0.id == pieceID }?.correctPosition == slotIndex
        }.count
    }
    
    // Pieces that are NOT on the board (in tray)
    var trayPieces: [JigsawPiece] {
        puzzle.shuffledPieces.filter { piece in
            !placedPieces.values.contains(piece.id)
        }
    }
    
    // Check if a piece is selected
    var hasSelection: Bool {
        selectedPieceID != nil
    }
    
    // Check if a piece at a given slot is correctly placed (locked)
    func isPieceLockedAt(_ slotIndex: Int) -> Bool {
        guard let pieceID = placedPieces[slotIndex],
              let piece = puzzle.shuffledPieces.first(where: { $0.id == pieceID }) else {
            return false
        }
        return piece.correctPosition == slotIndex
    }
    
    // Check if a piece ID is locked (in correct position)
    func isPieceLocked(_ pieceID: UUID) -> Bool {
        guard let slotIndex = placedPieces.first(where: { $0.value == pieceID })?.key,
              let piece = puzzle.shuffledPieces.first(where: { $0.id == pieceID }) else {
            return false
        }
        return piece.correctPosition == slotIndex
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView
            
            // Reference Image
            referenceImageView
            
            Spacer(minLength: 4)
            
            // Puzzle Board (3x3)
            puzzleBoardView
            
            // Instructions
            instructionText
            
            Spacer(minLength: 4)
            
            // Piece Tray
            pieceTrayView
            
            Spacer(minLength: 8)
            
            // Bottom buttons
            bottomButtonsView
        }
        .padding(.top, 16)
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(
            Group {
                if showSuccess {
                    SuccessOverlay(message: "Puzzle Complete!", emoji: "🧩", subtitle: "Great job!")
                }
            }
        )
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Jigsaw Puzzle")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Tap a piece, then tap where to place it")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(correctCount)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("Correct")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(placedPieces.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("Placed")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(moves)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("Moves")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Reference Image
    private var referenceImageView: some View {
        VStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) { showReference.toggle() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: showReference ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 13))
                    Text(showReference ? "Hide Reference" : "Show Reference")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.blue)
            }
            
            if showReference {
                Image(puzzle.imageName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill) // Force square
                    .frame(width: 90, height: 90)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Puzzle Board View
    private var puzzleBoardView: some View {
        let pieceSize: CGFloat = 70
        let spacing: CGFloat = 4
        
        return VStack(spacing: spacing) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        let slotIndex = row * gridSize + col
                        
                        Button(action: {
                            handleSlotTap(slotIndex)
                        }) {
                            BoardSlotView(
                                slotIndex: slotIndex,
                                placedPieceID: placedPieces[slotIndex],
                                allPieces: puzzle.shuffledPieces,
                                imageName: puzzle.imageName,
                                pieceSize: pieceSize,
                                gridSize: gridSize,
                                isHighlighted: hasSelection && !isPieceLockedAt(slotIndex),
                                isSelected: isSlotSelected(slotIndex),
                                showWrongFeedback: wrongPlacements.contains(slotIndex),
                                isLocked: isPieceLockedAt(slotIndex)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(hasSelection ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.2), value: hasSelection)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Instruction Text
    private var instructionText: some View {
        Group {
            if let selectedID = selectedPieceID {
                if placedPieces.values.contains(selectedID) {
                    Text("Tap a slot to move this piece")
                        .foregroundColor(.blue)
                } else {
                    Text("Tap a slot to place this piece")
                        .foregroundColor(.blue)
                }
            } else {
                Text("Tap a piece to select it")
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .animation(.easeInOut(duration: 0.2), value: selectedPieceID)
    }
    
    // MARK: - Piece Tray View
    private var pieceTrayView: some View {
        let pieceSize: CGFloat = 55
        
        return VStack(spacing: 8) {
            if trayPieces.isEmpty {
                Text("All pieces placed!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.green)
                    .padding(.vertical, 20)
            } else {
                // Use a grid layout for the tray pieces
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(pieceSize + 8), spacing: 8), count: 5),
                    spacing: 8
                ) {
                    ForEach(trayPieces, id: \.id) { piece in
                        Button(action: {
                            handleTrayPieceTap(piece)
                        }) {
                            TrayPieceView(
                                piece: piece,
                                imageName: puzzle.imageName,
                                pieceSize: pieceSize,
                                gridSize: gridSize,
                                isSelected: selectedPieceID == piece.id
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .id(piece.id) // Explicit ID for stable identity
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtonsView: some View {
        HStack(spacing: 20) {
            Button(action: resetPuzzle) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Reset")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.orange)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(10)
            }
            
            Button(action: onDismiss) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            }
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Check if slot contains selected piece
    private func isSlotSelected(_ slotIndex: Int) -> Bool {
        guard let selectedID = selectedPieceID else { return false }
        return placedPieces[slotIndex] == selectedID
    }
    
    // MARK: - Handle Tray Piece Tap
    private func handleTrayPieceTap(_ piece: JigsawPiece) {
        HapticFeedback.light.trigger()
        
        if selectedPieceID == piece.id {
            // Deselect if tapping same piece
            selectedPieceID = nil
        } else {
            // Select this piece
            selectedPieceID = piece.id
        }
    }
    
    // MARK: - Handle Slot Tap
    private func handleSlotTap(_ slotIndex: Int) {
        // If no piece selected, check if there's a piece in this slot to select
        if selectedPieceID == nil {
            if let pieceID = placedPieces[slotIndex] {
                // Don't allow selecting pieces that are already correct (locked)
                if isPieceLockedAt(slotIndex) {
                    HapticFeedback.warning.trigger()
                    return
                }
                // Select this placed piece
                selectedPieceID = pieceID
                HapticFeedback.light.trigger()
            }
            return
        }
        
        guard let selectedID = selectedPieceID else { return }
        
        // Don't allow placing into a slot that has a correctly placed piece (locked)
        if isPieceLockedAt(slotIndex) {
            HapticFeedback.warning.trigger()
            selectedPieceID = nil
            return
        }
        
        // Find the selected piece
        guard let piece = puzzle.shuffledPieces.first(where: { $0.id == selectedID }) else {
            selectedPieceID = nil
            return
        }
        
        // Check if this piece is already on the board somewhere
        let currentSlot = placedPieces.first(where: { $0.value == selectedID })?.key
        
        // If tapping the same slot the piece is already in, just deselect
        if currentSlot == slotIndex {
            selectedPieceID = nil
            return
        }
        
        // Clear any previous wrong feedback for this slot
        wrongPlacements.remove(slotIndex)
        
        // Check if there's already a piece in target slot
        if let existingPieceID = placedPieces[slotIndex] {
            // There's a piece in the target slot - we need to swap or send it to tray
            if let currentSlot = currentSlot {
                // Selected piece is on the board - swap the two pieces
                placedPieces[currentSlot] = existingPieceID
                placedPieces[slotIndex] = selectedID
                
                // Update wrong feedback for the swapped piece
                if let existingPiece = puzzle.shuffledPieces.first(where: { $0.id == existingPieceID }) {
                    if existingPiece.correctPosition != currentSlot {
                        wrongPlacements.insert(currentSlot)
                    } else {
                        wrongPlacements.remove(currentSlot)
                    }
                }
            } else {
                // Selected piece is from tray - send existing piece to tray
                placedPieces[slotIndex] = selectedID
                // existingPieceID is automatically removed since we overwrote slotIndex
            }
        } else {
            // Target slot is empty
            if let currentSlot = currentSlot {
                // Remove from current slot first
                placedPieces.removeValue(forKey: currentSlot)
                wrongPlacements.remove(currentSlot)
            }
            // Place in new slot
            placedPieces[slotIndex] = selectedID
        }
        
        // Clear selection
        selectedPieceID = nil
        moves += 1
        
        // Haptic feedback and visual feedback based on correctness
        let isCorrect = piece.correctPosition == slotIndex
        
        if isCorrect {
            HapticFeedback.success.trigger()
            wrongPlacements.remove(slotIndex)
        } else {
            HapticFeedback.error.trigger()
            wrongPlacements.insert(slotIndex)
        }
        
        // Check completion
        checkCompletion()
    }
    
    // MARK: - Reset Puzzle
    private func resetPuzzle() {
        withAnimation(.spring(response: 0.4)) {
            placedPieces.removeAll()
            selectedPieceID = nil
            wrongPlacements.removeAll()
            moves = 0
        }
        HapticFeedback.medium.trigger()
    }
    
    // MARK: - Check Completion
    private func checkCompletion() {
        guard placedPieces.count == totalPieces else { return }
        
        let allCorrect = placedPieces.allSatisfy { slotIndex, pieceID in
            puzzle.shuffledPieces.first { $0.id == pieceID }?.correctPosition == slotIndex
        }
        
        if allCorrect && !showSuccess {
            HapticFeedback.success.trigger()
            withAnimation(.spring(response: 0.5)) {
                showSuccess = true
                wrongPlacements.removeAll()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onComplete()
            }
        }
    }
}

// MARK: - Board Slot View
struct BoardSlotView: View {
    let slotIndex: Int
    let placedPieceID: UUID?
    let allPieces: [JigsawPiece]
    let imageName: String
    let pieceSize: CGFloat
    let gridSize: Int
    let isHighlighted: Bool
    let isSelected: Bool
    let showWrongFeedback: Bool
    let isLocked: Bool
    
    var placedPiece: JigsawPiece? {
        guard let pieceID = placedPieceID else { return nil }
        return allPieces.first { $0.id == pieceID }
    }
    
    var body: some View {
        ZStack {
            // Slot background
            RoundedRectangle(cornerRadius: 8)
                .fill(slotBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(slotBorderColor, style: slotBorderStyle)
                )
            
            // Placed piece
            if let piece = placedPiece {
                PieceImageView(
                    piece: piece,
                    imageName: imageName,
                    pieceSize: pieceSize,
                    gridSize: gridSize
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(pieceBorderColor, lineWidth: isLocked ? 3 : 2)
                )
                .overlay(
                    // Feedback icon (checkmark or X)
                    feedbackIcon
                )
                // Locked pieces have a slight opacity overlay to show they're fixed
                .overlay(
                    Group {
                        if isLocked {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.1))
                        }
                    }
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3), value: isSelected)
            }
            
            // Slot number hint (only if empty)
            if placedPieceID == nil && !isHighlighted {
                Text("\(slotIndex + 1)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.gray.opacity(0.4))
            }
        }
        .frame(width: pieceSize, height: pieceSize)
        .contentShape(Rectangle()) // Ensure entire area is tappable
    }
    
    private var slotBackgroundColor: Color {
        if isLocked {
            return Color.green.opacity(0.1)
        } else if showWrongFeedback {
            return Color.red.opacity(0.1)
        } else if isHighlighted {
            return Color.blue.opacity(0.1)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    private var slotBorderColor: Color {
        if isLocked {
            return Color.green
        } else if isSelected {
            return Color.blue
        } else if showWrongFeedback {
            return Color.red.opacity(0.6)
        } else if isHighlighted {
            return Color.blue.opacity(0.4)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
    
    private var slotBorderStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: isLocked ? 2 : (isSelected ? 3 : (placedPieceID == nil ? 2 : 1)),
            dash: placedPieceID == nil ? [5, 3] : []
        )
    }
    
    private var pieceBorderColor: Color {
        if isLocked {
            return Color.green
        } else if showWrongFeedback {
            return Color.red
        } else {
            return Color.clear
        }
    }
    
    @ViewBuilder
    private var feedbackIcon: some View {
        if isLocked {
            // Show lock icon for locked pieces
            ZStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                    .background(Circle().fill(Color.white).frame(width: 14, height: 14))
            }
            .offset(x: pieceSize / 2 - 12, y: -pieceSize / 2 + 12)
        } else if showWrongFeedback {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)
                .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                .offset(x: pieceSize / 2 - 12, y: -pieceSize / 2 + 12)
        }
    }
}

// MARK: - Tray Piece View
struct TrayPieceView: View {
    let piece: JigsawPiece
    let imageName: String
    let pieceSize: CGFloat
    let gridSize: Int
    let isSelected: Bool
    
    var body: some View {
        PieceImageView(
            piece: piece,
            imageName: imageName,
            pieceSize: pieceSize,
            gridSize: gridSize
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.1),
                radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
        // Add explicit content shape BEFORE scale effect for proper hit testing
        .contentShape(Rectangle())
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Piece Image View (FIXED - Proper Image Slicing)
/// This view displays a single piece of the jigsaw puzzle by showing the correct
/// portion of the full image based on the piece's correctPosition.
///
/// How it works:
/// 1. The full image is scaled to exactly (pieceSize * gridSize) in both dimensions (forced square)
/// 2. The image is placed in a container of size pieceSize x pieceSize
/// 3. The image is offset so that only the portion corresponding to correctPosition is visible
/// 4. The container clips the image to show only the piece
///
/// For a 3x3 grid with pieceSize = 55:
/// - Full image size = 165 x 165
/// - Position 0 (top-left): row=0, col=0 → shows top-left 55x55 portion
/// - Position 4 (center): row=1, col=1 → shows center 55x55 portion
/// - Position 8 (bottom-right): row=2, col=2 → shows bottom-right 55x55 portion
struct PieceImageView: View {
    let piece: JigsawPiece
    let imageName: String
    let pieceSize: CGFloat
    let gridSize: Int
    
    var body: some View {
        // Calculate which row and column this piece represents
        let row = piece.correctPosition / gridSize
        let col = piece.correctPosition % gridSize
        
        // The full image will be scaled to this size (3 * pieceSize for 3x3 grid)
        let fullImageSize = pieceSize * CGFloat(gridSize)
        
        // Calculate offset to show the correct portion
        // We need to move the image so the correct piece portion is visible in the center
        // For row=0, col=0: we want to see top-left, so shift image right (+) and down (+)
        // For row=1, col=1: we want to see center, so no shift needed (0, 0)
        // For row=2, col=2: we want to see bottom-right, so shift image left (-) and up (-)
        let centerOffset = CGFloat(gridSize - 1) / 2.0  // For 3x3, this is 1.0
        let offsetX = (centerOffset - CGFloat(col)) * pieceSize
        let offsetY = (centerOffset - CGFloat(row)) * pieceSize
        
        // Container that defines the piece size and clips the content
        Color.clear
            .frame(width: pieceSize, height: pieceSize)
            .background(
                Image(imageName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill) // Force the image to be square
                    .frame(width: fullImageSize, height: fullImageSize)
                    .offset(x: offsetX, y: offsetY)
            )
            .clipped()
            .cornerRadius(6)
    }
}

// MARK: - Preview
#if DEBUG
struct JigsawPuzzleView_Previews: PreviewProvider {
    static var previews: some View {
        JigsawPuzzleView(
            puzzle: JigsawPuzzle.generate(),
            onComplete: {},
            onDismiss: {}
        )
    }
}
#endif