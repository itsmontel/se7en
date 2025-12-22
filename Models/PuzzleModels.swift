import Foundation
import SwiftUI

// MARK: - Puzzle Types

enum PuzzleType: String, CaseIterable {
    case sudoku = "Sudoku"
    case memory = "Memory"
    case pattern = "Pattern"
    case jigsaw = "Jigsaw"
    
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
        // Generate a valid 6x6 Sudoku solution
        // 6x6 Sudoku uses 2x3 boxes (2 rows, 3 columns per box)
        var solution = [[Int]]()
        
        // Pre-defined valid solutions for 6x6 Sudoku
        let validSolutions = [
            [[1, 2, 3, 4, 5, 6], [4, 5, 6, 1, 2, 3], [2, 3, 1, 5, 6, 4], [5, 6, 4, 2, 3, 1], [3, 1, 2, 6, 4, 5], [6, 4, 5, 3, 1, 2]],
            [[2, 3, 4, 5, 6, 1], [5, 6, 1, 2, 3, 4], [3, 4, 2, 6, 1, 5], [6, 1, 5, 3, 4, 2], [4, 2, 3, 1, 5, 6], [1, 5, 6, 4, 2, 3]],
            [[3, 4, 5, 6, 1, 2], [6, 1, 2, 3, 4, 5], [4, 5, 3, 1, 2, 6], [1, 2, 6, 4, 5, 3], [5, 3, 4, 2, 6, 1], [2, 6, 1, 5, 3, 4]],
            [[4, 5, 6, 1, 2, 3], [1, 2, 3, 4, 5, 6], [5, 6, 4, 2, 3, 1], [2, 3, 1, 5, 6, 4], [6, 4, 5, 3, 1, 2], [3, 1, 2, 6, 4, 5]],
            [[5, 6, 1, 2, 3, 4], [2, 3, 4, 5, 6, 1], [6, 1, 5, 3, 4, 2], [3, 4, 2, 6, 1, 5], [1, 5, 6, 4, 2, 3], [4, 2, 3, 1, 5, 6]],
            [[6, 1, 2, 3, 4, 5], [3, 4, 5, 6, 1, 2], [1, 2, 6, 4, 5, 3], [4, 5, 3, 1, 2, 6], [2, 6, 1, 5, 3, 4], [5, 3, 4, 2, 6, 1]],
            [[1, 3, 5, 2, 4, 6], [2, 4, 6, 1, 3, 5], [3, 5, 1, 4, 6, 2], [4, 6, 2, 3, 5, 1], [5, 1, 3, 6, 2, 4], [6, 2, 4, 5, 1, 3]],
            [[1, 4, 2, 5, 3, 6], [3, 6, 5, 1, 4, 2], [2, 1, 4, 6, 5, 3], [5, 3, 6, 2, 1, 4], [4, 2, 1, 3, 6, 5], [6, 5, 3, 4, 2, 1]],
            [[2, 5, 3, 6, 4, 1], [4, 1, 6, 2, 5, 3], [3, 2, 5, 1, 6, 4], [6, 4, 1, 3, 2, 5], [5, 3, 2, 4, 1, 6], [1, 6, 4, 5, 3, 2]],
            [[3, 6, 4, 1, 5, 2], [5, 2, 1, 3, 6, 4], [4, 3, 6, 2, 1, 5], [1, 5, 2, 4, 3, 6], [6, 4, 3, 5, 2, 1], [2, 1, 5, 6, 4, 3]],
            [[4, 1, 5, 2, 6, 3], [6, 3, 2, 4, 1, 5], [5, 4, 1, 3, 2, 6], [2, 6, 3, 5, 4, 1], [1, 5, 4, 6, 3, 2], [3, 2, 6, 1, 5, 4]],
            [[5, 2, 6, 3, 1, 4], [1, 4, 3, 5, 2, 6], [6, 5, 2, 4, 3, 1], [3, 1, 4, 6, 5, 2], [2, 6, 5, 1, 4, 3], [4, 3, 1, 2, 6, 5]],
            [[6, 3, 1, 4, 2, 5], [2, 5, 4, 6, 3, 1], [1, 6, 3, 5, 4, 2], [4, 2, 5, 1, 6, 3], [3, 1, 6, 2, 5, 4], [5, 4, 2, 3, 1, 6]],
            [[1, 5, 4, 3, 6, 2], [3, 2, 6, 1, 5, 4], [4, 1, 5, 6, 2, 3], [6, 3, 2, 4, 1, 5], [5, 4, 1, 2, 3, 6], [2, 6, 3, 5, 4, 1]],
            [[2, 6, 5, 4, 1, 3], [4, 3, 1, 2, 6, 5], [5, 2, 6, 1, 3, 4], [1, 4, 3, 5, 2, 6], [6, 5, 2, 3, 4, 1], [3, 1, 4, 6, 5, 2]],
            [[3, 1, 6, 5, 2, 4], [5, 4, 2, 3, 1, 6], [6, 3, 1, 2, 4, 5], [2, 5, 4, 6, 3, 1], [1, 6, 3, 4, 5, 2], [4, 2, 5, 1, 6, 3]],
            [[4, 2, 1, 6, 3, 5], [6, 5, 3, 4, 2, 1], [1, 4, 2, 3, 5, 6], [3, 6, 5, 1, 4, 2], [2, 1, 4, 5, 6, 3], [5, 3, 6, 2, 1, 4]],
            [[5, 3, 2, 1, 4, 6], [1, 6, 4, 5, 3, 2], [2, 5, 3, 4, 6, 1], [4, 1, 6, 2, 5, 3], [3, 2, 5, 6, 1, 4], [6, 4, 1, 3, 2, 5]],
            [[6, 4, 3, 2, 5, 1], [2, 1, 5, 6, 4, 3], [3, 6, 4, 5, 1, 2], [5, 2, 1, 3, 6, 4], [4, 3, 6, 1, 2, 5], [1, 5, 2, 4, 3, 6]],
            [[1, 6, 5, 4, 2, 3], [4, 3, 2, 1, 6, 5], [5, 1, 6, 3, 4, 2], [2, 4, 3, 6, 1, 5], [6, 5, 1, 2, 3, 4], [3, 2, 4, 5, 6, 1]]
        ]
        
        solution = validSolutions.randomElement()!
        
        // Create puzzle by removing some numbers (keep 26-28 cells filled for 6x6)
        var puzzle = solution.map { $0.map { Optional($0) } }
        let cellsToRemove = Int.random(in: 8...10)
        var removed = 0
        
        while removed < cellsToRemove {
            let row = Int.random(in: 0..<6)
            let col = Int.random(in: 0..<6)
            if puzzle[row][col] != nil {
                puzzle[row][col] = nil
                removed += 1
            }
        }
        
        return SudokuPuzzle(solution: solution, initialGrid: puzzle)
    }
    
    func isValidMove(_ number: Int, at row: Int, col: Int, in grid: [[Int?]]) -> Bool {
        // Check row
        for c in 0..<6 {
            if c != col && grid[row][c] == number {
                return false
            }
        }
        
        // Check column
        for r in 0..<6 {
            if r != row && grid[r][col] == number {
                return false
            }
        }
        
        // Check 2x3 box (6x6 Sudoku uses 2 rows x 3 columns boxes)
        let boxRow = (row / 2) * 2
        let boxCol = (col / 3) * 3
        for r in boxRow..<boxRow + 2 {
            for c in boxCol..<boxCol + 3 {
                if (r != row || c != col) && grid[r][c] == number {
                    return false
                }
            }
        }
        
        return true
    }
    
    func isComplete(_ grid: [[Int?]]) -> Bool {
        for row in 0..<6 {
            for col in 0..<6 {
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
        // Compare both ID and matched state so SwiftUI detects changes
        lhs.id == rhs.id && lhs.isMatched == rhs.isMatched && lhs.isFlipped == rhs.isFlipped
    }
}

struct MemoryGame {
    let cards: [MemoryCard]
    
    static func generate() -> MemoryGame {
        // 8 pairs for 4x4 grid (16 cards total)
        let symbols = ["🎮", "🎯", "🎪", "🎨", "🎭", "🎸", "🎲", "🎺"]
        
        var cards: [MemoryCard] = []
        for symbol in symbols {
            cards.append(MemoryCard(value: symbol))
            cards.append(MemoryCard(value: symbol))
        }
        
        // Shuffle for random placement
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
    case pentagon = "pentagon.fill"
    
    var color: Color {
        switch self {
        case .circle: return .blue
        case .square: return .red
        case .triangle: return .green
        case .diamond: return .orange
        case .star: return .yellow
        case .heart: return .pink
        case .hexagon: return .purple
        case .pentagon: return .cyan
        }
    }
}

struct PatternSequence {
    let elements: [PatternElement]
    let length: Int
    
    static func generate(length: Int = 6) -> PatternSequence {
        // Generate exactly 'length' random elements
        var elements: [PatternElement] = []
        for _ in 0..<length {
            elements.append(PatternElement.allCases.randomElement()!)
        }
        return PatternSequence(elements: elements, length: length)
    }
    
    func matches(_ userInput: [PatternElement]) -> Bool {
        return userInput == elements
    }
}

// MARK: - Jigsaw Puzzle Models

// MARK: - Jigsaw Edge Type
enum JigsawEdge {
    case flat    // Border edge - straight line
    case tab     // Bump outward (male)
    case blank   // Indent inward (female)
}

// MARK: - Jigsaw Piece
struct JigsawPiece: Identifiable, Equatable {
    let id = UUID()
    let correctPosition: Int // 0-8 for 3x3 grid (where this piece SHOULD be)
    let topEdge: JigsawEdge
    let rightEdge: JigsawEdge
    let bottomEdge: JigsawEdge
    let leftEdge: JigsawEdge
    
    static func == (lhs: JigsawPiece, rhs: JigsawPiece) -> Bool {
        lhs.id == rhs.id && lhs.correctPosition == rhs.correctPosition
    }
}

// MARK: - Jigsaw Puzzle
struct JigsawPuzzle {
    let imageName: String
    let shuffledPieces: [JigsawPiece]
    static let gridSize = 3 // 3x3 grid
    
    // All 25 pet mood images (5 pets × 5 moods)
    static let allPetImages: [String] = {
        let petTypes = ["dog", "cat", "bunny", "hamster", "horse"]
        let healthStates = ["fullhealth", "happy", "content", "sad", "sick"]
        
        var images: [String] = []
        for pet in petTypes {
            for state in healthStates {
                images.append("\(pet)\(state)")
            }
        }
        return images
    }()
    
    static func generate() -> JigsawPuzzle {
        // Pick a random pet mood image from the 25 available
        let randomImage = allPetImages.randomElement() ?? "dogfullhealth"
        return generate(withImage: randomImage)
    }
    
    // Generate with a specific image
    static func generate(withImage imageName: String) -> JigsawPuzzle {
        // Create 9 pieces (3x3 grid) with proper interlocking edges
        var pieces: [JigsawPiece] = []
        
        // Define edge patterns - adjacent pieces must have matching tab/blank
        // We'll use a deterministic pattern for edge matching
        let edgePattern: [[JigsawEdge]] = generateEdgePattern()
        
        for position in 0..<9 {
            let row = position / gridSize
            let col = position % gridSize
            
            // Top edge: flat if row 0, otherwise opposite of piece above's bottom
            let topEdge: JigsawEdge = row == 0 ? .flat : edgePattern[row - 1][col]
            
            // Left edge: flat if col 0, otherwise opposite of piece left's right
            let leftEdge: JigsawEdge = col == 0 ? .flat : (edgePattern[row][col - 1] == .tab ? .blank : .tab)
            
            // Bottom edge: flat if last row, otherwise random tab/blank
            let bottomEdge: JigsawEdge = row == gridSize - 1 ? .flat : edgePattern[row][col]
            
            // Right edge: flat if last col, otherwise random tab/blank
            let rightEdge: JigsawEdge = col == gridSize - 1 ? .flat : (Bool.random() ? .tab : .blank)
            
            pieces.append(JigsawPiece(
                correctPosition: position,
                topEdge: topEdge,
                rightEdge: rightEdge,
                bottomEdge: bottomEdge,
                leftEdge: leftEdge
            ))
        }
        
        // Shuffle pieces ensuring none start in correct position
        var shuffled = pieces.shuffled()
        while countCorrectPositions(shuffled) > 2 {
            shuffled.shuffle()
        }
        
        return JigsawPuzzle(imageName: imageName, shuffledPieces: shuffled)
    }
    
    // Generate random edge pattern for bottom edges (determines interlocking)
    private static func generateEdgePattern() -> [[JigsawEdge]] {
        var pattern: [[JigsawEdge]] = []
        for _ in 0..<gridSize {
            var row: [JigsawEdge] = []
            for _ in 0..<gridSize {
                row.append(Bool.random() ? .tab : .blank)
            }
            pattern.append(row)
        }
        return pattern
    }
    
    // Check if puzzle is solved
    func isSolved(_ currentPieces: [JigsawPiece]) -> Bool {
        for (index, piece) in currentPieces.enumerated() {
            if piece.correctPosition != index {
                return false
            }
        }
        return true
    }
    
    // Reshuffle the current pieces
    func reshufflePieces(_ currentPieces: [JigsawPiece]) -> [JigsawPiece] {
        var shuffled = currentPieces.shuffled()
        while JigsawPuzzle.countCorrectPositions(shuffled) > 2 {
            shuffled.shuffle()
        }
        return shuffled
    }
    
    // Count how many pieces are in correct position
    private static func countCorrectPositions(_ pieces: [JigsawPiece]) -> Int {
        var count = 0
        for (index, piece) in pieces.enumerated() {
            if piece.correctPosition == index {
                count += 1
            }
        }
        return count
    }
}

