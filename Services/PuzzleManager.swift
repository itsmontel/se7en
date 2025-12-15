import Foundation
import Combine

@MainActor
class PuzzleManager: ObservableObject {
    static let shared = PuzzleManager()
    
    @Published var currentPuzzle: PuzzleType?
    @Published var puzzleExtensions: [String: [PuzzleExtension]] = [:] // appBundleID: [extensions]
    
    private let extensionMinutes = 15
    private let maxExtensionsPerDay = 10 // Prevent infinite extensions
    
    init() {
        loadExtensions()
    }
    
    // MARK: - Puzzle Selection
    
    func selectRandomPuzzle() -> PuzzleType {
        return PuzzleType.allCases.randomElement() ?? .sudoku
    }
    
    // MARK: - Extension Management
    
    func getExtensionsForApp(_ bundleID: String, today: Date = Date()) -> [PuzzleExtension] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return puzzleExtensions[bundleID]?.filter { ext in
            ext.timestamp >= startOfDay && ext.timestamp < endOfDay
        } ?? []
    }
    
    func getTotalExtensionMinutes(for bundleID: String, today: Date = Date()) -> Int {
        return getExtensionsForApp(bundleID, today: today).reduce(0) { $0 + $1.minutesGranted }
    }
    
    func canExtendApp(_ bundleID: String, today: Date = Date()) -> Bool {
        let todayExtensions = getExtensionsForApp(bundleID, today: today)
        return todayExtensions.count < maxExtensionsPerDay
    }
    
    func grantExtension(for bundleID: String, puzzleType: PuzzleType) {
        guard canExtendApp(bundleID) else {
            print("⚠️ Max extensions reached for app: \(bundleID)")
            return
        }
        
        let puzzleExt = PuzzleExtension(
            appBundleID: bundleID,
            minutesGranted: extensionMinutes,
            timestamp: Date(),
            puzzleType: puzzleType
        )
        
        if puzzleExtensions[bundleID] == nil {
            puzzleExtensions[bundleID] = []
        }
        puzzleExtensions[bundleID]?.append(puzzleExt)
        
        saveExtensions()
        
        print("✅ Granted \(extensionMinutes) minutes extension for \(bundleID) via \(puzzleType.rawValue) puzzle")
    }
    
    // MARK: - Persistence
    
    private func saveExtensions() {
        let encoder = JSONEncoder()
        var data: [String: Data] = [:]
        
        for (bundleID, extensions) in puzzleExtensions {
            if let encoded = try? encoder.encode(extensions) {
                data[bundleID] = encoded
            }
        }
        
        UserDefaults.standard.set(data, forKey: "puzzle_extensions")
    }
    
    private func loadExtensions() {
        guard let data = UserDefaults.standard.dictionary(forKey: "puzzle_extensions") as? [String: Data] else {
            return
        }
        
        let decoder = JSONDecoder()
        for (bundleID, encoded) in data {
            if let extensions = try? decoder.decode([PuzzleExtension].self, from: encoded) {
                puzzleExtensions[bundleID] = extensions
            }
        }
    }
}

// MARK: - PuzzleExtension Codable

extension PuzzleExtension: Codable {
    enum CodingKeys: String, CodingKey {
        case appBundleID
        case minutesGranted
        case timestamp
        case puzzleType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appBundleID = try container.decode(String.self, forKey: .appBundleID)
        minutesGranted = try container.decode(Int.self, forKey: .minutesGranted)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        let typeString = try container.decode(String.self, forKey: .puzzleType)
        puzzleType = PuzzleType(rawValue: typeString) ?? .sudoku
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appBundleID, forKey: .appBundleID)
        try container.encode(minutesGranted, forKey: .minutesGranted)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(puzzleType.rawValue, forKey: .puzzleType)
    }
}










