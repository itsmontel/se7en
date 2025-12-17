//
//  UsageSummary.swift
//  SE7ENDeviceActivityReportExtension
//
//  Data models for usage reporting
//

import Foundation
import ManagedSettings

// MARK: - App Usage Info
struct AppUsageInfo: Identifiable {
    let id = UUID()
    let name: String
    let usage: Int // minutes
    let token: ApplicationToken?
    
    init(name: String, usage: Int, token: ApplicationToken? = nil) {
        self.name = name
        self.usage = usage
        self.token = token
    }
}

// MARK: - Usage Summary
struct UsageSummary {
    let totalDuration: TimeInterval
    let appCount: Int
    let topApps: [AppUsage]
    
    var totalMinutes: Int {
        Int(totalDuration / 60)
    }
    
    var appsCount: Int {
        appCount
    }
}

// MARK: - App Usage (for top apps list)
struct AppUsage {
    let name: String
    let duration: TimeInterval
    
    var minutes: Int {
        Int(duration / 60)
    }
}
