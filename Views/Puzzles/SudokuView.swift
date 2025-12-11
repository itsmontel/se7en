import SwiftUI

// MARK: - Sudoku View
struct SudokuView: View {
    let puzzle: SudokuPuzzle
    let onComplete: () -> Void
    let onDismiss: () -> Void
    
    @State private var grid: [[Int?]]
    @State private var selectedCell: (row: Int, col: Int)? = nil
    @State private var showSuccess = false
    @State private var errorCells: Set<String> = []
    
    init(puzzle: SudokuPuzzle, onComplete: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.puzzle = puzzle
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        _grid = State(initialValue: puzzle.initialGrid)
    }
    
    var filledCells: Int {
        grid.flatMap { $0 }.compactMap { $0 }.count
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Sudoku 4×4")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Fill all cells with numbers 1-4")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Text("\(filledCells) / 16 cells filled")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
            .padding(.top, 20)
            
            // Sudoku Grid
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { col in
                            let isGiven = puzzle.initialGrid[row][col] != nil
                            let cellKey = "\(row)-\(col)"
                            SudokuCell(
                                value: grid[row][col],
                                isSelected: selectedCell?.row == row && selectedCell?.col == col,
                                isGiven: isGiven,
                                showsError: errorCells.contains(cellKey),
                                isTopBorder: row == 0 || row == 2,
                                isBottomBorder: row == 1 || row == 3,
                                isLeftBorder: col == 0 || col == 2,
                                isRightBorder: col == 1 || col == 3,
                                onTap: {
                                    if !isGiven {
                                        selectedCell = (row, col)
                                        HapticFeedback.light.trigger()
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 20)
            
            // Number Pad
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(1...4, id: \.self) { number in
                        NumberButton(number: number) {
                            enterNumber(number)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    ClearButton {
                        clearCell()
                    }
                    
                    HintButton {
                        showHint()
                    }
                }
            }
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
                    SuccessOverlay(message: "Puzzle Solved!", emoji: "🎉")
                }
            }
        )
    }
    
    private func enterNumber(_ number: Int) {
        guard let cell = selectedCell else {
            HapticFeedback.error.trigger()
            return
        }
        
        guard puzzle.initialGrid[cell.row][cell.col] == nil else {
            HapticFeedback.error.trigger()
            return
        }
        
        let cellKey = "\(cell.row)-\(cell.col)"
        
        if puzzle.isValidMove(number, at: cell.row, col: cell.col, in: grid) {
            grid[cell.row][cell.col] = number
            errorCells.remove(cellKey)
            HapticFeedback.success.trigger()
            
            if puzzle.isComplete(grid) {
                showSuccess = true
                HapticFeedback.success.trigger()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onComplete()
                }
            }
        } else {
            grid[cell.row][cell.col] = number
            errorCells.insert(cellKey)
            HapticFeedback.error.trigger()
        }
    }
    
    private func clearCell() {
        guard let cell = selectedCell else {
            HapticFeedback.error.trigger()
            return
        }
        
        guard puzzle.initialGrid[cell.row][cell.col] == nil else {
            HapticFeedback.error.trigger()
            return
        }
        
        grid[cell.row][cell.col] = nil
        errorCells.remove("\(cell.row)-\(cell.col)")
        HapticFeedback.light.trigger()
    }
    
    private func showHint() {
        guard let cell = selectedCell else {
            HapticFeedback.error.trigger()
            return
        }
        
        guard puzzle.initialGrid[cell.row][cell.col] == nil else {
            HapticFeedback.error.trigger()
            return
        }
        
        let correctNumber = puzzle.solution[cell.row][cell.col]
        grid[cell.row][cell.col] = correctNumber
        errorCells.remove("\(cell.row)-\(cell.col)")
        HapticFeedback.success.trigger()
        
        if puzzle.isComplete(grid) {
            showSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onComplete()
            }
        }
    }
}

// MARK: - Sudoku Cell
struct SudokuCell: View {
    let value: Int?
    let isSelected: Bool
    let isGiven: Bool
    let showsError: Bool
    let isTopBorder: Bool
    let isBottomBorder: Bool
    let isLeftBorder: Bool
    let isRightBorder: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(value != nil ? "\(value!)" : "")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(isGiven ? .primary : (showsError ? .red : .blue))
                .frame(width: 70, height: 70)
                .background(
                    Group {
                        if showsError {
                            Color.red.opacity(0.1)
                        } else if isSelected {
                            Color.blue.opacity(0.2)
                        } else {
                            Color.white
                        }
                    }
                )
                .overlay(
                    Rectangle()
                        .strokeBorder(
                            Color.gray.opacity(0.3),
                            lineWidth: 0.5
                        )
                )
                .overlay(
                    VStack(spacing: 0) {
                        if isTopBorder {
                            Rectangle()
                                .fill(Color.primary)
                                .frame(height: 2)
                        }
                        Spacer()
                        if isBottomBorder {
                            Rectangle()
                                .fill(Color.primary)
                                .frame(height: 2)
                        }
                    }
                )
                .overlay(
                    HStack(spacing: 0) {
                        if isLeftBorder {
                            Rectangle()
                                .fill(Color.primary)
                                .frame(width: 2)
                        }
                        Spacer()
                        if isRightBorder {
                            Rectangle()
                                .fill(Color.primary)
                                .frame(width: 2)
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Number Button
struct NumberButton: View {
    let number: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Clear Button
struct ClearButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                Text("Clear")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.red)
            .cornerRadius(12)
            .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Hint Button
struct HintButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                Text("Hint")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.orange)
            .cornerRadius(12)
            .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}


