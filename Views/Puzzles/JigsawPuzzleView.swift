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
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 90, height: 90)
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
                        
                        BoardSlotView(
                            slotIndex: slotIndex,
                            placedPieceID: placedPieces[slotIndex],
                            allPieces: puzzle.shuffledPieces,
                            imageName: puzzle.imageName,
                            pieceSize: pieceSize,
                            gridSize: gridSize,
                            isHighlighted: hasSelection,
                            isSelected: isSlotSelected(slotIndex)
                        )
                        .onTapGesture {
                            handleSlotTap(slotIndex)
                        }
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
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                    spacing: 8
                ) {
                    ForEach(trayPieces) { piece in
                        TrayPieceView(
                            piece: piece,
                            imageName: puzzle.imageName,
                            pieceSize: pieceSize,
                            gridSize: gridSize,
                            isSelected: selectedPieceID == piece.id
                        )
                        .onTapGesture {
                            handleTrayPieceTap(piece)
                        }
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
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedPieceID == piece.id {
                // Deselect if tapping same piece
                selectedPieceID = nil
            } else {
                // Select this piece
                selectedPieceID = piece.id
            }
        }
    }
    
    // MARK: - Handle Slot Tap
    private func handleSlotTap(_ slotIndex: Int) {
        // If no piece selected, check if there's a piece in this slot to select
        if selectedPieceID == nil {
            if let pieceID = placedPieces[slotIndex] {
                // Select this placed piece
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedPieceID = pieceID
                }
                HapticFeedback.light.trigger()
            }
            return
        }
        
        guard let selectedID = selectedPieceID else { return }
        
        // Find the selected piece
        guard let piece = puzzle.shuffledPieces.first(where: { $0.id == selectedID }) else { return }
        
        // Check if this piece is already on the board somewhere
        let currentSlot = placedPieces.first(where: { $0.value == selectedID })?.key
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // If there's already a piece in target slot, swap or send to tray
            if let existingPieceID = placedPieces[slotIndex] {
                if let currentSlot = currentSlot {
                    // Swap the pieces
                    placedPieces[currentSlot] = existingPieceID
                }
                // Otherwise existing piece goes back to tray (removed from placedPieces)
                else {
                    placedPieces.removeValue(forKey: slotIndex)
                }
            } else {
                // Remove from current slot if it was placed somewhere
                if let currentSlot = currentSlot {
                    placedPieces.removeValue(forKey: currentSlot)
                }
            }
            
            // Place the selected piece in the target slot
            placedPieces[slotIndex] = selectedID
            selectedPieceID = nil
        }
        
        moves += 1
        
        // Haptic feedback
        if piece.correctPosition == slotIndex {
            HapticFeedback.success.trigger()
        } else {
            HapticFeedback.medium.trigger()
        }
        
        // Check completion
        checkCompletion()
    }
    
    // MARK: - Reset Puzzle
    private func resetPuzzle() {
        withAnimation(.spring(response: 0.4)) {
            placedPieces.removeAll()
            selectedPieceID = nil
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
    
    var placedPiece: JigsawPiece? {
        guard let pieceID = placedPieceID else { return nil }
        return allPieces.first { $0.id == pieceID }
    }
    
    var isCorrect: Bool {
        guard let piece = placedPiece else { return false }
        return piece.correctPosition == slotIndex
    }
    
    var body: some View {
        ZStack {
            // Slot background
            RoundedRectangle(cornerRadius: 8)
                .fill(isHighlighted ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.blue :
                            (isHighlighted ? Color.blue.opacity(0.4) : Color.gray.opacity(0.2)),
                            style: StrokeStyle(
                                lineWidth: isSelected ? 3 : (placedPieceID == nil ? 2 : 1),
                                dash: placedPieceID == nil ? [5, 3] : []
                            )
                        )
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
                        .stroke(isCorrect ? Color.green : Color.clear, lineWidth: 2)
                )
                .overlay(
                    Group {
                        if isCorrect {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                                .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                                .offset(x: pieceSize / 2 - 12, y: -pieceSize / 2 + 12)
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
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.1),
                radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Piece Image View
struct PieceImageView: View {
    let piece: JigsawPiece
    let imageName: String
    let pieceSize: CGFloat
    let gridSize: Int
    
    var body: some View {
        let row = piece.correctPosition / gridSize
        let col = piece.correctPosition % gridSize
        let fullImageSize = pieceSize * CGFloat(gridSize)
        
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: fullImageSize, height: fullImageSize)
            .offset(
                x: -CGFloat(col) * pieceSize,
                y: -CGFloat(row) * pieceSize
            )
            .frame(width: pieceSize, height: pieceSize)
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
