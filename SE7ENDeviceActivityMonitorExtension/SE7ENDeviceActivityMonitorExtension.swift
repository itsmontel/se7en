import DeviceActivity
import Foundation
import ManagedSettings

// MARK: - DeviceActivityMonitor Extension
// Handles events from DeviceActivity framework when usage thresholds are reached
// This extension runs automatically in the background when thresholds are reached

@main
class SE7ENDeviceActivityMonitor: DeviceActivityMonitor {
    
    // Required static main() function for @main annotation
    static func main() {
        // The system will automatically instantiate this class when events occur
        // This function is required but doesn't need to do anything
    }
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        print("🟢 Device activity interval started: \(activity)")
        
        // Reset daily tracking when interval starts (midnight)
        // Note: We can't directly access ScreenTimeService from extension
        // Instead, we'll save to shared container and main app will read it
        saveToSharedContainer(key: "interval_started", value: Date().timeIntervalSince1970)
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        print("🔴 Device activity interval ended: \(activity)")
        
        // Save to shared container
        saveToSharedContainer(key: "interval_ended", value: Date().timeIntervalSince1970)
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        let eventString = String(describing: event)
        print("⚠️ Event threshold reached: \(eventString) for activity: \(activity)")
        
        // Extract bundle ID from event name
        // Format: "warning.bundleID", "limit.bundleID", or "update.bundleID"
        if let bundleID = extractBundleID(from: eventString) {
            if eventString.contains("update") {
                // Handle update events first (most frequent)
                // These fire every 10 minutes to update usage
                handleUpdate(for: bundleID, activity: activity)
            } else if eventString.contains("warning") {
                handleWarning(for: bundleID, activity: activity)
            } else if eventString.contains("limit") {
                handleLimit(for: bundleID, activity: activity)
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
        // Event format: "warning.com.example.app" or "limit.com.example.app" or "update.com.example.app"
        let parts = eventString.split(separator: ".")
        if parts.count >= 2 {
            // Skip the first part (warning/limit/update) and join the rest
            let bundleComponents = parts.dropFirst()
            let bundleID = bundleComponents.joined(separator: ".")
            return bundleID.isEmpty ? nil : bundleID
        }
        return nil
    }
    
    private func handleWarning(for bundleID: String, activity: DeviceActivityName) {
        print("🟡 Warning for: \(bundleID)")
        // Save event to shared container for main app to process
        saveEventToSharedContainer(type: "warning", bundleID: bundleID, activity: activity)
    }
    
    private func handleLimit(for bundleID: String, activity: DeviceActivityName) {
        print("🔴 Limit reached for: \(bundleID)")
        // Save event to shared container for main app to process
        saveEventToSharedContainer(type: "limit", bundleID: bundleID, activity: activity)
    }
    
    private func handleUpdate(for bundleID: String, activity: DeviceActivityName) {
        print("🔄 Update event for: \(bundleID)")
        // The threshold is 10 minutes, so we update usage by that amount
        // Save to shared container for main app to process
        saveEventToSharedContainer(type: "update", bundleID: bundleID, activity: activity)
        
        // Also update usage directly in shared container
        let updateInterval = 10 // minutes
        updateUsageInSharedContainer(bundleID: bundleID, minutes: updateInterval)
    }
    
    // MARK: - Shared Container Helpers
    
    private func saveToSharedContainer(key: String, value: Double) {
        let appGroupID = "group.com.se7en.app"
        
        // Access UserDefaults on main thread to avoid CFPrefsPlistSource errors
        DispatchQueue.main.async {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
                print("❌ Failed to access shared container")
                return
            }
            
            // Save directly - avoid nested dictionaries
            sharedDefaults.set(value, forKey: key)
            print("💾 Saved to shared container: \(key) = \(value)")
        }
    }
    
    private func saveEventToSharedContainer(type: String, bundleID: String, activity: DeviceActivityName) {
        let appGroupID = "group.com.se7en.app"
        
        // Access UserDefaults on main thread to avoid CFPrefsPlistSource errors
        DispatchQueue.main.async {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
                print("❌ Failed to access shared container")
                return
            }
            
            var events = sharedDefaults.array(forKey: "pendingEvents") as? [[String: String]] ?? []
            events.append([
                "type": type,
                "bundleID": bundleID,
                "activity": String(describing: activity),
                "timestamp": String(Date().timeIntervalSince1970)
            ])
            
            // Keep only last 100 events
            if events.count > 100 {
                events = Array(events.suffix(100))
            }
            
            sharedDefaults.set(events, forKey: "pendingEvents")
            print("💾 Saved event to shared container: \(type) for \(bundleID)")
        }
    }
    
    private func updateUsageInSharedContainer(bundleID: String, minutes: Int) {
        let appGroupID = "group.com.se7en.app"
        
        // Access UserDefaults on main thread to avoid CFPrefsPlistSource errors
        DispatchQueue.main.async {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
                print("❌ Failed to access shared container")
                return
            }
            
            // Use simple key-based storage for each app
            let key = "usage_\(bundleID)"
            let currentUsage = sharedDefaults.integer(forKey: key)
            let newUsage = currentUsage + minutes
            sharedDefaults.set(newUsage, forKey: key)
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
            
            print("📊 Updated usage in shared container: \(bundleID) = \(newUsage) minutes")
        }
    }
}
