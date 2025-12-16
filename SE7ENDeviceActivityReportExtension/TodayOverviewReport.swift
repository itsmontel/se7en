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
                        
                        // Match tokens for monitored apps using ApplicationToken directly
                        let storage = AppLimitStorage.shared
                        if let limit = storage.findLimit(for: appToken) {
                            let minutes = Int(duration / 60)
                            let seconds = duration
                            
                            // Update usage using the limit ID (stable UUID)
                            storage.updateUsage(limitId: limit.id, seconds: seconds)
                            
                            // Also update app name if it was empty
                            if limit.appName.isEmpty || limit.appName == "App" {
                                // Update the limit with the real app name
                                storage.updateAppLimit(
                                    id: limit.id,
                                    dailyLimitMinutes: nil,
                                    isEnabled: nil,
                                    appName: name
                                )
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
    
}


