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
        // Track TOTAL screen time from ALL apps (no filtering by category or app type)
        var totalSeconds: TimeInterval = 0
        
        for await datum in data {
            for await segment in datum.activitySegments {
                // Add ALL activity duration (includes all apps, all categories)
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
        
        // Calculate health score from TOTAL screen time (all apps combined, no filtering)
        let healthScore = calculateHealthScore(totalMinutes: totalMinutes)
        
        sharedDefaults.set(totalMinutes, forKey: "total_usage")
        sharedDefaults.set(healthScore, forKey: "health_score")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
        
        // Also write JSON backup for the main app.
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("screen_time_data.json")
            let payload: [String: Any] = [
                "total_usage": totalMinutes,
                "health_score": healthScore,
                "last_updated": Date().timeIntervalSince1970
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
                try? data.write(to: fileURL, options: [.atomic])
            }
        }
        
        sharedDefaults.synchronize()
        
        #if DEBUG
        print("📊 TOTAL: Saved \(totalMinutes) min, health: \(healthScore)%")
        #endif
    }
    
    /// Calculate health score based on TOTAL screen time (ALL apps combined)
    /// No filtering - health is calculated from total screen time across all apps
    private func calculateHealthScore(totalMinutes: Int) -> Int {
        let totalHours = Double(totalMinutes) / 60.0
        
        let healthScore: Int
        switch totalHours {
        case 0..<2: healthScore = 100
        case 2..<4: healthScore = Int(100.0 - (20.0 * (totalHours - 2.0)))
        case 4..<6: healthScore = Int(60.0 - (10.0 * (totalHours - 4.0)))
        case 6..<8: healthScore = Int(40.0 - (10.0 * (totalHours - 6.0)))
        case 8..<10: healthScore = Int(20.0 - (10.0 * (totalHours - 8.0)))
        default: healthScore = 0
        }
        
        return max(0, min(100, healthScore))
    }
}
