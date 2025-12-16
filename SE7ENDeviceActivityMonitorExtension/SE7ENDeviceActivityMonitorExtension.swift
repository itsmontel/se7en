import DeviceActivity
import Foundation
import FamilyControls
import ManagedSettings

@main
class SE7ENDeviceActivityMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore()
    let storage = AppLimitStorage.shared
    
    static func main() {}
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        // Extract limit ID from activity name (format: "limit_<UUID>")
        if activity.rawValue.hasPrefix("limit_") {
            let limitIdString = String(activity.rawValue.dropFirst(6)) // Remove "limit_" prefix
            if let limitId = UUID(uuidString: limitIdString) {
                // Check if it's a new day and reset usage
                let records = storage.loadUsageRecords()
                if let record = records[limitId] {
                    let today = Calendar.current.startOfDay(for: Date())
                    let recordDay = Calendar.current.startOfDay(for: record.lastResetDate)
                    if today > recordDay {
                        storage.updateUsage(limitId: limitId, seconds: 0)
                    }
                }
            }
        }
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Extract limit ID from activity name
        let limitIdString = activity.rawValue.replacingOccurrences(of: "limit_", with: "")
        guard let limitId = UUID(uuidString: limitIdString) else { return }
        
        // Find the matching limit
        let limits = storage.loadAppLimits()
        guard let limit = limits.first(where: { $0.id == limitId }),
              let token = limit.getToken() else { return }
        
        // Block the app
        store.shield.applications = [token]
        
        // Mark limit reached in shared storage
        if let defaults = UserDefaults(suiteName: AppGroupConstants.groupIdentifier) {
            defaults.set(true, forKey: "limit_reached_\(limitId.uuidString)")
            defaults.synchronize()
        }
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        // Optional: Show a 5-minute warning before blocking
    }
}