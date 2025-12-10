import DeviceActivity
import Foundation

// 🔥 ULTRA-MINIMAL Extension (under 1MB RAM)
// The extension is unreliable in iOS 17+ so we keep it simple
// Real tracking happens via timer-based fallback in main app

@main
class SE7ENDeviceActivityMonitor: DeviceActivityMonitor {
    
    static func main() {}
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        // Just mark that interval started
        saveFlag(key: "interval_started", value: true)
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        saveFlag(key: "interval_started", value: false)
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Use rawValue to reliably parse the event name (format: update.<tokenHash> / limit.<tokenHash>)
        let eventRawValue = event.rawValue
        
        // Extract token hash from rawValue
        guard let tokenHash = extractTokenHash(from: eventRawValue) else { return }
        
        if eventRawValue.contains("update") {
            incrementUsage(for: tokenHash)
        } else if eventRawValue.contains("limit") {
            markLimitReached(for: tokenHash)
        }
    }
    
    // MARK: - Minimal Helpers
    
    private func extractTokenHash(from eventRawValue: String) -> String? {
        // Expect formats like "update.<tokenHash>" or "limit.<tokenHash>"
        let parts = eventRawValue.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return String(parts[1])
    }
    
    private func incrementUsage(for tokenHash: String) {
        guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return }
        
        let key = "usage_\(tokenHash)"
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
        defaults.set(Date().timeIntervalSince1970, forKey: "last_update")
        defaults.synchronize()
    }
    
    private func markLimitReached(for tokenHash: String) {
        guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return }
        defaults.set(true, forKey: "limit_reached_\(tokenHash)")
        defaults.synchronize()
    }
    
    private func saveFlag(key: String, value: Bool) {
        guard let defaults = UserDefaults(suiteName: "group.com.se7en.app") else { return }
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }
}