//
//  SE7ENDeviceActivityReportExtension.swift
//  SE7ENDeviceActivityReportExtension
//
//  Created by Montel Nevers on 05/12/2025.
//

import DeviceActivity
import SwiftUI

@main
struct SE7ENDeviceActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Create a report for each DeviceActivityReport.Context that your app supports.
        // The extension will be called automatically by the system when monitoring is active
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }
        
        TodayOverviewReport { summary in
            TodayOverviewView(summary: summary)
        }
    }
}
