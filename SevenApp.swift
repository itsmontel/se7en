import SwiftUI
import CoreData

@main
struct SE7ENApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    let persistentContainer = CoreDataManager.shared.persistentContainer
    
    init() {
        // Setup notification categories
        NotificationService.shared.setupNotificationCategories()
        
        // Perform Core Data migration if needed
        CoreDataManager.shared.performMigrationIfNeeded()
        
        // Don't request permissions on app launch - wait for onboarding
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .environment(\.textCase, .none)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Sync data when app returns from background
                    appState.syncDataFromBackground()
                    
                    // Refresh Screen Time monitoring and data
                    print("📱 App entered foreground - refreshing Screen Time data")
                    ScreenTimeService.shared.refreshAllMonitoring()
                    
                    // Check for pending puzzles from shield action
                    appState.checkForPendingPuzzles()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Also refresh when app becomes active (covers first launch)
                    print("📱 App became active - refreshing Screen Time data")
                    ScreenTimeService.shared.refreshAllMonitoring()
                    
                    // Check for pending puzzles from shield action
                    appState.checkForPendingPuzzles()
                }
                .onOpenURL { url in
                    // Handle se7en://puzzle URL scheme
                    if url.scheme == "se7en" && url.host == "puzzle" {
                        print("🎯 App opened via puzzle URL: \(url)")
                        
                        // Extract parameters
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                           let queryItems = components.queryItems {
                            var tokenHash: String?
                            var appName: String?
                            
                            for item in queryItems {
                                if item.name == "tokenHash" {
                                    tokenHash = item.value
                                } else if item.name == "appName" {
                                    appName = item.value?.removingPercentEncoding
                                }
                            }
                            
                            if let tokenHash = tokenHash, let appName = appName {
                                // Set puzzle mode
                                let appGroupID = "group.com.se7en.app"
                                if let defaults = UserDefaults(suiteName: appGroupID) {
                                    defaults.set(true, forKey: "puzzleMode")
                                    defaults.set(tokenHash, forKey: "puzzleTokenHash")
                                    defaults.set(appName, forKey: "puzzleAppName_\(tokenHash)")
                                    defaults.synchronize()
                                }
                                
                                // Trigger ContentView to show puzzle
                                NotificationCenter.default.post(
                                    name: .appBlocked,
                                    object: nil,
                                    userInfo: [
                                        "appName": appName,
                                        "bundleID": tokenHash,
                                        "puzzleMode": true
                                    ]
                                )
                            }
                        }
                    }
                }
        }
    }
}


