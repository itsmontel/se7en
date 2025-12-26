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
        print("🚀 TodayOverviewReport: Processing device activity data...")
        print("🔍 TodayOverviewReport: Extension invoked at \(Date())")
        
        var totalDuration: TimeInterval = 0  // TOTAL screen time from ALL apps (no filtering)
        var perAppDuration: [String: TimeInterval] = [:]
        var tokenToDuration: [Application: TimeInterval] = [:]
        var tokenToName: [Application: String] = [:]
        var uniqueApps: Set<String> = []
        var totalAppOpens: Int = 0
        var segmentCount = 0
        var categoryCount = 0
        var appCount = 0
        
        // Process ALL device activity data - no filtering by category or app type
        // Health score will be calculated from TOTAL screen time (all apps combined)
        for await deviceActivityData in data {
            for await segment in deviceActivityData.activitySegments {
                segmentCount += 1
                // Note: numberOfPickups is not available on ActivitySegment in current iOS versions
                // We'll track app launches by counting unique app opens instead
                
                for await category in segment.categories {
                    categoryCount += 1
                    for await app in category.applications {
                        appCount += 1
                        let application = app.application
                        let rawName = application.localizedDisplayName ?? "Unknown"
                        
                        // Filter out placeholder app names only (not filtering by app type)
                        guard let name = sanitizedAppName(rawName) else {
                            continue
                        }
                        
                        let appDuration = app.totalActivityDuration
                        
                        // Count ALL apps with actual usage (no category filtering)
                        if appDuration > 0 {
                            // Count unique apps that were opened/used
                            if !uniqueApps.contains(name) {
                                uniqueApps.insert(name)
                                totalAppOpens += 1
                            }
                            
                            // Aggregate by app name (for display)
                            perAppDuration[name, default: 0] += appDuration
                            totalDuration += appDuration  // Add ALL app usage to total
                            
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
        print("📊 TodayOverviewReport: Processed \(segmentCount) segments, \(categoryCount) categories, \(appCount) apps")
        print("📊 TodayOverviewReport: \(totalMinutes) min total, \(uniqueApps.count) unique apps with usage, \(totalAppOpens) app opens")
        
        // Create mapping from app name to the Application token with most usage for that name
        var nameToToken: [String: Application] = [:]
        for (application, duration) in tokenToDuration {
            let appName = tokenToName[application] ?? "Unknown"
            // If we don't have a token for this name yet, or this token has more usage, use it
            if nameToToken[appName] == nil {
                nameToToken[appName] = application
            } else if let existingToken = nameToToken[appName],
                      let existingDuration = tokenToDuration[existingToken],
                      duration > existingDuration {
                nameToToken[appName] = application
            }
        }
        
        // Sort apps by duration and get top 10
        let sortedApps = perAppDuration.sorted { $0.value > $1.value }
        let topApps = sortedApps.prefix(10).map { name, duration in
            AppUsage(name: name, duration: duration, application: nameToToken[name])
        }
        
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
        
        // ✅ COMPUTE HEALTH SCORE HERE - Based on TOTAL screen time (ALL apps combined)
        // No filtering - health is calculated from all app usage, not just certain categories
        let healthScore = calculateHealthScore(totalMinutes: totalMinutes)
        
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
        
        // ✅ RELIABILITY: Always write all values, even if 0 (indicates extension ran)
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults.set(totalMinutes, forKey: "total_usage")
        sharedDefaults.set(appsCount, forKey: "apps_count")
        sharedDefaults.set(timestamp, forKey: "last_updated")
        sharedDefaults.set(topAppsPayload, forKey: "top_apps")
        sharedDefaults.set(perAppUsage, forKey: "per_app_usage")
        sharedDefaults.set(totalPickups, forKey: "total_app_opens")
        
        // ✅ SAVE HEALTH SCORE - Always write (even if 0) so main app knows extension ran
        sharedDefaults.set(healthScore, forKey: "health_score")
        
        // Save daily app opens history (for stats page)
        saveDailyAppOpens(totalPickups, to: sharedDefaults)
        
        // Save daily per-app usage history (for weekly aggregation)
        saveDailyPerAppUsage(perAppUsage, to: sharedDefaults)
        
        // Save daily screen time history (for stats page and weekly highlights)
        saveDailyScreenTime(totalMinutes, to: sharedDefaults)
        
        // Save daily health score history
        saveDailyHealthScore(healthScore, to: sharedDefaults)
        
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
                "health_score": healthScore,
                "last_updated": timestamp,
                "top_apps": topAppsPayload,
                "per_app_usage": perAppUsage,
                "total_app_opens": totalPickups
            ]
        )
        
        sharedDefaults.synchronize()
        
        #if DEBUG
        print("💾 REPORT: Saved - \(totalMinutes) min, \(appsCount) apps, health: \(healthScore)%")
        print("💾 REPORT: Timestamp: \(Date(timeIntervalSince1970: timestamp))")
        #endif
    }
    
    // MARK: - Health Score Calculation (computed here in the extension!)
    
    /// Calculate health score based on TOTAL screen time (ALL apps combined)
    /// This is THE source of truth for pet health - main app just reads this value
    /// Health is calculated from total screen time across ALL apps, not filtered by category
    private func calculateHealthScore(totalMinutes: Int) -> Int {
        let totalHours = Double(totalMinutes) / 60.0
        
        // Simple health calculation based on TOTAL screen time (all apps):
        // < 2 hours = 100% (fullHealth)
        // 2-4 hours = 80-60% (happy → content)
        // 4-6 hours = 60-40% (content → sad)
        // 6-8 hours = 40-20% (sad)
        // > 8 hours = 20-0% (sick)
        
        let healthScore: Int
        switch totalHours {
        case 0..<2:
            healthScore = 100
        case 2..<4:
            // Linear decrease from 100 to 60
            healthScore = Int(100.0 - (20.0 * (totalHours - 2.0)))
        case 4..<6:
            // Linear decrease from 60 to 40
            healthScore = Int(60.0 - (10.0 * (totalHours - 4.0)))
        case 6..<8:
            // Linear decrease from 40 to 20
            healthScore = Int(40.0 - (10.0 * (totalHours - 6.0)))
        case 8..<10:
            // Linear decrease from 20 to 0
            healthScore = Int(20.0 - (10.0 * (totalHours - 8.0)))
        default:
            healthScore = 0
        }
        
        return max(0, min(100, healthScore))
    }
    
    /// Save daily health score for historical tracking
    private func saveDailyHealthScore(_ healthScore: Int, to sharedDefaults: UserDefaults) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())
        
        // Load existing history
        var dailyHealth = sharedDefaults.dictionary(forKey: "daily_health_scores") as? [String: Int] ?? [:]
        
        // Update today's health score
        dailyHealth[todayKey] = healthScore
        
        // Keep only last 30 days
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let cutoffKey = dateFormatter.string(from: thirtyDaysAgo)
        
        dailyHealth = dailyHealth.filter { key, _ in
            key >= cutoffKey
        }
        
        sharedDefaults.set(dailyHealth, forKey: "daily_health_scores")
        
        #if DEBUG
        print("📱 REPORT: Saved health score \(healthScore)% for \(todayKey)")
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
    
    /// Save per-app usage for the day (enables weekly aggregation)
    private func saveDailyPerAppUsage(_ perAppUsage: [String: Int], to sharedDefaults: UserDefaults) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())
        
        // Load existing history
        var dailyPerAppUsage = sharedDefaults.dictionary(forKey: "daily_per_app_usage") as? [String: [String: Int]] ?? [:]
        
        // Update today's per-app usage
        dailyPerAppUsage[todayKey] = perAppUsage
        
        // Keep only last 14 days
        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let cutoffKey = dateFormatter.string(from: twoWeeksAgo)
        
        dailyPerAppUsage = dailyPerAppUsage.filter { key, _ in
            key >= cutoffKey
        }
        
        sharedDefaults.set(dailyPerAppUsage, forKey: "daily_per_app_usage")
        
        #if DEBUG
        print("📱 REPORT: Saved per-app usage for \(todayKey): \(perAppUsage.count) apps")
        #endif
    }
    
    /// Save daily screen time for historical tracking
    private func saveDailyScreenTime(_ totalMinutes: Int, to sharedDefaults: UserDefaults) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())
        
        // Load existing history
        var dailyScreenTime = sharedDefaults.dictionary(forKey: "daily_screen_time") as? [String: Int] ?? [:]
        
        // Update today's screen time
        dailyScreenTime[todayKey] = totalMinutes
        
        // Keep only last 14 days
        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let cutoffKey = dateFormatter.string(from: twoWeeksAgo)
        
        dailyScreenTime = dailyScreenTime.filter { key, _ in
            key >= cutoffKey
        }
        
        sharedDefaults.set(dailyScreenTime, forKey: "daily_screen_time")
        
        #if DEBUG
        print("📱 REPORT: Saved screen time \(totalMinutes) min for \(todayKey)")
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
