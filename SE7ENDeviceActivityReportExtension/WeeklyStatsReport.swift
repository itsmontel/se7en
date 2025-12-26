//
//  WeeklyStatsReport.swift
//  SE7ENDeviceActivityReportExtension
//
//  Reports weekly stats: average screen time and best day
//

import DeviceActivity
import SwiftUI
import Foundation
import FamilyControls
import ManagedSettings

// MARK: - Report Context
extension DeviceActivityReport.Context {
    static let weeklyStats = Self("weeklyStats")
}

// MARK: - Daily Health Data
struct DailyHealthData {
    let date: Date
    let dayName: String
    let dayNumber: Int
    let healthScore: Int
    let screenTimeMinutes: Int  // Screen time in minutes for this day
    let petMood: String  // PetHealthState raw value
    let isToday: Bool
    let isFuture: Bool
    let isBeforeInstall: Bool
}

// MARK: - Weekly Stats Data
struct WeeklyStatsData {
    let averageScreenTimeMinutes: Int
    let bestDay: String
    let bestDayMinutes: Int
    let totalScreenTimeMinutes: Int
    let daysWithData: Int
    let dailyBreakdown: [(day: String, minutes: Int)]
    let todayScreenTimeMinutes: Int  // Today's screen time
    let currentStreak: Int  // User's current streak
    let blockedAppsCount: Int  // Number of blocked apps
    let topApps: [TopAppInfo]  // Top 5 most used apps with tokens
    let worstDay: String  // Day with most screen time
    let worstDayMinutes: Int
    let isIncreasing: Bool  // Is screen time trending up?
    let peakUsageHour: Int?  // Hour with most usage (0-23)
    let dailyHealthData: [DailyHealthData]  // Daily health scores and moods
    let userPetType: String  // User's pet type (from shared container)
    
    static let empty = WeeklyStatsData(
        averageScreenTimeMinutes: 0,
        bestDay: "—",
        bestDayMinutes: 0,
        totalScreenTimeMinutes: 0,
        daysWithData: 0,
        dailyBreakdown: [],
        todayScreenTimeMinutes: 0,
        currentStreak: 0,
        blockedAppsCount: 0,
        topApps: [],
        worstDay: "—",
        worstDayMinutes: 0,
        isIncreasing: false,
        peakUsageHour: nil,
        dailyHealthData: [],
        userPetType: "dog"
    )
}

// MARK: - Top App Info
struct TopAppInfo {
    let name: String
    let minutes: Int
    let application: Application?
}

// MARK: - Weekly Stats Report
struct WeeklyStatsReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .weeklyStats
    let content: (WeeklyStatsData) -> WeeklyStatsView
    
    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> WeeklyStatsData {
        print("📊 WeeklyStatsReport: Processing weekly data (Monday-Sunday)...")
        
        let appGroupID = "group.com.se7en.app"
        let calendar = Calendar.current
        
        // Calculate start of the current week (Monday)
        var modifiedCalendar = calendar
        modifiedCalendar.firstWeekday = 2 // Monday
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday - 2 + 7) % 7
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return .empty
        }
        
        // Track daily screen time and per-app usage
        var dailyTotals: [Date: TimeInterval] = [:]
        var appUsage: [String: TimeInterval] = [:]
        var appTokens: [String: Application] = [:] // Track app tokens for icons
        var hourlyUsage: [Int: TimeInterval] = [:] // Track usage by hour
        
        for await deviceActivityData in data {
            for await segment in deviceActivityData.activitySegments {
                // Get the date and hour for this segment
                let segmentDate = calendar.startOfDay(for: segment.dateInterval.start)
                let hour = calendar.component(.hour, from: segment.dateInterval.start)
                
                // Sum up all activity for this segment
                for await category in segment.categories {
                    for await app in category.applications {
                        let duration = app.totalActivityDuration
                        if duration > 0 {
                            let appName = app.application.localizedDisplayName ?? "Unknown"
                            
                            dailyTotals[segmentDate, default: 0] += duration
                            appUsage[appName, default: 0] += duration
                            hourlyUsage[hour, default: 0] += duration
                            
                            // Store the application token for this app
                            if appTokens[appName] == nil {
                                appTokens[appName] = app.application
                            }
                        }
                    }
                }
            }
        }
        
        // Get top 5 apps with their tokens
        let topApps: [TopAppInfo] = appUsage.sorted { $0.value > $1.value }
            .prefix(5)
            .map { TopAppInfo(name: $0.key, minutes: Int($0.value / 60), application: appTokens[$0.key]) }
        
        // Find peak usage hour
        let peakHour = hourlyUsage.max { $0.value < $1.value }?.key
        
        // Process daily data
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEEE"
        
        var totalMinutes = 0
        var bestDay: (name: String, minutes: Int)? = nil
        var worstDay: (name: String, minutes: Int)? = nil
        var dailyBreakdown: [(day: String, minutes: Int)] = []
        
        // Sort by date (most recent first for display)
        let sortedDays = dailyTotals.sorted { $0.key > $1.key }
        
        for (date, duration) in sortedDays {
            let minutes = Int(duration / 60)
            let dayName = dayNameFormatter.string(from: date)
            
            totalMinutes += minutes
            dailyBreakdown.append((day: dayName, minutes: minutes))
            
            // Best day = lowest screen time (better discipline)
            if minutes > 0 {
                if bestDay == nil || minutes < bestDay!.minutes {
                    bestDay = (dayName, minutes)
                }
                if worstDay == nil || minutes > worstDay!.minutes {
                    worstDay = (dayName, minutes)
                }
            }
        }
        
        let daysWithData = dailyTotals.count
        let averageMinutes = daysWithData > 0 ? totalMinutes / daysWithData : 0
        
        // Check if screen time is increasing (compare first half to second half of week)
        let isIncreasing: Bool = {
            guard daysWithData >= 4 else { return false }
            let mid = daysWithData / 2
            let firstHalf = Array(dailyBreakdown.suffix(mid))
            let secondHalf = Array(dailyBreakdown.prefix(mid))
            let firstAvg = firstHalf.reduce(0) { $0 + $1.minutes } / max(1, firstHalf.count)
            let secondAvg = secondHalf.reduce(0) { $0 + $1.minutes } / max(1, secondHalf.count)
            return secondAvg > firstAvg
        }()
        
        // Get today's screen time and other shared data
        var todayScreenTime = 0
        var currentStreak = 0
        var blockedAppsCount = 0
        var userPetType = "dog"
        var installDate: Date?
        var dailyHealthHistory: [String: [String: Any]] = [:]
        
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            todayScreenTime = sharedDefaults.integer(forKey: "total_usage")
            if todayScreenTime == 0, let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int] {
                todayScreenTime = perAppUsage.values.reduce(0, +)
            }
            
            // Get current streak
            currentStreak = sharedDefaults.integer(forKey: "current_streak")
            
            // Get blocked apps count
            blockedAppsCount = sharedDefaults.integer(forKey: "blocked_apps_count")
            
            // Get user's pet type
            userPetType = sharedDefaults.string(forKey: "user_pet_type") ?? "dog"
            
            // Get install date
            if let installTimestamp = sharedDefaults.object(forKey: "install_date") as? Double {
                installDate = Date(timeIntervalSince1970: installTimestamp)
            }
            
            // Get daily health history
            dailyHealthHistory = sharedDefaults.dictionary(forKey: "daily_health") as? [String: [String: Any]] ?? [:]
        }
        
        // Calculate daily health data for each day of the week (Monday to Sunday)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let shortDayNameFormatter = DateFormatter()
        shortDayNameFormatter.dateFormat = "EEE" // Short day name
        
        var dailyHealthDataArray: [DailyHealthData] = []
        
        // Generate data for all 7 days of the week (Monday to Sunday)
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else {
                continue
            }
            
            let dateKey = dateFormatter.string(from: date)
            let dayName = shortDayNameFormatter.string(from: date)
            let dayNumber = calendar.component(.day, from: date)
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > Date()
            
            // Check if before install
            var isBeforeInstall = false
            if let install = installDate, date < calendar.startOfDay(for: install) {
                isBeforeInstall = true
            }
            
            // Get screen time for this day
            let duration = dailyTotals[calendar.startOfDay(for: date)] ?? 0
            let minutes = Int(duration / 60)
            
            // Calculate health score from screen time
            let totalHours = Double(minutes) / 60.0
            let healthScore: Int
            switch totalHours {
            case 0..<2: healthScore = 100
            case 2..<4: healthScore = Int(100.0 - (10.0 * (totalHours - 2.0)))
            case 4..<6: healthScore = Int(80.0 - (10.0 * (totalHours - 4.0)))
            case 6..<8: healthScore = Int(60.0 - (10.0 * (totalHours - 6.0)))
            case 8..<10: healthScore = Int(40.0 - (10.0 * (totalHours - 8.0)))
            case 10..<12: healthScore = Int(20.0 - (10.0 * (totalHours - 10.0)))
            default: healthScore = 0
            }
            let clampedScore = max(0, min(100, healthScore))
            
            // Determine pet mood from health score
            let petMood: String
            switch clampedScore {
            case 90...100: petMood = "fullhealth"
            case 70..<90: petMood = "happy"
            case 50..<70: petMood = "content"
            case 20..<50: petMood = "sad"
            default: petMood = "sick"
            }
            
            // Override with stored data if available (for past days)
            var finalScore = clampedScore
            var finalMood = petMood
            if !isFuture && !isBeforeInstall, let dayData = dailyHealthHistory[dateKey] {
                finalScore = dayData["score"] as? Int ?? clampedScore
                finalMood = dayData["mood"] as? String ?? petMood
            }
            
            dailyHealthDataArray.append(DailyHealthData(
                date: date,
                dayName: dayName,
                dayNumber: dayNumber,
                healthScore: finalScore,
                screenTimeMinutes: minutes,  // Add screen time minutes
                petMood: finalMood,
                isToday: isToday,
                isFuture: isFuture,
                isBeforeInstall: isBeforeInstall
            ))
        }
        
        print("📊 WeeklyStatsReport: \(daysWithData) days, avg \(averageMinutes) min, best: \(bestDay?.name ?? "none") (\(bestDay?.minutes ?? 0) min)")
        print("📊 WeeklyStatsReport: Top apps: \(topApps.count), worst day: \(worstDay?.name ?? "none"), trending: \(isIncreasing ? "up" : "down")")
        print("📊 WeeklyStatsReport: Today: \(todayScreenTime) min, streak: \(currentStreak), blocked: \(blockedAppsCount)")
        print("📊 WeeklyStatsReport: Daily health data: \(dailyHealthDataArray.count) days, pet type: \(userPetType)")
        
        // Save to shared container for other views
        await saveToSharedContainer(
            averageMinutes: averageMinutes,
            bestDay: bestDay?.name ?? "—",
            bestDayMinutes: bestDay?.minutes ?? 0,
            totalMinutes: totalMinutes,
            daysWithData: daysWithData
        )
        
        return WeeklyStatsData(
            averageScreenTimeMinutes: averageMinutes,
            bestDay: bestDay?.name ?? "—",
            bestDayMinutes: bestDay?.minutes ?? 0,
            totalScreenTimeMinutes: totalMinutes,
            daysWithData: daysWithData,
            dailyBreakdown: dailyBreakdown,
            todayScreenTimeMinutes: todayScreenTime,
            currentStreak: currentStreak,
            blockedAppsCount: blockedAppsCount,
            topApps: topApps,
            worstDay: worstDay?.name ?? "—",
            worstDayMinutes: worstDay?.minutes ?? 0,
            isIncreasing: isIncreasing,
            peakUsageHour: peakHour,
            dailyHealthData: dailyHealthDataArray,
            userPetType: userPetType
        )
    }
    
    @MainActor
    private func saveToSharedContainer(
        averageMinutes: Int,
        bestDay: String,
        bestDayMinutes: Int,
        totalMinutes: Int,
        daysWithData: Int
    ) async {
        let appGroupID = "group.com.se7en.app"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        sharedDefaults.set(averageMinutes, forKey: "weekly_avg_screen_time")
        sharedDefaults.set(bestDay, forKey: "weekly_best_day")
        sharedDefaults.set(bestDayMinutes, forKey: "weekly_best_day_minutes")
        sharedDefaults.set(totalMinutes, forKey: "weekly_total_screen_time")
        sharedDefaults.set(daysWithData, forKey: "weekly_days_with_data")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "weekly_stats_updated")
        sharedDefaults.synchronize()
        
        #if DEBUG
        print("💾 WeeklyStats: Saved avg=\(averageMinutes)m, best=\(bestDay) (\(bestDayMinutes)m)")
        #endif
    }
}

