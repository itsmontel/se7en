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
        var totalDuration: TimeInterval = 0
        var perAppDuration: [String: TimeInterval] = [:]
        var uniqueApps: Set<String> = []
        
        let monitoredSelections = loadMonitoredSelectionsFromSharedContainer()
        
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
                        uniqueApps.insert(name)
                        perAppDuration[name, default: 0] += duration
                        
                        // Match tokens for monitored apps - use token direct comparison
                        for monitored in monitoredSelections {
                            if monitored.selection.applicationTokens.contains(where: { $0 == appToken }) {
                                let minutes = Int(duration / 60)
                                
                                // ✅ CRITICAL: Compute hash from matched token to ensure consistency
                                let matchedTokenHash = String(appToken.hashValue)
                                
                                // Write usage with BOTH hashes for bulletproof matching
                                writeUsageToSharedContainer(
                                    appName: name,
                                    storedTokenHash: monitored.tokenHash, // Hash from goal creation
                                    matchedTokenHash: matchedTokenHash,   // Hash from matched token
                                    minutes: minutes
                                )
                                
                                if monitored.appName.isEmpty {
                                    updateGoalAppName(tokenHash: monitored.tokenHash, appName: name)
                                }
                                break
                            }
                        }
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
        
        let summary = UsageSummary(
            totalDuration: totalDuration,
            appCount: uniqueApps.count,
            topApps: topApps
        )
        
        saveToSharedContainer(summary: summary, perAppDuration: perAppDuration)
        
        return summary
    }
    
    /// Save summary to shared app group
    private func saveToSharedContainer(summary: UsageSummary, perAppDuration: [String: TimeInterval]) {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        let totalMinutes = Int(summary.totalDuration / 60)
        let appsCount = summary.appCount
        let topAppsPayload = summary.topApps.map { 
            ["name": $0.name, "minutes": Int($0.duration / 60)] 
        }
        
        var perAppUsage: [String: Int] = [:]
        for (appName, duration) in perAppDuration {
            let minutes = Int(duration / 60)
            if minutes > 0 {
                perAppUsage[appName] = minutes
            }
        }
        
        sharedDefaults.set(totalMinutes, forKey: "total_usage")
        sharedDefaults.set(appsCount, forKey: "apps_count")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
        sharedDefaults.set(topAppsPayload, forKey: "top_apps")
        sharedDefaults.set(perAppUsage, forKey: "per_app_usage")
        sharedDefaults.synchronize()
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
    
    // MARK: - Token Matching Helpers
    
    /// ✅ NEW: Struct to hold monitored selection info
    struct MonitoredAppInfo {
        let tokenHash: String
        let appName: String
        let limitMinutes: Int
        let selection: FamilyActivitySelection
    }
    
    /// Load monitored selections from shared container (individual apps only, no categories)
    private func loadMonitoredSelectionsFromSharedContainer() -> [MonitoredAppInfo] {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return [] }
        
        guard let monitoredApps = sharedDefaults.array(forKey: "monitored_app_selections") as? [[String: Any]] else {
            return []
        }
        
        var results: [MonitoredAppInfo] = []
        
        for appInfo in monitoredApps {
            guard let tokenHash = appInfo["tokenHash"] as? String,
                  let selectionData = appInfo["selectionData"] as? Data,
                  let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData),
                  !selection.applicationTokens.isEmpty,
                  selection.categoryTokens.isEmpty else {
                continue
            }
            
            let appName = appInfo["appName"] as? String ?? ""
            let limitMinutes = appInfo["limitMinutes"] as? Int ?? 0
            
            results.append(MonitoredAppInfo(
                tokenHash: tokenHash,
                appName: appName,
                limitMinutes: limitMinutes,
                selection: selection
            ))
        }
        
        return results
    }
    
    /// Write usage by token hash - writes with BOTH stored and matched hash for bulletproof matching
    private func writeUsageToSharedContainer(appName: String, storedTokenHash: String, matchedTokenHash: String, minutes: Int) {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // Write with stored hash (from goal creation)
        sharedDefaults.set(minutes, forKey: "usage_\(storedTokenHash)")
        
        // Write with matched hash (computed from actual token) - fallback if hash differs
        if matchedTokenHash != storedTokenHash {
            sharedDefaults.set(minutes, forKey: "usage_\(matchedTokenHash)")
        }
        
        // Update per-token-hash dictionary with BOTH hashes
        var perTokenUsage = sharedDefaults.dictionary(forKey: "per_token_hash_usage") as? [String: Int] ?? [:]
        perTokenUsage[storedTokenHash] = minutes
        if matchedTokenHash != storedTokenHash {
            perTokenUsage[matchedTokenHash] = minutes
        }
        sharedDefaults.set(perTokenUsage, forKey: "per_token_hash_usage")
        
        // Store hash mapping for lookup fallback
        var hashMapping = sharedDefaults.dictionary(forKey: "token_hash_mapping") as? [String: String] ?? [:]
        hashMapping[matchedTokenHash] = storedTokenHash
        hashMapping[storedTokenHash] = matchedTokenHash
        sharedDefaults.set(hashMapping, forKey: "token_hash_mapping")
        
        // Also store by app name as final fallback
        let normalizedName = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var nameToHash = sharedDefaults.dictionary(forKey: "app_name_to_hash") as? [String: String] ?? [:]
        nameToHash[normalizedName] = storedTokenHash
        sharedDefaults.set(nameToHash, forKey: "app_name_to_hash")
        
        sharedDefaults.synchronize()
    }
    
    /// Update goal app name if it was empty
    private func updateGoalAppName(tokenHash: String, appName: String) {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        var pendingNameUpdates = sharedDefaults.dictionary(forKey: "pending_goal_name_updates") as? [String: String] ?? [:]
        pendingNameUpdates[tokenHash] = appName
        sharedDefaults.set(pendingNameUpdates, forKey: "pending_goal_name_updates")
        sharedDefaults.synchronize()
    }
}


