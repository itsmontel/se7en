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
                }
        }
    }
}


