import SwiftUI

// MARK: - Sudoku View
struct SudokuView: View {
    let puzzle: SudokuPuzzle
    let onComplete: () -> Void
    let onDismiss: () -> Void
    
    @State private var grid: [[Int?]]
    @State private var selectedCell: (row: Int, col: Int)? = nil
    @State private var showSuccess = false
    @State private var showIncorrect = false
    @State private var errorCells: Set<String> = []
    @State private var isCheckingCompletion = false
    
    init(puzzle: SudokuPuzzle, onComplete: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.puzzle = puzzle
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        _grid = State(initialValue: puzzle.initialGrid)
        
        // Debug: Verify puzzle consistency at initialization
        print("=== SUDOKU VIEW INIT ===")
        print("First row of initialGrid: \(puzzle.initialGrid[0].map { $0 ?? 0 })")
        print("First row of solution: \(puzzle.solution[0])")
        print("========================")
    }
    
    var filledCells: Int {
        grid.flatMap { $0 }.compactMap { $0 }.count
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerView
            
            // Sudoku Grid
            sudokuGridView
            
            // Number Pad
            numberPadView
            
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
                } else if showIncorrect {
                    IncorrectOverlay(
                        message: "Incorrect Solution",
                        onDismiss: {
                            showIncorrect = false
                        }
                    )
                }
            }
        )
    }
    
    // MARK: - Header View
    private var headerView: some View {
            VStack(spacing: 8) {
                Text("Sudoku 6×6")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Fill all cells with numbers 1-6")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Text("\(filledCells) / 36 cells filled")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
            .padding(.top, 20)
    }
            
    // MARK: - Sudoku Grid View
    private var sudokuGridView: some View {
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { col in
                            SudokuCell(
                                value: grid[row][col],
                                isSelected: selectedCell?.row == row && selectedCell?.col == col,
                            isGiven: puzzle.initialGrid[row][col] != nil,
                            showsError: errorCells.contains("\(row)-\(col)"),
                                isTopBorder: row % 2 == 0,
                            isBottomBorder: row == 5 || (row + 1) % 2 == 0,
                                isLeftBorder: col % 3 == 0,
                            isRightBorder: col == 5 || (col + 1) % 3 == 0,
                                onTap: {
                                selectCell(row: row, col: col)
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
    }
            
    // MARK: - Number Pad View
    private var numberPadView: some View {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(1...6, id: \.self) { number in
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
    }
    
    // MARK: - Actions
    private func selectCell(row: Int, col: Int) {
        guard puzzle.initialGrid[row][col] == nil else {
            HapticFeedback.error.trigger()
            return
        }
        selectedCell = (row, col)
        HapticFeedback.light.trigger()
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
        
        // Update grid
        grid[cell.row][cell.col] = number
        
        // Check if valid
        if puzzle.isValidMove(number, at: cell.row, col: cell.col, in: grid) {
            errorCells.remove(cellKey)
            HapticFeedback.success.trigger()
        } else {
            errorCells.insert(cellKey)
            HapticFeedback.error.trigger()
        }
        
        // Check completion
        checkCompletion()
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
        
        checkCompletion()
    }
    
    private func checkCompletion() {
        guard !isCheckingCompletion else { return }
        
        // Check if all cells are filled
        let allFilled = grid.allSatisfy { row in
            row.allSatisfy { $0 != nil }
        }
        
        guard allFilled else { return }
        
        // Check if solution is correct
        isCheckingCompletion = true
        
        // Debug: Print the grids
        print("=== CHECKING COMPLETION ===")
        print("Current Grid:")
        for row in grid {
            print(row.map { $0 ?? 0 })
        }
        print("\nExpected Solution:")
        for row in puzzle.solution {
            print(row)
        }
        
        var isCorrect = true
        var mismatches: [(Int, Int)] = []
        for row in 0..<6 {
            for col in 0..<6 {
                if grid[row][col] != puzzle.solution[row][col] {
                    isCorrect = false
                    mismatches.append((row, col))
                    print("Mismatch at [\(row)][\(col)]: grid=\(grid[row][col] ?? -1), solution=\(puzzle.solution[row][col])")
                }
            }
        }
        print("Is Correct: \(isCorrect)")
        print("========================")
        
        if isCorrect {
            showSuccess = true
            showIncorrect = false
            HapticFeedback.success.trigger()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onComplete()
            }
        } else {
            showIncorrect = true
            showSuccess = false
            HapticFeedback.error.trigger()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showIncorrect = false
            }
        }
        
        isCheckingCompletion = false
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
            ZStack {
                // Background
                backgroundColor
                
                // Value text
                if let value = value {
                    Text("\(value)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)
                }
            }
            .frame(width: 50, height: 50)
            .overlay(cellBorders)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: some View {
                Group {
                    if showsError {
                        Color.red.opacity(0.15)
                    } else if isSelected {
                        Color.blue.opacity(0.25)
                    } else {
                        Color.white
                    }
        }
    }
    
    private var textColor: Color {
        if isGiven {
            return .primary
        } else if showsError {
            return .red
        } else {
            return .blue
                }
            }
    
    private var cellBorders: some View {
        ZStack {
            // Light cell border
                Rectangle()
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
            
            // Bold borders for boxes
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
        }
    }
}

// MARK: - Number Button
struct NumberButton: View {
    let number: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.light.trigger()
            action()
        }) {
            Text("\(number)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
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
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Clear Button
struct ClearButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.light.trigger()
            action()
        }) {
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
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Hint Button
struct HintButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.light.trigger()
            action()
        }) {
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
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Incorrect Overlay
struct IncorrectOverlay: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text(message)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20)
            .padding(40)
        }
    }
}
