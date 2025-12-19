import SwiftUI
import CoreData
import UserNotifications

// MARK: - App Delegate for Notification Handling
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Called when notification is tapped (app opens from notification)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        let actionIdentifier = response.actionIdentifier
        
        print("📬 Notification tapped - Category: \(categoryIdentifier), Action: \(actionIdentifier)")
        
        // Handle puzzle unlock notification
        if categoryIdentifier == "PUZZLE_UNLOCK" {
            print("🧩 Puzzle notification tapped - triggering puzzle mode")
            
            // Post notification to trigger puzzle mode check
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationCenter.default.post(
                    name: UIApplication.didBecomeActiveNotification,
                    object: nil
                )
            }
        }
        
        completionHandler()
    }
    
    /// Called when notification arrives while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct SE7ENApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    let persistentContainer = CoreDataManager.shared.persistentContainer
    
    init() {
        // Setup notification categories
        NotificationService.shared.setupNotificationCategories()
        
        // Perform Core Data migration if needed
        CoreDataManager.shared.performMigrationIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .environment(\.textCase, .none)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Check for pending puzzle notification from shield
                    checkAndSendPendingPuzzleNotification()
                    
                    // Check for puzzle mode FIRST
                    appState.checkForPendingPuzzles()
                    
                    // Force check all limits and apply shields
                    ScreenTimeService.shared.forceCheckAndApplyShields()
                    
                    // Check one-session mode
                    ScreenTimeService.shared.setupOneSessionMonitoring()
                    
                    // Sync data
                    appState.syncDataFromBackground()
                    ScreenTimeService.shared.refreshAllMonitoring()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Re-block one-session apps
                    ScreenTimeService.shared.checkAndReBlockOneSessionApps()
                    ScreenTimeService.shared.checkAndReBlockOneSessionAppsImproved()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppDidBecomeActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    handleAppWillResignActive()
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    // MARK: - App Lifecycle Handlers
    
    private func handleAppWillEnterForeground() {
        print("📱 App entering foreground")
        
        // ✅ Check for pending puzzle notification from shield
        checkAndSendPendingPuzzleNotification()
        
        // ✅ CRITICAL: Check for puzzle mode FIRST
        appState.checkForPendingPuzzles()
        
        // ✅ CRITICAL: Force check all limits and apply shields
        // This ensures shields are active even if the monitor extension didn't trigger
        ScreenTimeService.shared.forceCheckAndApplyShields()
        
        // ✅ CRITICAL: Check one-session mode and setup monitoring
        ScreenTimeService.shared.setupOneSessionMonitoring()
        
        // Sync data from background
        appState.syncDataFromBackground()
        
        // Refresh Screen Time monitoring and data
        ScreenTimeService.shared.refreshAllMonitoring()
    }
    
    /// Check if shield action set a pending puzzle notification flag
    private func checkAndSendPendingPuzzleNotification() {
        let appGroupID = "group.com.se7en.app"
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // Check if there's a pending puzzle notification
        if defaults.bool(forKey: "pendingPuzzleNotification") {
            let appName = defaults.string(forKey: "pendingPuzzleAppName") ?? "App"
            
            // Clear the flag first
            defaults.removeObject(forKey: "pendingPuzzleNotification")
            defaults.removeObject(forKey: "pendingPuzzleAppName")
            defaults.synchronize()
            
            // Send local notification from main app (this works reliably)
            let content = UNMutableNotificationContent()
            content.title = "🧩 Puzzle Time!"
            content.body = "Solve a puzzle to unlock \(appName)"
            content.sound = .default
            content.categoryIdentifier = "PUZZLE_UNLOCK"
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            let request = UNNotificationRequest(
                identifier: "puzzle_unlock_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to send puzzle notification: \(error)")
                } else {
                    print("✅ Puzzle notification sent from main app")
                }
            }
        }
    }
    
    private func handleAppDidEnterBackground() {
        print("📱 App entering background")
        
        // ✅ CRITICAL: Check for One-Session Mode apps and re-block them
        ScreenTimeService.shared.checkAndReBlockOneSessionApps()
        ScreenTimeService.shared.checkAndReBlockOneSessionAppsImproved()
        
        // ✅ CRITICAL: Mark timestamp for one-session detection
        markBackgroundTimestamp()
    }
    
    private func handleAppDidBecomeActive() {
        print("📱 App became active")
        
        // Check time since last background - if long, check one-session apps
        checkAndHandleOneSessionAfterBackground()
    }
    
    private func handleAppWillResignActive() {
        print("📱 App will resign active")
        
        // Pre-emptively mark one-session apps
        markOneSessionAppsForReBlock()
    }
    
    // MARK: - One-Session Mode Helpers
    
    private func markBackgroundTimestamp() {
        let appGroupID = "group.com.se7en.app"
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        defaults.set(Date().timeIntervalSince1970, forKey: "app_background_timestamp")
        defaults.synchronize()
    }
    
    private func checkAndHandleOneSessionAfterBackground() {
        let appGroupID = "group.com.se7en.app"
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        let backgroundTimestamp = defaults.double(forKey: "app_background_timestamp")
        if backgroundTimestamp > 0 {
            let timeSinceBackground = Date().timeIntervalSince1970 - backgroundTimestamp
            
            // If we were in background for more than 30 seconds, check one-session apps
            if timeSinceBackground > 30 {
                print("📱 Was in background for \(Int(timeSinceBackground))s - checking one-session apps")
                ScreenTimeService.shared.checkAndReBlockOneSessionAppsImproved()
            }
        }
    }
    
    private func markOneSessionAppsForReBlock() {
        let appGroupID = "group.com.se7en.app"
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        // Check if in One-Session mode
        let modeString = defaults.string(forKey: "globalUnlockMode") ?? "Extra Time"
        guard modeString == "One Session" else { return }
        
        // Mark all active one-session apps for re-blocking
        let allKeys = Array(defaults.dictionaryRepresentation().keys)
        for key in allKeys where key.hasPrefix("oneSessionStartTime_") {
            let tokenHash = String(key.dropFirst("oneSessionStartTime_".count))
            
            // Set flag that this app should be re-blocked
            defaults.set(true, forKey: "shouldReBlock_\(tokenHash)")
        }
        defaults.synchronize()
    }
    
    // MARK: - URL Handling
    
    private func handleIncomingURL(_ url: URL) {
        print("📱 App opened with URL: \(url)")
        
        guard url.scheme == "se7en" else { return }
        
        // Handle puzzle mode
        if url.host == "puzzle" {
            print("🧩 URL: Puzzle mode requested")
            
            // Force check for puzzle mode immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appState.checkForPendingPuzzles()
            }
            
            // Also post notification
            NotificationCenter.default.post(
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }
        
        // Handle unlock confirmation
        if url.host == "unlocked" {
            print("🔓 URL: App unlocked")
            // The puzzle was completed and app should be unblocked
            // This is handled by the ContentView's puzzle completion flow
        }
    }
}


// MARK: - Notification Names

extension Notification.Name {
    static let showPuzzleMode = Notification.Name("showPuzzleMode")
}
