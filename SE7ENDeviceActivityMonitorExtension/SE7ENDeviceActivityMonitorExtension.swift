//
//  SE7ENDeviceActivityMonitorExtension.swift
//  SE7ENDeviceActivityMonitorExtension
//
//  FIXED VERSION: Handles one-session blocking, reliable shield detection, and proper unlock flow
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
    
    func incrementUsage(tokenHash: String, limitID: UUID?, minutes: Int = 1) {
        guard let defaults = sharedDefaults else { return }
        
        let usageKey = "usage_\(tokenHash)"
        let currentUsage = defaults.integer(forKey: usageKey)
        let newUsage = currentUsage + minutes
        defaults.set(newUsage, forKey: usageKey)
        
        if let limitID = limitID {
            let uuidKey = "usage_v2_\(limitID.uuidString)"
            defaults.set(newUsage, forKey: uuidKey)
            
            var hashToUUID = defaults.dictionary(forKey: "token_hash_to_limit_uuid") as? [String: String] ?? [:]
            hashToUUID[tokenHash] = limitID.uuidString
            defaults.set(hashToUUID, forKey: "token_hash_to_limit_uuid")
        }
        
        defaults.set(Date().timeIntervalSince1970, forKey: "usage_last_update_\(tokenHash)")
        defaults.synchronize()
        
        print("📊 Monitor: Updated usage for \(tokenHash.prefix(8))...: \(newUsage) minutes")
    }
    
    func getUsage(tokenHash: String) -> Int {
        return sharedDefaults?.integer(forKey: "usage_\(tokenHash)") ?? 0
    }
    
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
        
        let appGroupID = "group.com.se7en.app"
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        let today = Calendar.current.startOfDay(for: Date())
        
        // ✅ CRITICAL: Clear all extensions and one-session flags from previous days
        if let defaults = sharedDefaults {
            let allKeys = Array(defaults.dictionaryRepresentation().keys)
            for key in allKeys {
                // Clear old extensions
                if key.hasPrefix("extension_end_") {
                    let tokenHash = String(key.dropFirst("extension_end_".count))
                    let timestamp = defaults.double(forKey: key)
                    if timestamp > 0 {
                        let extensionDate = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: timestamp))
                        if extensionDate < today {
                            defaults.removeObject(forKey: key)
                            defaults.removeObject(forKey: "hasActiveExtension_\(tokenHash)")
                            defaults.removeObject(forKey: "extensionLimit_\(tokenHash)")
                            print("🧹 Monitor: Cleared extension from previous day for \(tokenHash.prefix(8))...")
                        }
                    }
                }
                
                // ✅ NEW: Clear one-session flags at start of new day
                if key.hasPrefix("oneSessionActive_") {
                    defaults.set(false, forKey: key)
                    let tokenHash = String(key.dropFirst("oneSessionActive_".count))
                    defaults.removeObject(forKey: "oneSessionStartTime_\(tokenHash)")
                }
            }
            defaults.synchronize()
        }
        
        // Reset usage for this activity
        if let limitID = extractLimitID(from: activity) {
            SharedStorage.shared.clearLimitReached(limitID: limitID)
            unblockAppsForLimit(limitID: limitID)
            
            let limits = SharedStorage.shared.loadLimits()
            if let limit = limits.first(where: { $0.id == limitID }),
               let selection = limit.getSelection(),
               let firstToken = selection.applicationTokens.first {
                let tokenHash = String(firstToken.hashValue)
                SharedStorage.shared.resetUsage(tokenHash: tokenHash, limitID: limitID)
            }
        }
        
        // Handle token hash based activity names
        if rawValue.contains("se7en.") && !rawValue.contains("limit.") {
            let parts = rawValue.split(separator: ".")
            if parts.count >= 2 {
                let tokenHash = String(parts.dropFirst().joined(separator: "."))
                    .replacingOccurrences(of: "_", with: ".")
                
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
        
        // ✅ NEW: Check and re-block any one-session apps when interval ends
        checkAndReBlockOneSessionApps()
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
            
            // ✅ NEW: Check one-session status on every update
            // This detects when user leaves and returns to an app
            checkOneSessionStatusForToken(tokenHash)
            return
        }
        
        if eventString.hasPrefix("warning.") {
            let tokenHash = String(eventString.dropFirst(8))
            handleWarningEvent(tokenHash: tokenHash)
            return
        }
        
        if eventString.hasPrefix("limit.") {
            let tokenHash = String(eventString.dropFirst(6))
            
            // Check if puzzle was just requested
            if hasRecentPuzzleRequest(for: tokenHash) {
                print("⏭️ Monitor: Skipping block - puzzle was just requested")
                return
            }
            
            // Check if there's an active extension
            if hasActiveExtension(for: tokenHash) {
                print("⏭️ Monitor: Skipping block - app has active extension")
                return
            }
            
            // ✅ CRITICAL: Block immediately
            handleLimitEvent(tokenHash: tokenHash)
            return
        }
        
        // ✅ NEW: Handle global reporting events for real-time usage
        if eventString.hasPrefix("global.") {
            print("📊 Monitor: Global reporting event fired")
            checkAllLimitsAndBlock()
            return
        }
    }
    
    // MARK: - One-Session Mode Handling
    
    /// ✅ NEW: Check one-session status when app usage is detected
    private func checkOneSessionStatusForToken(_ tokenHash: String) {
        let appGroupID = "group.com.se7en.app"
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // Check if this app was in one-session mode
        let oneSessionKey = "oneSessionActive_\(tokenHash)"
        let wasInOneSession = defaults.bool(forKey: oneSessionKey)
        
        if wasInOneSession {
            // Check if user left the app (usage gap > 30 seconds indicates they left)
            let lastUpdateKey = "usage_last_update_\(tokenHash)"
            let lastUpdate = defaults.double(forKey: lastUpdateKey)
            let now = Date().timeIntervalSince1970
            let timeSinceLastUpdate = now - lastUpdate
            
            // If it's been more than 2 minutes since last update, they left and came back
            // Re-block them!
            if timeSinceLastUpdate > 120 && lastUpdate > 0 {
                print("🔒 Monitor: One-Session expired - user left app (gap: \(Int(timeSinceLastUpdate))s)")
                
                // Clear the one-session flag
                defaults.set(false, forKey: oneSessionKey)
                defaults.removeObject(forKey: "oneSessionStartTime_\(tokenHash)")
                defaults.synchronize()
                
                // Re-block the app
                blockAppByTokenHash(tokenHash)
            }
        }
    }
    
    /// ✅ NEW: Check and re-block all one-session apps
    private func checkAndReBlockOneSessionApps() {
        let appGroupID = "group.com.se7en.app"
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // Check global unlock mode
        let unlockMode: String = defaults.string(forKey: "globalUnlockMode") ?? "Extra Time"
        guard unlockMode == "One Session" else { return }
        
        let allKeys = Array(defaults.dictionaryRepresentation().keys)
        for key in allKeys where key.hasPrefix("oneSessionActive_") {
            if defaults.bool(forKey: key) {
                let tokenHash = String(key.dropFirst("oneSessionActive_".count))
                
                print("🔒 Monitor: Re-blocking app \(tokenHash.prefix(8))... (One-Session Mode)")
                
                // Clear flags
                defaults.set(false, forKey: key)
                defaults.removeObject(forKey: "oneSessionStartTime_\(tokenHash)")
                defaults.synchronize()
                
                // Re-block
                blockAppByTokenHash(tokenHash)
            }
        }
    }
    
    /// ✅ NEW: Check all limits and block apps that exceed them
    private func checkAllLimitsAndBlock() {
        let limits = SharedStorage.shared.loadLimits()
        
        for limit in limits where limit.isActive {
            guard let selection = limit.getSelection(),
                  let firstToken = selection.applicationTokens.first else { continue }
            
            let tokenHash = String(firstToken.hashValue)
            let usage = SharedStorage.shared.getUsage(tokenHash: tokenHash)
            
            // Skip if has active extension
            if hasActiveExtension(for: tokenHash) {
                continue
            }
            
            // Check if usage exceeds limit
            if usage >= limit.dailyLimitMinutes {
                print("🚫 Monitor: Usage (\(usage)) >= limit (\(limit.dailyLimitMinutes)) for \(limit.appName)")
                blockApps(selection: selection, limitID: limit.id, appName: limit.appName)
            }
        }
    }
    
    // MARK: - Extension Checks
    
    private func hasRecentPuzzleRequest(for tokenHash: String) -> Bool {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return false }
        
        if sharedDefaults.bool(forKey: "puzzleRequested_\(tokenHash)") {
            let requestTime = sharedDefaults.double(forKey: "puzzleRequestTime_\(tokenHash)")
            if requestTime > 0 {
                let timeSinceRequest = Date().timeIntervalSince1970 - requestTime
                if timeSinceRequest < 60.0 { // Extended to 60 seconds for reliability
                    print("✅ Monitor: Puzzle was requested \(String(format: "%.1f", timeSinceRequest))s ago")
                    return true
                }
            }
        }
        
        return false
    }
    
    private func hasActiveExtension(for tokenHash: String) -> Bool {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return false }
        
        // Check the extension end time
        let timestamp = sharedDefaults.double(forKey: "extension_end_\(tokenHash)")
        if timestamp > 0 {
            let extensionEndTime = Date(timeIntervalSince1970: timestamp)
            
            // Check if extension was granted today
            let today = Calendar.current.startOfDay(for: Date())
            let extensionDate = Calendar.current.startOfDay(for: extensionEndTime)
            if extensionDate < today {
                // Extension from previous day, clear it
                sharedDefaults.removeObject(forKey: "extension_end_\(tokenHash)")
                sharedDefaults.removeObject(forKey: "hasActiveExtension_\(tokenHash)")
                sharedDefaults.removeObject(forKey: "extensionLimit_\(tokenHash)")
                sharedDefaults.synchronize()
                return false
            }
            
            if Date() < extensionEndTime {
                print("✅ Monitor: Active extension found until \(extensionEndTime)")
                return true
            }
        }
        
        // Also check the hasActiveExtension flag
        if sharedDefaults.bool(forKey: "hasActiveExtension_\(tokenHash)") {
            let timestamp = sharedDefaults.double(forKey: "extension_end_\(tokenHash)")
            if timestamp > 0 {
                let extensionEndTime = Date(timeIntervalSince1970: timestamp)
                let today = Calendar.current.startOfDay(for: Date())
                let extensionDate = Calendar.current.startOfDay(for: extensionEndTime)
                if extensionDate < today {
                    sharedDefaults.removeObject(forKey: "extension_end_\(tokenHash)")
                    sharedDefaults.removeObject(forKey: "hasActiveExtension_\(tokenHash)")
                    sharedDefaults.removeObject(forKey: "extensionLimit_\(tokenHash)")
                    sharedDefaults.synchronize()
                    return false
                }
                if timestamp > Date().timeIntervalSince1970 {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Event Handlers
    
    private func handleUpdateEvent(tokenHash: String) {
        guard !tokenHash.isEmpty else { return }
        
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
        
        // ✅ NEW: Check if this increment pushes over the limit
        if let limitID = matchedLimitID,
           let limit = limits.first(where: { $0.id == limitID }) {
            let currentUsage = SharedStorage.shared.getUsage(tokenHash: tokenHash)
            if currentUsage >= limit.dailyLimitMinutes {
                // Check for extensions before blocking
                if !hasActiveExtension(for: tokenHash) && !hasRecentPuzzleRequest(for: tokenHash) {
                    print("🚫 Monitor: Usage threshold reached during update event")
                    if let selection = limit.getSelection() {
                        blockApps(selection: selection, limitID: limit.id, appName: limit.appName)
                    }
                }
            }
        }
    }
    
    private func handleWarningEvent(tokenHash: String) {
        print("⏰ Monitor: User approaching limit for \(tokenHash.prefix(8))...")
    }
    
    private func handleLimitEvent(tokenHash: String) {
        guard !tokenHash.isEmpty else {
            print("⚠️ Monitor: Empty token hash in limit event")
            return
        }
        
        // Double-check extension status
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
        
        // ✅ NEW: Check one-session apps before interval ends
        checkAndReBlockOneSessionApps()
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        print("⏰ Monitor: Warning - approaching limit for \(event.rawValue)")
    }
    
    // MARK: - Blocking Logic
    
    private func blockAppByTokenHash(_ tokenHash: String) {
        let limits = SharedStorage.shared.loadLimits()
        
        // Method 1: Check if tokenHash is a UUID
        if let uuid = UUID(uuidString: tokenHash) {
            if let limit = limits.first(where: { $0.id == uuid && $0.isActive }),
               let selection = limit.getSelection() {
                blockApps(selection: selection, limitID: limit.id, appName: limit.appName)
                return
            }
        }
        
        // Method 2: Match by token hash
        for limit in limits where limit.isActive {
            guard let selection = limit.getSelection() else { continue }
            
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
    
    private func blockApps(selection: FamilyActivitySelection, limitID: UUID, appName: String) {
        // ✅ CRITICAL: Use additive blocking - don't replace existing blocks
        var currentShielded = store.shield.applications ?? Set()
        for token in selection.applicationTokens {
            currentShielded.insert(token)
        }
        store.shield.applications = currentShielded.isEmpty ? nil : currentShielded
        
        // Also block categories if any
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        
        // Mark limit as reached
        SharedStorage.shared.markLimitReached(limitID: limitID)
        
        // ✅ NEW: Store the app name for shield configuration
        let appGroupID = "group.com.se7en.app"
        if let defaults = UserDefaults(suiteName: appGroupID) {
            if let firstToken = selection.applicationTokens.first {
                let tokenHash = String(firstToken.hashValue)
                defaults.set(appName, forKey: "limitAppName_\(tokenHash)")
                defaults.set(true, forKey: "limitReached_\(tokenHash)")
                defaults.synchronize()
            }
        }
        
        print("🚫 Monitor: BLOCKED '\(appName)' (limit \(limitID.uuidString.prefix(8))...)")
    }
    
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
        store.shield.applications = currentShielded.isEmpty ? nil : currentShielded
        
        print("✅ Monitor: Unblocked apps for limit \(limitID.uuidString.prefix(8))...")
    }
    
    // MARK: - Helpers
    
    private func extractLimitID(from activity: DeviceActivityName) -> UUID? {
        let rawValue = activity.rawValue
        
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