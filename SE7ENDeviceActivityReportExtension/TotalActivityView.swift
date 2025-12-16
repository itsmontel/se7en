//
//  TotalActivityView.swift
//  SE7ENDeviceActivityReportExtension
//

import SwiftUI

struct TotalActivityView: View {
    let totalActivity: TotalActivityData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total Activity")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(format(duration: totalActivity.totalDuration))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("\(totalActivity.appsCount) apps")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            // SAVE DATA WHEN VIEW APPEARS
            saveDataToSharedContainer()
        }
    }
    
    private func saveDataToSharedContainer() {
        let appGroupID = "group.com.se7en.app"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        let totalMinutes = Int(totalActivity.totalDuration / 60)
        
        sharedDefaults.set(totalMinutes, forKey: "total_usage")
        sharedDefaults.set(totalActivity.appsCount, forKey: "apps_count")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
        sharedDefaults.synchronize()
        
        // File backup
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("screen_time_data.json")
            let data: [String: Any] = [
                "total_usage": totalMinutes,
                "apps_count": totalActivity.appsCount,
                "last_updated": Date().timeIntervalSince1970
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
                try? jsonData.write(to: fileURL)
            }
        }
    }
    
    private func format(duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}
