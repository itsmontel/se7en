//
//  TodayOverviewReport.swift
//  SE7ENDeviceActivityReportExtension
//

import DeviceActivity
import SwiftUI
import Foundation
import FamilyControls

// MARK: - Shared Types (for extension access)
struct StoredAppLimit: Codable, Identifiable {
    let id: UUID
    let appName: String
    var dailyLimitMinutes: Int
    var usageMinutes: Int
    var isActive: Bool
    let createdAt: Date
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
    
    func getSelection() -> FamilyActivitySelection? {
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData)
    }
    
    func containsToken(_ token: AnyHashable) -> Bool {
        guard let selection = getSelection() else { return false }
        // Compare tokens by hash value (tokens are Hashable)
        let tokenHash = token.hashValue
        return selection.applicationTokens.contains { ($0 as AnyHashable).hashValue == tokenHash }
    }
}

final class LimitStorageManager {
    static let shared = LimitStorageManager()
    
    private let appGroupID = "group.com.se7en.app"
    private let limitsKey = "stored_app_limits_v2"
    private let usagePrefix = "usage_v2_"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    private init() {}
    
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
    
    func setUsage(for limitID: UUID, minutes: Int) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(minutes, forKey: usagePrefix + limitID.uuidString)
        
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
    
    func findLimit(for token: AnyHashable) -> StoredAppLimit? {
        let limits = loadLimits()
        for limit in limits {
            if limit.containsToken(token) {
                return limit
            }
        }
        return nil
    }
}

extension DeviceActivityReport.Context {
    static let todayOverview = Self("todayOverview")
}

struct TodayOverviewReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .todayOverview
    let content: (UsageSummary) -> TodayOverviewView
    
    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> UsageSummary {
        var totalDuration: TimeInterval = 0
        var perAppDuration: [String: TimeInterval] = [:]
        var uniqueApps: Set<String> = []
        
        // ✅ NEW: Load limits using the new storage manager
        let storageManager = LimitStorageManager.shared
        let storedLimits = storageManager.loadLimits()
        
        print("📊 TodayOverviewReport: Processing data")
        print("   Stored limits count: \(storedLimits.count)")
        
        // Process device activity data
        for await deviceActivityData in data {
            for await segment in deviceActivityData.activitySegments {
                for await category in segment.categories {
                    for await app in category.applications {
                        guard let name = sanitizedAppName(app.application.localizedDisplayName),
                              let appToken = app.application.token else {
                            continue
                        }
                        
                        let duration = app.totalActivityDuration
                        let minutes = Int(duration / 60)
                        
                        uniqueApps.insert(name)
                        perAppDuration[name, default: 0] += duration
                        
                        // ✅ NEW: Match using direct token comparison
                        for limit in storedLimits {
                            guard let selection = limit.getSelection() else { continue }
                            
                            // Direct token comparison - THE RELIABLE WAY
                            // Compare tokens using hash value (tokens are Hashable)
                            let appTokenHash = (appToken as AnyHashable).hashValue
                            let foundMatch = selection.applicationTokens.contains { ($0 as AnyHashable).hashValue == appTokenHash }
                            
                            if foundMatch {
                                // Found a match! Update usage
                                let currentUsage = storageManager.getUsage(for: limit.id)
                                let newUsage = max(currentUsage, minutes)
                                
                                if newUsage > currentUsage {
                                    storageManager.setUsage(for: limit.id, minutes: newUsage)
                                    print("✅ Updated usage for '\(limit.appName)': \(newUsage) min (ID: \(limit.id.uuidString.prefix(8)))")
                                }
                                
                                // Also write to per_app_usage for backward compatibility
                                writeUsageByName(appName: name, minutes: minutes)
                                
                                break
                            }
                        }
                        
                        // Fallback: Also write by name for any app (for dashboard display)
                        writeUsageByName(appName: name, minutes: minutes)
                    }
                }
            }
        }
        
        totalDuration = perAppDuration.values.reduce(0, +)
        
        guard totalDuration > 0 else {
            return UsageSummary(totalDuration: 0, appCount: 0, topApps: [])
        }
        
        let topApps: [AppUsage] = perAppDuration
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { AppUsage(name: $0.key, duration: $0.value) }
        
        return UsageSummary(
            totalDuration: totalDuration,
            appCount: uniqueApps.count,
            topApps: topApps
        )
    }
    
    // MARK: - Helper Methods
    
    private func writeUsageByName(appName: String, minutes: Int) {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        let normalizedName = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Write to per_app_usage dictionary
        var perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int] ?? [:]
        perAppUsage[normalizedName] = minutes
        perAppUsage[appName] = minutes  // Also original case
        sharedDefaults.set(perAppUsage, forKey: "per_app_usage")
        sharedDefaults.synchronize()
    }
    
    private func sanitizedAppName(_ raw: String?) -> String? {
        guard let name = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        
        let lower = name.lowercased()
        if lower == "unknown" { return nil }
        if lower.contains("familycontrols") || lower.contains("authentication") { return nil }
        
        // Filter out "app 12345" patterns
        if let regex = try? NSRegularExpression(pattern: #"^app\s*\d{2,}$"#, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: name.utf16.count)
            if regex.firstMatch(in: name, options: [], range: range) != nil {
                return nil
            }
        }
        
        return name
    }
}


