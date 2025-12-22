import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

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
            print("🟢 ShieldAction: Primary button (Open SE7EN) pressed")
            
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
            
            // ✅ Set flag for main app to send notification when it becomes active
            defaults.set(true, forKey: "pendingPuzzleNotification")
            defaults.set(appName, forKey: "pendingPuzzleAppName")
            
            // Synchronize BEFORE responding
                defaults.synchronize()
            
            print("📝 ShieldAction: Stored puzzle data for token \(tokenHash.prefix(8))...")
            print("   App Name: \(appName)")
            print("   ℹ️ User should now open SE7EN to solve the puzzle")
            
            // Use .defer to dismiss the shield (user needs to manually open SE7EN)
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
            defaults.set(true, forKey: "pendingPuzzleNotification")
            defaults.set("Website", forKey: "pendingPuzzleAppName")
            defaults.synchronize()
            
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
            defaults.set(true, forKey: "pendingPuzzleNotification")
            defaults.set("Category", forKey: "pendingPuzzleAppName")
            defaults.synchronize()
            
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