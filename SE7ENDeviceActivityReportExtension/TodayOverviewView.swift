//
//  TodayOverviewView.swift
//  SE7ENDeviceActivityReportExtension
//

import SwiftUI

struct TodayOverviewView: View {
    let summary: UsageSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text("Today's Screen Time")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            // Total duration
            Text(format(duration: summary.totalDuration))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            // Apps used count
            Text("Apps used today: \(summary.appCount)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            // Top 10 apps header - only show if we have app data
            if !summary.topApps.isEmpty {
                Text("Top 10 apps today")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.top, 8)
                
                // Top apps list
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(summary.topApps) { app in
                        HStack {
                            Text(app.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(format(duration: app.duration))
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else if summary.appCount > 0 {
                // We have usage but no per-app breakdown
                Text("Individual app breakdown not available")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Helper function to format duration
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
