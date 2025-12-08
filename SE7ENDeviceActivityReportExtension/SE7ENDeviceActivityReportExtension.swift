//
//  SE7ENDeviceActivityReportExtension.swift
//  SE7ENDeviceActivityReportExtension
//

import DeviceActivity
import SwiftUI

@main
struct SE7ENDeviceActivityReportExtension: DeviceActivityReportExtension {
    init() {
        print("🎬 SE7ENDeviceActivityReportExtension: INITIALIZED")
        print("🏗️ SE7ENDeviceActivityReportExtension: Building scenes...")
    }
    
    var body: some DeviceActivityReportScene {
        TotalActivityReport { totalActivity in
            print("📊 TotalActivityReport scene rendered")
            return TotalActivityView(totalActivity: totalActivity)
        }
        
        TodayOverviewReport { summary in
            print("📊 TodayOverviewReport scene rendered")
            return TodayOverviewView(summary: summary)
        }
    }
}


