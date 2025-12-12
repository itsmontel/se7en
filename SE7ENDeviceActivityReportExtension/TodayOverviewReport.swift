//
//  TodayOverviewReport.swift
//  SE7ENDeviceActivityReportExtension
//

import DeviceActivity
import SwiftUI
import Foundation
import FamilyControls

extension DeviceActivityReport.Context {
    static let todayOverview = Self("todayOverview")
}

struct TodayOverviewReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .todayOverview
    let content: (UsageSummary) -> TodayOverviewView
    
    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> UsageSummary {
        print("🚀 TodayOverviewReport.makeConfiguration: EXTENSION INVOKED!")
        print("   ⏰ Time: \(Date())")
        print("   🆔 Context: \(context)")
        
        // ⚠️ CRITICAL: Log the data object to see if it's empty
        print("   📊 DeviceActivityResults data object received")
        
        var totalDuration: TimeInterval = 0
        var perAppDuration: [String: TimeInterval] = [:]
        var uniqueApps: Set<String> = []
        var segmentCount = 0
        var categoryCount = 0
        var appCount = 0
        
        // ✅ Load pending selections from main app for token matching
        let pendingSelections = loadPendingSelections()
        print("   📋 Loaded \(pendingSelections.count) pending selections from main app")
        
        // Map to store: main app's encoded key -> real app name and usage
        var tokenKeyToAppName: [String: String] = [:]
        var tokenKeyToUsage: [String: Int] = [:]
        
        // ⚠️ Add iteration counter to see if loop runs
        var dataIterations = 0
        
        // Process all device activity data
        for await deviceActivityData in data {
            dataIterations += 1
            print("   📦 Processing deviceActivityData iteration #\(dataIterations)...")
            for await segment in deviceActivityData.activitySegments {
                segmentCount += 1
                // ⚠️ Don't add segment.totalActivityDuration here - we'll calculate from perAppDuration instead
                // This ensures totalDuration matches the sum of displayed apps (excluding filtered apps)
                print("   📈 Segment \(segmentCount): duration=\(Int(segment.totalActivityDuration))s")
                
                // Drill into categories and applications
                for await category in segment.categories {
                    categoryCount += 1
                    print("      📂 Category \(categoryCount)")
                    for await app in category.applications {
                        appCount += 1
                        let rawName = app.application.localizedDisplayName ?? "nil"
                        let durationMinutes = Int(app.totalActivityDuration / 60)
                        print("         📱 App \(appCount): \(rawName) = \(Int(app.totalActivityDuration))s")
                        
                        // ✅ Try to match this app's token against pending selections from main app
                        if let appToken = app.application.token {
                            for (encodedKey, pendingSelection) in pendingSelections {
                                // Direct token comparison - this works because tokens are Equatable
                                if pendingSelection.applicationTokens.contains(appToken) {
                                    if let validName = sanitizedAppName(rawName) {
                                        tokenKeyToAppName[encodedKey] = validName
                                        tokenKeyToUsage[encodedKey] = durationMinutes
                                        print("         ✅ MATCHED: \(validName) -> key \(String(encodedKey.prefix(20)))...")
                                    }
                                    break // Only match once per app
                                }
                            }
                        }
                        
                        // Filter out placeholder app names
                        guard let name = sanitizedAppName(app.application.localizedDisplayName) else {
                            print("         ⚠️ Filtered out: \(rawName)")
                            continue
                        }
                        
                        uniqueApps.insert(name)
                        perAppDuration[name, default: 0] += app.totalActivityDuration
                    }
                }
            }
        }
        
        print("   📊 Token matching results: \(tokenKeyToAppName.count) matches found")
        
        // ⚠️ FIX: Calculate totalDuration from perAppDuration to match displayed apps
        // This ensures the total matches the sum of all displayed apps (excluding filtered placeholder apps)
        totalDuration = perAppDuration.values.reduce(0, +)
        
        print("📊 TodayOverviewReport SUMMARY:")
        print("   Segments: \(segmentCount), Categories: \(categoryCount), Apps: \(appCount)")
        print("   totalDuration: \(Int(totalDuration))s (\(Int(totalDuration/60)) minutes)")
        print("   uniqueApps: \(uniqueApps.count)")
        print("   perAppDuration: \(perAppDuration.count) entries")
        
        // ⚠️ Add detailed breakdown
        print("📊 Detailed app breakdown:")
        for (appName, duration) in perAppDuration.sorted(by: { $0.value > $1.value }).prefix(10) {
            print("   • \(appName): \(Int(duration/60)) minutes")
        }
        
        // No usage → empty summary
        guard totalDuration > 0 else {
            print("⚠️ TodayOverviewReport: NO USAGE DATA - Returning .empty")
            return .empty
        }
        
        // Build top 10 apps by duration
        let topApps: [AppUsage] = perAppDuration
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { name, duration in
                AppUsage(name: name, duration: duration)
            }
        
        let summary = UsageSummary(
            totalDuration: totalDuration,
            appCount: uniqueApps.count,
            topApps: topApps
        )
        
        // Save summary to shared container
        saveSummaryToSharedContainer(summary, perAppDuration: perAppDuration, tokenKeyToAppName: tokenKeyToAppName, tokenKeyToUsage: tokenKeyToUsage)
        
        return summary
    }
    
    /// Load pending selections from main app (saved when limits are created)
    private func loadPendingSelections() -> [String: FamilyActivitySelection] {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Failed to load pending selections: no shared defaults")
            return [:]
        }
        
        sharedDefaults.synchronize()
        
        guard let pendingData = sharedDefaults.dictionary(forKey: "pending_app_selections") as? [String: Data] else {
            print("⚠️ No pending_app_selections found in shared container")
            return [:]
        }
        
        var result: [String: FamilyActivitySelection] = [:]
        
        for (encodedKey, data) in pendingData {
            do {
                let selection = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
                result[encodedKey] = selection
                print("   📦 Decoded pending selection: \(String(encodedKey.prefix(20)))... with \(selection.applicationTokens.count) app tokens")
            } catch {
                print("   ❌ Failed to decode pending selection: \(error)")
            }
        }
        
        return result
    }
    
    /// Save summary to shared app group
    private func saveSummaryToSharedContainer(_ summary: UsageSummary, perAppDuration: [String: TimeInterval], tokenKeyToAppName: [String: String], tokenKeyToUsage: [String: Int]) {
        let appGroupID = "group.com.se7en.app"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ TodayOverviewReport: Failed to open shared defaults")
            return
        }
        
        let totalMinutes = Int(summary.totalDuration / 60)
        let appsCount = summary.appCount
        let topAppsPayload = summary.topApps.map { 
            ["name": $0.name, "minutes": Int($0.duration / 60)] 
        }
        
        // Build per-app usage dictionary keyed by app name (for Dashboard)
        var perAppUsage: [String: Int] = [:]
        for (appName, duration) in perAppDuration {
            let minutes = Int(duration / 60)
            if minutes > 0 {
                perAppUsage[appName] = minutes
            }
        }
        
        // Save data
        sharedDefaults.set(totalMinutes, forKey: "total_usage")
        sharedDefaults.set(appsCount, forKey: "apps_count")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
        sharedDefaults.set(topAppsPayload, forKey: "top_apps")
        sharedDefaults.set(perAppUsage, forKey: "per_app_usage")
        
        // ✅ CRITICAL: Save token-based mappings for Limits page
        // These use the main app's encoded key, so the main app can look up by its own key
        sharedDefaults.set(tokenKeyToAppName, forKey: "token_key_to_app_name")
        sharedDefaults.set(tokenKeyToUsage, forKey: "token_key_to_usage")
        
        sharedDefaults.synchronize()
        
        print("💾 TodayOverviewReport: Saved to shared container")
        print("   • Total minutes: \(totalMinutes)")
        print("   • Per-app usage: \(perAppUsage.count) apps")
        print("   • Token mappings: \(tokenKeyToAppName.count) entries")
        print("   • Token usage: \(tokenKeyToUsage.count) entries")
    }
    
    /// Filter out placeholder app names like "app 902388" or "Unknown"
    private func sanitizedAppName(_ raw: String?) -> String? {
        guard let name = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        
        let lower = name.lowercased()
        if lower == "unknown" {
            return nil
        }
        
        // Filter out system/auth helper labels that should not surface to users
        if lower.contains("familycontrols") || lower.contains("authentication") {
            return nil
        }
        
        // Match patterns like "app 902388" or "app902388"
        if let regex = try? NSRegularExpression(pattern: #"^app\s*\d{2,}$"#, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: name.utf16.count)
            if regex.firstMatch(in: name, options: [], range: range) != nil {
                return nil
            }
        }
        
        return name
    }
}


