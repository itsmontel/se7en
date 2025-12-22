//
//  TodayOverviewReport.swift
//  SE7ENDeviceActivityReportExtension
//
//  Reports today's app usage and saves to shared container for main app
//

import DeviceActivity
import SwiftUI
import Foundation
import FamilyControls
import ManagedSettings

// MARK: - Report Context
extension DeviceActivityReport.Context {
    static let todayOverview = Self("todayOverview")
}

// MARK: - Today Overview Report
struct TodayOverviewReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .todayOverview
    let content: (UsageSummary) -> TodayOverviewView
    
    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> UsageSummary {
        #if DEBUG
        print("🚀 TodayOverviewReport: Processing device activity data...")
        #endif
        
        var totalDuration: TimeInterval = 0
        var perAppDuration: [String: TimeInterval] = [:]
        var tokenToDuration: [Application: TimeInterval] = [:]
        var tokenToName: [Application: String] = [:]
        var uniqueApps: Set<String> = []
        var totalAppOpens: Int = 0
        
        // Process all device activity data
        for await deviceActivityData in data {
            for await segment in deviceActivityData.activitySegments {
                // Note: numberOfPickups is not available on ActivitySegment in current iOS versions
                // We'll track app launches by counting unique app opens instead
                
                for await category in segment.categories {
                    for await app in category.applications {
                        let application = app.application
                        let rawName = application.localizedDisplayName ?? "Unknown"
                        
                        // Filter out placeholder app names
                        guard let name = sanitizedAppName(rawName) else {
                            continue
                        }
                        
                        let appDuration = app.totalActivityDuration
                        
                        // Only count apps with actual usage (duration > 0)
                        if appDuration > 0 {
                            // Count unique apps that were opened/used
                            if !uniqueApps.contains(name) {
                                uniqueApps.insert(name)
                                totalAppOpens += 1
                            }
                            
                            // Aggregate by app name (for display)
                            perAppDuration[name, default: 0] += appDuration
                            totalDuration += appDuration
                            
                            // Aggregate by application (for reliable limit matching)
                            tokenToDuration[application, default: 0] += appDuration
                            if tokenToName[application] == nil {
                                tokenToName[application] = name
                            }
                        }
                    }
                }
            }
        }
        
        let totalMinutes = Int(totalDuration / 60)
        #if DEBUG
        print("📊 TodayOverviewReport: \(totalMinutes) min total, \(uniqueApps.count) apps, \(totalAppOpens) app opens")
        #endif
        
        // Sort apps by duration and get top 10
        let sortedApps = perAppDuration.sorted { $0.value > $1.value }
        let topApps = sortedApps.prefix(10).map { AppUsage(name: $0.key, duration: $0.value) }
        
        let summary = UsageSummary(
            totalDuration: totalDuration,
            appCount: uniqueApps.count,
            topApps: topApps,
            totalPickups: totalAppOpens
        )
        
        // Save to shared container for main app.
        // IMPORTANT: Perform App Group I/O on MainActor to avoid CFPrefsPlistSource issues.
        await saveToSharedContainer(
            summary: summary,
            perAppDuration: perAppDuration,
            tokenToDuration: tokenToDuration,
            tokenToName: tokenToName,
            totalPickups: totalAppOpens
        )
        
        return summary
    }
    
    // MARK: - Save to Shared Container
    
    @MainActor
    private func saveToSharedContainer(
        summary: UsageSummary,
        perAppDuration: [String: TimeInterval],
        tokenToDuration: [Application: TimeInterval],
        tokenToName: [Application: String],
        totalPickups: Int
    ) async {
        let appGroupID = "group.com.se7en.app"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            #if DEBUG
            print("❌ REPORT: Failed to access App Group")
            #endif
            return
        }
        
        let totalMinutes = summary.totalMinutes
        let appsCount = summary.appCount
        
        // Build per-app usage dictionary (minutes)
        var perAppUsage: [String: Int] = [:]
        for (appName, duration) in perAppDuration {
            let minutes = Int(duration / 60)
            if minutes > 0 {
                perAppUsage[appName] = minutes
            }
        }
        
        // Build top apps payload
        let topAppsPayload: [[String: Any]] = summary.topApps.map {
            ["name": $0.name, "minutes": $0.minutes]
        }
        
        // Write core values
        sharedDefaults.set(totalMinutes, forKey: "total_usage")
        sharedDefaults.set(appsCount, forKey: "apps_count")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
        sharedDefaults.set(topAppsPayload, forKey: "top_apps")
        sharedDefaults.set(perAppUsage, forKey: "per_app_usage")
        sharedDefaults.set(totalPickups, forKey: "total_app_opens")
        
        // Save daily app opens history (for stats page)
        saveDailyAppOpens(totalPickups, to: sharedDefaults)
        
        // Match tokens to limits and write usage by token hash
        matchTokensToLimits(
            tokenToDuration: tokenToDuration,
            tokenToName: tokenToName,
            sharedDefaults: sharedDefaults
        )
        
        // Also write a JSON backup file. The main app can read this even when shared defaults
        // are empty due to cross-process UserDefaults flakiness.
        writeScreenTimeJSONBackup(
            appGroupID: appGroupID,
            payload: [
                "total_usage": totalMinutes,
                "apps_count": appsCount,
                "last_updated": Date().timeIntervalSince1970,
                "top_apps": topAppsPayload,
                "per_app_usage": perAppUsage,
                "total_app_opens": totalPickups
            ]
        )
        
        sharedDefaults.synchronize()
        
        #if DEBUG
        print("💾 REPORT: Saved \(totalMinutes) min, \(appsCount) apps")
        #endif
    }
    
    @MainActor
    private func writeScreenTimeJSONBackup(appGroupID: String, payload: [String: Any]) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            #if DEBUG
            print("❌ REPORT: Failed to access App Group container URL for JSON backup")
            #endif
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("screen_time_data.json")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            try data.write(to: fileURL, options: [.atomic])
            #if DEBUG
            print("💾 REPORT: Wrote JSON backup to \(fileURL.lastPathComponent)")
            #endif
        } catch {
            #if DEBUG
            print("❌ REPORT: Failed to write JSON backup: \(error)")
            #endif
        }
    }
    
    // MARK: - Token to Limit Matching
    
    private func matchTokensToLimits(
        tokenToDuration: [Application: TimeInterval],
        tokenToName: [Application: String],
        sharedDefaults: UserDefaults
    ) {
        // Load stored limits
        guard let limitsData = sharedDefaults.data(forKey: "stored_app_limits_v2"),
              let limits = try? JSONDecoder().decode([StoredLimit].self, from: limitsData) else {
            #if DEBUG
            print("📭 REPORT: No stored limits found")
            #endif
            return
        }
        
        #if DEBUG
        print("🔗 REPORT: Matching \(tokenToDuration.count) apps to \(limits.count) limits...")
        #endif
        
        var usageByLimitUUID: [String: Int] = [:]
        var nameByLimitUUID: [String: String] = [:]
        var hashToLimitUUID: [String: String] = [:]
        
        // For each application in report, find matching limit
        for (application, duration) in tokenToDuration {
            let minutes = Int(duration / 60)
            guard minutes > 0 else { continue }
            
            let appName = tokenToName[application] ?? "Unknown"
            
            // Get the token (it's optional)
            guard let appToken = application.token else { continue }
            let tokenHash = String(appToken.hashValue)
            
            // Try to find limit by direct token comparison
            for limit in limits where limit.isActive {
                guard let selection = limit.getSelection() else { continue }
                
                // Direct token comparison (most reliable)
                if selection.applicationTokens.contains(appToken) {
                    let uuidString = limit.id.uuidString
                    usageByLimitUUID[uuidString] = minutes
                    nameByLimitUUID[uuidString] = appName
                    hashToLimitUUID[tokenHash] = uuidString
                    #if DEBUG
                    print("✅ REPORT: Matched '\(appName)' -> limit \(uuidString.prefix(8))..., \(minutes) min")
                    #endif
                    break
                }
            }
            
            // Also save by token hash (for backwards compatibility with token hash based lookups)
            sharedDefaults.set(minutes, forKey: "usage_\(tokenHash)")
        }
        
        // Save usage by limit UUID (primary method for main app)
        for (uuidString, minutes) in usageByLimitUUID {
            sharedDefaults.set(minutes, forKey: "usage_v2_\(uuidString)")
        }
        
        // Save name mappings
        let existingNameMap = sharedDefaults.dictionary(forKey: "limit_id_to_app_name") as? [String: String] ?? [:]
        var updatedNameMap = existingNameMap
        for (uuid, name) in nameByLimitUUID {
            updatedNameMap[uuid] = name
        }
        sharedDefaults.set(updatedNameMap, forKey: "limit_id_to_app_name")
        
        // Save hash to UUID mapping (for backwards compatibility)
        let existingHashMap = sharedDefaults.dictionary(forKey: "token_hash_to_limit_uuid") as? [String: String] ?? [:]
        var updatedHashMap = existingHashMap
        for (hash, uuid) in hashToLimitUUID {
            updatedHashMap[hash] = uuid
        }
        sharedDefaults.set(updatedHashMap, forKey: "token_hash_to_limit_uuid")
        
        #if DEBUG
        print("✅ REPORT: Matched \(usageByLimitUUID.count) limits")
        #endif
    }
    
    // MARK: - Daily App Opens History
    
    private func saveDailyAppOpens(_ appOpens: Int, to sharedDefaults: UserDefaults) {
        // Get today's date key
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())
        
        // Load existing daily app opens history
        var dailyAppOpens = sharedDefaults.dictionary(forKey: "daily_app_opens") as? [String: Int] ?? [:]
        
        // Update today's app opens
        dailyAppOpens[todayKey] = appOpens
        
        // Keep only last 30 days
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let cutoffKey = dateFormatter.string(from: thirtyDaysAgo)
        
        // Remove old entries
        dailyAppOpens = dailyAppOpens.filter { key, _ in
            key >= cutoffKey
        }
        
        // Save back
        sharedDefaults.set(dailyAppOpens, forKey: "daily_app_opens")
        #if DEBUG
        print("📱 REPORT: Saved \(appOpens) app opens for \(todayKey)")
        #endif
    }
    
    // MARK: - Helpers
    
    /// Filter out placeholder app names
    private func sanitizedAppName(_ raw: String?) -> String? {
        guard let name = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        
        let lower = name.lowercased()
        
        // Filter out system/placeholder names
        if lower == "unknown" { return nil }
        if lower.contains("familycontrols") { return nil }
        if lower.contains("authentication") { return nil }
        
        // Filter out "app 902388" style placeholders
        if let regex = try? NSRegularExpression(pattern: #"^app\s*\d{2,}$"#, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: name.utf16.count)
            if regex.firstMatch(in: name, options: [], range: range) != nil {
                return nil
            }
        }
        
        return name
    }
}

// MARK: - Stored Limit (for decoding)
private struct StoredLimit: Codable {
    let id: UUID
    let appName: String
    let dailyLimitMinutes: Int
    let usageMinutes: Int
    let isActive: Bool
    let createdAt: Date
    let selectionData: Data
    
    func getSelection() -> FamilyActivitySelection? {
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData)
    }
}
