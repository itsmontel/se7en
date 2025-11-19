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
        var apps: [InstalledApp] = []
        
        // Method 1: Use URL schemes to detect installed apps (App Store approved)
        let appsToCheck = getCommonAppsWithSchemes()
        
        for (name, bundleID, urlScheme) in appsToCheck {
            if let url = URL(string: urlScheme), UIApplication.shared.canOpenURL(url) {
                // App is installed
                let installedApp = InstalledApp(
                    name: name,
                    bundleID: bundleID,
                    icon: nil, // We'll use SF Symbols instead
                    displayName: name
                )
                apps.append(installedApp)
            }
        }
        
        // If no apps detected via URL schemes, fallback to common apps list
        if apps.isEmpty {
            apps = getCommonApps()
        }
        
        // Sort alphabetically
        return apps.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }
    
    private func getAppIcon(bundleID: String) -> UIImage? {
        // For now, we'll use SF Symbols instead of trying to extract real app icons
        // In a production app, you'd use proper icon extraction methods
        return nil
    }
    
    private func getCommonAppsWithSchemes() -> [(String, String, String)] {
        // Returns (App Name, Bundle ID, URL Scheme) for detection
        return [
            ("Instagram", "com.burbn.instagram", "instagram://"),
            ("Facebook", "com.facebook.Facebook", "fb://"),
            ("X", "com.atebits.Tweetie2", "twitter://"),
            ("TikTok", "com.zhiliaoapp.musically", "tiktok://"),
            ("Snapchat", "com.toyopagroup.picaboo", "snapchat://"),
            ("YouTube", "com.google.ios.youtube", "youtube://"),
            ("Reddit", "com.reddit.Reddit", "reddit://"),
            ("WhatsApp", "net.whatsapp.WhatsApp", "whatsapp://"),
            ("Telegram", "ph.telegra.Telegraph", "tg://"),
            ("Discord", "com.hammerandchisel.discord", "discord://"),
            ("Netflix", "com.netflix.Netflix", "nflx://"),
            ("Spotify", "com.spotify.client", "spotify://"),
            ("Amazon", "com.amazon.Amazon", "amazon://"),
            ("Uber", "com.ubercab.UberClient", "uber://"),
            ("Lyft", "com.lyft.Lyft", "lyft://"),
            ("Pinterest", "com.pinterest", "pinterest://"),
            ("LinkedIn", "com.linkedin.LinkedIn", "linkedin://"),
            ("Twitch", "tv.twitch", "twitch://"),
            ("Zoom", "us.zoom.videomeetings", "zoomus://"),
            ("Slack", "com.tinyspeck.chatlyio", "slack://"),
            ("Gmail", "com.google.Gmail", "googlegmail://"),
            ("Chrome", "com.google.chrome.ios", "googlechrome://"),
            ("Firefox", "org.mozilla.ios.Firefox", "firefox://"),
            ("Dropbox", "com.getdropbox.Dropbox", "dbapi-1://"),
            ("Evernote", "com.evernote.iPhone.Evernote", "evernote://"),
            ("Shazam", "com.shazam.Shazam", "shazam://"),
            ("Venmo", "com.venmo.touch.v2", "venmo://"),
            ("PayPal", "com.yourcompany.PPClient", "paypal://"),
            ("Waze", "com.waze.iphone", "waze://"),
            ("Yelp", "com.yelp.yelpiphone", "yelp4://")
        ]
    }
    
    private func getCommonApps() -> [InstalledApp] {
        // Fallback list of common apps that users might want to monitor
        let commonApps = [
            ("Instagram", "com.burbn.instagram"),
            ("Facebook", "com.facebook.Facebook"),
            ("X", "com.atebits.Tweetie2"),
            ("TikTok", "com.zhiliaoapp.musically"),
            ("Snapchat", "com.toyopagroup.picaboo"),
            ("YouTube", "com.google.ios.youtube"),
            ("Reddit", "com.reddit.Reddit"),
            ("WhatsApp", "net.whatsapp.WhatsApp"),
            ("Telegram", "ph.telegra.Telegraph"),
            ("Discord", "com.hammerandchisel.discord"),
            ("Safari", "com.apple.mobilesafari"),
            ("Chrome", "com.google.chrome.ios"),
            ("Netflix", "com.netflix.Netflix"),
            ("Spotify", "com.spotify.client"),
            ("Amazon", "com.amazon.Amazon"),
            ("Uber", "com.ubercab.UberClient"),
            ("Lyft", "com.lyft.Lyft"),
            ("Maps", "com.apple.Maps"),
            ("Mail", "com.apple.mobilemail"),
            ("Messages", "com.apple.MobileSMS"),
            ("Phone", "com.apple.mobilephone"),
            ("Settings", "com.apple.Preferences"),
            ("Photos", "com.apple.mobileslideshow"),
            ("Camera", "com.apple.camera"),
            ("Music", "com.apple.Music"),
            ("App Store", "com.apple.AppStore"),
            ("Calendar", "com.apple.mobilecal"),
            ("Clock", "com.apple.mobiletimer"),
            ("Weather", "com.apple.weather"),
            ("Notes", "com.apple.mobilenotes"),
            ("Reminders", "com.apple.reminders"),
            ("Contacts", "com.apple.MobileAddressBook")
        ]
        
        return commonApps.map { name, bundleID in
            InstalledApp(
                name: name,
                bundleID: bundleID,
                icon: nil,
                displayName: name
            )
        }
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
