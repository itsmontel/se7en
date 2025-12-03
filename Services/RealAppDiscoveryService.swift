import Foundation
import FamilyControls
import ManagedSettings
import UIKit

// App Category enum matching iOS categories
enum AppCategory: String, CaseIterable, Identifiable {
    case social = "Social"
    case entertainment = "Entertainment"
    case productivity = "Productivity"
    case games = "Games"
    case shopping = "Shopping"
    case healthFitness = "Health & Fitness"
    case education = "Education"
    case newsReading = "News & Reading"
    case photoVideo = "Photo & Video"
    case travelLocal = "Travel & Local"
    case utilities = "Utilities"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .social: return "person.2.fill"
        case .entertainment: return "tv.fill"
        case .productivity: return "briefcase.fill"
        case .games: return "gamecontroller.fill"
        case .shopping: return "cart.fill"
        case .healthFitness: return "heart.fill"
        case .education: return "book.fill"
        case .newsReading: return "newspaper.fill"
        case .photoVideo: return "camera.fill"
        case .travelLocal: return "map.fill"
        case .utilities: return "wrench.fill"
        case .other: return "app.fill"
        }
    }
    
    var color: String {
        switch self {
        case .social: return "blue"
        case .entertainment: return "red"
        case .productivity: return "green"
        case .games: return "purple"
        case .shopping: return "orange"
        case .healthFitness: return "pink"
        case .education: return "indigo"
        case .newsReading: return "teal"
        case .photoVideo: return "yellow"
        case .travelLocal: return "cyan"
        case .utilities: return "gray"
        case .other: return "secondary"
        }
    }
    
    // Map common bundle IDs to categories
    static func category(for bundleID: String) -> AppCategory {
        let socialApps = ["instagram", "facebook", "twitter", "tiktok", "snapchat", "whatsapp", "telegram", "discord", "reddit", "linkedin", "pinterest", "tumblr"]
        let entertainmentApps = ["youtube", "netflix", "hulu", "disney", "hbo", "prime", "spotify", "music", "podcasts", "twitch", "tidal"]
        let productivityApps = ["slack", "notion", "evernote", "trello", "asana", "zoom", "teams", "dropbox", "drive", "onedrive"]
        let gamesApps = ["game", "play", "chess", "puzzle", "candy", "clash", "fortnite", "roblox", "minecraft"]
        let shoppingApps = ["amazon", "ebay", "etsy", "wish", "shop", "target", "walmart", "bestbuy"]
        let healthApps = ["health", "fitness", "workout", "calm", "headspace", "strava", "myfitnesspal", "fitbit", "peloton"]
        let educationApps = ["duolingo", "khan", "coursera", "udemy", "brilliant", "quizlet", "canvas", "blackboard"]
        let newsApps = ["news", "nyt", "cnn", "bbc", "reuters", "medium", "flipboard", "feedly"]
        let photoVideoApps = ["photo", "camera", "vsco", "lightroom", "snapseed", "facetune", "tiktok"]
        let travelApps = ["maps", "uber", "lyft", "airbnb", "booking", "expedia", "waze", "transit"]
        let utilityApps = ["weather", "calculator", "notes", "reminders", "files", "scanner", "vpn"]
        
        let lowerBundleID = bundleID.lowercased()
        
        if socialApps.contains(where: { lowerBundleID.contains($0) }) { return .social }
        if entertainmentApps.contains(where: { lowerBundleID.contains($0) }) { return .entertainment }
        if productivityApps.contains(where: { lowerBundleID.contains($0) }) { return .productivity }
        if gamesApps.contains(where: { lowerBundleID.contains($0) }) { return .games }
        if shoppingApps.contains(where: { lowerBundleID.contains($0) }) { return .shopping }
        if healthApps.contains(where: { lowerBundleID.contains($0) }) { return .healthFitness }
        if educationApps.contains(where: { lowerBundleID.contains($0) }) { return .education }
        if newsApps.contains(where: { lowerBundleID.contains($0) }) { return .newsReading }
        if photoVideoApps.contains(where: { lowerBundleID.contains($0) }) { return .photoVideo }
        if travelApps.contains(where: { lowerBundleID.contains($0) }) { return .travelLocal }
        if utilityApps.contains(where: { lowerBundleID.contains($0) }) { return .utilities }
        
        return .other
    }
}

// Real app data structure using FamilyControls tokens
struct RealInstalledApp: Identifiable {
    let id = UUID()
    let token: AnyHashable  // Token from FamilyActivitySelection (opaque type)
    let displayName: String
    let bundleID: String
    let category: AppCategory
    
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
        
        for (appName, iconName) in iconMap {
            if displayName.lowercased().contains(appName.lowercased()) {
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
            if displayName.lowercased().contains(appName.lowercased()) {
                return color
            }
        }
        
        return UIColor.systemBlue
    }
}

class RealAppDiscoveryService: ObservableObject {
    static let shared = RealAppDiscoveryService()
    
    @Published var selectedApps: Set<AnyHashable> = []
    @Published var categorizedApps: [AppCategory: [RealInstalledApp]] = [:]
    @Published var isLoading = false
    
    private init() {}
    
    // This will be called after user selects apps using FamilyActivityPicker
    func processSelectedApps(_ selection: FamilyActivitySelection) {
        isLoading = true
        
        var apps: [RealInstalledApp] = []
        
        // Process selected application tokens
        for token in selection.applicationTokens {
            // Extract app information from token
            let bundleID = extractBundleID(from: token)
            let displayName = extractDisplayName(from: token) ?? "Unknown App"
            let category = AppCategory.category(for: bundleID)
            
            let app = RealInstalledApp(
                token: token,
                displayName: displayName,
                bundleID: bundleID,
                category: category
            )
            apps.append(app)
        }
        
        // Categorize apps
        var categorized: [AppCategory: [RealInstalledApp]] = [:]
        for app in apps {
            if categorized[app.category] == nil {
                categorized[app.category] = []
            }
            categorized[app.category]?.append(app)
        }
        
        // Sort within each category
        for category in categorized.keys {
            categorized[category]?.sort { $0.displayName < $1.displayName }
        }
        
        DispatchQueue.main.async {
            self.categorizedApps = categorized
            self.selectedApps = selection.applicationTokens
            self.isLoading = false
        }
    }
    
    func getApps(for category: AppCategory) -> [RealInstalledApp] {
        return categorizedApps[category] ?? []
    }
    
    func getAllCategories() -> [AppCategory] {
        return AppCategory.allCases.filter { !getApps(for: $0).isEmpty }
    }
    
    func extractBundleID(from token: AnyHashable) -> String {
        // The token contains the bundle ID in its description
        // This is a workaround since tokens don't expose bundleID directly
        let description = String(describing: token)
        // Extract bundle ID from the token description if possible
        // Format is typically: Token(bundleIdentifier: "com.example.app")
        if let range = description.range(of: "bundleIdentifier: \"") {
            let startIndex = range.upperBound
            if let endRange = description[startIndex...].range(of: "\"") {
                return String(description[startIndex..<endRange.lowerBound])
            }
        }
        return "unknown.app"
    }
    
    func extractDisplayName(from token: AnyHashable) -> String? {
        // Try to get the display name from the token
        // This is a simplified version - in production you'd want more robust extraction
        let bundleID = extractBundleID(from: token)
        
        // Extract last component of bundle ID as a fallback
        let components = bundleID.split(separator: ".")
        if let last = components.last {
            return String(last).capitalized
        }
        
        return nil
    }
    
    func canMonitorApp(_ bundleID: String) -> Bool {
        // Don't allow monitoring of critical system apps
        let restrictedApps = [
            "com.apple.mobilephone",
            "com.apple.MobileSMS",
            "com.apple.Preferences",
            "com.apple.springboard"
        ]
        
        return !restrictedApps.contains(bundleID)
    }
}


