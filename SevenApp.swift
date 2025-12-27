import SwiftUI
import CoreData
import UserNotifications
import UIKit

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
            
            // ✅ Post custom notification to dismiss tap screen and show puzzle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationCenter.default.post(
                    name: .puzzleNotificationTapped,
                    object: nil
                )
            }
            
            // Also trigger the standard app active notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        // ✅ CRITICAL: Configure UIKit appearance FIRST, before any views are created
        // This must happen in init() to ensure it runs before SwiftUI renders
        Self.configureGlobalAppearance()
        
        // Setup notification categories
        NotificationService.shared.setupNotificationCategories()
        
        // Perform Core Data migration if needed
        CoreDataManager.shared.performMigrationIfNeeded()
        
        // Initialize BlockedAppsManager and apply blocking state
        _ = BlockedAppsManager.shared
    }
    
    /// Configure global UIKit appearance settings
    /// Called in init() to ensure it runs before any SwiftUI views are created
    private static func configureGlobalAppearance() {
        // Tab Bar appearance - this is the main culprit for uppercase text
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        
        // Configure tab bar item appearance to NOT transform text
        let itemAppearance = UITabBarItemAppearance()
        
        // Normal state
        itemAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        // Selected state
        itemAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        tabBarAppearance.stackedLayoutAppearance = itemAppearance
        tabBarAppearance.inlineLayoutAppearance = itemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        
        // Navigation Bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withProperTextCase() // ✅ Apply text case modifier at root level
                .environmentObject(appState)
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Check for pending puzzle notification from shield
                    checkAndSendPendingPuzzleNotification()
                    
                    // Check for puzzle mode FIRST
                    appState.checkForPendingPuzzles()
                    
                    // Check and apply blocking state (new simplified model)
                    BlockedAppsManager.shared.loadState()
                    BlockedAppsManager.shared.checkAndReblock()
                    
                    // Mark blocked apps status for streak tracking
                    updateBlockedAppsStatusForStreak()
                    
                    // Sync data
                    appState.syncDataFromBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Check if unblock period expired
                    BlockedAppsManager.shared.checkAndReblock()
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
    /// Note: Notification is now sent from TapNotificationScreen in ContentView
    /// This method only clears stale flags if needed
    private func checkAndSendPendingPuzzleNotification() {
        // Notification sending is now handled by TapNotificationScreen
        // This ensures the notification is sent AFTER the tap notification screen is shown
        // The flow is:
        // 1. Shield Action sets flags and opens SE7EN app
        // 2. ContentView shows TapNotificationScreen
        // 3. TapNotificationScreen sends the notification after a delay
        // 4. User taps notification -> puzzle view appears
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
        
        // Mark blocked apps status for streak tracking
        updateBlockedAppsStatusForStreak()
        
        // Check time since last background - if long, check one-session apps
        checkAndHandleOneSessionAfterBackground()
    }
    
    private func handleAppWillResignActive() {
        print("📱 App will resign active")
        
        // Mark blocked apps status for streak tracking before going to background
        updateBlockedAppsStatusForStreak()
        
        // Pre-emptively mark one-session apps
        markOneSessionAppsForReBlock()
    }
    
    // MARK: - Streak Tracking
    
    private func updateBlockedAppsStatusForStreak() {
        let blockedCount = BlockedAppsManager.shared.blockedCount
        let hasBlockedApps = blockedCount > 0
        print("📊 Updating blocked apps status for streak: \(hasBlockedApps) (\(blockedCount) apps)")
        CoreDataManager.shared.markBlockedAppsStatus(hasBlockedApps: hasBlockedApps)
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
        
        // Handle tap notification screen (from shield action)
        if url.host == "tapnotification" {
            print("📱 URL: Tap notification screen requested")
            
            // Post notification to show tap notification screen
            // ContentView will handle this via checkForTapNotificationScreen()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: UIApplication.didBecomeActiveNotification,
                    object: nil
                )
            }
        }
        
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
    static let puzzleNotificationTapped = Notification.Name("puzzleNotificationTapped")
}
