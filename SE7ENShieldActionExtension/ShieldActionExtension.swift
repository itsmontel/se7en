import Foundation
import ManagedSettings
import ManagedSettingsUI
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {
    
    private let appGroupID = "group.com.se7en.app"
    
    // MARK: - Application Shield Action
    
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let tokenHash = String(application.hashValue)
        
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            completionHandler(.close)
            return
        }
        
        switch action {
        case .primaryButtonPressed:
            // Get app name
            let appName = getAppName(for: tokenHash, defaults: defaults)
            
            // Check if we're already showing the "tap notification" shield
            if defaults.bool(forKey: "showTapNotificationShield") {
                // User tapped while on tap notification screen - this shouldn't happen
                // but if it does, just close the shield
                defaults.set(false, forKey: "showTapNotificationShield")
                defaults.synchronize()
                completionHandler(.close)
                return
            }
            
            // ✅ Step 1: Set flag to show "Tap Notification" shield UI
            defaults.set(true, forKey: "showTapNotificationShield")
            defaults.set(appName, forKey: "tapNotificationAppName")
            
            // ✅ Step 2: Store puzzle data for when user opens SE7EN
            defaults.set(true, forKey: "puzzleMode")
            defaults.set(tokenHash, forKey: "puzzleTokenHash")
            defaults.set(true, forKey: "needsPuzzle_\(tokenHash)")
            defaults.set(appName, forKey: "puzzleAppName_\(tokenHash)")
            defaults.set(true, forKey: "puzzleRequested_\(tokenHash)")
            defaults.set(Date().timeIntervalSince1970, forKey: "puzzleRequestTime_\(tokenHash)")
            defaults.set(true, forKey: "shouldOpenPuzzle")
            
            defaults.synchronize()
            
            // ✅ Step 3: Send notification immediately
            sendPuzzleNotification(appName: appName)
            
            // ✅ Step 4: Return .defer to refresh shield (will now show tap notification UI)
            completionHandler(.defer)
            
        case .secondaryButtonPressed:
            // "Stay Focused" or dismiss tap notification screen
            // Clear the tap notification flag if set
            defaults.set(false, forKey: "showTapNotificationShield")
            defaults.synchronize()
            completionHandler(.close)
            
        @unknown default:
            completionHandler(.close)
        }
    }
    
    // MARK: - Web Domain Shield Action
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let tokenHash = String(webDomain.hashValue)
        
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            completionHandler(.close)
            return
        }
        
        switch action {
        case .primaryButtonPressed:
            if defaults.bool(forKey: "showTapNotificationShield") {
                defaults.set(false, forKey: "showTapNotificationShield")
                defaults.synchronize()
                completionHandler(.close)
                return
            }
            
            let appName = "Website"
            
            defaults.set(true, forKey: "showTapNotificationShield")
            defaults.set(appName, forKey: "tapNotificationAppName")
            defaults.set(true, forKey: "puzzleMode")
            defaults.set(tokenHash, forKey: "puzzleTokenHash")
            defaults.set(true, forKey: "needsPuzzle_\(tokenHash)")
            defaults.set(appName, forKey: "puzzleAppName_\(tokenHash)")
            defaults.set(true, forKey: "puzzleRequested_\(tokenHash)")
            defaults.set(Date().timeIntervalSince1970, forKey: "puzzleRequestTime_\(tokenHash)")
            defaults.set(true, forKey: "shouldOpenPuzzle")
            defaults.synchronize()
            
            sendPuzzleNotification(appName: appName)
            completionHandler(.defer)
            
        case .secondaryButtonPressed:
            defaults.set(false, forKey: "showTapNotificationShield")
            defaults.synchronize()
            completionHandler(.close)
            
        @unknown default:
            completionHandler(.close)
        }
    }
    
    // MARK: - Category Shield Action
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let tokenHash = String(category.hashValue)
        
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            completionHandler(.close)
            return
        }
        
        switch action {
        case .primaryButtonPressed:
            if defaults.bool(forKey: "showTapNotificationShield") {
                defaults.set(false, forKey: "showTapNotificationShield")
                defaults.synchronize()
                completionHandler(.close)
                return
            }
            
            let appName = "Category"
            
            defaults.set(true, forKey: "showTapNotificationShield")
            defaults.set(appName, forKey: "tapNotificationAppName")
            defaults.set(true, forKey: "puzzleMode")
            defaults.set(tokenHash, forKey: "puzzleTokenHash")
            defaults.set(true, forKey: "needsPuzzle_\(tokenHash)")
            defaults.set(appName, forKey: "puzzleAppName_\(tokenHash)")
            defaults.set(true, forKey: "puzzleRequested_\(tokenHash)")
            defaults.set(Date().timeIntervalSince1970, forKey: "puzzleRequestTime_\(tokenHash)")
            defaults.set(true, forKey: "shouldOpenPuzzle")
            defaults.synchronize()
            
            sendPuzzleNotification(appName: appName)
            completionHandler(.defer)
            
        case .secondaryButtonPressed:
            defaults.set(false, forKey: "showTapNotificationShield")
            defaults.synchronize()
            completionHandler(.close)
            
        @unknown default:
            completionHandler(.close)
        }
    }
    
    // MARK: - Send Notification
    
    private func sendPuzzleNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🧩 Solve a Puzzle"
        content.body = "Tap here to unlock \(appName)"
        content.sound = .default
        content.categoryIdentifier = "PUZZLE_UNLOCK"
        
        // Add userInfo for deep linking
        content.userInfo = [
            "type": "puzzle_unlock",
            "appName": appName
        ]
        
        // Send immediately (0.1 second trigger)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "puzzle_unlock_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ ShieldAction: Failed to send notification: \(error)")
            } else {
                print("✅ ShieldAction: Notification sent for \(appName)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAppName(for tokenHash: String, defaults: UserDefaults) -> String {
        // Try stored limit name first
        if let appName = defaults.string(forKey: "limitAppName_\(tokenHash)"), !appName.isEmpty {
            return appName
        }
        
        // Try per_app_usage keys
        if let perAppUsage = defaults.dictionary(forKey: "per_app_usage") as? [String: Int] {
            for (appName, _) in perAppUsage {
                return appName
            }
        }
        
        // Try stored limits
        if let data = defaults.data(forKey: "stored_app_limits_v2"),
           let limits = try? JSONDecoder().decode([StoredLimit].self, from: data) {
            for limit in limits where limit.isActive {
                return limit.appName
            }
        }
        
        return "App"
    }
}

// MARK: - Helper Structs

private struct StoredLimit: Codable {
    let id: UUID
    let appName: String
    let dailyLimitMinutes: Int
    let usageMinutes: Int
    let isActive: Bool
    let createdAt: Date
    let selectionData: Data?
}

