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
            print("📊 Fetched usage from shared container: \(bundleID) = \(usage) minutes")
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
        print("📊 Requesting report update for \(bundleID)")
    }
    
    /// Update usage record for an app
    /// This is called when we have usage data from reports or events
    /// MUST be called on main thread (Core Data requirement)
    func updateUsageRecord(bundleID: String, minutes: Int) {
        // Ensure we're on main thread for Core Data access
        assert(Thread.isMainThread, "updateUsageRecord must be called on main thread")
        
        let goals = coreDataManager.getActiveAppGoals()
        
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else {
            print("⚠️ No goal found for bundle ID: \(bundleID)")
            return
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // Get or create usage record
        if let record = coreDataManager.getTodaysUsageRecord(for: bundleID) {
            // Update existing record
            record.actualUsageMinutes = Int32(minutes)
            record.didExceedLimit = minutes >= Int(goal.dailyLimitMinutes)
            print("📊 Updated usage record for \(bundleID): \(minutes) minutes")
        } else {
            // Create new record
            _ = coreDataManager.createUsageRecord(
                for: goal,
                date: today,
                actualUsageMinutes: minutes,
                didExceedLimit: minutes >= Int(goal.dailyLimitMinutes)
            )
            print("📊 Created usage record for \(bundleID): \(minutes) minutes")
        }
        
        coreDataManager.save()
        
        // Post notification to update UI
        NotificationCenter.default.post(
            name: .screenTimeDataUpdated,
            object: nil
        )
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
                print("📊 Initialized usage record for \(goal.appName ?? bundleID)")
            }
        }
        
        coreDataManager.save()
    }
}

