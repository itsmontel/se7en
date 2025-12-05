import DeviceActivity
import Foundation
import ManagedSettings

// MARK: - DeviceActivityMonitor Extension
// Handles events from DeviceActivity framework when usage thresholds are reached

class SE7ENDeviceActivityMonitor: DeviceActivityMonitor {
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        print("🟢 Device activity interval started: \(activity)")
        
        // Reset daily tracking when interval starts (midnight)
        ScreenTimeService.shared.unblockAllApps()
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        print("🔴 Device activity interval ended: \(activity)")
        CoreDataManager.shared.save()
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        let eventString = String(describing: event)
        print("⚠️ Event threshold reached: \(eventString)")
        
        // Extract bundle ID from event name
        // Format: "warning.bundleID" or "limit.bundleID"
        if let bundleID = extractBundleID(from: eventString) {
            if eventString.contains("warning") {
                handleWarning(for: bundleID)
            } else if eventString.contains("limit") {
                handleLimit(for: bundleID)
            }
        }
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        print("🟡 Interval will start warning: \(activity)")
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        print("🟡 Interval will end warning: \(activity)")
    }
    
    // MARK: - Helpers
    
    private func extractBundleID(from eventString: String) -> String? {
        // Event format: "warning.com.example.app" or "limit.com.example.app"
        let parts = eventString.split(separator: ".")
        if parts.count >= 2 {
            // Skip the first part (warning/limit) and join the rest
            let bundleComponents = parts.dropFirst()
            let bundleID = bundleComponents.joined(separator: ".")
            return bundleID.isEmpty ? nil : bundleID
        }
        return nil
    }
    
    private func handleWarning(for bundleID: String) {
        print("🟡 Warning for: \(bundleID)")
        ScreenTimeService.shared.handleWarning(for: bundleID)
    }
    
    private func handleLimit(for bundleID: String) {
        print("🔴 Limit reached for: \(bundleID)")
        ScreenTimeService.shared.handleLimitReached(for: bundleID)
    }
}
