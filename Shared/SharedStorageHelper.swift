//
//  SharedStorageHelper.swift
//  SE7EN
//
//  Shared storage utilities for App Group communication
//

import Foundation
import FamilyControls
import ManagedSettings

final class SharedStorageHelper {
    static let shared = SharedStorageHelper()
    
    private let appGroupID = "group.com.se7en.app"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    private init() {}
    
    // MARK: - Puzzle Tracking
    
    /// Mark that a puzzle is needed for a specific application
    func setNeedsPuzzle(for application: Application, value: Bool) {
        guard let token = application.token else { return }
        let tokenHash = String(token.hashValue)
        setNeedsPuzzle(for: tokenHash, value: value)
    }
    
    /// Mark that a puzzle is needed for a token hash
    func setNeedsPuzzle(for tokenHash: String, value: Bool) {
        let key = "needsPuzzle_\(tokenHash)"
        sharedDefaults?.set(value, forKey: key)
        sharedDefaults?.synchronize()
        print("💾 SharedStorage: Set needsPuzzle for \(tokenHash.prefix(8))... = \(value)")
    }
    
    /// Check if a puzzle is needed for a token hash
    func needsPuzzle(for tokenHash: String) -> Bool {
        let key = "needsPuzzle_\(tokenHash)"
        return sharedDefaults?.bool(forKey: key) ?? false
    }
    
    /// Clear the puzzle flag for a token hash
    func clearNeedsPuzzle(for tokenHash: String) {
        let key = "needsPuzzle_\(tokenHash)"
        sharedDefaults?.removeObject(forKey: key)
        sharedDefaults?.synchronize()
        print("💾 SharedStorage: Cleared needsPuzzle for \(tokenHash.prefix(8))...")
    }
    
    /// Get all token hashes that need puzzles
    func getAllPendingPuzzles() -> [String] {
        guard let defaults = sharedDefaults else { return [] }
        var pending: [String] = []
        
        // Iterate through all keys to find puzzle flags
        if let allKeys = defaults.dictionaryRepresentation().keys as? [String] {
            for key in allKeys where key.hasPrefix("needsPuzzle_") {
                if defaults.bool(forKey: key) {
                    let tokenHash = String(key.dropFirst("needsPuzzle_".count))
                    pending.append(tokenHash)
                }
            }
        }
        
        return pending
    }
    
    // MARK: - App Name Lookup
    
    /// Get app name for a token hash (from stored limits)
    func getAppName(for tokenHash: String) -> String? {
        // Try to find in stored limits
        guard let limitsData = sharedDefaults?.data(forKey: "stored_app_limits_v2"),
              let limits = try? JSONDecoder().decode([StoredAppLimitData].self, from: limitsData) else {
            return nil
        }
        
        // Find limit by matching token hash
        for limit in limits where limit.isActive {
            guard let selectionData = limit.selectionData,
                  let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData) else {
                continue
            }
            
            // Check if this limit's tokens match
            if let firstToken = selection.applicationTokens.first,
               String(firstToken.hashValue) == tokenHash {
                return limit.appName
            }
        }
        
        return nil
    }
}

// MARK: - Stored App Limit Data (for decoding)
struct StoredAppLimitData: Codable {
    let id: UUID
    let appName: String
    let dailyLimitMinutes: Int
    let usageMinutes: Int
    let isActive: Bool
    let createdAt: Date
    let selectionData: Data?
}






