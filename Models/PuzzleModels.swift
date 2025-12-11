import Foundation
import SwiftUI

// MARK: - Puzzle Types

enum PuzzleType: String, CaseIterable {
    case sudoku = "Sudoku"
    case memory = "Memory"
    case pattern = "Pattern"
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Puzzle Result

struct PuzzleResult {
    let type: PuzzleType
    let solved: Bool
    let timeTaken: TimeInterval
    let appBundleID: String
    let timestamp: Date
}

// MARK: - Puzzle Extension Record

struct PuzzleExtension {
    let appBundleID: String
    let minutesGranted: Int
    let timestamp: Date
    let puzzleType: PuzzleType
}

// MARK: - Sudoku Models

struct SudokuPuzzle {
    let solution: [[Int]]
    let initialGrid: [[Int?]]
    
    static func generate() -> SudokuPuzzle {
        // Generate a valid 4x4 Sudoku solution
        var solution = [[Int]]()
        
        // Pre-defined valid solutions for 4x4 Sudoku
        let validSolutions = [
            [[1, 2, 3, 4], [3, 4, 1, 2], [2, 3, 4, 1], [4, 1, 2, 3]],
            [[2, 3, 4, 1], [4, 1, 2, 3], [1, 4, 3, 2], [3, 2, 1, 4]],
            [[3, 4, 1, 2], [1, 2, 3, 4], [4, 1, 2, 3], [2, 3, 4, 1]],
            [[4, 1, 2, 3], [2, 3, 4, 1], [3, 2, 1, 4], [1, 4, 3, 2]],
            [[1, 3, 2, 4], [2, 4, 3, 1], [3, 2, 4, 1], [4, 1, 3, 2]]
        ]
        
        solution = validSolutions.randomElement()!
        
        // Create puzzle by removing some numbers (keep 8-10 cells filled)
        var puzzle = solution.map { $0.map { Optional($0) } }
        let cellsToRemove = Int.random(in: 6...8)
        var removed = 0
        
        while removed < cellsToRemove {
            let row = Int.random(in: 0..<4)
            let col = Int.random(in: 0..<4)
            if puzzle[row][col] != nil {
                puzzle[row][col] = nil
                removed += 1
            }
        }
        
        return SudokuPuzzle(solution: solution, initialGrid: puzzle)
    }
    
    func isValidMove(_ number: Int, at row: Int, col: Int, in grid: [[Int?]]) -> Bool {
        // Check row
        for c in 0..<4 {
            if c != col && grid[row][c] == number {
                return false
            }
        }
        
        // Check column
        for r in 0..<4 {
            if r != row && grid[r][col] == number {
                return false
            }
        }
        
        // Check 2x2 box
        let boxRow = (row / 2) * 2
        let boxCol = (col / 2) * 2
        for r in boxRow..<boxRow + 2 {
            for c in boxCol..<boxCol + 2 {
                if (r != row || c != col) && grid[r][c] == number {
                    return false
                }
            }
        }
        
        return true
    }
    
    func isComplete(_ grid: [[Int?]]) -> Bool {
        for row in 0..<4 {
            for col in 0..<4 {
                if grid[row][col] == nil || grid[row][col] != solution[row][col] {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: - Memory Game Models

struct MemoryCard: Identifiable, Equatable {
    let id = UUID()
    let value: String
    var isFlipped = false
    var isMatched = false
    
    static func == (lhs: MemoryCard, rhs: MemoryCard) -> Bool {
        lhs.id == rhs.id
    }
}

struct MemoryGame {
    let cards: [MemoryCard]
    
    static func generate() -> MemoryGame {
        let symbols = ["🎮", "🎯", "🎪", "🎨", "🎭", "🎸", "🎺", "🎹"]
        
        var cards: [MemoryCard] = []
        for symbol in symbols {
            cards.append(MemoryCard(value: symbol))
            cards.append(MemoryCard(value: symbol))
        }
        
        cards.shuffle()
        
        return MemoryGame(cards: cards)
    }
}

// MARK: - Pattern Game Models

enum PatternElement: String, CaseIterable {
    case circle = "circle.fill"
    case square = "square.fill"
    case triangle = "triangle.fill"
    case diamond = "diamond.fill"
    case star = "star.fill"
    case heart = "heart.fill"
    case hexagon = "hexagon.fill"
    
    var color: Color {
        switch self {
        case .circle: return .blue
        case .square: return .red
        case .triangle: return .green
        case .diamond: return .orange
        case .star: return .yellow
        case .heart: return .pink
        case .hexagon: return .purple
        }
    }
}

struct PatternSequence {
    let elements: [PatternElement]
    let length: Int
    
    static func generate(length: Int = 7) -> PatternSequence {
        let elements = (0..<length).map { _ in PatternElement.allCases.randomElement()! }
        return PatternSequence(elements: elements, length: length)
    }
    
    func matches(_ userInput: [PatternElement]) -> Bool {
        return userInput == elements
    }
}

