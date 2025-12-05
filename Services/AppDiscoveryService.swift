import Foundation
import UIKit

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let icon: UIImage?
    let displayName: String
    
    var iconName: String {
        // Map common apps to SF Symbols for consistent UI
        let iconMap = [
            "Instagram": "camera.fill",
            "Facebook": "f.circle.fill",
            "X": "x.circle.fill",
            "Twitter": "x.circle.fill",
            "TikTok": "music.note.list",
            "Snapchat": "camera.macro.circle.fill",
            "YouTube": "play.circle.fill",
            "Reddit": "r.circle.fill",
            "WhatsApp": "message.circle.fill",
            "Telegram": "paperplane.circle.fill",
            "Discord": "gamecontroller.fill",
            "Safari": "safari.fill",
            "Chrome": "globe",
            "Netflix": "tv.fill",
            "Spotify": "music.note",
            "Amazon": "cart.fill",
            "Uber": "car.fill",
            "Lyft": "car.2.fill"
        ]
        
        // Check for partial matches in app name
        for (appName, iconName) in iconMap {
            if name.lowercased().contains(appName.lowercased()) || 
               displayName.lowercased().contains(appName.lowercased()) {
                return iconName
            }
        }
        
        return "app.fill"
    }
    
    var color: UIColor {
        let colorMap = [
            "Instagram": UIColor.systemPink,
            "Facebook": UIColor.systemBlue,
            "X": UIColor.label,
            "Twitter": UIColor.systemBlue,
            "TikTok": UIColor.label,
            "Snapchat": UIColor.systemYellow,
            "YouTube": UIColor.systemRed,
            "Reddit": UIColor.systemOrange,
            "WhatsApp": UIColor.systemGreen,
            "Telegram": UIColor.systemBlue,
            "Discord": UIColor.systemIndigo,
            "Safari": UIColor.systemBlue,
            "Chrome": UIColor.systemBlue,
            "Netflix": UIColor.systemRed,
            "Spotify": UIColor.systemGreen,
            "Amazon": UIColor.systemOrange,
            "Uber": UIColor.label,
            "Lyft": UIColor.systemPink
        ]
        
        for (appName, color) in colorMap {
            if name.lowercased().contains(appName.lowercased()) || 
               displayName.lowercased().contains(appName.lowercased()) {
                return color
            }
        }
        
        return UIColor.systemBlue
    }
}

class AppDiscoveryService: ObservableObject {
    static let shared = AppDiscoveryService()
    
    @Published var installedApps: [InstalledApp] = []
    @Published var isLoading = false
    
    private init() {}
    
    func discoverInstalledApps() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = self?.getInstalledApps() ?? []
            
            DispatchQueue.main.async {
                self?.installedApps = apps
                self?.isLoading = false
            }
        }
    }
    
    private func getInstalledApps() -> [InstalledApp] {
        // NO FAKE APPS - Screen Time API will show real apps via FamilyActivityPicker
        // This service should not be used anymore - use RealAppDiscoveryService instead
        return []
    }
    
    private func getAppIcon(bundleID: String) -> UIImage? {
        // For now, we'll use SF Symbols instead of trying to extract real app icons
        // In a production app, you'd use proper icon extraction methods
        return nil
    }
    
    private func getCommonAppsWithSchemes() -> [(String, String, String)] {
        // NO FAKE APPS - Screen Time API shows real apps only via FamilyActivityPicker
        // This method should not be used - use RealAppDiscoveryService with FamilyActivityPicker instead
        return []
    }
    
    private func getCommonApps() -> [InstalledApp] {
        // NO FAKE APPS - Screen Time API shows real apps only
        // This method should not be used - use RealAppDiscoveryService with FamilyActivityPicker instead
        return []
    }
    
    func canMonitorApp(_ bundleID: String) -> Bool {
        // Don't allow monitoring of critical system apps
        let restrictedApps = [
            "com.apple.mobilephone", // Phone
            "com.apple.MobileSMS", // Messages
            "com.apple.Preferences", // Settings
            "com.apple.springboard", // Home Screen
            "com.apple.mobilesafari" // Safari (optional - you might want to allow this)
        ]
        
        return !restrictedApps.contains(bundleID)
    }
}

// Make InstalledApp hashable for Set operations
extension InstalledApp: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
    
    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}
