//
//  SE7ENDeviceActivityMonitorExtension.swift
//  SE7ENDeviceActivityMonitorExtension
//
//  Handles app blocking when usage limits are reached
//

import DeviceActivity
import Foundation
import FamilyControls
import ManagedSettings

// MARK: - Shared Constants
private enum SharedConstants {
    static let appGroupID = "group.com.se7en.app"
    static let limitsKey = "stored_app_limits_v2"
}

// MARK: - Stored App Limit (for decoding from shared container)
private struct StoredAppLimit: Codable {
    let id: UUID
    let appName: String
    let dailyLimitMinutes: Int
    let usageMinutes: Int
    let isActive: Bool
    let createdAt: Date
    let selectionData: Data
    
    func getSelection() -> FamilyActivitySelection? {
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData)
    }
}

// MARK: - Shared Storage Helper
private class SharedStorage {
    static let shared = SharedStorage()
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: SharedConstants.appGroupID)
    }
    
    func loadLimits() -> [StoredAppLimit] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: SharedConstants.limitsKey),
              let limits = try? JSONDecoder().decode([StoredAppLimit].self, from: data) else {
            return []
        }
        return limits
    }
    
    func markLimitReached(limitID: UUID) {
        sharedDefaults?.set(true, forKey: "limit_reached_\(limitID.uuidString)")
        sharedDefaults?.synchronize()
    }
    
    func clearLimitReached(limitID: UUID) {
        sharedDefaults?.removeObject(forKey: "limit_reached_\(limitID.uuidString)")
        sharedDefaults?.synchronize()
    }
    
    // MARK: - Usage Tracking
    
    /// Increment usage for a limit (called when update events fire)
    func incrementUsage(tokenHash: String, limitID: UUID?, minutes: Int = 1) {
        guard let defaults = sharedDefaults else { return }
        
        // Store by token hash (primary key for matching)
        let usageKey = "usage_\(tokenHash)"
        let currentUsage = defaults.integer(forKey: usageKey)
        let newUsage = currentUsage + minutes
        defaults.set(newUsage, forKey: usageKey)
        
        // Also store by limit UUID if available
        if let limitID = limitID {
            let uuidKey = "usage_v2_\(limitID.uuidString)"
            defaults.set(newUsage, forKey: uuidKey)
            
            // Map token hash to limit UUID for the main app
            var hashToUUID = defaults.dictionary(forKey: "token_hash_to_limit_uuid") as? [String: String] ?? [:]
            hashToUUID[tokenHash] = limitID.uuidString
            defaults.set(hashToUUID, forKey: "token_hash_to_limit_uuid")
        }
        
        // Store last update time
        defaults.set(Date().timeIntervalSince1970, forKey: "usage_last_update_\(tokenHash)")
        defaults.synchronize()
        
        print("📊 Monitor: Updated usage for \(tokenHash.prefix(8))...: \(newUsage) minutes")
    }
    
    /// Get current usage for a token hash
    func getUsage(tokenHash: String) -> Int {
        return sharedDefaults?.integer(forKey: "usage_\(tokenHash)") ?? 0
    }
    
    /// Reset usage for a limit (called at interval start - new day)
    func resetUsage(tokenHash: String, limitID: UUID?) {
        guard let defaults = sharedDefaults else { return }
        
        defaults.set(0, forKey: "usage_\(tokenHash)")
        if let limitID = limitID {
            defaults.set(0, forKey: "usage_v2_\(limitID.uuidString)")
        }
        defaults.synchronize()
        
        print("🔄 Monitor: Reset usage for \(tokenHash.prefix(8))...")
    }
}

// MARK: - Device Activity Monitor Extension
@main
class SE7ENDeviceActivityMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore()
    
    static func main() {}
    
    // MARK: - Interval Lifecycle
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        let rawValue = activity.rawValue
        print("🌅 Monitor: Interval started for \(rawValue)")
        
        // New day started - clear any previous blocks and reset usage for this activity
        if let limitID = extractLimitID(from: activity) {
            SharedStorage.shared.clearLimitReached(limitID: limitID)
            
            // Unblock apps for this limit (new day = fresh start)
            unblockAppsForLimit(limitID: limitID)
            
            // Reset usage counter for this limit
            // Find the token hash for this limit
            let limits = SharedStorage.shared.loadLimits()
            if let limit = limits.first(where: { $0.id == limitID }),
               let selection = limit.getSelection(),
               let firstToken = selection.applicationTokens.first {
                let tokenHash = String(firstToken.hashValue)
                SharedStorage.shared.resetUsage(tokenHash: tokenHash, limitID: limitID)
            }
        }
        
        // Also handle token hash based activity names
        if rawValue.contains("se7en.") && !rawValue.contains("limit.") {
            // Extract token hash from activity name (format: "se7en.<tokenHash>")
            let parts = rawValue.split(separator: ".")
            if parts.count >= 2 {
                let tokenHash = String(parts.dropFirst().joined(separator: "."))
                    .replacingOccurrences(of: "_", with: ".")
                
                // Find matching limit
                let limits = SharedStorage.shared.loadLimits()
                for limit in limits where limit.isActive {
                    guard let selection = limit.getSelection() else { continue }
                    if let firstToken = selection.applicationTokens.first {
                        let computedHash = String(firstToken.hashValue)
                        if computedHash == tokenHash {
                            SharedStorage.shared.resetUsage(tokenHash: tokenHash, limitID: limit.id)
                            SharedStorage.shared.clearLimitReached(limitID: limit.id)
                            unblockAppsForLimit(limitID: limit.id)
                            break
                        }
                    }
                }
            }
        }
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        print("🌙 Monitor: Interval ended for \(activity.rawValue)")
    }
    
    // MARK: - Event Thresholds
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        let eventString = event.rawValue
        print("📊 Monitor: Event threshold reached - \(eventString)")
        
        // Parse event type
        if eventString.hasPrefix("update.") {
            let tokenHash = String(eventString.dropFirst(7))
            handleUpdateEvent(tokenHash: tokenHash)
            return
        }
        
        if eventString.hasPrefix("warning.") {
            let tokenHash = String(eventString.dropFirst(8))
            handleWarningEvent(tokenHash: tokenHash)
            return
        }
        
        if eventString.hasPrefix("limit.") {
            let tokenHash = String(eventString.dropFirst(6))
            
            // ✅ CRITICAL: Check if puzzle was just requested (within last 5 seconds)
            if hasRecentPuzzleRequest(for: tokenHash) {
                print("⏭️ Monitor: Skipping block - puzzle was just requested")
                return
            }
            
            // ✅ CRITICAL: Check if there's an active extension before blocking
            if hasActiveExtension(for: tokenHash) {
                print("⏭️ Monitor: Skipping block - app has active extension")
                return
            }
            
            handleLimitEvent(tokenHash: tokenHash)
            return
        }
    }
    
    /// ✅ Check if puzzle was just requested (within last 5 seconds)
    private func hasRecentPuzzleRequest(for tokenHash: String) -> Bool {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return false }
        
        // Check if puzzle was requested
        if sharedDefaults.bool(forKey: "puzzleRequested_\(tokenHash)") {
            // Check if it was requested recently (within last 5 seconds)
            let requestTime = sharedDefaults.double(forKey: "puzzleRequestTime_\(tokenHash)")
            if requestTime > 0 {
                let timeSinceRequest = Date().timeIntervalSince1970 - requestTime
                if timeSinceRequest < 5.0 {
                    print("✅ Monitor: Puzzle was requested \(String(format: "%.1f", timeSinceRequest))s ago")
                    return true
                }
            }
        }
        
        return false
    }
    
    /// ✅ Check if there's an active extension for this token
    private func hasActiveExtension(for tokenHash: String) -> Bool {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return false }
        
        // Check the extension end time
        let timestamp = sharedDefaults.double(forKey: "extension_end_\(tokenHash)")
        if timestamp > 0 {
            let extensionEndTime = Date(timeIntervalSince1970: timestamp)
            if Date() < extensionEndTime {
                print("✅ Monitor: Active extension found until \(extensionEndTime)")
                return true
            }
        }
        
        // Also check the hasActiveExtension flag
        if sharedDefaults.bool(forKey: "hasActiveExtension_\(tokenHash)") {
            let timestamp = sharedDefaults.double(forKey: "extension_end_\(tokenHash)")
            if timestamp > Date().timeIntervalSince1970 {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Event Handlers
    
    /// Handle update events (fires every minute when app is being used)
    private func handleUpdateEvent(tokenHash: String) {
        guard !tokenHash.isEmpty else { return }
        
        // Find the limit to get the UUID
        let limits = SharedStorage.shared.loadLimits()
        var matchedLimitID: UUID?
        
        // Try to match by UUID first
        if let uuid = UUID(uuidString: tokenHash) {
            matchedLimitID = uuid
        } else {
            // Try to match by token hash
            for limit in limits where limit.isActive {
                guard let selection = limit.getSelection() else { continue }
                if let firstToken = selection.applicationTokens.first {
                    let computedHash = String(firstToken.hashValue)
                    if computedHash == tokenHash {
                        matchedLimitID = limit.id
                        break
                    }
                }
            }
        }
        
        // Increment usage by 1 minute
        SharedStorage.shared.incrementUsage(tokenHash: tokenHash, limitID: matchedLimitID, minutes: 1)
    }
    
    /// Handle warning events (user at 80% of limit)
    private func handleWarningEvent(tokenHash: String) {
        print("⏰ Monitor: User approaching limit for \(tokenHash.prefix(8))...")
        // Could send a local notification here if desired
    }
    
    /// Handle limit events (user reached limit - BLOCK)
    private func handleLimitEvent(tokenHash: String) {
        guard !tokenHash.isEmpty else {
            print("⚠️ Monitor: Empty token hash in limit event")
            return
        }
        
        // ✅ Double-check extension status before blocking
        if hasActiveExtension(for: tokenHash) {
            print("⏭️ Monitor: Not blocking - active extension exists")
            return
        }
        
        // Find the limit and block the app
        blockAppByTokenHash(tokenHash)
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        print("⏰ Monitor: Warning - approaching limit for \(event.rawValue)")
    }
    
    // MARK: - Blocking Logic
    
    /// Block app using token hash (the primary method - matches how limits are stored)
    private func blockAppByTokenHash(_ tokenHash: String) {
        let limits = SharedStorage.shared.loadLimits()
        
        // Find the limit that matches this token hash
        // The main app stores token hash in appBundleID field of AppGoal
        // But limits are stored with UUID - we need to find by matching the selection
        
        // Method 1: Check if tokenHash is a UUID (new system)
        if let uuid = UUID(uuidString: tokenHash) {
            if let limit = limits.first(where: { $0.id == uuid && $0.isActive }),
               let selection = limit.getSelection() {
                blockApps(selection: selection, limitID: limit.id, appName: limit.appName)
                return
            }
        }
        
        // Method 2: Try to match by stored selection's token hash
        for limit in limits where limit.isActive {
            guard let selection = limit.getSelection() else { continue }
            
            // Compute hash from first token and compare
            if let firstToken = selection.applicationTokens.first {
                let computedHash = String(firstToken.hashValue)
                if computedHash == tokenHash {
                    blockApps(selection: selection, limitID: limit.id, appName: limit.appName)
                    return
                }
            }
        }
        
        print("⚠️ Monitor: No matching limit found for token hash: \(tokenHash.prefix(12))...")
    }
    
    /// Block apps in a selection
    private func blockApps(selection: FamilyActivitySelection, limitID: UUID, appName: String) {
        // Block all apps in the selection
        store.shield.applications = Set(selection.applicationTokens)
        
        // Also block categories if any
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        
        // Mark limit as reached in shared storage
        SharedStorage.shared.markLimitReached(limitID: limitID)
        
        print("🚫 Monitor: BLOCKED '\(appName)' (limit \(limitID.uuidString.prefix(8))...)")
    }
    
    /// Unblock apps for a specific limit
    private func unblockAppsForLimit(limitID: UUID) {
        let limits = SharedStorage.shared.loadLimits()
        
        guard let limit = limits.first(where: { $0.id == limitID }),
              let selection = limit.getSelection() else {
            return
        }
        
        // Remove these apps from the shield
        var currentShielded = store.shield.applications ?? []
        for token in selection.applicationTokens {
            currentShielded.remove(token)
        }
        store.shield.applications = currentShielded
        
        print("✅ Monitor: Unblocked apps for limit \(limitID.uuidString.prefix(8))...")
    }
    
    // MARK: - Helpers
    
    /// Extract limit ID from activity name (format: "se7en.limit.<UUID>" or "limit_<UUID>")
    private func extractLimitID(from activity: DeviceActivityName) -> UUID? {
        let rawValue = activity.rawValue
        
        // Try various formats
        if rawValue.hasPrefix("se7en.limit.") {
            let uuidString = String(rawValue.dropFirst(12))
            return UUID(uuidString: uuidString)
        } else if rawValue.hasPrefix("limit_") {
            let uuidString = String(rawValue.dropFirst(6))
            return UUID(uuidString: uuidString)
        } else if rawValue.hasPrefix("limit.") {
            let uuidString = String(rawValue.dropFirst(6))
            return UUID(uuidString: uuidString)
        }
        
        return nil
    }
}
