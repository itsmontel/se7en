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
        
        // ✅ FIX: Use rawValue directly instead of parsing string description
        let eventRawValue = event.rawValue
        
        // Extract token hash from rawValue (format: "update.<tokenHash>" or "limit.<tokenHash>")
        guard let tokenHash = extractTokenHash(from: eventRawValue) else {
            print("⚠️ Monitor Extension: Could not extract token hash from event: \(eventRawValue)")
            return
        }
        
        if eventRawValue.contains("update") {
            incrementUsage(for: tokenHash)
            print("📊 Monitor Extension: Incremented usage for token hash: \(tokenHash)")
        } else if eventRawValue.contains("limit") {
            markLimitReached(for: tokenHash)
            print("🚫 Monitor Extension: Limit reached for token hash: \(tokenHash)")
        }
    }
    
    // MARK: - Minimal Helpers
    
    private func extractTokenHash(from eventRawValue: String) -> String? {
        // Event format: "update.<tokenHash>" or "limit.<tokenHash>" or "warning.<tokenHash>"
        // Split on "." and take everything after the first part
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