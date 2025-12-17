//
//  ShieldActionExtension.swift
//  SE7ENShieldActionExtension
//
//  Handles button taps on the shield UI - opens SE7EN in puzzle mode
//

import Foundation
import UIKit
import ManagedSettings
import ManagedSettingsUI
import FamilyControls

class ShieldActionExtension: ShieldActionDelegate {
    
    private let appGroupID = "group.com.se7en.app"
    
    override func handle(action: ShieldAction, for applicationToken: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // User wants to solve the puzzle
            // Get app name from token hash (we'll need to look it up from shared storage)
            let tokenHash = String(applicationToken.hashValue)
            
            // Try to get app name from shared storage
            let appName: String
            if let defaults = UserDefaults(suiteName: appGroupID),
               let storedName = defaults.string(forKey: "puzzleAppName_\(tokenHash)") {
                appName = storedName
            } else {
                // Fallback: try to get from stored limits
                appName = getAppNameFromTokenHash(tokenHash) ?? "App"
            }
            
            print("🎯 ShieldAction: Primary button pressed for \(appName)")
            
            // Store puzzle request in shared container
            if let defaults = UserDefaults(suiteName: appGroupID) {
                defaults.set(true, forKey: "needsPuzzle_\(tokenHash)")
                defaults.set(appName, forKey: "puzzleAppName_\(tokenHash)")
                defaults.set(tokenHash, forKey: "puzzleTokenHash")
                defaults.set(true, forKey: "puzzleMode") // Flag for fullscreen puzzle mode
                defaults.synchronize()
                print("💾 ShieldAction: Stored puzzle request for \(tokenHash.prefix(8))...")
            }
            
            // Return .defer to allow the main app to open
            // The main app will check for puzzleMode flag on launch and show puzzle
            completionHandler(.defer)
            
        case .secondaryButtonPressed:
            // User chose to close - keep the shield active
            print("🎯 ShieldAction: Secondary button pressed - closing app")
            completionHandler(.close)
            
        @unknown default:
            completionHandler(.close)
        }
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            print("🎯 ShieldAction: Primary button pressed for web domain")
            completionHandler(.defer)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            print("🎯 ShieldAction: Primary button pressed for category")
            completionHandler(.defer)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }
    
    // Helper to get app name from token hash
    private func getAppNameFromTokenHash(_ tokenHash: String) -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let limitsData = defaults.data(forKey: "stored_app_limits_v2") else {
            return nil
        }
        
        // Decode limits to find matching app
        struct StoredLimit: Codable {
            let id: UUID
            let appName: String
            let selectionData: Data
        }
        
        guard let limits = try? JSONDecoder().decode([StoredLimit].self, from: limitsData) else {
            return nil
        }
        
        // Find limit by matching token hash
        for limit in limits {
            if let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: limit.selectionData),
               let firstToken = selection.applicationTokens.first,
               String(firstToken.hashValue) == tokenHash {
                return limit.appName
            }
        }
        
        return nil
    }
}
