//
//  AppLimitModels.swift
//  SE7ENDeviceActivityReportExtension
//
//  FIXED VERSION - Proper token comparison
//

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
    let selectionData: Data // Encoded FamilyActivitySelection (ApplicationToken cannot be archived directly)
    let appName: String
    let bundleIdentifier: String?
    let dailyLimitMinutes: Int
    let isEnabled: Bool
    let createdAt: Date
    
    init(token: ApplicationToken, appName: String, bundleIdentifier: String?, dailyLimitMinutes: Int, isEnabled: Bool = true) {
        self.id = UUID()
        // Create a FamilyActivitySelection containing just this token (it's Codable)
        var selection = FamilyActivitySelection()
        selection.applicationTokens = [token]
        self.selectionData = (try? PropertyListEncoder().encode(selection)) ?? Data()
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dailyLimitMinutes = dailyLimitMinutes
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }
    
    init(id: UUID, selectionData: Data, appName: String, bundleIdentifier: String?, dailyLimitMinutes: Int, isEnabled: Bool, createdAt: Date) {
        self.id = id
        self.selectionData = selectionData
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dailyLimitMinutes = dailyLimitMinutes
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
    
    func updated(dailyLimitMinutes: Int? = nil, isEnabled: Bool? = nil, appName: String? = nil) -> AppLimit {
        return AppLimit(
            id: self.id,
            selectionData: self.selectionData,
            appName: appName ?? self.appName,
            bundleIdentifier: self.bundleIdentifier,
            dailyLimitMinutes: dailyLimitMinutes ?? self.dailyLimitMinutes,
            isEnabled: isEnabled ?? self.isEnabled,
            createdAt: self.createdAt
        )
    }
    
    // Get the selection
    func getSelection() -> FamilyActivitySelection? {
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData)
    }
    
    // Decode the token back (get first token from selection)
    func getToken() -> ApplicationToken? {
        guard let selection = getSelection(),
              let firstToken = selection.applicationTokens.first else {
            return nil
        }
        return firstToken
    }
    
    // ✅ FIXED: Check if this limit contains the given token using DIRECT comparison
    func containsToken(_ appToken: ApplicationToken) -> Bool {
        guard let selection = getSelection() else { return false }
        // ApplicationToken is Equatable - use direct comparison
        return selection.applicationTokens.contains(appToken)
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
        
        let recordDay = Calendar.current.startOfDay(for: record.lastResetDate)
        if recordDay < today {
            return 0
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
    
    // MARK: - ✅ FIXED: Token-based lookup using direct comparison
    func findLimit(for token: ApplicationToken) -> AppLimit? {
        let limits = loadAppLimits()
        return limits.first { limit in
            limit.containsToken(token)
        }
    }
    
    func findLimitId(for token: ApplicationToken) -> UUID? {
        return findLimit(for: token)?.id
    }
}
