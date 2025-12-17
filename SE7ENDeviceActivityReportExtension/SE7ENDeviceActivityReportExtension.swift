//
//  SE7ENDeviceActivityReportExtension.swift
//  SE7ENDeviceActivityReportExtension
//
//  Main entry point for the Device Activity Report Extension
//

import DeviceActivity
import SwiftUI

@main
struct SE7ENDeviceActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Total screen time report
        TotalActivityReport { totalMinutes in
            TotalActivityView(activityReport: totalMinutes)
        }
        
        // Detailed app usage report
        TodayOverviewReport { summary in
            TodayOverviewView(summary: summary)
        }
    }
}
