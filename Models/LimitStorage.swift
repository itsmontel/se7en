//
//  LimitStorage.swift
//  SE7EN
//
//  FIXED VERSION - Properly syncs with extension and reads real app names
//

import Foundation
import FamilyControls

// MARK: - Stored App Limit (Codable for persistence)
struct StoredAppLimit: Codable, Identifiable {
    let id: UUID  // ✅ STABLE identifier - never changes
    var appName: String  // Made mutable so we can update with real name from extension
    var dailyLimitMinutes: Int
    var usageMinutes: Int
    var isActive: Bool
    let createdAt: Date
    
    // Selection data stored as Data (FamilyActivitySelection is Codable)
    let selectionData: Data
    
    init(id: UUID = UUID(), appName: String, dailyLimitMinutes: Int, selection: FamilyActivitySelection) {
        self.id = id
        self.appName = appName
        self.dailyLimitMinutes = dailyLimitMinutes
        self.usageMinutes = 0
        self.isActive = true
        self.createdAt = Date()
        self.selectionData = (try? PropertyListEncoder().encode(selection)) ?? Data()
    }
    
    // Decode the selection when needed
    func getSelection() -> FamilyActivitySelection? {
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData)
    }
    
    // ✅ FIXED: Check if a token matches using direct comparison
    func containsToken(_ appToken: ApplicationToken) -> Bool {
        guard let selection = getSelection() else { return false }
        return selection.applicationTokens.contains(appToken)
    }
}

// MARK: - Limit Storage Manager (Shared between app and extension)
final class LimitStorageManager {
    static let shared = LimitStorageManager()
    
    private let appGroupID = "group.com.se7en.app"
    private let limitsKey = "stored_app_limits_v2"
    private let usagePrefix = "usage_v2_"
    private let nameMapKey = "limit_id_to_app_name"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    private init() {}
    
    // MARK: - Save/Load Limits
    
    func saveLimits(_ limits: [StoredAppLimit]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(limits) else { return }
        defaults.set(data, forKey: limitsKey)
        defaults.synchronize()
    }
    
    func loadLimits() -> [StoredAppLimit] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: limitsKey),
              let limits = try? JSONDecoder().decode([StoredAppLimit].self, from: data) else {
            return []
        }
        return limits
    }
    
    func addLimit(_ limit: StoredAppLimit) {
        var limits = loadLimits()
        
        // Remove any existing limit for the same app (by name)
        limits.removeAll { $0.appName.lowercased() == limit.appName.lowercased() }
        
        limits.append(limit)
        saveLimits(limits)
    }
    
    func removeLimit(id: UUID) {
        var limits = loadLimits()
        limits.removeAll { $0.id == id }
        saveLimits(limits)
        
        // Also clear usage
        sharedDefaults?.removeObject(forKey: usagePrefix + id.uuidString)
        sharedDefaults?.synchronize()
    }
    
    func updateLimit(id: UUID, dailyLimitMinutes: Int? = nil, isActive: Bool? = nil) {
        var limits = loadLimits()
        if let index = limits.firstIndex(where: { $0.id == id }) {
            if let minutes = dailyLimitMinutes {
                limits[index].dailyLimitMinutes = minutes
            }
            if let active = isActive {
                limits[index].isActive = active
            }
            saveLimits(limits)
        }
    }
    
    // MARK: - Usage Tracking
    
    func setUsage(for limitID: UUID, minutes: Int) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(minutes, forKey: usagePrefix + limitID.uuidString)
        
        // Also update in the limits array
        var limits = loadLimits()
        if let index = limits.firstIndex(where: { $0.id == limitID }) {
            limits[index].usageMinutes = minutes
            saveLimits(limits)
        }
        
        defaults.synchronize()
    }
    
    func getUsage(for limitID: UUID) -> Int {
        guard let defaults = sharedDefaults else { return 0 }
        
        // First check the direct key
        let directUsage = defaults.integer(forKey: usagePrefix + limitID.uuidString)
        if directUsage > 0 {
            return directUsage
        }
        
        // Fallback: Check the limits array
        let limits = loadLimits()
        if let limit = limits.first(where: { $0.id == limitID }) {
            return limit.usageMinutes
        }
        
        return 0
    }
    
    // MARK: - ✅ NEW: Real App Name Mapping (Written by Extension)
    
    /// Get the real app name for a limit (as discovered by the extension)
    func getRealAppName(for limitID: UUID) -> String? {
        guard let defaults = sharedDefaults else { return nil }
        let nameMap = defaults.dictionary(forKey: nameMapKey) as? [String: String] ?? [:]
        return nameMap[limitID.uuidString]
    }
    
    /// Store a real app name mapping
    func setRealAppName(for limitID: UUID, name: String) {
        guard let defaults = sharedDefaults else { return }
        var nameMap = defaults.dictionary(forKey: nameMapKey) as? [String: String] ?? [:]
        nameMap[limitID.uuidString] = name
        defaults.set(nameMap, forKey: nameMapKey)
        defaults.synchronize()
        print("💾 Stored real app name: '\(name)' for limit \(limitID.uuidString.prefix(8))")
    }
    
    /// Get all real app name mappings
    func getAllRealAppNames() -> [UUID: String] {
        guard let defaults = sharedDefaults else { return [:] }
        let nameMap = defaults.dictionary(forKey: nameMapKey) as? [String: String] ?? [:]
        var result: [UUID: String] = [:]
        for (uuidString, name) in nameMap {
            if let uuid = UUID(uuidString: uuidString) {
                result[uuid] = name
            }
        }
        return result
    }
    
    // MARK: - ✅ NEW: Get Usage by Real App Name (for flexible matching)
    
    /// Get usage for a limit by looking up the real app name from per_app_usage
    func getUsageByRealAppName(for limitID: UUID) -> Int {
        guard let defaults = sharedDefaults else { return 0 }
        
        // First get the real app name for this limit
        guard let realAppName = getRealAppName(for: limitID) else { return 0 }
        
        // Now look up usage in per_app_usage
        let perAppUsage = defaults.dictionary(forKey: "per_app_usage") as? [String: Int] ?? [:]
        let normalizedName = realAppName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try exact match
        if let usage = perAppUsage[realAppName], usage > 0 {
            return usage
        }
        
        // Try normalized match
        if let usage = perAppUsage[normalizedName], usage > 0 {
            return usage
        }
        
        return 0
    }
    
    // MARK: - Token Matching
    
    /// Find a limit that contains the given token using direct comparison
    func findLimit(for token: ApplicationToken) -> StoredAppLimit? {
        let limits = loadLimits()
        for limit in limits {
            if limit.containsToken(token) {
                return limit
            }
        }
        return nil
    }
    
    /// Find a limit by app name (fallback)
    func findLimit(byAppName name: String) -> StoredAppLimit? {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return loadLimits().first {
            $0.appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
        }
    }
    
    /// Get all active limits
    func getActiveLimits() -> [StoredAppLimit] {
        return loadLimits().filter { $0.isActive }
    }
    
    // MARK: - ✅ NEW: Comprehensive Usage Lookup
    
    /// Get the best available usage for a limit ID
    func getBestUsage(for limitID: UUID) -> Int {
        // Priority 1: Direct UUID-based usage
        let directUsage = getUsage(for: limitID)
        if directUsage > 0 {
            return directUsage
        }
        
        // Priority 2: Look up by real app name in per_app_usage
        guard let defaults = sharedDefaults,
              let realAppName = getRealAppName(for: limitID) else {
            return 0
        }
        
        let perAppUsage = defaults.dictionary(forKey: "per_app_usage") as? [String: Int] ?? [:]
        
        if let usage = perAppUsage[realAppName], usage > 0 {
            return usage
        }
        
        let normalized = realAppName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let usage = perAppUsage[normalized], usage > 0 {
            return usage
        }
        
        return 0
    }
    
    // MARK: - Debug
    
    func debugPrintLimits() {
        let limits = loadLimits()
        let nameMap = getAllRealAppNames()
        
        print("\n" + String(repeating: "=", count: 60))
        print("📊 STORED LIMITS (v2 - UUID based)")
        print(String(repeating: "=", count: 60))
        for limit in limits {
            let selection = limit.getSelection()
            let tokenCount = selection?.applicationTokens.count ?? 0
            let realName = nameMap[limit.id]
            print("  • ID: \(limit.id.uuidString.prefix(8))...")
            print("    Stored Name: '\(limit.appName)'")
            if let real = realName {
                print("    Real Name: '\(real)' ✅")
            } else {
                print("    Real Name: (not yet discovered)")
            }
            print("    Limit: \(limit.dailyLimitMinutes) min")
            print("    Usage: \(getBestUsage(for: limit.id)) min")
            print("    Tokens: \(tokenCount)")
            print("    Active: \(limit.isActive)")
        }
        print(String(repeating: "=", count: 60) + "\n")
    }
}
