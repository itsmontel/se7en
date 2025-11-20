import DeviceActivity
import Foundation
import ManagedSettings

// DeviceActivity extensions moved to Extensions/DeviceActivityExtensions.swift

// MARK: - DeviceActivityMonitor Extension

class SE7ENDeviceActivityMonitor: DeviceActivityMonitor {
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        print("🟢 Device activity interval started: \(activity)")
        
        // Reset daily tracking when interval starts (typically at midnight)
        if activity == .se7enDaily {
            resetDailyTracking()
        }
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        print("🔴 Device activity interval ended: \(activity)")
        
        // Handle end-of-day processing
        if activity == .se7enDaily {
            processDayEnd()
        }
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        print("⚠️ Event threshold reached: \(event) for activity: \(activity)")
        
        // Extract bundle ID from event name
        let eventString = String(describing: event)
        
        if eventString.contains("warning") {
            handleWarningEvent(event, activity: activity)
        } else if eventString.contains("limit") {
            handleLimitEvent(event, activity: activity)
        }
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        
        print("🟡 Interval will start warning for activity: \(activity)")
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        
        print("🟡 Interval will end warning for activity: \(activity)")
    }
    
    // MARK: - Private Methods
    
    private func handleWarningEvent(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        let eventString = String(describing: event)
        
        // Extract bundle ID from event name (format: "se7en.warning.bundleID")
        if let bundleID = extractBundleID(from: eventString, prefix: "se7en.warning.") {
            print("🟡 Warning threshold reached for app: \(bundleID)")
            
            // Send warning notification
            sendWarningNotification(for: bundleID)
        }
    }
    
    private func handleLimitEvent(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        let eventString = String(describing: event)
        
        // Extract bundle ID from event name (format: "se7en.limit.bundleID")
        if let bundleID = extractBundleID(from: eventString, prefix: "se7en.limit.") {
            print("🔴 Limit threshold reached for app: \(bundleID)")
            
            // Handle limit exceeded - this is the critical function
            handleLimitExceeded(for: bundleID)
        }
    }
    
    private func extractBundleID(from eventString: String, prefix: String) -> String? {
        guard eventString.hasPrefix(prefix) else { return nil }
        let bundleID = String(eventString.dropFirst(prefix.count))
        return bundleID.isEmpty ? nil : bundleID
    }
    
    private func sendWarningNotification(for bundleID: String) {
        // Get app name from Core Data
        let coreDataManager = CoreDataManager.shared
        let goals = coreDataManager.getActiveAppGoals()
        
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else {
            print("⚠️ No goal found for bundle ID: \(bundleID)")
            return
        }
        
        let appName = goal.appName ?? "Unknown App"
        let limitMinutes = Int(goal.dailyLimitMinutes)
        let warningMinutes = Int(Double(limitMinutes) * 0.2) // 20% remaining
        
        // Send notification
        NotificationService.shared.sendLimitWarningNotification(
            appName: appName,
            timeRemaining: warningMinutes
        )
        
        print("📱 Sent warning notification for \(appName)")
    }
    
    private func handleLimitExceeded(for bundleID: String) {
        print("🚨 Handling limit exceeded for: \(bundleID)")
        
        // Delegate to ScreenTimeService to handle the limit exceeded (no auto credit loss)
        ScreenTimeService.shared.handleLimitExceeded(for: bundleID)
        
        print("✅ App blocked for \(bundleID) - credit preserved unless user chooses to unblock")
    }
    
    private func resetDailyTracking() {
        print("🔄 Resetting daily tracking for new day")
        
        // Unblock all apps at start of new day
        ScreenTimeService.shared.unblockAllApps()
        
        // Note: Individual app usage tracking resets automatically
        // with the DeviceActivity interval
    }
    
    private func processDayEnd() {
        print("🌅 Processing end of day")
        
        // Check if it's end of week (Sunday night)
        let calendar = Calendar.current
        let today = Date()
        
        if calendar.component(.weekday, from: today) == 1 { // Sunday
            print("📅 End of week detected - triggering weekly reset")
            ScreenTimeService.shared.performWeeklyReset()
        }
        
        // Save any pending Core Data changes
        CoreDataManager.shared.save()
    }
}

// MARK: - DeviceActivityMonitor Registration

extension ScreenTimeService {
    
    // Method to register the monitor (called during app setup)
    func registerDeviceActivityMonitor() {
        // The actual registration happens automatically when the app
        // starts monitoring with DeviceActivityCenter
        print("📝 DeviceActivityMonitor is configured for SE7EN")
    }
    
    // Helper method to check if monitoring is active
    func isMonitoringActive() -> Bool {
        return !activeSchedules.isEmpty
    }
    
    // Get active monitoring status for debugging
    func getMonitoringStatus() -> [String: Any] {
        return [
            "isAuthorized": isAuthorized,
            "activeSchedules": activeSchedules.map { String(describing: $0) },
            "monitoredApps": Array(monitoredAppSelections.keys)
        ]
    }
}