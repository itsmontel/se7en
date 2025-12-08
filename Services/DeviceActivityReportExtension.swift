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
    func fetchUsageForApp(bundleID: String, activityName: DeviceActivityName, selection: FamilyActivitySelection) async -> Int {
        // First, try to get from shared container (updated by monitor/report extensions)
        // Prefer the explicit key `usage_<bundleID>` that the monitor writes
        let queue = DispatchQueue(label: "com.se7en.sharedDefaults.read", qos: .utility)
        var usage: Int = 0
        
        queue.sync {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
            
            // 1) Direct per-app key written by the monitor extension
            let perAppKey = "usage_\(bundleID)"
            let perAppUsage = sharedDefaults.integer(forKey: perAppKey)
            if perAppUsage > 0 {
                usage = perAppUsage
                return
            }
            
            // 2) Legacy dictionary storage (if ever present)
            if let usageData = sharedDefaults.dictionary(forKey: "appUsageData") as? [String: Int] {
                // Try to find usage by matching tokens in the selection
                for token in selection.applicationTokens {
                    let tokenKey = String(describing: token)
                    if let tokenUsage = usageData[tokenKey], tokenUsage > 0 {
                        usage = max(usage, tokenUsage)
                    }
                }
                
                // Also try direct bundle ID lookup (in case extension saves by bundle ID)
                if usage == 0, let bundleUsage = usageData[bundleID], bundleUsage > 0 {
                    usage = bundleUsage
                }
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

