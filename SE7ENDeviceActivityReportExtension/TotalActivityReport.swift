//
//  TotalActivityReport.swift
//  SE7ENDeviceActivityReportExtension
//
//  Created by Montel Nevers on 05/12/2025.
//

import DeviceActivity
import SwiftUI
import Foundation

extension DeviceActivityReport.Context {
    // If your app initializes a DeviceActivityReport with this context, then the system will use
    // your extension's corresponding DeviceActivityReportScene to render the contents of the
    // report.
    static let totalActivity = Self("Total Activity")
}

struct TotalActivityReport: DeviceActivityReportScene {
    // Define which context your scene will represent.
    let context: DeviceActivityReport.Context = .totalActivity
    
    // Define the custom configuration and the resulting view for this report.
    let content: (String) -> TotalActivityView
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        // Extract usage data and save to shared container
        // Process all activity segments to extract app usage
        let totalActivityDuration = await extractAndSaveUsageData(data: data)
        
        // Reformat the data into a configuration that can be used to create
        // the report's view.
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        
        return formatter.string(from: totalActivityDuration) ?? "No activity data"
    }
    
    private func extractAndSaveUsageData(data: DeviceActivityResults<DeviceActivityData>) async -> TimeInterval {
        // Process all activity segments to extract total usage and distinct apps
        var totalUsage: TimeInterval = 0
        var uniqueApps: Set<String> = []
        
        // Iterate through the async sequence using for await
        for await deviceActivityData in data {
            // activitySegments is also an async sequence, so we need for await here too
            for await segment in deviceActivityData.activitySegments {
                // Accumulate total usage duration
                totalUsage += segment.totalActivityDuration
                
                // Capture distinct apps seen in this segment
                for await category in segment.categories {
                    for await app in category.applications {
                        let identifier = app.application.bundleIdentifier
                        let name = app.application.localizedDisplayName
                        let key = identifier ?? name ?? "Unknown"
                        uniqueApps.insert(key)
                    }
                }
            }
        }
        
        // Save total usage
        let totalMinutes = Int(totalUsage / 60)
        let appsCount = uniqueApps.count
        
        // Save to shared container
        let appGroupID = "group.com.se7en.app"
        DispatchQueue.main.async {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
            
            // Save total usage
            sharedDefaults.set(totalMinutes, forKey: "total_usage")
            sharedDefaults.set(appsCount, forKey: "apps_count")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
            
            print("📊 DeviceActivityReport: Total usage: \(totalMinutes) minutes, distinct apps: \(appsCount)")
        }
        
        return totalUsage
    }
    
    private func saveUsageToSharedContainer(key: String, minutes: Int) {
        // Use App Group to share data between extension and main app
        let appGroupID = "group.com.se7en.app"
        
        // Access UserDefaults on main thread to avoid CFPrefsPlistSource errors
        DispatchQueue.main.async {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
                print("❌ Failed to access shared container with ID: \(appGroupID)")
                print("⚠️ Make sure App Groups capability is enabled in Xcode")
                return
            }
            
            // Save directly - UserDefaults is thread-safe
            // Use simple key-value storage instead of nested dictionaries
            sharedDefaults.set(minutes, forKey: key)
            
            // Also save timestamp
            if key == "total_usage" {
                sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
            }
            
            print("💾 Saved usage to shared container: \(key) = \(minutes)")
        }
    }
}
