//
//  TodayOverviewView.swift
//  SE7ENDeviceActivityReportExtension
//

import SwiftUI

struct TodayOverviewView: View {
    let summary: UsageSummary
    
    var body: some View {
        // App background color that adapts to light/dark mode
        let appBackground = Color(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0)
            } else {
                return UIColor(red: 1.0, green: 0.98, blue: 0.9, alpha: 1.0)
            }
        })
        
        VStack(alignment: .leading, spacing: 16) {
            // Summary stats - side by side
            HStack(spacing: 20) {
                // Today's Screen Time
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Screen Time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    
                    Text(format(duration: summary.totalDuration))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Apps Used
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Apps Used")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("\(summary.appCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 4)
            
            // Top apps list
            if !summary.topApps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Apps")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    ForEach(summary.topApps.prefix(5), id: \.name) { app in
                        HStack {
                            // App name
                            Text(app.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Spacer()
                            
                            // Usage time
                            Text(format(duration: app.duration))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(appBackground)
                        .cornerRadius(12)
                    }
                }
            } else if summary.appCount > 0 {
                Text("Individual app breakdown not available")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(.top, 0)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            print("📊 TodayOverviewView appeared with \(summary.appCount) apps, \(Int(summary.totalDuration / 60)) min total")
        }
    }
    
    private func format(duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
