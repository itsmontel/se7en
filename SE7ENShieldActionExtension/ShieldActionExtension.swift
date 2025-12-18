import Foundation
import ManagedSettings
import ManagedSettingsUI

class ShieldActionExtension: ShieldActionDelegate {
    
    let appGroupID = "group.com.se7en.app"
    
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        print("🛡️ ShieldAction: Handling response for application")
        
        // Store puzzle info in shared container
        let tokenHash = String(application.hashValue)
        
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ ShieldAction: Failed to access shared defaults")
            completionHandler(.close)
            return
        }
        
        switch action {
        case .primaryButtonPressed:
            print("🟢 ShieldAction: Primary button (Start Puzzle) pressed")
            
            // ✅ CRITICAL: Set puzzle mode flags BEFORE opening app
            defaults.set(true, forKey: "puzzleMode")
            defaults.set(tokenHash, forKey: "puzzleTokenHash")
            defaults.set(true, forKey: "needsPuzzle_\(tokenHash)")
            
            // Try to get app name from stored data
            if let appName = defaults.string(forKey: "limitAppName_\(tokenHash)") {
                defaults.set(appName, forKey: "puzzleAppName_\(tokenHash)")
            } else {
                // Fallback: try to find from per_app_usage keys
                if let perAppUsage = defaults.dictionary(forKey: "per_app_usage") as? [String: Int] {
                    for (appName, _) in perAppUsage {
                        // Store the first matching app name
                        defaults.set(appName, forKey: "puzzleAppName_\(tokenHash)")
                        break
                    }
                } else {
                    defaults.set("App", forKey: "puzzleAppName_\(tokenHash)")
                }
            }
            
            // ✅ CRITICAL: Set a flag to prevent shield from reappearing
            defaults.set(true, forKey: "puzzleRequested_\(tokenHash)")
            defaults.set(Date().timeIntervalSince1970, forKey: "puzzleRequestTime_\(tokenHash)")
            
            // ✅ CRITICAL: Synchronize BEFORE opening app
            defaults.synchronize()
            
            print("📝 ShieldAction: Stored puzzle data - tokenHash: \(tokenHash)")
            
            // ✅ CRITICAL: Use .defer to open the SE7EN app
            // .defer tells iOS to open the main app, which will check for puzzleMode flag
            // The puzzle flags are already set above, so the app will show the puzzle
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
            
            // Set puzzle mode flags
            defaults.set(true, forKey: "puzzleMode")
            defaults.set(tokenHash, forKey: "puzzleTokenHash")
            defaults.set(true, forKey: "needsPuzzle_\(tokenHash)")
            defaults.set("Website", forKey: "puzzleAppName_\(tokenHash)")
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
            defaults.synchronize()
            
            completionHandler(.defer)
            
        case .secondaryButtonPressed:
            completionHandler(.close)
            
        @unknown default:
            completionHandler(.close)
        }
    }
    
}
