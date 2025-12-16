//
//  TotalActivityReport.swift
//  SE7ENDeviceActivityReportExtension
//

import DeviceActivity
import SwiftUI
import Foundation

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (TotalActivityData) -> TotalActivityView
    
    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> TotalActivityData {
        var totalDuration: TimeInterval = 0
        var uniqueApps: Set<String> = []
        
        // Process all device activity data
        for await deviceActivityData in data {
            for await segment in deviceActivityData.activitySegments {
                totalDuration += segment.totalActivityDuration
                
                // Drill into categories and applications to count unique apps
                for await category in segment.categories {
                    for await app in category.applications {
                        // Filter out placeholder app names
                        guard let name = sanitizedAppName(app.application.localizedDisplayName) else {
                            continue
                        }
                        uniqueApps.insert(name)
                    }
                }
            }
        }
        
        print("📊 TotalActivityReport: totalDuration=\(Int(totalDuration))s uniqueApps=\(uniqueApps.count)")
        
        // Save to shared container
        saveToSharedContainer(totalDuration: totalDuration, appsCount: uniqueApps.count)
        
        return TotalActivityData(
            totalDuration: totalDuration,
            appsCount: uniqueApps.count
        )
    }
    
    private func saveToSharedContainer(totalDuration: TimeInterval, appsCount: Int) {
        let appGroupID = "group.com.se7en.app"
        let totalMinutes = Int(totalDuration / 60)
        
        // METHOD 1: UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.set(totalMinutes, forKey: "total_usage")
            sharedDefaults.set(appsCount, forKey: "apps_count")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
            sharedDefaults.synchronize()
        }
        
        // METHOD 2: File backup
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("screen_time_data.json")
            let data: [String: Any] = [
                "total_usage": totalMinutes,
                "apps_count": appsCount,
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

struct TotalActivityData {
    let totalDuration: TimeInterval
    let appsCount: Int
}









