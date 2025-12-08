//
//  UsageSummary.swift
//  SE7ENDeviceActivityReportExtension
//
//  Created by Cursor on 05/12/2025.
//

import Foundation

struct AppUsage: Identifiable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
}

struct UsageSummary {
    let totalDuration: TimeInterval
    let appCount: Int
    let topApps: [AppUsage]
    
    static let empty = UsageSummary(totalDuration: 0, appCount: 0, topApps: [])
}




