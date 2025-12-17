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
            HStack(alignment: .top, spacing: 0) {
                // Today's Screen Time
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Screen...")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Text(format(duration: summary.totalDuration))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Apps Used
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Apps Used")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Text("\(summary.appCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 20)
            
            // Top 10 Distractions list
            if !summary.topApps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top 10 Distractions")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(summary.topApps.prefix(10).enumerated()), id: \.offset) { index, app in
                            HStack(spacing: 16) {
                                // Number (1-10)
                                Text("\(index + 1)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(width: 30, alignment: .leading)
                                
                                // App name
                                Text(app.name)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // Usage time
                                Text(format(duration: app.duration))
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            
                            // Divider between items (but not after last item)
                            if index < min(summary.topApps.count, 10) - 1 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            } else if summary.appCount > 0 {
                Text("Individual app breakdown not available")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .background(appBackground)
        .cornerRadius(16)
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
