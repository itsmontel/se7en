//
//  TodayOverviewView.swift
//  SE7ENDeviceActivityReportExtension
//

import SwiftUI

struct TodayOverviewView: View {
    let summary: UsageSummary
    
    var body: some View {
        let appBackground = Color(red: 1.0, green: 0.98, blue: 0.9) // soft yellow to match app theme
        VStack(alignment: .leading, spacing: 16) {
            // Summary stats - side by side
                HStack(spacing: 20) {
                    // Today's Screen Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Screen Time")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text(format(duration: summary.totalDuration))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Apps Used
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Apps Used")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("\(summary.appCount)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.bottom, 8)
                
                // Divider
                Divider()
                    .padding(.vertical, 4)
                
                // Top 10 Distractions header - only show if we have app data
                if !summary.topApps.isEmpty {
                    Text("Top 10 Distractions")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                    
                    // Top apps list with numeric rank (1-10)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(summary.topApps.prefix(10).enumerated()), id: \.element.id) { index, app in
                            HStack(spacing: 12) {
                                // Rank badge
                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(width: 32, height: 32)
                                    .background(appBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
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
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(appBackground)
                            .cornerRadius(12)
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
            .padding(.top, 72) // move content further down to avoid clipping
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
    }
    
    // Helper function to format duration
    private func format(duration: TimeInterval) -> String {
        if duration > 0 && duration < 60 {
            return "<1m"
        }
        
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
    
    // Helper function to get app icon based on name
    @ViewBuilder
    private func appIcon(for appName: String) -> some View {
        let iconName = iconForApp(appName)
        Image(systemName: iconName)
    }
    
    // Map app names to SF Symbols
    private func iconForApp(_ appName: String) -> String {
        let lowerName = appName.lowercased()
        
        // Common app icon mappings
        if lowerName.contains("instagram") { return "camera.fill" }
        if lowerName.contains("facebook") || lowerName.contains("meta") { return "f.circle.fill" }
        if lowerName.contains("twitter") || lowerName.contains("x ") { return "x.circle.fill" }
        if lowerName.contains("tiktok") { return "music.note.list" }
        if lowerName.contains("snapchat") { return "camera.macro.circle.fill" }
        if lowerName.contains("youtube") { return "play.circle.fill" }
        if lowerName.contains("reddit") { return "r.circle.fill" }
        if lowerName.contains("whatsapp") { return "message.circle.fill" }
        if lowerName.contains("telegram") { return "paperplane.circle.fill" }
        if lowerName.contains("discord") { return "gamecontroller.fill" }
        if lowerName.contains("safari") { return "safari.fill" }
        if lowerName.contains("chrome") { return "globe" }
        if lowerName.contains("netflix") { return "tv.fill" }
        if lowerName.contains("spotify") { return "music.note" }
        if lowerName.contains("amazon") { return "cart.fill" }
        if lowerName.contains("uber") || lowerName.contains("lyft") { return "car.fill" }
        if lowerName.contains("se7en") { return "7.circle.fill" }
        
        // Default app icon
        return "app.fill"
    }
}




