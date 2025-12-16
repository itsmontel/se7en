import Foundation
import FamilyControls
import ManagedSettings

// MARK: - Shared Constants
enum AppGroupConstants {
    static let groupIdentifier = "group.com.se7en.app"
    static let limitsKey = "app_limits_v2"
    static let usageKey = "app_usage_tracking"
}

// MARK: - App Limit Model
struct AppLimit: Codable, Identifiable {
    let id: UUID
    let tokenData: Data // Encoded ApplicationToken
    let appName: String
    let bundleIdentifier: String?
    let dailyLimitMinutes: Int
    let isEnabled: Bool
    let createdAt: Date
    
    init(token: ApplicationToken, appName: String, bundleIdentifier: String?, dailyLimitMinutes: Int, isEnabled: Bool = true) {
        self.id = UUID()
        self.tokenData = Self.encode(token: token)
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dailyLimitMinutes = dailyLimitMinutes
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }
    
    // Custom initializer to preserve ID and createdAt when updating
    init(id: UUID, tokenData: Data, appName: String, bundleIdentifier: String?, dailyLimitMinutes: Int, isEnabled: Bool, createdAt: Date) {
        self.id = id
        self.tokenData = tokenData
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dailyLimitMinutes = dailyLimitMinutes
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
    
    // Create updated copy preserving ID and createdAt
    func updated(dailyLimitMinutes: Int? = nil, isEnabled: Bool? = nil, appName: String? = nil) -> AppLimit {
        return AppLimit(
            id: self.id,
            tokenData: self.tokenData,
            appName: appName ?? self.appName,
            bundleIdentifier: self.bundleIdentifier,
            dailyLimitMinutes: dailyLimitMinutes ?? self.dailyLimitMinutes,
            isEnabled: isEnabled ?? self.isEnabled,
            createdAt: self.createdAt
        )
    }
    
    // Decode the token back
    func getToken() -> ApplicationToken? {
        return Self.decode(data: tokenData)
    }
    
    // Encode ApplicationToken to Data
    private static func encode(token: ApplicationToken) -> Data {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        } catch {
            print("❌ Failed to encode ApplicationToken: \(error)")
            return Data()
        }
    }
    
    // Decode Data back to ApplicationToken
    private static func decode(data: Data) -> ApplicationToken? {
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: ApplicationToken.self, from: data)
        } catch {
            print("❌ Failed to decode ApplicationToken: \(error)")
            return nil
        }
    }
}

// MARK: - App Usage Tracking
struct AppUsageRecord: Codable {
    let limitId: UUID
    var totalSecondsToday: TimeInterval
    var lastResetDate: Date
    var sessions: [UsageSession]
    
    struct UsageSession: Codable {
        let startTime: Date
        let endTime: Date?
        var duration: TimeInterval {
            guard let end = endTime else { return 0 }
            return end.timeIntervalSince(startTime)
        }
    }
}

// MARK: - Shared Storage Manager
class AppLimitStorage {
    static let shared = AppLimitStorage()
    
    private let userDefaults: UserDefaults?
    
    init() {
        self.userDefaults = UserDefaults(suiteName: AppGroupConstants.groupIdentifier)
    }
    
    // MARK: - App Limits
    func saveAppLimits(_ limits: [AppLimit]) {
        guard let defaults = userDefaults else { return }
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(limits) {
            defaults.set(encoded, forKey: AppGroupConstants.limitsKey)
            defaults.synchronize()
        }
    }
    
    func loadAppLimits() -> [AppLimit] {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: AppGroupConstants.limitsKey) else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([AppLimit].self, from: data)) ?? []
    }
    
    func addAppLimit(_ limit: AppLimit) {
        var limits = loadAppLimits()
        limits.append(limit)
        saveAppLimits(limits)
    }
    
    func removeAppLimit(id: UUID) {
        var limits = loadAppLimits()
        limits.removeAll { $0.id == id }
        saveAppLimits(limits)
    }
    
    func updateAppLimit(id: UUID, dailyLimitMinutes: Int?, isEnabled: Bool?, appName: String? = nil) {
        var limits = loadAppLimits()
        guard let index = limits.firstIndex(where: { $0.id == id }) else { return }
        
        let oldLimit = limits[index]
        // Use the updated() method to preserve ID and createdAt
        limits[index] = oldLimit.updated(
            dailyLimitMinutes: dailyLimitMinutes,
            isEnabled: isEnabled,
            appName: appName
        )
        saveAppLimits(limits)
    }
    
    // MARK: - Usage Tracking
    func saveUsageRecords(_ records: [UUID: AppUsageRecord]) {
        guard let defaults = userDefaults else { return }
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(records) {
            defaults.set(encoded, forKey: AppGroupConstants.usageKey)
            defaults.synchronize()
        }
    }
    
    func loadUsageRecords() -> [UUID: AppUsageRecord] {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: AppGroupConstants.usageKey) else {
            return [:]
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([UUID: AppUsageRecord].self, from: data)) ?? [:]
    }
    
    func updateUsage(limitId: UUID, seconds: TimeInterval) {
        var records = loadUsageRecords()
        
        let today = Calendar.current.startOfDay(for: Date())
        
        if var record = records[limitId] {
            // Check if we need to reset (new day)
            let lastResetDay = Calendar.current.startOfDay(for: record.lastResetDate)
            if today > lastResetDay {
                record.totalSecondsToday = seconds
                record.lastResetDate = Date()
                record.sessions = []
            } else {
                record.totalSecondsToday += seconds
            }
            records[limitId] = record
        } else {
            records[limitId] = AppUsageRecord(
                limitId: limitId,
                totalSecondsToday: seconds,
                lastResetDate: Date(),
                sessions: []
            )
        }
        
        saveUsageRecords(records)
    }
    
    func getUsageMinutes(limitId: UUID) -> Int {
        let records = loadUsageRecords()
        let today = Calendar.current.startOfDay(for: Date())
        
        guard let record = records[limitId] else { return 0 }
        
        // Check if record is from today
        let recordDay = Calendar.current.startOfDay(for: record.lastResetDate)
        if recordDay < today {
            return 0 // Reset happened
        }
        
        return Int(record.totalSecondsToday / 60)
    }
    
    func resetAllUsageForToday() {
        var records = loadUsageRecords()
        let today = Date()
        
        for (id, var record) in records {
            record.totalSecondsToday = 0
            record.lastResetDate = today
            record.sessions = []
            records[id] = record
        }
        
        saveUsageRecords(records)
    }
    
    // MARK: - Token-based lookup helpers
    func findLimit(for token: ApplicationToken) -> AppLimit? {
        let limits = loadAppLimits()
        return limits.first { limit in
            guard let limitToken = limit.getToken() else { return false }
            return limitToken == token
        }
    }
    
    func findLimitId(for token: ApplicationToken) -> UUID? {
        return findLimit(for: token)?.id
    }
}

