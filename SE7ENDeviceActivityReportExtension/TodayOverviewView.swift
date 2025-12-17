//
//  TodayOverviewView.swift
//  SE7ENDeviceActivityReportExtension
//
//  UI for displaying today's app usage overview
//

import SwiftUI
import DeviceActivity
import FamilyControls

struct TodayOverviewView: View {
    let activityReport: UsageSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Today's App Usage")
                    .font(.headline)
                Spacer()
            }
            
            // Summary Stats
            HStack(spacing: 20) {
                VStack {
                    Text("\(activityReport.totalMinutes)")
                        .font(.title.bold())
                        .foregroundColor(.primary)
                    Text("Total Minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text("\(activityReport.appCount)")
                        .font(.title.bold())
                        .foregroundColor(.primary)
                    Text("Apps Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Top Apps
            if !activityReport.topApps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Most Used Apps")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    ForEach(Array(activityReport.topApps.prefix(5).enumerated()), id: \.offset) { index, app in
                        HStack {
                            // App rank indicator
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                
                                Text("\(app.minutes) min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Usage bar
                            let maxUsage = activityReport.topApps.first?.minutes ?? 1
                            let barWidth = CGFloat(app.minutes) / CGFloat(max(maxUsage, 1)) * 60
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.7))
                                .frame(width: max(barWidth, 4), height: 8)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else {
                Text("No app usage data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    let sampleApps = [
        AppUsage(name: "Instagram", duration: 7200),
        AppUsage(name: "TikTok", duration: 5700),
        AppUsage(name: "Safari", duration: 2700)
    ]
    
    let summary = UsageSummary(
        totalDuration: 15600,
        appCount: 8,
        topApps: sampleApps
    )
    
    return TodayOverviewView(activityReport: summary)
        .padding()
}
