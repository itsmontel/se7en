import DeviceActivity
import Foundation
import FamilyControls

// MARK: - DeviceActivityReport Service
// Provides methods to fetch usage data using DeviceActivityReport.Context

@MainActor
final class DeviceActivityReportService {
    static let shared = DeviceActivityReportService()
    
    // Use lazy to avoid initialization order issues
    private var coreDataManager: CoreDataManager {
        CoreDataManager.shared
    }
    
    private let appGroupID = "group.com.se7en.app"
    
    // ✅ PERFORMANCE: Throttle updates to prevent excessive saves
    private var lastUpdateTime: [String: Date] = [:]
    private var lastUpdateValue: [String: Int] = [:]
    private let updateThrottleInterval: TimeInterval = 5.0 // Only update every 5 seconds max
    private var pendingSaves: Set<String> = []
    private var saveTimer: Timer?
    
    private init() {}
    
    /// Fetch usage data for a specific app from the extension via shared container
    /// This method is now primarily used as a fallback - syncUsageFromSharedContainer handles the main sync
    func fetchUsageForApp(bundleID: String, activityName: DeviceActivityName, selection: FamilyActivitySelection) async -> Int {
        // First, try to get from shared container (updated by monitor/report extensions)
        let queue = DispatchQueue(label: "com.se7en.sharedDefaults.read", qos: .utility)
        var usage: Int = 0
        
        queue.sync {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
            
            // Priority 1: Try per-app usage from report extension (keyed by app name)
            // Need to match by app name from goal
            if let goal = coreDataManager.getActiveAppGoals().first(where: { $0.appBundleID == bundleID }),
               let appName = goal.appName {
                let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int] ?? [:]
                let normalizedGoalName = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                for (reportAppName, reportUsage) in perAppUsage {
                    let normalizedReportName = reportAppName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if normalizedGoalName == normalizedReportName {
                        usage = reportUsage
                        break
                    }
                }
            }
            
            // Priority 2: Fallback to monitor extension data (keyed by token hash)
            if usage == 0 {
                let perAppKey = "usage_\(bundleID)"
                usage = sharedDefaults.integer(forKey: perAppKey)
            }
        }
        
        if usage > 0 {
            // Update Core Data with the latest usage from extension
            // Ensure Core Data operations happen on main thread
            await MainActor.run {
                updateUsageRecord(bundleID: bundleID, minutes: usage)
            }
            return usage
        }
        
        // Fallback to Core Data record (may be outdated)
        // Core Data access should be on main thread
        return await MainActor.run {
            if let record = coreDataManager.getTodaysUsageRecord(for: bundleID) {
                let usage = Int(record.actualUsageMinutes)
                if usage > 0 {
                    return usage
                }
            }
            return 0
        }
    }
    
    /// Request a report update for an app
    /// This triggers the extension to generate a report (called automatically by system)
    func requestReportUpdate(for bundleID: String, activityName: DeviceActivityName, selection: FamilyActivitySelection) async {
        // The extension will be called automatically by the system when monitoring is active
        // We just need to ensure the activity is being monitored
    }
    
    /// Update usage record for an app
    /// This is called when we have usage data from reports or events
    /// MUST be called on main thread (Core Data requirement)
    /// ✅ PERFORMANCE: Throttled to prevent excessive updates
    func updateUsageRecord(bundleID: String, minutes: Int) {
        // Ensure we're on main thread for Core Data access
        assert(Thread.isMainThread, "updateUsageRecord must be called on main thread")
        
        let now = Date()
        let lastTime = lastUpdateTime[bundleID] ?? Date.distantPast
        let lastValue = lastUpdateValue[bundleID] ?? -1
        
        // ✅ PERFORMANCE: Skip if value unchanged and recently updated
        if minutes == lastValue && now.timeIntervalSince(lastTime) < updateThrottleInterval {
            return // No change, skip update
        }
        
        let goals = coreDataManager.getActiveAppGoals()
        
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else {
            return
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // Get or create usage record
        if let record = coreDataManager.getTodaysUsageRecord(for: bundleID) {
            // Only update if value changed
            if Int(record.actualUsageMinutes) != minutes {
            record.actualUsageMinutes = Int32(minutes)
            record.didExceedLimit = minutes >= Int(goal.dailyLimitMinutes)
                pendingSaves.insert(bundleID)
            }
        } else {
            // Create new record
            _ = coreDataManager.createUsageRecord(
                for: goal,
                date: today,
                actualUsageMinutes: minutes,
                didExceedLimit: minutes >= Int(goal.dailyLimitMinutes)
            )
            pendingSaves.insert(bundleID)
        }
        
        // Update tracking
        lastUpdateTime[bundleID] = now
        lastUpdateValue[bundleID] = minutes
        
        // ✅ PERFORMANCE: Batch saves instead of saving immediately
        scheduleBatchedSave()
    }
    
    /// ✅ PERFORMANCE: Batch Core Data saves to reduce I/O
    private func scheduleBatchedSave() {
        // Cancel existing timer
        saveTimer?.invalidate()
        
        // Schedule batched save after short delay
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self, !self.pendingSaves.isEmpty else { return }
            
            // Save all pending changes at once
            self.coreDataManager.save()
            self.pendingSaves.removeAll()
        
            // Post single notification for all updates
        NotificationCenter.default.post(
            name: .screenTimeDataUpdated,
            object: nil
        )
        }
    }
    
    /// Initialize usage records for all monitored apps
    /// This ensures we have records even before threshold events fire
    func initializeUsageRecords() {
        let goals = coreDataManager.getActiveAppGoals()
        let today = Calendar.current.startOfDay(for: Date())
        
        for goal in goals {
            guard let bundleID = goal.appBundleID else { continue }
            
            // Create usage record if it doesn't exist
            if coreDataManager.getTodaysUsageRecord(for: bundleID) == nil {
                _ = coreDataManager.createUsageRecord(
                    for: goal,
                    date: today,
                    actualUsageMinutes: 0,
                    didExceedLimit: false
                )
            }
        }
        
        coreDataManager.save()
    }
}

