import Foundation
import FamilyControls

// MARK: - Stored App Limit (Codable for persistence)
struct StoredAppLimit: Codable, Identifiable {
    let id: UUID  // ✅ STABLE identifier - never changes
    let appName: String
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
    
    // Check if a token matches this limit's selection
    func containsToken(_ token: AnyHashable) -> Bool {
        guard let selection = getSelection() else { return false }
        // Compare tokens by hash value (tokens are Hashable)
        let tokenHash = token.hashValue
        return selection.applicationTokens.contains { ($0 as AnyHashable).hashValue == tokenHash }
    }
}

// MARK: - Limit Storage Manager (Shared between app and extension)
final class LimitStorageManager {
    static let shared = LimitStorageManager()
    
    private let appGroupID = "group.com.se7en.app"
    private let limitsKey = "stored_app_limits_v2"
    private let usagePrefix = "usage_v2_"
    
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
        return defaults.integer(forKey: usagePrefix + limitID.uuidString)
    }
    
    // MARK: - Token Matching (The Key Part!)
    
    /// Find a limit that contains the given token using DIRECT COMPARISON
    func findLimit(for token: AnyHashable) -> StoredAppLimit? {
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
    
    // MARK: - Debug
    
    func debugPrintLimits() {
        let limits = loadLimits()
        print("\n" + String(repeating: "=", count: 50))
        print("📊 STORED LIMITS (v2 - UUID based)")
        print(String(repeating: "=", count: 50))
        for limit in limits {
            let selection = limit.getSelection()
            let tokenCount = selection?.applicationTokens.count ?? 0
            print("  • ID: \(limit.id.uuidString.prefix(8))...")
            print("    Name: \(limit.appName)")
            print("    Limit: \(limit.dailyLimitMinutes) min")
            print("    Usage: \(limit.usageMinutes) min")
            print("    Tokens: \(tokenCount)")
            print("    Active: \(limit.isActive)")
        }
        print(String(repeating: "=", count: 50) + "\n")
    }
}

