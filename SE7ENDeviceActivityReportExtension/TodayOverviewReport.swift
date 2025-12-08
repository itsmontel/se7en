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
    let context: DeviceActivityReport.Context = .todayOverview
    let content: (UsageSummary) -> TodayOverviewView
    
    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> UsageSummary {
        print("🚀 TodayOverviewReport.makeConfiguration: EXTENSION INVOKED!")
        print("   ⏰ Current time: \(Date())")
        print("   📅 Context: \(context)")
        
        var totalDuration: TimeInterval = 0
        var perAppDuration: [String: TimeInterval] = [:]
        var uniqueApps: Set<String> = []
        var segmentCount = 0
        var categoryCount = 0
        var appCount = 0
        var dataIterations = 0
        
        // Process all device activity data
        for await deviceActivityData in data {
            dataIterations += 1
            print("   📦 Processing deviceActivityData iteration \(dataIterations)...")
            for await segment in deviceActivityData.activitySegments {
                segmentCount += 1
                totalDuration += segment.totalActivityDuration
                print("   📈 Segment \(segmentCount): duration=\(Int(segment.totalActivityDuration))s")
                
                // Drill into categories and applications
                for await category in segment.categories {
                    categoryCount += 1
                    print("      📂 Category \(categoryCount)")
                    for await app in category.applications {
                        appCount += 1
                        let rawName = app.application.localizedDisplayName ?? "nil"
                        print("         📱 App \(appCount): \(rawName) = \(Int(app.totalActivityDuration))s")
                        
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
        
        print("📊 TodayOverviewReport SUMMARY:")
        print("   Segments: \(segmentCount), Categories: \(categoryCount), Apps: \(appCount)")
        print("   totalDuration: \(Int(totalDuration))s")
        print("   uniqueApps: \(uniqueApps.count)")
        print("   perAppDuration: \(perAppDuration.count) entries")
        
        // No usage → empty summary
        guard totalDuration > 0 else {
            print("⚠️ TodayOverviewReport: NO USAGE DATA - Returning .empty")
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
        
        // Save summary to shared container
        saveSummaryToSharedContainer(summary)
        
        return summary
    }
    
    /// Save summary to shared app group
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


