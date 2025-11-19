import DeviceActivity
import Foundation

// This class handles device activity monitoring callbacks
class SE7ENDeviceActivityMonitor: DeviceActivityMonitor {
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Called when monitoring interval starts (e.g., at midnight)
        print("Monitoring started for activity: \(activity)")
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Called when monitoring interval ends (e.g., at 11:59 PM)
        print("Monitoring ended for activity: \(activity)")
    }
    
    func handleEventThreshold(event: String, activity: DeviceActivityName) {
        // Handle different event types
        switch event {
        case "limitWarning":
            handleLimitWarning(activity: activity)
        case "limitExceeded":
            handleLimitExceeded(activity: activity)
        default:
            break
        }
    }
    
    private func handleLimitWarning(activity: DeviceActivityName) {
        // Extract bundle ID from activity name
        let activityString = activity.rawValue
        if activityString.hasPrefix("se7en_") {
            let bundleID = String(activityString.dropFirst(6)) // Remove "se7en_" prefix
            
            // Send warning notification
            NotificationService.shared.sendLimitWarningNotification(
                appName: getAppNameFromBundleID(bundleID),
                timeRemaining: 5 // 5 minutes warning
            )
            
            print("Limit warning for app: \(bundleID)")
        }
    }
    
    private func handleLimitExceeded(activity: DeviceActivityName) {
        // Extract bundle ID from activity name
        let activityString = activity.rawValue
        if activityString.hasPrefix("se7en_") {
            let bundleID = String(activityString.dropFirst(6)) // Remove "se7en_" prefix
            
            // Handle credit loss through ScreenTimeService
            Task { @MainActor in
                ScreenTimeService.shared.handleLimitExceeded(for: bundleID)
            }
            
            print("Limit exceeded for app: \(bundleID)")
        }
    }
    
    private func getAppNameFromBundleID(_ bundleID: String) -> String {
        // Map common bundle IDs to app names
        let appNames: [String: String] = [
            "com.instagram.biz": "Instagram",
            "com.facebook.Facebook": "Facebook",
            "com.atebits.Tweetie2": "X (Twitter)",
            "com.zhiliaoapp.musically": "TikTok",
            "com.toyopagroup.picaboo": "Snapchat",
            "com.google.ios.youtube": "YouTube",
            "com.reddit.Reddit": "Reddit",
            "com.burbn.instagram": "Instagram",
            "com.twitter.twitter": "Twitter"
        ]
        
        return appNames[bundleID] ?? bundleID
    }
}
