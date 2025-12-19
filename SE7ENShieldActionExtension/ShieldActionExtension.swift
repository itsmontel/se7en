import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {
    
    let appGroupID = "group.com.se7en.app"
    
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        print("🛡️ ShieldAction: Handling response for application")
        
        let tokenHash = String(application.hashValue)
        
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ ShieldAction: Failed to access shared defaults")
            completionHandler(.close)
            return
        }
        
        switch action {
        case .primaryButtonPressed:
            print("🟢 ShieldAction: Primary button (Start Puzzle) pressed")
            
            // ✅ CRITICAL: Set ALL puzzle mode flags
            defaults.set(true, forKey: "puzzleMode")
            defaults.set(tokenHash, forKey: "puzzleTokenHash")
            defaults.set(true, forKey: "needsPuzzle_\(tokenHash)")
            
            // Get app name from stored limit data
            let appName = getAppName(for: tokenHash, defaults: defaults)
            defaults.set(appName, forKey: "puzzleAppName_\(tokenHash)")
            
            // Set puzzle request timestamp (to prevent immediate re-blocking)
            defaults.set(true, forKey: "puzzleRequested_\(tokenHash)")
            defaults.set(Date().timeIntervalSince1970, forKey: "puzzleRequestTime_\(tokenHash)")
            
            // ✅ CRITICAL: Set flag to open SE7EN app
            defaults.set(true, forKey: "shouldOpenPuzzle")
            
            // Synchronize BEFORE responding
            defaults.synchronize()
            
            print("📝 ShieldAction: Stored puzzle data for token \(tokenHash.prefix(8))...")
            print("   App Name: \(appName)")
            
            // ✅ Send notification to open SE7EN app
            sendPuzzleNotification(appName: appName)
            
            // Use .defer to dismiss the shield
            completionHandler(.defer)
            
        case .secondaryButtonPressed:
            print("🔴 ShieldAction: Secondary button (Cancel) pressed")
            // User chose to stay blocked - just close the shield
            completionHandler(.close)
            
        @unknown default:
            print("⚠️ ShieldAction: Unknown response type")
            completionHandler(.close)
        }
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        print("🛡️ ShieldAction: Handling response for webDomain")
        
        let tokenHash = String(webDomain.hashValue)
        
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            completionHandler(.close)
            return
        }
        
        switch action {
        case .primaryButtonPressed:
            print("🟢 ShieldAction: Primary button pressed for web domain")
            
            defaults.set(true, forKey: "puzzleMode")
            defaults.set(tokenHash, forKey: "puzzleTokenHash")
            defaults.set(true, forKey: "needsPuzzle_\(tokenHash)")
            defaults.set("Website", forKey: "puzzleAppName_\(tokenHash)")
            defaults.set(true, forKey: "puzzleRequested_\(tokenHash)")
            defaults.set(Date().timeIntervalSince1970, forKey: "puzzleRequestTime_\(tokenHash)")
            defaults.set(true, forKey: "shouldOpenPuzzle")
            defaults.synchronize()
            
            // Send notification to open SE7EN app
            sendPuzzleNotification(appName: "Website")
            
            completionHandler(.defer)
            
        case .secondaryButtonPressed:
            completionHandler(.close)
            
        @unknown default:
            completionHandler(.close)
        }
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        print("🛡️ ShieldAction: Handling response for category")
        
        let tokenHash = String(category.hashValue)
        
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            completionHandler(.close)
            return
        }
        
        switch action {
        case .primaryButtonPressed:
            print("🟢 ShieldAction: Primary button pressed for category")
            
            defaults.set(true, forKey: "puzzleMode")
            defaults.set(tokenHash, forKey: "puzzleTokenHash")
            defaults.set(true, forKey: "needsPuzzle_\(tokenHash)")
            defaults.set("Category", forKey: "puzzleAppName_\(tokenHash)")
            defaults.set(true, forKey: "puzzleRequested_\(tokenHash)")
            defaults.set(Date().timeIntervalSince1970, forKey: "puzzleRequestTime_\(tokenHash)")
            defaults.set(true, forKey: "shouldOpenPuzzle")
            defaults.synchronize()
            
            // Send notification to open SE7EN app
            sendPuzzleNotification(appName: "Category")
            
            completionHandler(.defer)
            
        case .secondaryButtonPressed:
            completionHandler(.close)
            
        @unknown default:
            completionHandler(.close)
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
                // Return the first app name we find
                return appName
            }
        }
        
        // Try stored limits
        if let data = defaults.data(forKey: "stored_app_limits_v2"),
           let limits = try? JSONDecoder().decode([StoredLimit].self, from: data) {
            for limit in limits {
                // Try to match by comparing first token hash
                if let selectionData = limit.selectionData,
                   let _ = try? PropertyListDecoder().decode(FamilyActivitySelectionProxy.self, from: selectionData) {
                    // We can't directly compare tokens here, so just return the first active limit's name
                    if limit.isActive {
                        return limit.appName
                    }
                }
            }
        }
        
        return "App"
    }
    
    // MARK: - Notification Methods
    
    /// Send a notification that opens SE7EN app when tapped
    private func sendPuzzleNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🧩 Puzzle Time!"
        content.body = "Tap here to open SE7EN and solve a puzzle to unlock \(appName)"
        content.sound = .default
        content.categoryIdentifier = "PUZZLE_UNLOCK"
        content.userInfo = ["action": "open_puzzle", "appName": appName]
        
        // Trigger immediately (0.1 second delay minimum required)
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
                print("✅ ShieldAction: Notification sent - tap to open SE7EN")
            }
        }
    }
}

// MARK: - Helper Structs for Decoding

private struct StoredLimit: Codable {
    let id: UUID
    let appName: String
    let dailyLimitMinutes: Int
    let usageMinutes: Int
    let isActive: Bool
    let createdAt: Date
    let selectionData: Data?
}

private struct FamilyActivitySelectionProxy: Codable {
    // This is just for checking if data can be decoded
    // We don't need the actual tokens here
}