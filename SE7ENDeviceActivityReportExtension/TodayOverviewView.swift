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
                return UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0) // Dark charcoal for dark mode
            } else {
                return UIColor(red: 1.0, green: 0.98, blue: 0.9, alpha: 1.0) // Soft yellow for light mode
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
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.bottom, 8)
                
                // Divider
                Divider()
                    .padding(.vertical, 2)
                
                // Top 10 Distractions header - only show if we have app data
                if !summary.topApps.isEmpty {
                    Text("Top 10 Distractions")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                    
                    // Top apps list with numeric rank (1-10)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(summary.topApps.prefix(10).enumerated()), id: \.element.id) { index, app in
                            HStack(spacing: 10) {
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
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)
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
            .padding(.top, 0) // Reduced top padding to push content closer to "Today's Dashboard" header
            .padding(.horizontal, 8) // Minimal horizontal padding - wider container, closer to edges
            .padding(.vertical, 8) // Reduced vertical padding
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .onAppear {
                // SAVE DATA WHEN VIEW APPEARS - THIS WILL DEFINITELY RUN!
                saveDataToSharedContainer()
            }
    }
    
    // MARK: - Save to Shared Container (called from onAppear)
    
    private func saveDataToSharedContainer() {
        let appGroupID = "group.com.se7en.app"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        let totalMinutes = Int(summary.totalDuration / 60)
        let appsCount = summary.appCount
        
        // Save to UserDefaults
        sharedDefaults.set(totalMinutes, forKey: "total_usage")
        sharedDefaults.set(appsCount, forKey: "apps_count")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
        
        // Build top apps array
        let topAppsPayload: [[String: Any]] = summary.topApps.map {
            ["name": $0.name, "minutes": Int($0.duration / 60)]
        }
        sharedDefaults.set(topAppsPayload, forKey: "top_apps")
        
        // Force sync
        sharedDefaults.synchronize()
        
        // Also write to file as backup
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("screen_time_data.json")
            let data: [String: Any] = [
                "total_usage": totalMinutes,
                "apps_count": appsCount,
                "last_updated": Date().timeIntervalSince1970
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
                try? jsonData.write(to: fileURL)
            }
        }
    }
    
    // MARK: - Helpers
    
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
