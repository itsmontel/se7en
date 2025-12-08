//
//  TodayOverviewReport.swift
//  SE7ENDeviceActivityReportExtension
//

import DeviceActivity
import SwiftUI
import Foundation

extension DeviceActivityReport.Context {
    static let todayOverview = Self("todayOverview")
}

struct TodayOverviewReport: DeviceActivityReportScene {
    // The context this scene responds to
    let context: DeviceActivityReport.Context = .todayOverview
    
    // The view we render, given a UsageSummary
    let content: (UsageSummary) -> TodayOverviewView
    
    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> UsageSummary {
        var totalDuration: TimeInterval = 0
        var perAppDuration: [String: TimeInterval] = [:]
        var uniqueApps: Set<String> = []
        
        // data can contain multiple DeviceActivityData entries (e.g. multiple devices)
        for await deviceActivityData in data {
            // Each DeviceActivityData has an async sequence of segments
            for await segment in deviceActivityData.activitySegments {
                totalDuration += segment.totalActivityDuration
                
                // Drill into categories and applications
                for await category in segment.categories {
                    for await app in category.applications {
                        // Some system placeholders arrive as "app 902388" or "Unknown" – drop those
                        guard let name = sanitizedAppName(app.application.localizedDisplayName) else { continue }
                        uniqueApps.insert(name)
                        perAppDuration[name, default: 0] += app.totalActivityDuration
                    }
                }
            }
        }
        
        print("📊 TodayOverviewReport: totalDuration=\(Int(totalDuration))s uniqueApps=\(uniqueApps.count) perApp=\(perAppDuration.count)")
        
        // No usage → empty summary
        guard totalDuration > 0 else {
            return .empty
        }
        
        // Build top 10 apps by duration
        let topApps: [AppUsage] = perAppDuration
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { AppUsage(name: $0.key, duration: $0.value) }
        
        let summary = UsageSummary(
            totalDuration: totalDuration,
            appCount: uniqueApps.count,
            topApps: topApps
        )
        
        // Persist a lightweight summary for the main app (optional quick read)
        saveSummaryToSharedContainer(summary)
        
        return summary
    }
    
    /// Save totals/app count/top apps summary to the shared app group so the main app can read simple numbers without re-rendering the report.
    private func saveSummaryToSharedContainer(_ summary: UsageSummary) {
        let appGroupID = "group.com.se7en.app"
        DispatchQueue.main.async {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
                print("❌ TodayOverviewReport: Failed to open shared defaults")
                return
            }
            
            let totalMinutes = Int(summary.totalDuration / 60)
            let appsCount = summary.appCount
            let topAppsPayload = summary.topApps.map { ["name": $0.name, "minutes": Int($0.duration / 60)] }
            
            sharedDefaults.set(totalMinutes, forKey: "total_usage")
            sharedDefaults.set(appsCount, forKey: "apps_count")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
            sharedDefaults.set(topAppsPayload, forKey: "top_apps")
            
            print("💾 TodayOverviewReport: Saved summary to shared container (minutes=\(totalMinutes), apps=\(appsCount), top=\(topAppsPayload.count))")
        }
    }
    
    /// Filters out placeholder names such as "app 902388" or "Unknown"
    private func sanitizedAppName(_ raw: String?) -> String? {
        guard let name = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        
        let lower = name.lowercased()
        if lower == "unknown" { return nil }
        
        // Match strings like "app 902388" or "app902388"
        if let regex = try? NSRegularExpression(pattern: #"^app\s*\d{2,}$"#, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: name.utf16.count)
            if regex.firstMatch(in: name, options: [], range: range) != nil {
                return nil
            }
        }
        
        return name
    }
}
