import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

// MARK: - Screen Time Service
// Clean implementation for Screen Time API integration

@MainActor
final class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()
    
    // MARK: - Properties
    
    private let authCenter = AuthorizationCenter.shared
    private let deviceActivityCenter = DeviceActivityCenter()
    private let settingsStore = ManagedSettingsStore()
    private let coreDataManager = CoreDataManager.shared
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    
    private var cancellables = Set<AnyCancellable>()
    
    // Track last logged usage values to prevent log spam
    private var lastLoggedUsage: [String: Int] = [:]
    
    // ✅ PERFORMANCE: Track blocked apps to prevent repeated blocking calls
    private var blockedApps: Set<String> = []
    private var lastBlockTime: [String: Date] = [:]
    private let blockThrottleInterval: TimeInterval = 10.0 // Don't re-block same app within 10 seconds
    
    // MARK: - Token Storage
    // Key: bundle ID or app identifier, Value: FamilyActivitySelection for that app
    private var appSelections: [String: FamilyActivitySelection] = [:]
    
    // Selection of ALL apps for dashboard usage tracking (not monitoring)
    var allAppsSelection: FamilyActivitySelection? {
        get {
            if _allAppsSelection == nil {
                _allAppsSelection = loadAllAppsSelection()
            }
            return _allAppsSelection
        }
        set {
            _allAppsSelection = newValue
            if let selection = newValue {
                saveAllAppsSelection(selection)
                
                // Immediately process the selection to create goals and records
                Task {
                    await updateUsageFromAllAppsSelection(selection)
                }
            }
        }
    }
    private var _allAppsSelection: FamilyActivitySelection?
    
    // MARK: - Initialization
    
    private init() {
        // Check current authorization status
        authorizationStatus = authCenter.authorizationStatus
        isAuthorized = authorizationStatus == .approved
        
        // Listen for authorization changes
        authCenter.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                let wasAuthorized = self?.isAuthorized ?? false
                self?.authorizationStatus = status
                self?.isAuthorized = status == .approved
                
                // If we just became authorized, set up monitoring
                if !wasAuthorized && status == .approved {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.refreshAllMonitoring()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Load saved selections on init
        loadSavedSelections()
        
        // Load all apps selection
        _allAppsSelection = loadAllAppsSelection()
        
        // Initialize usage records for all monitored apps (deferred to avoid initialization order issues)
        // This ensures we have records even before threshold events fire
        DispatchQueue.main.async {
            DeviceActivityReportService.shared.initializeUsageRecords()
            
            // ⚠️ CRITICAL: Start monitoring immediately if authorized
            if self.isAuthorized {
                self.refreshAllMonitoring()
            }
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        do {
            print("🔐 Requesting Screen Time authorization...")
            try await authCenter.requestAuthorization(for: .individual)
            isAuthorized = authCenter.authorizationStatus == .approved
            print("🔐 Authorization result: \(isAuthorized ? "Approved" : "Denied")")
            print("🔐 Authorization status: \(authCenter.authorizationStatus)")
        } catch {
            isAuthorized = false
            print("❌ Screen Time auth failed:", error)
        }
    }
    
    // MARK: - App Selection Management
    
    /// Add an app for monitoring from FamilyActivitySelection
    /// - Parameters:
    ///   - selection: The FamilyActivitySelection containing the app's token
    ///   - appName: Display name of the app
    ///   - bundleID: Bundle identifier (can be extracted or provided)
    ///   - dailyLimitMinutes: Daily usage limit in minutes
    func addAppForMonitoring(
        selection: FamilyActivitySelection,
        appName: String,
        bundleID: String,
        dailyLimitMinutes: Int
    ) {
        guard isAuthorized else {
            print("❌ Cannot add app - not authorized")
            return
        }
        
        guard let firstToken = selection.applicationTokens.first else {
            print("❌ Cannot add app - no tokens in selection")
            return
        }
        
        // ✅ Use token hash as the unique identifier - compute from first token
        let tokenHash = String(firstToken.hashValue)
        
        // ✅ CRITICAL: Verify hash consistency - compute from all tokens and use first
        // This ensures the hash matches what the extension will compute
        var computedHashes: [String] = []
        for token in selection.applicationTokens {
            computedHashes.append(String(token.hashValue))
        }
        
        // Use the first token's hash (should be consistent)
        let verifiedTokenHash = computedHashes.first ?? tokenHash
        
        print("\n" + String(repeating: "=", count: 60))
        print("📱 ADDING APP FOR MONITORING")
        print("   Token hash: \(verifiedTokenHash)")
        print("   All token hashes: \(computedHashes)")
        print("   Custom name: '\(appName)'")
        print("   Limit: \(dailyLimitMinutes) minutes")
        print(String(repeating: "=", count: 60))
        
        // Store the selection with verified token hash as key
        appSelections[verifiedTokenHash] = selection
        saveSelection(selection, forBundleID: verifiedTokenHash)
        
        // 🔥 CRITICAL: Save to shared container IMMEDIATELY for extension access
        saveSelectionToSharedContainer(selection: selection, tokenHash: verifiedTokenHash)
        
        // ✅ CRITICAL: Save to LimitStorageManager so extension can find the limit!
        let storedLimit = StoredAppLimit(
            appName: appName,
            dailyLimitMinutes: dailyLimitMinutes,
            selection: selection
        )
        LimitStorageManager.shared.addLimit(storedLimit)
        print("💾 Saved StoredAppLimit: \(storedLimit.id.uuidString.prefix(8))... for '\(appName)'")
        
        // ✅ NEW: Save ALL monitored app selections for extension to access
        saveAllMonitoredSelectionsToSharedContainer()
        
        // Create app goal in Core Data using verified token hash as identifier
        let appGoal = coreDataManager.createAppGoal(
            appName: appName.isEmpty ? "" : appName,
            bundleID: verifiedTokenHash,
            dailyLimitMinutes: dailyLimitMinutes
        )
        
        // 🔥 Initialize usage record AND shared container to 0 IMMEDIATELY
        let today = Calendar.current.startOfDay(for: Date())
        if coreDataManager.getTodaysUsageRecord(for: verifiedTokenHash) == nil {
            _ = coreDataManager.createUsageRecord(
                for: appGoal,
                date: today,
                actualUsageMinutes: 0,
                didExceedLimit: false
            )
            coreDataManager.save()
        }
        
        // Initialize shared container
        initializeSharedContainerUsage(tokenHash: verifiedTokenHash)
        
        // Set up basic DeviceActivity monitoring
        setupBasicMonitoring(for: appGoal, selection: selection)
        
        // ✅ CRITICAL: Refresh global monitoring to include this new app
        // This ensures the report extension can see this app's usage
        if let allApps = allAppsSelection {
            setupGlobalMonitoringForReports(selection: allApps)
        }
        
        print("✅ App added and monitoring started!")
    }
    
    // MARK: - New UUID-Based Limit Management

    /// Add an app for monitoring using the new reliable storage
    func addAppLimitReliable(
        selection: FamilyActivitySelection,
        appName: String,
        dailyLimitMinutes: Int
    ) {
        guard isAuthorized else {
            print("❌ Cannot add app - not authorized")
            return
        }
        
        guard !selection.applicationTokens.isEmpty else {
            print("❌ Cannot add app - no tokens in selection")
            return
        }
        
        // ✅ Create with stable UUID (not hash!)
        let limit = StoredAppLimit(
            appName: appName,
            dailyLimitMinutes: dailyLimitMinutes,
            selection: selection
        )
        
        print("\n" + String(repeating: "=", count: 60))
        print("📱 ADDING APP LIMIT (UUID-based)")
        print("   ID: \(limit.id.uuidString)")
        print("   Name: '\(appName)'")
        print("   Limit: \(dailyLimitMinutes) minutes")
        print("   Tokens: \(selection.applicationTokens.count)")
        print(String(repeating: "=", count: 60))
        
        // Save to shared storage
        LimitStorageManager.shared.addLimit(limit)
        
        // ✅ Create Core Data goal with UUID stored in appBundleID field
        let limitUUIDString = limit.id.uuidString
        _ = coreDataManager.createAppGoal(
            appName: appName,
            bundleID: limitUUIDString,  // ✅ Store UUID, not token hash!
            dailyLimitMinutes: dailyLimitMinutes
        )
        
        // Store selection with UUID key (for lookup)
        appSelections[limitUUIDString] = selection
        saveSelection(selection, forBundleID: limitUUIDString)
        
        // Set up monitoring
        setupCombinedMonitoringReliable(limitID: limit.id, selection: selection, limitMinutes: dailyLimitMinutes)
        
        print("✅ App limit added successfully!")
    }

    /// Set up monitoring using UUID-based identification
    private func setupCombinedMonitoringReliable(limitID: UUID, selection: FamilyActivitySelection, limitMinutes: Int) {
        let idString = limitID.uuidString
        let warningMinutes = max(1, Int(Double(limitMinutes) * 0.8))
        
        print("\n🔧 SETTING UP MONITORING (UUID-based):")
        print("   Limit ID: \(idString.prefix(8))...")
        print("   Warning at: \(warningMinutes) min")
        print("   Limit at: \(limitMinutes) min")
        
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        // Events use UUID, not hash
        let warningEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: warningMinutes)
        )
        
        let limitEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: limitMinutes)
        )
        
        let activityName = DeviceActivityName("se7en.limit.\(idString)")
        
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            DeviceActivityEvent.Name("warning.\(idString)"): warningEvent,
            DeviceActivityEvent.Name("limit.\(idString)"): limitEvent
        ]
        
        do {
            try deviceActivityCenter.startMonitoring(activityName, during: schedule, events: events)
            print("✅ Monitoring started successfully!")
        } catch {
            print("❌ Failed to start monitoring: \(error)")
        }
    }

    /// Get usage for a limit by its UUID
    func getUsageReliable(for limitID: UUID) -> Int {
        return LimitStorageManager.shared.getUsage(for: limitID)
    }

    /// Get all stored limits
    func getAllLimits() -> [StoredAppLimit] {
        return LimitStorageManager.shared.loadLimits()
    }

    /// Remove a limit by UUID
    func removeLimitReliable(id: UUID) {
        // Stop monitoring
        let activityName = DeviceActivityName("se7en.limit.\(id.uuidString)")
        deviceActivityCenter.stopMonitoring([activityName])
        
        // Remove from storage
        LimitStorageManager.shared.removeLimit(id: id)
        
        // Also remove from Core Data
        let goals = coreDataManager.getActiveAppGoals()
        if let goal = goals.first(where: { $0.appBundleID == id.uuidString }) {
            coreDataManager.deleteAppGoal(goal)
        }
        
        // Remove from in-memory cache
        appSelections.removeValue(forKey: id.uuidString)
        
        print("🗑️ Removed limit: \(id.uuidString.prefix(8))...")
    }
    
    // MARK: - Simple Monitoring Setup
    
    private func saveSelectionToSharedContainer(selection: FamilyActivitySelection, tokenHash: String) {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Failed to save selection to shared container")
            return
        }
        
        do {
            let data = try PropertyListEncoder().encode(selection)
            sharedDefaults.set(data, forKey: "selection_\(tokenHash)")
            sharedDefaults.synchronize()
            print("💾 Saved selection to shared container for: \(tokenHash)")
        } catch {
            print("❌ Failed to encode selection: \(error)")
        }
    }
    
    /// ✅ CRITICAL: Save ONLY individual app selections (NO CATEGORIES!)
    /// Limits page is ONLY for individual apps, categories are for Dashboard only
    func saveAllMonitoredSelectionsToSharedContainer() {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Failed to access shared container")
            return
        }
        
        // Get all active goals
        let goals = coreDataManager.getActiveAppGoals()
        
        // Build array of monitored app info - ONLY INDIVIDUAL APPS
        var monitoredApps: [[String: Any]] = []
        
        for goal in goals {
            guard let tokenHash = goal.appBundleID,
                  let selection = appSelections[tokenHash] else {
                continue
            }
            
            // ✅ CRITICAL: ONLY save selections that have individual app tokens
            // REJECT any selection with category tokens - categories are for Dashboard ONLY
            guard !selection.applicationTokens.isEmpty,
                  selection.categoryTokens.isEmpty else {
                print("⚠️ Skipping \(goal.appName ?? tokenHash) - has categories (Limits are ONLY for individual apps)")
                continue
            }
            
            // Encode the selection
            if let selectionData = try? PropertyListEncoder().encode(selection) {
                let appInfo: [String: Any] = [
                    "tokenHash": tokenHash,
                    "appName": goal.appName ?? "",
                    "limitMinutes": Int(goal.dailyLimitMinutes),
                    "selectionData": selectionData
                ]
                monitoredApps.append(appInfo)
            }
        }
        
        sharedDefaults.set(monitoredApps, forKey: "monitored_app_selections")
        sharedDefaults.synchronize()
        
    }
    
    private func setupBasicMonitoring(for goal: AppGoal, selection: FamilyActivitySelection) {
        guard let tokenHash = goal.appBundleID else { return }
        
        let limitMinutes = Int(goal.dailyLimitMinutes)
        let updateInterval = 1 // 1 minute
        
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        let updateEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: updateInterval)
        )
        
        let limitEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: limitMinutes)
        )
        
        let activityName = makeActivityName(for: tokenHash)
        
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            DeviceActivityEvent.Name("update.\(tokenHash)"): updateEvent,
            DeviceActivityEvent.Name("limit.\(tokenHash)"): limitEvent
        ]
        
        do {
            try deviceActivityCenter.startMonitoring(activityName, during: schedule, events: events)
            print("✅ DeviceActivity monitoring started for: \(tokenHash)")
        } catch {
            print("⚠️ DeviceActivity monitoring failed: \(error)")
        }
    }
    
    /// Fetch usage for all monitored apps when app becomes active
    /// Call this from scene lifecycle (willEnterForeground)
    func refreshUsageForAllApps() {
        Task { @MainActor in
            let goals = coreDataManager.getActiveAppGoals()
            for goal in goals {
                guard let tokenHash = goal.appBundleID,
                      let selection = appSelections[tokenHash] else { continue }
                
                let activityName = makeActivityName(for: tokenHash)
                let usage = await DeviceActivityReportService.shared.fetchUsageForApp(
                    bundleID: tokenHash,
                    activityName: activityName,
                    selection: selection
                )
                
                if usage > 0 {
                    updateUsage(for: tokenHash, minutes: usage)
                    
                    // Check limit
                    if usage >= Int(goal.dailyLimitMinutes) {
                        blockApp(tokenHash)
                    }
                }
            }
            
            // Sync from shared container too
            syncUsageFromSharedContainer()
            
            // Notify UI
            NotificationCenter.default.post(
                name: .screenTimeDataUpdated,
                object: nil
            )
        }
    }
    
    // MARK: - Shared Container Initialization
    
    private func initializeSharedContainerUsage(tokenHash: String) {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        let key = "usage_\(tokenHash)"
        if sharedDefaults.object(forKey: key) == nil {
            sharedDefaults.set(0, forKey: key)
            sharedDefaults.synchronize()
            print("💾 Initialized shared container usage to 0 for \(tokenHash)")
        }
    }
    
    /// Check if we have a stored selection for an app
    func hasSelection(for bundleID: String) -> Bool {
        return appSelections[bundleID] != nil
    }
    
    /// Get the selection for an app
    func getSelection(for bundleID: String) -> FamilyActivitySelection? {
        return appSelections[bundleID]
    }
    
    /// Remove an app from monitoring
    func removeApp(bundleID: String) {
        appSelections.removeValue(forKey: bundleID)
        removeSelection(forBundleID: bundleID)
        stopMonitoring(for: bundleID)
        print("🗑️ Removed app: \(bundleID)")
    }
    
    // MARK: - Monitoring Setup
    
    /// Helper to create activity name from bundle ID
    private func makeActivityName(for bundleID: String) -> DeviceActivityName {
        return DeviceActivityName("se7en.\(bundleID.replacingOccurrences(of: ".", with: "_"))")
    }
    
    /// Combined monitoring setup with both frequent updates AND limit enforcement
    /// This ensures real-time usage tracking while also enforcing limits
    private func setupCombinedMonitoring(for goal: AppGoal, selection: FamilyActivitySelection) {
        // ✅ bundleID field now contains token hash
        guard let tokenHash = goal.appBundleID else {
            print("❌ No token hash for goal!")
            return
        }
        
        let limitMinutes = Int(goal.dailyLimitMinutes)
        let warningMinutes = max(1, Int(Double(limitMinutes) * 0.8))
        let updateInterval = 1 // 1 minute for real-time tracking
        
        print("\n🔧 SETTING UP MONITORING:")
        print("   Custom name: '\(goal.appName ?? "None")'")
        print("   Token hash: '\(tokenHash)'")
        print("   Update interval: \(updateInterval) min")
        print("   Warning at: \(warningMinutes) min")
        print("   Limit at: \(limitMinutes) min")
        print("   Tokens: \(selection.applicationTokens.count)")
        
        // Create schedule (midnight to midnight)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        // Create events: update (1 min), warning (80%), and limit (100%)
        let updateEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,  // ✅ Use tokens directly
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: updateInterval)
        )
        
        let warningEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: warningMinutes)
        )
        
        let limitEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: limitMinutes)
        )
        
        // ✅ Use token hash in activity name
        let activityName = makeActivityName(for: tokenHash)
        
        // ✅ Log the exact event names being used (with token hash)
        let updateEventName = DeviceActivityEvent.Name("update.\(tokenHash)")
        let warningEventName = DeviceActivityEvent.Name("warning.\(tokenHash)")
        let limitEventName = DeviceActivityEvent.Name("limit.\(tokenHash)")
        
        print("   Event names:")
        print("   - Update: '\(String(describing: updateEventName))'")
        print("   - Warning: '\(String(describing: warningEventName))'")
        print("   - Limit: '\(String(describing: limitEventName))'")
        
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            updateEventName: updateEvent,
            warningEventName: warningEvent,
            limitEventName: limitEvent
        ]
        
        do {
            try deviceActivityCenter.startMonitoring(activityName, during: schedule, events: events)
            print("✅ Monitoring started successfully!")
            print("   Activity name: '\(String(describing: activityName))'\n")
        } catch {
            print("❌ FAILED to start monitoring!")
            print("   Error: \(error)")
            print("   Error details: \(error.localizedDescription)\n")
        }
    }
    
    private func setupMonitoring(for goal: AppGoal, selection: FamilyActivitySelection) {
        // Legacy method - now redirects to combined monitoring
        setupCombinedMonitoring(for: goal, selection: selection)
    }
    
    /// Set up monitoring with frequent thresholds for usage tracking
    /// This fires events every 1 minute to update usage data
    private func setupMonitoringWithFrequentUpdates(for goal: AppGoal, selection: FamilyActivitySelection) {
        guard let bundleID = goal.appBundleID else { return }
        
        // Use frequent thresholds: every 1 minute
        // This will fire events regularly to update usage
        let updateInterval = 1 // minutes
        let highLimit = 1440 // 24 hours (won't block)
        
        // Unique activity name for this app
        let activityName = makeActivityName(for: bundleID)
        
        print("🔧 Setting up frequent monitoring for \(goal.appName ?? "Unknown"):")
        print("   Bundle ID: \(bundleID)")
        print("   Tokens: \(selection.applicationTokens.count)")
        print("   Activity Name: \(activityName)")
        print("   Schedule: Daily from midnight to 11:59 PM")
        print("   Update interval: \(updateInterval) minutes")
        print("   High limit: \(highLimit) minutes (won't block)")
        
        // Create schedule (midnight to midnight)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        // Create frequent update events (every 1 minute)
        // These will fire regularly to update usage
        let updateEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: updateInterval)
        )
        
        // Also set a high limit event (won't block, just for tracking)
        let limitEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: highLimit)
        )
        
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            DeviceActivityEvent.Name("update.\(bundleID)"): updateEvent,
            DeviceActivityEvent.Name("limit.\(bundleID)"): limitEvent
        ]
        
        do {
            try deviceActivityCenter.startMonitoring(activityName, during: schedule, events: events)
            print("✅ Started frequent monitoring for \(goal.appName ?? bundleID)")
            print("   Activity Name: \(activityName)")
            print("   Update threshold: \(updateInterval) minutes")
            print("   Events configured: update.\(bundleID), limit.\(bundleID)")
            print("   Monitoring should fire events every \(updateInterval) minutes")
        } catch {
            print("❌ Failed to start frequent monitoring for \(bundleID): \(error)")
            print("   Error details: \(error.localizedDescription)")
            print("   This will prevent usage tracking from working!")
        }
    }
    
    private func stopMonitoring(for bundleID: String) {
        let activityName = makeActivityName(for: bundleID)
        deviceActivityCenter.stopMonitoring([activityName])
        print("🛑 Stopped monitoring for \(bundleID)")
    }
    
    func stopAllMonitoring() {
        for bundleID in appSelections.keys {
            stopMonitoring(for: bundleID)
        }
        settingsStore.clearAllSettings()
        print("🛑 Stopped all monitoring")
    }
    
    // MARK: - App Blocking
    // IMPORTANT: Use tokens directly from FamilyActivitySelection - don't rely on bundle IDs
    
    func blockApp(_ bundleID: String) {
        // ✅ PERFORMANCE: Throttle blocking to prevent repeated calls
        let now = Date()
        if let lastBlock = lastBlockTime[bundleID],
           now.timeIntervalSince(lastBlock) < blockThrottleInterval,
           blockedApps.contains(bundleID) {
            return // Already blocked recently, skip
        }
        
        // First try to get selection by bundle ID (for individual apps)
        if let selection = appSelections[bundleID] {
            // Block specific apps from this selection using tokens
            var blockedAppsSet = settingsStore.shield.applications ?? Set()
            for token in selection.applicationTokens {
                blockedAppsSet.insert(token)
            }
            settingsStore.shield.applications = blockedAppsSet.isEmpty ? nil : blockedAppsSet
            
            // Also block categories if present
            if !selection.categoryTokens.isEmpty {
                settingsStore.shield.applicationCategories = .specific(selection.categoryTokens)
            }
            
            // Track blocking
            blockedApps.insert(bundleID)
            lastBlockTime[bundleID] = now
            return
        }
        
        // Fallback: If bundle ID lookup fails, use allAppsSelection
        // This handles cases where we have categories or can't extract bundle IDs
        if let allApps = allAppsSelection {
            var blockedApps = settingsStore.shield.applications ?? Set()
            
            // Block all application tokens
            for token in allApps.applicationTokens {
                blockedApps.insert(token)
            }
            settingsStore.shield.applications = blockedApps.isEmpty ? nil : blockedApps
            
            // Block all category tokens
            if !allApps.categoryTokens.isEmpty {
                settingsStore.shield.applicationCategories = .specific(allApps.categoryTokens)
            }
            
            print("🚫 Blocked using allAppsSelection (apps: \(allApps.applicationTokens.count), categories: \(allApps.categoryTokens.count))")
        } else {
            print("❌ No selection found for blocking: \(bundleID)")
        }
    }
    
    func unblockApp(_ bundleID: String) {
        // ✅ FIX: bundleID is actually a tokenHash, find selection by tokenHash
        var selection: FamilyActivitySelection?
        
        // Try 1: Get from in-memory appSelections
        if let foundSelection = appSelections[bundleID] {
            selection = foundSelection
        } else {
            // Try 2: Load from shared container
            let appGroupID = "group.com.se7en.app"
            if let sharedDefaults = UserDefaults(suiteName: appGroupID),
               let selectionData = sharedDefaults.data(forKey: "selection_\(bundleID)"),
               let decodedSelection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData) {
                selection = decodedSelection
                // Cache it for future use
                appSelections[bundleID] = decodedSelection
            } else {
                // Try 3: Find goal by tokenHash and get its selection
                let goals = coreDataManager.getActiveAppGoals()
                if let _ = goals.first(where: { $0.appBundleID == bundleID }),
                   let goalSelection = appSelections[bundleID] {
                    selection = goalSelection
                } else if let _ = goals.first(where: { $0.appBundleID == bundleID }),
                          let goalSelection = appSelections[bundleID] {
                    selection = goalSelection
                }
            }
        }
        
        // Unblock using the selection
        if let selection = selection {
            unblockWithSelection(selection)
            
            // ✅ CRITICAL: Also remove from blockedApps tracking
            blockedApps.remove(bundleID)
            
            return
        }
        
        // ✅ FALLBACK: If we can't find selection, try to unblock by finding the token in blocked apps
        // This handles cases where the app was blocked but we lost the selection reference
        if let allApps = allAppsSelection {
            // Try to find the token in allAppsSelection by matching hash
            for token in allApps.applicationTokens {
                if String(token.hashValue) == bundleID {
                    // Found the token, unblock it
                    var blockedAppsSet = settingsStore.shield.applications ?? Set()
                    blockedAppsSet.remove(token)
                    settingsStore.shield.applications = blockedAppsSet.isEmpty ? nil : blockedAppsSet
                    blockedApps.remove(bundleID)
                    return
                }
            }
        }
        
        // ✅ FALLBACK 2: Try to find token in all stored selections
        for (_, storedSelection) in appSelections {
            for token in storedSelection.applicationTokens {
                if String(token.hashValue) == bundleID {
                    // Found matching token, unblock it
                    var blockedAppsSet = settingsStore.shield.applications ?? Set()
                    blockedAppsSet.remove(token)
                    settingsStore.shield.applications = blockedAppsSet.isEmpty ? nil : blockedAppsSet
                    blockedApps.remove(bundleID)
                    return
                }
            }
        }
        
        // ✅ FALLBACK 3: Try loading from shared container and finding token
        let appGroupID = "group.com.se7en.app"
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            // Try all stored selections in shared container
            let allKeys = sharedDefaults.dictionaryRepresentation().keys
            for key in allKeys where key.hasPrefix("selection_") {
                if let selectionData = sharedDefaults.data(forKey: key),
                   let decodedSelection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData) {
                    for token in decodedSelection.applicationTokens {
                        if String(token.hashValue) == bundleID {
                            // Found matching token, unblock it
                            var blockedAppsSet = settingsStore.shield.applications ?? Set()
                            blockedAppsSet.remove(token)
                            settingsStore.shield.applications = blockedAppsSet.isEmpty ? nil : blockedAppsSet
                            blockedApps.remove(bundleID)
                            return
                        }
                    }
                }
            }
        }
        
        // Last resort: Clear all blocks if we can't find the specific app
        // This ensures the app gets unblocked even if we can't find the exact selection
        settingsStore.shield.applications = nil
        settingsStore.shield.applicationCategories = nil
        blockedApps.remove(bundleID)
    }
    
    /// Block using tokens directly from a FamilyActivitySelection (recommended approach)
    /// This doesn't require bundle IDs and works with both apps and categories
    func blockWithSelection(_ selection: FamilyActivitySelection) {
        // Block application tokens
        if !selection.applicationTokens.isEmpty {
            var blockedApps = settingsStore.shield.applications ?? Set()
            for token in selection.applicationTokens {
                blockedApps.insert(token)
            }
            settingsStore.shield.applications = blockedApps
        }
        
        // Block category tokens
        if !selection.categoryTokens.isEmpty {
            settingsStore.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        
        print("🚫 Blocked with selection (apps: \(selection.applicationTokens.count), categories: \(selection.categoryTokens.count))")
    }
    
    /// Unblock using tokens directly from a FamilyActivitySelection
    func unblockWithSelection(_ selection: FamilyActivitySelection) {
        // Unblock application tokens
        if !selection.applicationTokens.isEmpty {
            var blockedApps = settingsStore.shield.applications ?? Set()
            for token in selection.applicationTokens {
                blockedApps.remove(token)
            }
            settingsStore.shield.applications = blockedApps.isEmpty ? nil : blockedApps
        }
        
        // Note: Category unblocking is all-or-nothing - we can't selectively unblock
        // If you need to unblock categories, you'll need to clear all and re-apply
        print("✅ Unblocked with selection")
    }
    
    /// Block all apps/categories from allAppsSelection
    /// This is the recommended approach when using FamilyActivityPicker
    func blockAllSelectedApps() {
        guard let selection = allAppsSelection else {
            print("⚠️ No allAppsSelection to block")
            return
        }
        
        // Block application tokens
        if !selection.applicationTokens.isEmpty {
            settingsStore.shield.applications = selection.applicationTokens
            print("🚫 Blocked \(selection.applicationTokens.count) apps")
        }
        
        // Block category tokens
        if !selection.categoryTokens.isEmpty {
            settingsStore.shield.applicationCategories = .specific(selection.categoryTokens)
            print("🚫 Blocked \(selection.categoryTokens.count) categories")
        }
    }
    
    func unblockAllApps() {
        settingsStore.shield.applications = nil
        settingsStore.shield.applicationCategories = nil
        print("✅ Unblocked all apps and categories")
    }
    
    // MARK: - Usage Tracking
    
    /// Get usage minutes for a specific app
    /// Uses the last synced Core Data values without forcing a new sync on every call
    func getUsageMinutes(for bundleID: String) -> Int {
        // Get from Core Data (which is now updated by syncUsageFromSharedContainer)
        if let record = coreDataManager.getTodaysUsageRecord(for: bundleID) {
            return Int(record.actualUsageMinutes)
        }
        
        // Create record if doesn't exist
        let goals = coreDataManager.getActiveAppGoals()
        if let goal = goals.first(where: { $0.appBundleID == bundleID }) {
            let today = Calendar.current.startOfDay(for: Date())
            _ = coreDataManager.createUsageRecord(
                for: goal,
                date: today,
                actualUsageMinutes: 0,
                didExceedLimit: false
            )
            coreDataManager.save()
        }
        
        return 0
    }
    
    /// Fetch usage data from DeviceActivityReport for a specific app
    /// This attempts to get real-time usage data
    func fetchUsageFromReport(for bundleID: String) async -> Int {
        guard let selection = appSelections[bundleID] else {
        return 0
    }
    
        // Get the activity name for this app
        let activityName = makeActivityName(for: bundleID)
        
        // Try to fetch usage from report service
        let usage = await DeviceActivityReportService.shared.fetchUsageForApp(
            bundleID: bundleID,
            activityName: activityName,
            selection: selection
        )
        
        // Update the usage record if we got data
        // Ensure Core Data operations happen on main thread
        if usage > 0 {
            await MainActor.run {
                DeviceActivityReportService.shared.updateUsageRecord(bundleID: bundleID, minutes: usage)
            }
    }
    
        return usage
    }
    
    // 🚀 OPTIMIZED: High-performance sync with throttling and caching
    private var lastSyncTime: Date = Date.distantPast
    private var cachedUsageData: [String: Int] = [:]
    private var lastDataHash: Int = 0
    private let syncThrottleInterval: TimeInterval = 5.0 // Only sync every 5 seconds max
    
    func syncUsageFromSharedContainer() {
        // 🚀 THROTTLE: Prevent excessive sync calls
        let now = Date()
        guard now.timeIntervalSince(lastSyncTime) >= syncThrottleInterval else {
            return
        }
        
        // 🚀 BACKGROUND: Move to background queue to avoid blocking UI
        Task.detached(priority: .utility) {
            await self.performOptimizedUsageSync()
        }
    }
    
    private func performOptimizedUsageSync() async {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // 🚀 FAST CHECK: Only proceed if data actually changed
        let perAppUsage = sharedDefaults.dictionary(forKey: "per_app_usage") as? [String: Int] ?? [:]
        let currentDataHash = perAppUsage.hashValue
        
        guard currentDataHash != lastDataHash else {
            return // No changes, skip sync
        }
        
        await MainActor.run {
            self.lastSyncTime = Date()
            self.lastDataHash = currentDataHash
            self.cachedUsageData = perAppUsage
        }
        
        // 🚀 BATCH: Get all goals at once
        let goals = await MainActor.run {
            self.coreDataManager.getActiveAppGoals()
        }
        
        // 🚀 BATCH: Prepare all updates
        var updates: [(goal: AppGoal, usage: Int)] = []
        
        for goal in goals {
            guard let tokenHash = goal.appBundleID,
                  let appName = goal.appName else { continue }
            
            var usageMinutes: Int = 0
            
            // 🚀 FAST LOOKUP: Direct hash lookup instead of linear search
            let normalizedGoalName = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            // Try exact match first (most common case)
            if let exactMatch = perAppUsage[appName] {
                usageMinutes = exactMatch
            } else {
                // Fallback to normalized matching only if needed
                for (reportAppName, reportUsage) in perAppUsage {
                    let normalizedReportName = reportAppName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if normalizedGoalName == normalizedReportName {
                        usageMinutes = reportUsage
                        break
                    }
                }
            }
            
            // Fallback to token-based lookup
            if usageMinutes == 0 {
                let key = "usage_\(tokenHash)"
                usageMinutes = sharedDefaults.integer(forKey: key)
            }
            
            if usageMinutes > 0 {
                updates.append((goal: goal, usage: usageMinutes))
            }
        }
        
        // 🚀 BATCH: Apply all updates at once on main thread
        await MainActor.run {
            self.applyBatchedUsageUpdates(updates)
        }
    }
    
    private func applyBatchedUsageUpdates(_ updates: [(goal: AppGoal, usage: Int)]) {
        guard !updates.isEmpty else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        var hasChanges = false
        
        for (goal, usageMinutes) in updates {
            guard let tokenHash = goal.appBundleID else { continue }
            
            if let record = coreDataManager.getTodaysUsageRecord(for: tokenHash) {
                // Only update if actually changed
                if usageMinutes != Int(record.actualUsageMinutes) {
                    record.actualUsageMinutes = Int32(usageMinutes)
                    record.didExceedLimit = usageMinutes >= Int(goal.dailyLimitMinutes)
                    hasChanges = true
                }
            } else {
                // Create new record
                _ = coreDataManager.createUsageRecord(
                    for: goal,
                    date: today,
                    actualUsageMinutes: usageMinutes,
                    didExceedLimit: usageMinutes >= Int(goal.dailyLimitMinutes)
                )
                hasChanges = true
            }
            
            // Update tracking
            lastLoggedUsage[tokenHash] = usageMinutes
        }
        
        // 🚀 SINGLE SAVE: Only save if there are actual changes
        if hasChanges {
            coreDataManager.save()
        }
    }
    
    
    /// Update usage data from reports for all apps (allAppsSelection or monitored apps)
    /// This should be called periodically to refresh usage data
    func updateUsageFromReport() async {
        print("🔄 updateUsageFromReport: Starting...")
        
        // First, sync from shared container (monitor extension writes here)
        syncUsageFromSharedContainer()
        
        // First, try to update from all apps selection (either apps OR categories)
        if let allApps = allAppsSelection, (!allApps.applicationTokens.isEmpty || !allApps.categoryTokens.isEmpty) {
            print("📱 Updating from allAppsSelection with \(allApps.applicationTokens.count) apps and \(allApps.categoryTokens.count) categories")
            await updateUsageFromAllAppsSelection(allApps)
        } else {
            print("⚠️ No allAppsSelection found, falling back to monitored apps")
        }
        
        // Also update monitored apps (they may have different limits/tracking)
        let goals = coreDataManager.getActiveAppGoals()
        print("📊 Updating \(goals.count) monitored app goals")
        
        for goal in goals {
            guard let bundleID = goal.appBundleID,
                  hasSelection(for: bundleID) else {
                continue
            }
            
            // Fetch usage from report
            let usage = await fetchUsageFromReport(for: bundleID)
            
            if usage > 0 {
                updateUsage(for: bundleID, minutes: usage)
                print("📊 Fetched and updated usage for \(goal.appName ?? bundleID): \(usage) minutes")
            }
        }
        
        // Post notification to update UI
        await MainActor.run {
            NotificationCenter.default.post(
                name: .screenTimeDataUpdated,
                object: nil
            )
    }
    
        print("✅ updateUsageFromReport: Completed")
    }
    
    /// Update usage data from all apps selection
    private func updateUsageFromAllAppsSelection(_ selection: FamilyActivitySelection) async {
        let realAppDiscovery = RealAppDiscoveryService.shared
        
        print("🔄 updateUsageFromAllAppsSelection: Processing \(selection.applicationTokens.count) apps and \(selection.categoryTokens.count) categories")
        
        // Handle category-based selection (preferred method)
        if !selection.categoryTokens.isEmpty {
            print("📱 Processing category-based selection with \(selection.categoryTokens.count) categories")
            
            // For categories, we set up a single monitoring activity that includes all categories
            // DeviceActivityReport will automatically handle all apps in those categories
            let categoryGoalName = "All Categories Tracking"
            let categoryBundleID = "com.se7en.allcategories"
            
            // Check if we already have a goal for category tracking
            let goals = coreDataManager.getActiveAppGoals()
            var categoryGoal = goals.first(where: { $0.appBundleID == categoryBundleID })
            
            // Create a goal for category-based tracking if it doesn't exist
            if categoryGoal == nil {
                categoryGoal = coreDataManager.createAppGoal(
                    appName: categoryGoalName,
                    bundleID: categoryBundleID,
                    dailyLimitMinutes: 0 // No limit, just tracking
                )
                print("📱 Created category tracking goal")
            }
            
            // Store the full selection (with categories) for this tracking goal
            if !hasSelection(for: categoryBundleID), let goal = categoryGoal {
                saveSelection(selection, forBundleID: categoryBundleID)
                appSelections[categoryBundleID] = selection
                print("💾 Stored category selection for tracking")
            }
            
            // Set up monitoring with the full selection (includes categories)
            if let goal = categoryGoal, let storedSelection = appSelections[categoryBundleID] {
                let trackingLimit = 1440 // 24 hours (won't block)
                
                // Update goal limit if needed
                if goal.dailyLimitMinutes == 0 {
                    coreDataManager.updateAppGoal(goal, dailyLimitMinutes: trackingLimit)
                }
                
                // Set up monitoring with frequent thresholds for category-based tracking
                setupMonitoringWithFrequentUpdates(for: goal, selection: storedSelection)
                print("📊 Set up category-based monitoring for \(selection.categoryTokens.count) categories")
                
                // CRITICAL: Also set up a global monitoring session for DeviceActivityReport
                setupGlobalMonitoringForReports(selection: storedSelection)
            }
            
            // Note: We can't extract individual apps from categories in DeviceActivityReport
            // The extension only provides total usage. Individual app breakdown requires applicationTokens
            // For now, we'll track total usage and show categories in the UI
            print("✅ Category-based selection processed - DeviceActivityReport will handle usage tracking")
            print("📊 Note: Individual app breakdown not available when only categories are selected")
            coreDataManager.save()
            return
        }
        
        // Handle individual app-based selection (fallback)
        print("📱 Processing individual app-based selection with \(selection.applicationTokens.count) apps")
        for token in selection.applicationTokens {
            // Get display name from token (this always works)
            let appName = realAppDiscovery.extractDisplayName(from: token)
            
            // Generate stable internal ID from app name (not from bundle ID)
            // This is what we'll use for storage and monitoring
            let stableID = "app.name.\(appName.lowercased().replacingOccurrences(of: " ", with: "."))"
        
            // Ensure we have a goal and usage record for this app
            let goals = coreDataManager.getActiveAppGoals()
            var goal = goals.first(where: { $0.appBundleID == stableID })
            
            // Create goal if it doesn't exist (for tracking all apps)
            if goal == nil {
                goal = coreDataManager.createAppGoal(
                    appName: appName,
                    bundleID: stableID, // Use stable ID, not extracted bundle ID
                    dailyLimitMinutes: 0 // No limit, just tracking
                )
                print("📱 Created tracking goal for: \(appName) (\(stableID))")
            }
            
            // Ensure we have a selection stored for this app (needed for fetching usage)
            if !hasSelection(for: stableID), let goal = goal {
                // Store the selection for this app
                // Create a selection with just this token
                var appSelection = FamilyActivitySelection()
                appSelection.applicationTokens = [token]
                saveSelection(appSelection, forBundleID: stableID)
                appSelections[stableID] = appSelection
            }
            
            // Ensure usage record exists
            if coreDataManager.getTodaysUsageRecord(for: stableID) == nil, let goal = goal {
                let today = Calendar.current.startOfDay(for: Date())
            _ = coreDataManager.createUsageRecord(
                for: goal,
                date: today,
                    actualUsageMinutes: 0,
                    didExceedLimit: false
                )
                coreDataManager.save()
                print("📊 Created usage record for: \(stableID)")
            }
            
            // Set up monitoring with a daily schedule (required for DeviceActivityReport)
            // Use frequent thresholds (every 1 minute) to get regular usage updates
            // This ensures we get usage data without blocking apps
            if let appSelection = appSelections[stableID], let goal = goal {
                // Always set up frequent monitoring for all apps in allAppsSelection
                // This ensures we get regular usage updates
                let trackingLimit = 1440 // 24 hours (won't block)
                
                // Update goal limit if it's 0 (tracking only)
                if goal.dailyLimitMinutes == 0 {
                    coreDataManager.updateAppGoal(goal, dailyLimitMinutes: trackingLimit)
                }
                
                // Set up monitoring with frequent thresholds
                setupMonitoringWithFrequentUpdates(for: goal, selection: appSelection)
                print("📊 Set up frequent monitoring for \(stableID) (10min update intervals)")
                
                // Also ensure global monitoring is set up for this selection
                if selection.applicationTokens.count + selection.categoryTokens.count > 0 {
                    setupGlobalMonitoringForReports(selection: selection)
                }
            }
            
            // Try to fetch usage from report if we have a selection
            if hasSelection(for: stableID), let goal = goal {
                let fetchedUsage = await fetchUsageFromReport(for: stableID)
                if fetchedUsage > 0 {
                    updateUsage(for: stableID, minutes: fetchedUsage)
                    print("📊 Fetched and updated usage for \(goal.appName ?? stableID): \(fetchedUsage) minutes")
                }
            }
        }
        
        coreDataManager.save()
    }
    
    /// Get total screen time today across all apps (from allAppsSelection) or monitored apps
    func getTotalScreenTimeToday() async -> (totalMinutes: Int, appsUsed: Int) {
        // First try to get from all apps selection (either apps OR categories)
        if let allApps = allAppsSelection, (!allApps.applicationTokens.isEmpty || !allApps.categoryTokens.isEmpty) {
            return await getAllAppsUsageToday(from: allApps)
        }
        
        // Fallback to monitored apps
        let goals = coreDataManager.getActiveAppGoals()
        var totalMinutes = 0
        var appsUsed = 0
        
        for goal in goals {
            guard let bundleID = goal.appBundleID,
                  hasSelection(for: bundleID) else {
                continue
            }
            
            let usage = getUsageMinutes(for: bundleID)
            // Count ALL apps being tracked (even if usage is 0)
            // This shows the user that monitoring is active
            totalMinutes += usage
            appsUsed += 1  // Count all apps, not just ones with usage
        }
        
        return (totalMinutes, appsUsed)
    }
    
    /// Get total screen time from all apps selection
    private func getAllAppsUsageToday(from selection: FamilyActivitySelection) async -> (totalMinutes: Int, appsUsed: Int) {
        var totalMinutes = 0
        var appsUsed = 0
        
        print("📊 Getting usage from selection with \(selection.applicationTokens.count) apps and \(selection.categoryTokens.count) categories")
        
        // If we have categories, use those (they include all apps in the categories)
        // Categories are better than individual apps as they auto-track all apps
        if !selection.categoryTokens.isEmpty {
            print("📱 Using category-based tracking - will count all apps used today")
            // For category-based selection, we'll get usage from DeviceActivityReport
            // which handles categories automatically
            return await getCategoryUsageToday(from: selection)
        }
        
        // Fall back to individual app tracking
        let realAppDiscovery = RealAppDiscoveryService.shared
        
        // First, ensure all apps have goals and records
        for token in selection.applicationTokens {
            // Get display name from token (this always works)
            let appName = realAppDiscovery.extractDisplayName(from: token)
            
            // Generate stable internal ID from app name (not from bundle ID)
            let stableID = "app.name.\(appName.lowercased().replacingOccurrences(of: " ", with: "."))"
            
            // Ensure goal exists
            let goals = coreDataManager.getActiveAppGoals()
            if goals.first(where: { $0.appBundleID == stableID }) == nil {
                _ = coreDataManager.createAppGoal(
            appName: appName,
                    bundleID: stableID, // Use stable ID, not extracted bundle ID
                    dailyLimitMinutes: 0
                )
            }
            
            // Ensure selection is stored
            if !hasSelection(for: stableID) {
                var appSelection = FamilyActivitySelection()
                appSelection.applicationTokens = [token]
                saveSelection(appSelection, forBundleID: stableID)
                appSelections[stableID] = appSelection
        }
    }
        coreDataManager.save()
        
        // Now get usage for each app
        for token in selection.applicationTokens {
            // Get display name and generate stable ID
            let appName = realAppDiscovery.extractDisplayName(from: token)
            let stableID = "app.name.\(appName.lowercased().replacingOccurrences(of: " ", with: "."))"
            
            // Get usage for this app (will create record if needed)
            let usage = getUsageMinutes(for: stableID)
            
            // ⚠️ CRITICAL FIX: Only count apps with usage > 0
            // Don't count apps that haven't been used yet today
            if usage > 0 {
                totalMinutes += usage
                appsUsed += 1  // Only count apps that have been used
            }
        }
        
        print("📊 getAllAppsUsageToday: \(totalMinutes) minutes across \(appsUsed) apps (out of \(selection.applicationTokens.count) total apps)")
        
        return (totalMinutes, appsUsed)
    }
    
    /// Get usage for category-based selections
    private func getCategoryUsageToday(from selection: FamilyActivitySelection) async -> (totalMinutes: Int, appsUsed: Int) {
        print("📊 Getting category-based usage for \(selection.categoryTokens.count) categories...")
        
        // Try to read from shared container first (from DeviceActivityReport extension)
        let appGroupID = "group.com.se7en.app"
        
        // Access UserDefaults on main thread to avoid CFPrefsPlistSource errors
        return await MainActor.run {
            guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
                print("❌ Failed to access shared container for category usage")
                // Fallback to estimate
                let estimatedApps = selection.categoryTokens.count * 15
                return (0, estimatedApps)
            }
            
            // CRITICAL FIX: Force synchronize for cross-process access
            sharedDefaults.synchronize()
            
            // Read total usage directly
            let totalUsage = sharedDefaults.integer(forKey: "total_usage")
            
            // Get apps count - use from shared container (already filtered to apps with usage > 0)
            let appsCount = sharedDefaults.integer(forKey: "apps_count")
            
            if totalUsage > 0 || appsCount > 0 {
                print("📊 Found category usage from extension: \(totalUsage) minutes, \(appsCount) apps (with usage)")
                return (totalUsage, appsCount)
            }
            
            // No usage data yet - return 0 for both
            print("📊 No category usage data yet from extension")
            return (0, 0)
        }
        
        // Fallback: estimate based on categories selected
        // Each category typically has 10-20 apps, so estimate conservatively
        let estimatedApps = selection.categoryTokens.count * 15
        print("📊 Category fallback: Estimated \(estimatedApps) apps from \(selection.categoryTokens.count) categories")
        print("📊 Note: DeviceActivityReport will provide real usage data when available")
        
        // Return estimated count with 0 usage (will be updated by DeviceActivityReport)
        return (0, estimatedApps)
    }
    
    /// Get total screen time today (synchronous)
    /// Uses the EXACT same logic as DashboardView: reads from shared container "total_usage" key first
    /// This matches how the dashboard gets its screen time data
    func getTotalScreenTimeTodaySync() -> Int {
        let appGroupID = "group.com.se7en.app"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ getTotalScreenTimeTodaySync: Failed to access shared container")
            return 0
        }
        
        // CRITICAL FIX: Force synchronize to read fresh data from disk
        // The DeviceActivityReport extension writes to disk from a separate process
        sharedDefaults.synchronize()
        
        // EXACT SAME LOGIC AS DASHBOARD: Read from "total_usage" key first
        let totalUsage = sharedDefaults.integer(forKey: "total_usage")
        
        if totalUsage > 0 {
            print("📊 getTotalScreenTimeTodaySync: Using shared container total_usage: \(totalUsage) minutes")
            return totalUsage
        }
        
        // Fallback: Sum up usage from monitored apps (same as async version fallback)
        let goals = coreDataManager.getActiveAppGoals()
        var totalMinutes = 0
        
        for goal in goals {
            guard let bundleID = goal.appBundleID,
                  hasSelection(for: bundleID) else {
                continue
            }
            
            let usage = getUsageMinutes(for: bundleID)
            totalMinutes += usage
        }
        
        print("📊 getTotalScreenTimeTodaySync: Fallback - summed from monitored apps: \(totalMinutes) minutes")
        return totalMinutes
    }
    
    /// Get the app with the most usage today (from allAppsSelection or monitored apps)
    func getTopAppToday() async -> (name: String, bundleID: String, minutes: Int)? {
        // First try to get from all apps selection (either apps OR categories)
        if let allApps = allAppsSelection, (!allApps.applicationTokens.isEmpty || !allApps.categoryTokens.isEmpty) {
            return await getTopAppFromAllApps(from: allApps)
        }
        
        // Fallback to monitored apps
        let goals = coreDataManager.getActiveAppGoals()
        var topApp: (name: String, bundleID: String, minutes: Int)?
        var maxUsage = 0
        
        for goal in goals {
            guard let appName = goal.appName,
                  let bundleID = goal.appBundleID,
                  hasSelection(for: bundleID) else {
                continue
            }
            
            let usage = getUsageMinutes(for: bundleID)
            if usage > maxUsage {
                maxUsage = usage
                topApp = (name: appName, bundleID: bundleID, minutes: usage)
            }
        }
        
        return topApp
    }
    
    /// Get top app from all apps selection
    private func getTopAppFromAllApps(from selection: FamilyActivitySelection) async -> (name: String, bundleID: String, minutes: Int)? {
        var topApp: (name: String, bundleID: String, minutes: Int)?
        var maxUsage = 0
        
        let realAppDiscovery = RealAppDiscoveryService.shared
        
        for token in selection.applicationTokens {
            // Get display name from token (this always works)
            let appName = realAppDiscovery.extractDisplayName(from: token)
            
            // Generate stable internal ID from app name (not from bundle ID)
            let stableID = "app.name.\(appName.lowercased().replacingOccurrences(of: " ", with: "."))"
            
            // Get usage for this app
            let usage = getUsageMinutes(for: stableID)
            if usage > maxUsage {
                maxUsage = usage
                topApp = (name: appName, bundleID: stableID, minutes: usage)
        }
    }
    
        return topApp
    }
    
    func updateUsage(for bundleID: String, minutes: Int) {
        let goals = coreDataManager.getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        if let existing = coreDataManager.getTodaysUsageRecord(for: bundleID) {
            existing.actualUsageMinutes = Int32(minutes)
            existing.didExceedLimit = minutes >= Int(goal.dailyLimitMinutes)
        } else {
            _ = coreDataManager.createUsageRecord(
                for: goal,
                date: today,
                actualUsageMinutes: minutes,
                didExceedLimit: minutes >= Int(goal.dailyLimitMinutes)
            )
        }
        
        coreDataManager.save()
    }
    
    // MARK: - Persistence
    
    private let selectionsKey = "se7en.appSelections"
    private let allAppsSelectionKey = "se7en.allAppsSelection"
    
    func saveAllAppsSelection(_ selection: FamilyActivitySelection) {
        do {
            let data = try PropertyListEncoder().encode(selection)
            UserDefaults.standard.set(data, forKey: allAppsSelectionKey)
            // Force UserDefaults to sync immediately for critical onboarding data
            UserDefaults.standard.synchronize()
            print("💾 Saved all apps selection with \(selection.applicationTokens.count) apps and \(selection.categoryTokens.count) categories to UserDefaults")
            
            // Verify the save by immediately reading it back
            if let verification = loadAllAppsSelection() {
                print("✅ Verification: Successfully saved and loaded \(verification.applicationTokens.count) apps and \(verification.categoryTokens.count) categories")
            } else {
                print("❌ ERROR: Failed to verify save - could not load back the selection!")
            }
        } catch {
            print("❌ Failed to save all apps selection: \(error)")
        }
    }
    
    func loadAllAppsSelection() -> FamilyActivitySelection? {
        guard let data = UserDefaults.standard.data(forKey: allAppsSelectionKey) else {
            return nil
        }
        
        do {
            let selection = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
            print("📂 Loaded all apps selection with \(selection.applicationTokens.count) apps")
            return selection
        } catch {
            print("❌ Failed to load all apps selection: \(error)")
            return nil
        }
    }
    
    private func saveSelection(_ selection: FamilyActivitySelection, forBundleID bundleID: String) {
        // Save to UserDefaults (selection can be encoded)
        do {
            let data = try PropertyListEncoder().encode(selection)
            var allSelections = UserDefaults.standard.dictionary(forKey: selectionsKey) as? [String: Data] ?? [:]
            allSelections[bundleID] = data
            UserDefaults.standard.set(allSelections, forKey: selectionsKey)
            print("💾 Saved selection for: \(bundleID)")
        } catch {
            print("❌ Failed to save selection: \(error)")
            }
    }
    
    private func removeSelection(forBundleID bundleID: String) {
        var allSelections = UserDefaults.standard.dictionary(forKey: selectionsKey) as? [String: Data] ?? [:]
        allSelections.removeValue(forKey: bundleID)
        UserDefaults.standard.set(allSelections, forKey: selectionsKey)
    }
    
    private func loadSavedSelections() {
        guard let allSelections = UserDefaults.standard.dictionary(forKey: selectionsKey) as? [String: Data] else {
            return
        }
        
        for (bundleID, data) in allSelections {
            do {
                let selection = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
                appSelections[bundleID] = selection
                print("📂 Loaded selection for: \(bundleID)")
            } catch {
                print("❌ Failed to load selection for \(bundleID): \(error)")
            }
        }
        
        print("📂 Loaded \(appSelections.count) app selections")
    }
    
    // MARK: - Debug
    
    func debugPrintState() {
        print("\n" + String(repeating: "=", count: 50))
        print("🔍 SCREEN TIME SERVICE STATE")
        print(String(repeating: "=", count: 50))
        print("Authorization: \(isAuthorized ? "✅ Approved" : "❌ Not Approved")")
        print("Stored Selections: \(appSelections.count)")
        
        for (bundleID, selection) in appSelections {
            print("  • \(bundleID): \(selection.applicationTokens.count) tokens")
        }
        
        let goals = coreDataManager.getActiveAppGoals()
        print("\nApp Goals in Core Data: \(goals.count)")
        for goal in goals {
            let bundleID = goal.appBundleID ?? "nil"
            let hasSelection = hasSelection(for: bundleID)
            print("  • \(goal.appName ?? "Unknown")")
            print("    Bundle: \(bundleID)")
            print("    Connected: \(hasSelection ? "✅" : "❌")")
            print("    Limit: \(goal.dailyLimitMinutes) min")
        }
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    // MARK: - Handle Limit Events
    
    func handleWarning(for bundleID: String) {
        // Ensure Core Data access happens on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let goals = self.coreDataManager.getActiveAppGoals()
            guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else { return }
        
            let appName = goal.appName ?? "App"
            let limitMinutes = Int(goal.dailyLimitMinutes)
            let remainingMinutes = Int(Double(limitMinutes) * 0.2)
            
            NotificationService.shared.sendLimitWarningNotification(
                appName: appName,
                timeRemaining: remainingMinutes
            )
        
            // Update usage to 80% of limit
            self.updateUsage(for: bundleID, minutes: Int(Double(limitMinutes) * 0.8))
        
            // Also update via report service for consistency
            DeviceActivityReportService.shared.updateUsageRecord(
                bundleID: bundleID,
                minutes: Int(Double(limitMinutes) * 0.8)
            )
            
            print("⚠️ Warning sent for \(appName)")
        }
    }
    
    func handleLimitReached(for bundleID: String) {
        // Ensure Core Data access happens on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let goals = self.coreDataManager.getActiveAppGoals()
            guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else { return }
            
            let appName = goal.appName ?? "App"
            let limitMinutes = Int(goal.dailyLimitMinutes)
            
            // ✅ NEW: Don't block immediately - show puzzle instead
            // Block the app temporarily to prevent usage while puzzle is shown
            self.blockApp(bundleID)
            
            // Update usage
            self.updateUsage(for: bundleID, minutes: limitMinutes)
            
            // Also update via report service for consistency
            DeviceActivityReportService.shared.updateUsageRecord(
                bundleID: bundleID,
                minutes: limitMinutes
            )
        
            // ✅ PERFORMANCE: Throttle puzzle notifications to prevent spam
            let now = Date()
            let lastPuzzleKey = "lastPuzzle_\(bundleID)"
            if let lastPuzzleTime = UserDefaults.standard.object(forKey: lastPuzzleKey) as? Date,
               now.timeIntervalSince(lastPuzzleTime) < 30.0 { // Don't show puzzle again within 30 seconds
                return
            }
            UserDefaults.standard.set(now, forKey: lastPuzzleKey)
        
            // Post notification for UI to show puzzle view
            NotificationCenter.default.post(
                name: .appBlocked,
                object: nil,
                userInfo: ["appName": appName, "bundleID": bundleID]
            )
        }
    }
    
    /// Grant temporary extension after puzzle completion
    /// ✅ FIXED VERSION: Properly unblocks apps using stored selections
    func grantTemporaryExtensionFixed(for bundleID: String, minutes: Int) {
        let appGroupID = "group.com.se7en.app"
        
        // Check global unlock mode
        let unlockMode: UnlockMode
        if let sharedDefaults = UserDefaults(suiteName: appGroupID),
           let modeString = sharedDefaults.string(forKey: "globalUnlockMode"),
           let mode = UnlockMode(rawValue: modeString) {
            unlockMode = mode
        } else {
            unlockMode = .extraTime
        }
        
        print("\n" + String(repeating: "=", count: 60))
        print("🔓 GRANTING EXTENSION")
        print("   Token/ID: \(bundleID.prefix(12))...")
        print("   Mode: \(unlockMode.rawValue)")
        print("   Minutes: \(minutes)")
        print(String(repeating: "=", count: 60))
        
        // ✅ CRITICAL FIX: Use multiple strategies to ensure unblock works
        var unblocked = false
        
        // Strategy 1: Direct lookup in appSelections
        if let selection = appSelections[bundleID] {
            unblockUsingSelection(selection)
            unblocked = true
            print("✅ Unblocked via appSelections lookup")
        }
        
        // Strategy 2: Find in stored limits by token hash or UUID
        if !unblocked {
            let limits = LimitStorageManager.shared.loadLimits()
            for limit in limits {
                if let selection = limit.getSelection() {
                    if let firstToken = selection.applicationTokens.first {
                        let computedHash = String(firstToken.hashValue)
                        if computedHash == bundleID || limit.id.uuidString == bundleID {
                            unblockUsingSelection(selection)
                            unblocked = true
                            print("✅ Unblocked via stored limits lookup")
                            break
                        }
                    }
                }
            }
        }
        
        // Strategy 3: Search in allAppsSelection
        if !unblocked, let allApps = allAppsSelection {
            for token in allApps.applicationTokens {
                if String(token.hashValue) == bundleID {
                    var blockedAppsSet = settingsStore.shield.applications ?? Set()
                    blockedAppsSet.remove(token)
                    settingsStore.shield.applications = blockedAppsSet.isEmpty ? nil : blockedAppsSet
                    unblocked = true
                    print("✅ Unblocked via allAppsSelection")
                    break
                }
            }
        }
        
        // Strategy 4: Nuclear option - clear all shields and rebuild
        if !unblocked {
            print("⚠️ Using nuclear unblock - clearing and rebuilding shields")
            clearShieldAndRebuildWithoutApp(tokenHash: bundleID)
            unblocked = true
        }
        
        // Remove from blocked tracking
        blockedApps.remove(bundleID)
        
        // Update shared container based on unlock mode
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            if unlockMode == .extraTime {
                // Extra Time Mode: Grant time extension (keep current usage, add to limit)
        let extensionEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
                
                // Get current usage before granting extension
                let currentUsage = getUsageMinutes(for: bundleID)
                
                // Get base limit for logging
                let goals = coreDataManager.getActiveAppGoals()
                let baseLimit = goals.first(where: { $0.appBundleID == bundleID })?.dailyLimitMinutes ?? 0
                
                sharedDefaults.set(extensionEndTime.timeIntervalSince1970, forKey: "extension_end_\(bundleID)")
                sharedDefaults.set(true, forKey: "hasActiveExtension_\(bundleID)")
                sharedDefaults.set(minutes, forKey: "extensionLimit_\(bundleID)")
                sharedDefaults.set(false, forKey: "limitReached_\(bundleID)")
                // Store current usage (don't reset to 0)
                sharedDefaults.set(currentUsage, forKey: "usage_at_extension_\(bundleID)")
                
        UserDefaults.standard.set(extensionEndTime, forKey: "extension_end_\(bundleID)")
        
                // Update CoreData: keep current usage, add extension minutes
                if let _ = goals.first(where: { $0.appBundleID == bundleID }) {
                    if let record = coreDataManager.getTodaysUsageRecord(for: bundleID) {
                        // Keep current usage, just add extension minutes
                        record.extendedLimitMinutes = Int32(minutes)
                        record.didExceedLimit = false
                        coreDataManager.save()
                    } else {
                        // Get goal again for createUsageRecord
                        if let goal = goals.first(where: { $0.appBundleID == bundleID }) {
                            let today = Calendar.current.startOfDay(for: Date())
                            let newRecord = coreDataManager.createUsageRecord(
                                for: goal,
                                date: today,
                                actualUsageMinutes: currentUsage,
                                didExceedLimit: false
                            )
                            newRecord.extendedLimitMinutes = Int32(minutes)
                            coreDataManager.save()
                        }
                    }
                }
                
                print("✅ Granted \(minutes) minute extension (Extra Time Mode) - Usage: \(currentUsage), New Limit: \(Int(baseLimit) + minutes)")
            } else {
                // One-Session Mode: Mark as active session
                sharedDefaults.set(true, forKey: "oneSessionActive_\(bundleID)")
                sharedDefaults.set(Date().timeIntervalSince1970, forKey: "oneSessionStartTime_\(bundleID)")
                sharedDefaults.set(false, forKey: "hasActiveExtension_\(bundleID)")
                sharedDefaults.set(false, forKey: "limitReached_\(bundleID)")
                
                print("✅ Unlocked for one session (One-Session Mode)")
            }
            
            // Clear ALL puzzle flags
            sharedDefaults.removeObject(forKey: "needsPuzzle_\(bundleID)")
            sharedDefaults.removeObject(forKey: "puzzleRequested_\(bundleID)")
            sharedDefaults.removeObject(forKey: "puzzleRequestTime_\(bundleID)")
            sharedDefaults.synchronize()
        }
        
        // Notify UI
        NotificationCenter.default.post(name: .screenTimeDataUpdated, object: nil)
        print("✅ Extension grant complete\n")
    }
    
    /// Check for One-Session Mode apps and re-block them when app goes to background
    func checkAndReBlockOneSessionApps() {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // Get all keys that start with "oneSessionActive_"
        let allKeys = Array(sharedDefaults.dictionaryRepresentation().keys)
        for key in allKeys where key.hasPrefix("oneSessionActive_") {
            if sharedDefaults.bool(forKey: key) {
                let tokenHash = String(key.dropFirst("oneSessionActive_".count))
                
                // Check if unlock mode is still One-Session (user might have changed it)
                let unlockMode: UnlockMode
                if let modeString = sharedDefaults.string(forKey: "globalUnlockMode"),
                   let mode = UnlockMode(rawValue: modeString) {
                    unlockMode = mode
                } else {
                    unlockMode = .extraTime
                }
                
                // Only re-block if still in One-Session Mode
                if unlockMode == .oneSession {
                    // Re-block the app
                    blockApp(tokenHash)
                    
                    // Clear one-session flag
                    sharedDefaults.set(false, forKey: key)
                    sharedDefaults.removeObject(forKey: "oneSessionStartTime_\(tokenHash)")
                    sharedDefaults.synchronize()
                    
                    print("🔒 Re-blocked app \(tokenHash.prefix(8))... (One-Session Mode - user left app)")
                }
            }
        }
    }
    
    /// Check if app has active extension
    func hasActiveExtension(for bundleID: String) -> Bool {
        let appGroupID = "group.com.se7en.app"
        
        // Check in UserDefaults first
        if let extensionEndTime = UserDefaults.standard.object(forKey: "extension_end_\(bundleID)") as? Date {
            // ✅ Check if extension was granted today (not yesterday)
            let today = Calendar.current.startOfDay(for: Date())
            let extensionDate = Calendar.current.startOfDay(for: extensionEndTime)
            if extensionDate < today {
                // Extension was from a previous day, clear it
                UserDefaults.standard.removeObject(forKey: "extension_end_\(bundleID)")
                if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
                    sharedDefaults.removeObject(forKey: "extension_end_\(bundleID)")
                    sharedDefaults.removeObject(forKey: "hasActiveExtension_\(bundleID)")
                    sharedDefaults.removeObject(forKey: "extensionLimit_\(bundleID)")
                    sharedDefaults.synchronize()
                }
            return false
        }
            
            if Date() < extensionEndTime {
                return true
            }
        }
        
        // Also check shared container
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            let timestamp = sharedDefaults.double(forKey: "extension_end_\(bundleID)")
            if timestamp > 0 {
                let extensionEndTime = Date(timeIntervalSince1970: timestamp)
                
                // ✅ Check if extension was granted today (not yesterday)
                let today = Calendar.current.startOfDay(for: Date())
                let extensionDate = Calendar.current.startOfDay(for: extensionEndTime)
                if extensionDate < today {
                    // Extension was from a previous day, clear it
                    sharedDefaults.removeObject(forKey: "extension_end_\(bundleID)")
                    sharedDefaults.removeObject(forKey: "hasActiveExtension_\(bundleID)")
                    sharedDefaults.removeObject(forKey: "extensionLimit_\(bundleID)")
                    sharedDefaults.synchronize()
                    return false
                }
                
                if Date() < extensionEndTime {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Get the effective limit for an app (accounts for extension mode)
    func getEffectiveDailyLimit(for bundleID: String) -> Int {
        let appGroupID = "group.com.se7en.app"
        
        // Get base limit from CoreData
        let goals = coreDataManager.getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else {
            return 0
        }
        let baseLimit = Int(goal.dailyLimitMinutes)
        
        // ✅ Check if there's an active extension - ADD extension minutes to base limit
        if hasActiveExtension(for: bundleID) {
            if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
                let extensionMinutes = sharedDefaults.integer(forKey: "extensionLimit_\(bundleID)")
                if extensionMinutes > 0 {
                    return baseLimit + extensionMinutes
                }
            }
            return baseLimit + 15 // Default extension is 15 minutes
        }
        
        // Otherwise use the normal daily limit
        return baseLimit
    }
    
    /// Get usage minutes that accounts for extension reset
    func getEffectiveUsageMinutes(for bundleID: String) -> Int {
        let appGroupID = "group.com.se7en.app"
        
        // ✅ If there's an active extension, use current usage (not reset)
        if hasActiveExtension(for: bundleID) {
            // Use normal usage tracking (keep current usage, don't reset)
            return getUsageMinutes(for: bundleID)
        }
        
        // Otherwise use normal usage tracking
        return getUsageMinutes(for: bundleID)
    }
    
    /// Check if app is in one-session mode
    func isOneSessionActive(for bundleID: String) -> Bool {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return false }
        return sharedDefaults.bool(forKey: "oneSessionActive_\(bundleID)")
    }
    
    /// Get effective limit (base limit + puzzle extensions)
    func getEffectiveLimit(for bundleID: String) -> Int {
        let goals = coreDataManager.getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else {
            return 0
        }
        
        let baseLimit = Int(goal.dailyLimitMinutes)
        let puzzleManager = PuzzleManager.shared
        let extensionMinutes = puzzleManager.getTotalExtensionMinutes(for: bundleID)
        
        return baseLimit + extensionMinutes
    }
    
    func handleUsageUpdate(for bundleID: String) {
        // Handle frequent update events (every 1 minute)
        // The threshold that was reached is 1 minute, so update usage to that
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let goals = self.coreDataManager.getActiveAppGoals()
            guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else { return }
            
            // The update threshold is 1 minute
            // This means the app has been used for at least 1 minute since last update
            // Update usage to reflect this
            let updateThreshold = 1 // minutes
            let currentUsage = self.getUsageMinutes(for: bundleID)
            
            // If this is the first update, set to threshold amount
            // Otherwise, increment by threshold (since event fires every 1 min)
            let finalUsage = currentUsage == 0 ? updateThreshold : currentUsage + updateThreshold
            
            // Update usage record
            self.updateUsage(for: bundleID, minutes: finalUsage)
            
            // Also update via report service for consistency
            DeviceActivityReportService.shared.updateUsageRecord(
                bundleID: bundleID,
                minutes: finalUsage
            )
            
            print("🔄 Updated usage for \(goal.appName ?? bundleID): \(finalUsage) minutes")
            
            // Post notification to update UI
            NotificationCenter.default.post(
                name: .screenTimeDataUpdated,
                object: nil
            )
        }
    }
    
    // MARK: - Additional Methods (for compatibility)
    
    /// Check and update app blocking status
    /// ✅ PERFORMANCE: Throttled to prevent excessive checks
    private var lastBlockingCheck: Date = Date.distantPast
    private let blockingCheckInterval: TimeInterval = 15.0 // Only check every 15 seconds
    
    func checkAndUpdateAppBlocking() {
        let now = Date()
        guard now.timeIntervalSince(lastBlockingCheck) >= blockingCheckInterval else {
            return // Too soon, skip check
        }
        lastBlockingCheck = now
        
        // Re-check all apps for blocking status
        let goals = coreDataManager.getActiveAppGoals()
        for goal in goals {
            guard let bundleID = goal.appBundleID else { continue }
            
            // ✅ CRITICAL: Skip if app has active extension (puzzle was completed)
            if hasActiveExtension(for: bundleID) {
                continue // Don't re-block apps with active extensions
            }
            
            let usage = getUsageMinutes(for: bundleID)
            let effectiveLimit = getEffectiveLimit(for: bundleID) // Accounts for extensions
            
            // Only block if usage exceeds effective limit AND no active extension
            if usage >= effectiveLimit {
                blockApp(bundleID)
            } else if usage < effectiveLimit && blockedApps.contains(bundleID) {
                // Usage is now below limit, unblock if it was previously blocked
                unblockApp(bundleID)
            }
        }
    }
    
    /// Get today's usage record for an app
    func getAppUsageToday(for bundleID: String) -> AppUsageRecord? {
        return coreDataManager.getTodaysUsageRecord(for: bundleID)
    }
    
    /// Perform weekly reset
    func performWeeklyReset() {
        // Unblock all apps
        unblockAllApps()
        
        // Complete current weekly plan
        if let currentPlan = coreDataManager.getCurrentWeeklyPlan() {
            currentPlan.isCompleted = true
            currentPlan.paymentAmount = Double(7 - Int(currentPlan.creditsRemaining))
        }
        
        // Create new weekly plan
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? Date()
        _ = coreDataManager.createWeeklyPlan(startDate: startOfWeek, endDate: endOfWeek)
        
        coreDataManager.save()
        print("📅 Weekly reset completed")
    }
        
    /// Refresh all app usage data
    func refreshAllAppUsage() async {
        let goals = coreDataManager.getActiveAppGoals()
        
        for goal in goals {
            guard let bundleID = goal.appBundleID else { continue }
            
            // Usage is tracked by DeviceActivityMonitor
            // This method is mainly for triggering UI updates
            let usage = getUsageMinutes(for: bundleID)
            
            // Check if limit exceeded (accounting for puzzle extensions)
            let effectiveLimit = getEffectiveLimit(for: bundleID)
            if usage >= effectiveLimit {
                // Only block if extension has expired
                if !hasActiveExtension(for: bundleID) {
                    handleLimitReached(for: bundleID)
                }
            }
        }
        
        // Notify UI to refresh
        await MainActor.run {
            NotificationCenter.default.post(name: .screenTimeDataUpdated, object: nil)
        }
    }
    
    
    /// Set up global monitoring specifically for DeviceActivityReport extensions
    /// This ensures the report extensions receive data even without individual app limits
    private func setupGlobalMonitoringForReports(selection: FamilyActivitySelection) {
        let globalActivityName = DeviceActivityName("se7en.global.reports")
        
        // ✅ CRITICAL: Merge category selection with individual app limit tokens
        // This ensures report extension sees BOTH category apps AND individual limit apps
        var combinedSelection = selection
        
        // Add tokens from all stored limits (individual app limits)
        let storedLimits = LimitStorageManager.shared.loadLimits()
        for limit in storedLimits where limit.isActive {
            if let limitSelection = limit.getSelection() {
                // Add individual app tokens to combined selection
                for token in limitSelection.applicationTokens {
                    combinedSelection.applicationTokens.insert(token)
                }
            }
        }
        
        // Also add tokens from in-memory appSelections
        for (_, appSelection) in appSelections {
            for token in appSelection.applicationTokens {
                combinedSelection.applicationTokens.insert(token)
            }
        }
        
        print("🌍 Setting up global monitoring for DeviceActivityReport extensions")
        print("   Activity Name: \(globalActivityName)")
        print("   Apps (combined): \(combinedSelection.applicationTokens.count)")
        print("   Categories: \(combinedSelection.categoryTokens.count)")
        
        // Create 24-hour schedule
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        // ⚠️ CRITICAL FIX: Use 1-minute threshold instead of 1440!
        // This ensures reports get updated frequently
        let reportingEvent = DeviceActivityEvent(
            applications: combinedSelection.applicationTokens,
            categories: combinedSelection.categoryTokens,
            threshold: DateComponents(minute: 1) // ✅ Changed from 1440 to 1
        )
        
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            DeviceActivityEvent.Name("global.reporting"): reportingEvent
        ]
        
        do {
            try deviceActivityCenter.startMonitoring(globalActivityName, during: schedule, events: events)
            print("✅ Started global monitoring for DeviceActivityReport extensions")
            print("   This enables the report extensions to receive usage data")
            print("   Individual app limits will now be tracked!")
        } catch {
            print("❌ Failed to start global monitoring: \(error)")
            print("   DeviceActivityReport extensions may not receive data!")
        }
    }
    
    // MARK: - App Lifecycle Monitoring Refresh
    
    /// Refresh all monitoring setups when app opens
    /// This ensures monitoring is active and usage data can be tracked
    // 🚀 OPTIMIZED: Much lighter monitoring refresh with throttling
    private var lastMonitoringRefresh: Date = Date.distantPast
    private let monitoringRefreshInterval: TimeInterval = 60.0 // Only refresh every minute
    
    func refreshAllMonitoring() {
        guard isAuthorized else { return }
        
        // 🚀 THROTTLE: Prevent excessive monitoring refresh
        let now = Date()
        guard now.timeIntervalSince(lastMonitoringRefresh) >= monitoringRefreshInterval else {
            print("⚡ Monitoring refresh throttled")
            return
        }
        lastMonitoringRefresh = now
        
        // 🚀 BACKGROUND: Move heavy operations to background
        Task.detached(priority: .utility) {
            await self.performLightweightMonitoringRefresh()
        }
    }
    
    private func performLightweightMonitoringRefresh() async {
        // ✅ Essential operations only
        saveAllMonitoredSelectionsToSharedContainer()
        processPendingMonitorEvents()
        
        // 🚀 CONDITIONAL: Only update if allAppsSelection exists
        if let allApps = allAppsSelection, (!allApps.applicationTokens.isEmpty || !allApps.categoryTokens.isEmpty) {
                await updateUsageFromAllAppsSelection(allApps)
                
            // Single UI notification
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .screenTimeDataUpdated,
                        object: nil
                    )
            }
        }
        
        print("✅ Lightweight monitoring refresh completed")
    }
    
    // MARK: - Monitor Extension Event Processing
    
    /// Process pending events from the Monitor Extension (via shared container)
    private func processPendingMonitorEvents() {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID),
              let events = sharedDefaults.array(forKey: "pendingEvents") as? [[String: String]],
              !events.isEmpty else {
            return
        }
        
        print("📥 Processing \(events.count) pending events from Monitor Extension")
        
        // Process all events
        for event in events {
            guard let type = event["type"],
                  let bundleID = event["bundleID"] else {
                continue
            }
            
            switch type {
            case "update":
                // Update usage by 1 minute (the threshold interval)
                let currentUsage = getUsageMinutes(for: bundleID)
                let newUsage = currentUsage + 1
                updateUsage(for: bundleID, minutes: newUsage)
                print("📊 Processed update event: \(bundleID) = \(newUsage) minutes")
                
            case "warning":
                handleWarning(for: bundleID)
                print("⚠️ Processed warning event: \(bundleID)")
                
            case "limit":
                handleLimitReached(for: bundleID)
                print("🚫 Processed limit event: \(bundleID)")
                
            default:
                print("⚠️ Unknown event type: \(type)")
            }
        }
        
        // Clear processed events
        sharedDefaults.set([], forKey: "pendingEvents")
        print("✅ Processed all pending events")
        
        // Also read usage data directly from shared container
        // Read total_usage and apps_count directly
        if let totalUsage = sharedDefaults.object(forKey: "total_usage") as? Int, totalUsage > 0 {
            print("📊 Found total usage in shared container: \(totalUsage) minutes")
        }
        
        if let appsCount = sharedDefaults.object(forKey: "apps_count") as? Int, appsCount > 0 {
            print("📊 Found apps count in shared container: \(appsCount) apps")
        }
    }
    
    // MARK: - Monitoring Verification
    
    /// Add this method after refreshAllMonitoring()
    func verifyMonitoringSetup() {
        print("\n" + String(repeating: "=", count: 60))
        print("🔍 MONITORING VERIFICATION")
        print(String(repeating: "=", count: 60))
        
        print("📱 Authorization Status: \(isAuthorized ? "✅ Authorized" : "❌ Not Authorized")")
        print("📱 Auth Status Detail: \(authorizationStatus)")
        
        if let allApps = allAppsSelection {
            print("\n📦 All Apps Selection:")
            print("   • Application tokens: \(allApps.applicationTokens.count)")
            print("   • Category tokens: \(allApps.categoryTokens.count)")
            print("   • Total items: \(allApps.applicationTokens.count + allApps.categoryTokens.count)")
        } else {
            print("\n❌ No allAppsSelection found!")
        }
        
        let goals = coreDataManager.getActiveAppGoals()
        print("\n🎯 Active Goals: \(goals.count)")
        for goal in goals {
            let bundleID = goal.appBundleID ?? "unknown"
            let hasSelection = hasSelection(for: bundleID)
            print("   • \(goal.appName ?? "Unknown"): \(hasSelection ? "✅" : "❌") connected")
        }
        
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    // MARK: - ✅ NEW: Unblock Helper Methods
    
    /// Unblock using a FamilyActivitySelection directly
    private func unblockUsingSelection(_ selection: FamilyActivitySelection) {
        var blockedApps = settingsStore.shield.applications ?? Set()
        
        for token in selection.applicationTokens {
            blockedApps.remove(token)
        }
        
        settingsStore.shield.applications = blockedApps.isEmpty ? nil : blockedApps
        print("🔓 Removed \(selection.applicationTokens.count) tokens from shield")
    }
    
    /// Nuclear option: Clear all shields and rebuild without specific app
    private func clearShieldAndRebuildWithoutApp(tokenHash: String) {
        // Clear everything first
        settingsStore.shield.applications = nil
        settingsStore.shield.applicationCategories = nil
        
        // Rebuild block list excluding the unblocked app
        var newBlocked: Set<ApplicationToken> = []
        let limits = LimitStorageManager.shared.loadLimits()
        let appGroupID = "group.com.se7en.app"
        
        for limit in limits where limit.isActive {
            guard let selection = limit.getSelection(),
                  let defaults = UserDefaults(suiteName: appGroupID) else { continue }
            
            // Skip the app we're unblocking
            if let firstToken = selection.applicationTokens.first {
                let thisHash = String(firstToken.hashValue)
                if thisHash == tokenHash || limit.id.uuidString == tokenHash {
                    continue
                }
            }
            
            // Only re-block if limit was reached and no active extension
            let limitReached = defaults.bool(forKey: "limit_reached_\(limit.id.uuidString)")
            if limitReached {
                if let firstToken = selection.applicationTokens.first {
                    let hash = String(firstToken.hashValue)
                    if !hasActiveExtension(for: hash) {
                        for token in selection.applicationTokens {
                            newBlocked.insert(token)
                        }
                    }
                }
            }
        }
        
        settingsStore.shield.applications = newBlocked.isEmpty ? nil : newBlocked
        print("🔄 Rebuilt shield with \(newBlocked.count) apps")
    }
    
    // MARK: - ✅ NEW: Improved One-Session Mode
    
    /// Improved re-blocking that uses stored selections
    func checkAndReBlockOneSessionAppsImproved() {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        let modeString = sharedDefaults.string(forKey: "globalUnlockMode") ?? "Extra Time"
        guard modeString == "One Session" else { return }
        
        print("🔍 Checking for One-Session apps to re-block...")
        
        let allKeys = Array(sharedDefaults.dictionaryRepresentation().keys)
        for key in allKeys where key.hasPrefix("oneSessionActive_") {
            if sharedDefaults.bool(forKey: key) {
                let tokenHash = String(key.dropFirst("oneSessionActive_".count))
                
                print("🔒 Re-blocking \(tokenHash.prefix(8))... (One-Session expired)")
                
                // Find selection and block
                var blocked = false
                
                if let selection = appSelections[tokenHash] {
                    blockWithSelection(selection)
                    blocked = true
                }
                
                if !blocked {
                    let limits = LimitStorageManager.shared.loadLimits()
                    for limit in limits {
                        if let selection = limit.getSelection(),
                           let firstToken = selection.applicationTokens.first {
                            let computedHash = String(firstToken.hashValue)
                            if computedHash == tokenHash || limit.id.uuidString == tokenHash {
                                blockWithSelection(selection)
                                blocked = true
                                break
                            }
                        }
                    }
                }
                
                // Clear flags and mark as blocked
                sharedDefaults.set(false, forKey: key)
                sharedDefaults.removeObject(forKey: "oneSessionStartTime_\(tokenHash)")
                sharedDefaults.set(true, forKey: "limitReached_\(tokenHash)")
                sharedDefaults.synchronize()
            }
        }
    }
    
    /// Setup monitoring for stale one-session apps
    func setupOneSessionMonitoring() {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        let modeString = sharedDefaults.string(forKey: "globalUnlockMode") ?? "Extra Time"
        guard modeString == "One Session" else { return }
        
        let allKeys = Array(sharedDefaults.dictionaryRepresentation().keys)
        for key in allKeys where key.hasPrefix("oneSessionStartTime_") {
            let startTime = sharedDefaults.double(forKey: key)
            if startTime > 0 {
                let elapsed = Date().timeIntervalSince1970 - startTime
                
                // If session started >5 min ago, check for stale session
                if elapsed > 300 {
                    let tokenHash = String(key.dropFirst("oneSessionStartTime_".count))
                    let lastUpdate = sharedDefaults.double(forKey: "usage_last_update_\(tokenHash)")
                    let timeSinceUpdate = Date().timeIntervalSince1970 - lastUpdate
                    
                    // No update in 2+ min means user left
                    if timeSinceUpdate > 120 {
                        print("🔒 Stale one-session for \(tokenHash.prefix(8))... - re-blocking")
                        sharedDefaults.set(true, forKey: "oneSessionActive_\(tokenHash)")
                        checkAndReBlockOneSessionAppsImproved()
                    }
                }
            }
        }
    }
    
    // MARK: - ✅ NEW: Force Shield Check
    
    /// Force check all limits and apply shields (call on app foreground)
    func forceCheckAndApplyShields() {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        
        print("🔍 Force checking all limits...")
        
        let limits = LimitStorageManager.shared.loadLimits()
        
        for limit in limits where limit.isActive {
            guard let selection = limit.getSelection(),
                  let firstToken = selection.applicationTokens.first else { continue }
            
            let tokenHash = String(firstToken.hashValue)
            
            // Skip if has active extension
            if hasActiveExtension(for: tokenHash) { continue }
            
            // Skip if has active one-session
            if sharedDefaults.bool(forKey: "oneSessionActive_\(tokenHash)") { continue }
            
            // Get usage and check against limit
            let usage = sharedDefaults.integer(forKey: "usage_\(tokenHash)")
            
            if usage >= limit.dailyLimitMinutes {
                print("🚫 Force blocking \(limit.appName) - usage (\(usage)) >= limit (\(limit.dailyLimitMinutes))")
                blockWithSelection(selection)
                
                sharedDefaults.set(true, forKey: "limitReached_\(tokenHash)")
                sharedDefaults.set(limit.appName, forKey: "limitAppName_\(tokenHash)")
                sharedDefaults.synchronize()
            }
        }
    }
    
}

