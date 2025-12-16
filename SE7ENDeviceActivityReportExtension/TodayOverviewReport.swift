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
        print("🚀 TodayOverviewReport.makeConfiguration: STARTING!")
        print("   ⏰ Time: \(Date())")
        
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
            print("   📦 Processing deviceActivityData iteration #\(dataIterations)...")
            
            for await segment in deviceActivityData.activitySegments {
                segmentCount += 1
                print("   📈 Segment \(segmentCount): duration=\(Int(segment.totalActivityDuration))s")
                
                // Drill into categories and applications
                for await category in segment.categories {
                    categoryCount += 1
                    
                    for await app in category.applications {
                        appCount += 1
                        let rawName = app.application.localizedDisplayName ?? "Unknown"
                        
                        // Filter out placeholder app names
                        guard let name = sanitizedAppName(rawName) else {
                            continue
                        }
                        
                        let appDuration = app.totalActivityDuration
                        uniqueApps.insert(name)
                        perAppDuration[name, default: 0] += appDuration
                        totalDuration += appDuration
                        
                        if appDuration > 60 { // Only log apps with > 1 minute usage
                            print("      📱 App: \(name) = \(Int(appDuration/60))m")
                        }
                    }
                }
            }
        }
        
        print("📊 TodayOverviewReport: Processing complete!")
        print("   • Data iterations: \(dataIterations)")
        print("   • Segments: \(segmentCount)")
        print("   • Categories: \(categoryCount)")
        print("   • Apps processed: \(appCount)")
        print("   • Unique apps: \(uniqueApps.count)")
        print("   • Total duration: \(Int(totalDuration/60)) minutes")
        
        // Sort apps by duration and get top 10
        let sortedApps = perAppDuration.sorted { $0.value > $1.value }
        let topApps = sortedApps.prefix(10).map { AppUsage(name: $0.key, duration: $0.value) }
        
        let summary = UsageSummary(
            totalDuration: totalDuration,
            appCount: uniqueApps.count,
            topApps: topApps
        )
        
        // CRITICAL: Save to shared container SYNCHRONOUSLY
        print("💾 TodayOverviewReport: About to save to shared container...")
        saveToSharedContainer(summary: summary, perAppDuration: perAppDuration)
        
        return summary
    }
    
    /// Save summary to shared app group - DIAGNOSTIC VERSION
    private func saveToSharedContainer(summary: UsageSummary, perAppDuration: [String: TimeInterval]) {
        let appGroupID = "group.com.se7en.app"
        
        // Try multiple methods to ensure data is saved
        
        // METHOD 1: UserDefaults with App Group
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            let totalMinutes = Int(summary.totalDuration / 60)
            let appsCount = summary.appCount
            let timestamp = Date().timeIntervalSince1970
            
            let topAppsPayload: [[String: Any]] = summary.topApps.map { 
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
            sharedDefaults.set(timestamp, forKey: "last_updated")
            sharedDefaults.set(topAppsPayload, forKey: "top_apps")
            sharedDefaults.set(perAppUsage, forKey: "per_app_usage")
            sharedDefaults.synchronize()
        }
        
        // METHOD 2: Also write to a file in the shared container (backup method)
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("screen_time_data.json")
            let totalMinutes = Int(summary.totalDuration / 60)
            let data: [String: Any] = [
                "total_usage": totalMinutes,
                "apps_count": summary.appCount,
                "last_updated": Date().timeIntervalSince1970
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
                try? jsonData.write(to: fileURL)
            }
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


