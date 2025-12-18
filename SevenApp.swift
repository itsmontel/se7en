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
                    // ✅ CRITICAL: Check for puzzle mode FIRST when app enters foreground
                    // This handles when app is opened from shield action
                    appState.checkForPendingPuzzles()
                    
                    // Sync data when app returns from background
                    appState.syncDataFromBackground()
                    
                    // Refresh Screen Time monitoring and data
                    ScreenTimeService.shared.refreshAllMonitoring()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // ✅ Check for One-Session Mode apps and re-block them
                    ScreenTimeService.shared.checkAndReBlockOneSessionApps()
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📱 App opened with URL: \(url)")
        
        guard url.scheme == "se7en" else { return }
        
        // Handle puzzle mode
        if url.host == "puzzle" {
            print("🧩 URL: Puzzle mode requested")
            // The puzzle mode will be picked up by ContentView's checkPuzzleMode()
            // Just post a notification to ensure it's checked
                                NotificationCenter.default.post(
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }
    }
}


