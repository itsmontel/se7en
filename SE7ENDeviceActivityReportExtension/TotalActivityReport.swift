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
        saveToSharedContainer(totalMinutes: totalMinutes)
        
        return totalMinutes
    }
    
    private func saveToSharedContainer(totalMinutes: Int) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.se7en.app") else {
            print("❌ TOTAL: Failed to access App Group")
            return
        }
        
        sharedDefaults.set(totalMinutes, forKey: "total_usage")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
        sharedDefaults.synchronize()
        
        print("📊 TOTAL: Saved \(totalMinutes) minutes")
    }
}
