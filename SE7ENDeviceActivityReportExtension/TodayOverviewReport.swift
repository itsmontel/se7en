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
        print("🚀 [REPORT_EXT] TodayOverviewReport.makeConfiguration() CALLED")
        print("🚀 [REPORT_EXT] Starting to process DeviceActivityResults...")
        
        var totalDurationFromApps: TimeInterval = 0
        var totalDurationFromSegments: TimeInterval = 0
        var totalDurationFromCategories: TimeInterval = 0
        var perAppDuration: [String: TimeInterval] = [:]
        var perCategoryDuration: [String: TimeInterval] = [:] // Track category-level usage too
        var tokenToDuration: [Application: TimeInterval] = [:]
        var tokenToName: [Application: String] = [:]
        var uniqueApps: Set<String> = []
        var uniqueCategories: Set<String> = []
        var totalAppOpens: Int = 0
        var segmentCount = 0
        var categoryCount = 0
        var appCount = 0
        var hasDataAtSegmentLevel = false
        var hasDataAtCategoryLevel = false
        var hasDataAtAppLevel = false
        
        // Process all device activity data
        for await deviceActivityData in data {
            print("📊 [REPORT_EXT] Processing deviceActivityData...")
            
            for await segment in deviceActivityData.activitySegments {
                segmentCount += 1
                let segmentDuration = segment.totalActivityDuration
                print("📊 [REPORT_EXT] Segment \(segmentCount): duration=\(Int(segmentDuration/60)) min")
                
                if segmentDuration > 0 {
                    hasDataAtSegmentLevel = true
                    totalDurationFromSegments += segmentDuration
                }
                
                for await category in segment.categories {
                    categoryCount += 1
                    let categoryDuration = category.totalActivityDuration
                    let categoryActivity = category.category
                    let categoryName = categoryActivity.localizedDisplayName ?? "Category \(categoryCount)"
                    
                    print("📊 [REPORT_EXT] Category '\(categoryName)': duration=\(Int(categoryDuration/60)) min")
                    
                    if categoryDuration > 0 {
                        hasDataAtCategoryLevel = true
                        if !uniqueCategories.contains(categoryName) {
                            uniqueCategories.insert(categoryName)
                            totalDurationFromCategories += categoryDuration
                        }
                        // Track per-category duration (for when apps aren't available)
                        perCategoryDuration[categoryName, default: 0] += categoryDuration
                    }
                    
                    for await app in category.applications {
                        appCount += 1
                        let application = app.application
                        let rawName = application.localizedDisplayName ?? "Unknown"
                        
                        // Filter out placeholder app names
                        guard let name = sanitizedAppName(rawName) else {
                            continue
                        }
                        
                        let appDuration = app.totalActivityDuration
                        
                        // Only count apps with actual usage (duration > 0)
                        if appDuration > 0 {
                            hasDataAtAppLevel = true
                            print("✅ [REPORT_EXT] App: \(name) - \(Int(appDuration/60)) min")
                            
                            // Count unique apps that were opened/used
                            if !uniqueApps.contains(name) {
                                uniqueApps.insert(name)
                                totalAppOpens += 1
                            }
                            
                            // Aggregate by app name (for display)
                            perAppDuration[name, default: 0] += appDuration
                            totalDurationFromApps += appDuration
                            
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
        
        // Determine total duration using the most granular data available
        var totalDuration: TimeInterval
        var appCountForSummary: Int
        
        if hasDataAtAppLevel && totalDurationFromApps > 0 {
            // Best case: we have individual app data
            totalDuration = totalDurationFromApps
            appCountForSummary = uniqueApps.count
            print("📊 [REPORT_EXT] Using app-level data: \(Int(totalDuration/60)) min from \(appCountForSummary) apps")
        } else if hasDataAtCategoryLevel && totalDurationFromCategories > 0 {
            // Category-level data (when user selects "All Categories")
            totalDuration = totalDurationFromCategories
            appCountForSummary = uniqueCategories.count // Report categories as "apps"
            print("📊 [REPORT_EXT] Using category-level data: \(Int(totalDuration/60)) min from \(appCountForSummary) categories")
            print("⚠️ [REPORT_EXT] Note: User selected categories, individual app breakdown not available")
        } else if hasDataAtSegmentLevel && totalDurationFromSegments > 0 {
            // Fallback to segment-level total
            totalDuration = totalDurationFromSegments
            appCountForSummary = 0
            print("📊 [REPORT_EXT] Using segment-level data: \(Int(totalDuration/60)) min (no app breakdown)")
        } else {
            totalDuration = 0
            appCountForSummary = 0
        }
        
        let totalMinutes = Int(totalDuration / 60)
        print("📊 [REPORT_EXT] FINAL: \(totalMinutes) min total")
        print("📊 [REPORT_EXT] Data sources: segments=\(hasDataAtSegmentLevel), categories=\(hasDataAtCategoryLevel), apps=\(hasDataAtAppLevel)")
        print("📊 [REPORT_EXT] Processed: \(segmentCount) segments, \(categoryCount) categories, \(appCount) app entries")
        
        if totalMinutes == 0 {
            print("⚠️ [REPORT_EXT] WARNING: No screen time data!")
            print("   - Is Screen Time enabled in Settings?")
            print("   - Has the device been used today?")
            print("   - totalDurationFromSegments: \(Int(totalDurationFromSegments/60)) min")
            print("   - totalDurationFromCategories: \(Int(totalDurationFromCategories/60)) min")
            print("   - totalDurationFromApps: \(Int(totalDurationFromApps/60)) min")
        }
        
        // Sort apps by duration and get top 10
        let sortedApps = perAppDuration.sorted { $0.value > $1.value }
        let topApps = sortedApps.prefix(10).map { AppUsage(name: $0.key, duration: $0.value) }
        
        let summary = UsageSummary(
            totalDuration: totalDuration,
            appCount: appCountForSummary,
            topApps: topApps,
            totalPickups: totalAppOpens
        )
        
        print("📊 [REPORT_EXT] Created summary: \(Int(totalDuration/60)) min, \(appCountForSummary) apps/categories")
        
        // Save to shared container for main app.
        // IMPORTANT: Perform App Group I/O on MainActor to avoid CFPrefsPlistSource issues.
        await saveToSharedContainer(
            summary: summary,
            perAppDuration: perAppDuration,
            perCategoryDuration: perCategoryDuration,
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
        perCategoryDuration: [String: TimeInterval],
        tokenToDuration: [Application: TimeInterval],
        tokenToName: [Application: String],
        totalPickups: Int
    ) async {
        print("💾 [REPORT_EXT] saveToSharedContainer() called")
        let appGroupID = "group.com.se7en.app"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ [REPORT_EXT] Failed to access App Group!")
            return
        }
        
        let totalMinutes = summary.totalMinutes
        let appsCount = summary.appCount
        
        print("💾 [REPORT_EXT] Preparing to write: totalMinutes=\(totalMinutes), appsCount=\(appsCount)")
        
        // Build per-app usage dictionary (minutes)
        // If we have app-level data, use that; otherwise use category-level data
        var perAppUsage: [String: Int] = [:]
        
        if !perAppDuration.isEmpty {
            // We have individual app data
            for (appName, duration) in perAppDuration {
                let minutes = Int(duration / 60)
                if minutes > 0 {
                    perAppUsage[appName] = minutes
                }
            }
            print("💾 [REPORT_EXT] Using app-level data: \(perAppUsage.count) apps")
        } else if !perCategoryDuration.isEmpty {
            // Fallback to category data when apps aren't available
            // This happens when user selects "All Categories" instead of individual apps
            for (categoryName, duration) in perCategoryDuration {
                let minutes = Int(duration / 60)
                if minutes > 0 {
                    perAppUsage["[Category] \(categoryName)"] = minutes
                }
            }
            print("💾 [REPORT_EXT] Using category-level data: \(perAppUsage.count) categories")
        }
        
        // Build top apps payload
        let topAppsPayload: [[String: Any]] = summary.topApps.map {
            ["name": $0.name, "minutes": $0.minutes]
        }
        
        // Write core values
        print("💾 [REPORT_EXT] Writing to UserDefaults...")
        sharedDefaults.set(totalMinutes, forKey: "total_usage")
        sharedDefaults.set(appsCount, forKey: "apps_count")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
        sharedDefaults.set(topAppsPayload, forKey: "top_apps")
        sharedDefaults.set(perAppUsage, forKey: "per_app_usage")
        sharedDefaults.set(totalPickups, forKey: "total_app_opens")
        print("✅ [REPORT_EXT] Wrote total_usage=\(totalMinutes), apps_count=\(appsCount)")
        
        // Save daily app opens history (for stats page)
        saveDailyAppOpens(totalPickups, to: sharedDefaults)
        
        // Save daily per-app usage history (for weekly aggregation)
        saveDailyPerAppUsage(perAppUsage, to: sharedDefaults)
        
        // Save daily screen time history (for stats page and weekly highlights)
        saveDailyScreenTime(totalMinutes, to: sharedDefaults)
        
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
