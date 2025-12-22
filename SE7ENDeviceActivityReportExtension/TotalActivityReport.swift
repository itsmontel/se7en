//
//  TotalActivityReport.swift
//  SE7ENDeviceActivityReportExtension
//
//  Simple report for total screen time
//

import DeviceActivity
import SwiftUI

// MARK: - Report Context
extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
}

// MARK: - Total Activity Report
struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (Int) -> TotalActivityView
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Int {
        var totalSeconds: TimeInterval = 0
        
        for await datum in data {
            for await segment in datum.activitySegments {
                totalSeconds += segment.totalActivityDuration
            }
        }
        
        let totalMinutes = Int(totalSeconds / 60)
        
        // Save to shared container for main app
        // IMPORTANT: Perform App Group I/O on MainActor to avoid CFPrefsPlistSource issues.
        await saveToSharedContainer(totalMinutes: totalMinutes)
        
        return totalMinutes
    }
    
    @MainActor
    private func saveToSharedContainer(totalMinutes: Int) async {
        let appGroupID = "group.com.se7en.app"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            #if DEBUG
            print("❌ TOTAL: Failed to access App Group")
            #endif
            return
        }
        
        sharedDefaults.set(totalMinutes, forKey: "total_usage")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
        
        // Also write JSON backup for the main app.
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("screen_time_data.json")
            let payload: [String: Any] = [
                "total_usage": totalMinutes,
                "last_updated": Date().timeIntervalSince1970
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
                try? data.write(to: fileURL, options: [.atomic])
            }
        }
        
        sharedDefaults.synchronize()
        
        #if DEBUG
        print("📊 TOTAL: Saved \(totalMinutes) minutes")
        #endif
    }
}
