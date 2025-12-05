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
struct RealInstalledApp: Identifiable, Equatable {
    let id = UUID()
    let token: AnyHashable  // Token from FamilyActivitySelection (opaque type)
    let displayName: String
    let bundleID: String
    let category: AppCategory
    
    // MARK: - Equatable Conformance
    static func == (lhs: RealInstalledApp, rhs: RealInstalledApp) -> Bool {
        // Compare based on bundleID and displayName since tokens are opaque
        return lhs.id == rhs.id &&
               lhs.bundleID == rhs.bundleID &&
               lhs.displayName == rhs.displayName &&
               lhs.category == rhs.category
    }
    
    var iconName: String {
        // Use generic app icon - Screen Time API provides real app data
        // Category-based icon fallback
        switch category {
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
    
    var color: UIColor {
        // Use category-based color - Screen Time API provides real app data
        switch category {
        case .social: return UIColor.systemBlue
        case .entertainment: return UIColor.systemRed
        case .productivity: return UIColor.systemGreen
        case .games: return UIColor.systemPurple
        case .shopping: return UIColor.systemOrange
        case .healthFitness: return UIColor.systemPink
        case .education: return UIColor.systemIndigo
        case .newsReading: return UIColor.systemTeal
        case .photoVideo: return UIColor.systemYellow
        case .travelLocal: return UIColor.systemCyan
        case .utilities: return UIColor.systemGray
        case .other: return UIColor.label
        }
    }
}

class RealAppDiscoveryService: ObservableObject {
    static let shared = RealAppDiscoveryService()
    
    @Published var selectedApps: Set<AnyHashable> = []
    @Published var categorizedApps: [AppCategory: [RealInstalledApp]] = [:]
    @Published var isLoading = false
    
    // Store the full selection for creating individual app selections
    @Published var currentSelection: FamilyActivitySelection = FamilyActivitySelection()
    
    // Map app display names to their tokens for proper identification
    private var appTokenMap: [String: AnyHashable] = [:]
    
    private init() {}
    
    // This will be called after user selects apps using FamilyActivityPicker
    func processSelectedApps(_ selection: FamilyActivitySelection) {
        isLoading = true
        currentSelection = selection
        
        var apps: [RealInstalledApp] = []
        var tokenMap: [String: AnyHashable] = [:]
        
        // Process selected application tokens
        for token in selection.applicationTokens {
            // Extract app information from token
            let bundleID = extractBundleID(from: token)
            let displayName = extractDisplayName(from: token) ?? "Unknown App"
            let category = AppCategory.category(for: bundleID)
            
            // Store token mapping for this app
            tokenMap[displayName] = token
            
            let app = RealInstalledApp(
                token: token,
                displayName: displayName,
                bundleID: bundleID,
                category: category
            )
            apps.append(app)
        }
        
        // Store token map
        appTokenMap = tokenMap
        
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
    
    // Get a FamilyActivitySelection for a specific app by name
    func getSelectionForApp(_ appName: String) -> FamilyActivitySelection? {
        guard let token = appTokenMap[appName] else {
            return nil
        }
        
        // Create a selection with just this app's token
        var selection = FamilyActivitySelection()
        // Note: We can't directly add tokens, but we can use the current selection
        // and filter it. However, since tokens are opaque, we'll use the full selection
        // and let ScreenTimeService handle individual app monitoring
        return currentSelection
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
        print("🔍 Extracting bundle ID from token description: \(description.prefix(200))")
        
        // Try multiple patterns to extract bundle ID
        let patterns = [
            #"bundleIdentifier:\s*"([^"]+)""#,
            #"bundleID:\s*"([^"]+)""#,
            #"identifier:\s*"([^"]+)""#,
            #"(com\.[a-zA-Z0-9\-\.]+[a-zA-Z0-9]+)"#,
            #"([a-z]+\.[a-z]+\.[a-z0-9]+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)) {
                
                let range = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
                if let swiftRange = Range(range, in: description) {
                    let bundleID = String(description[swiftRange])
                    // Validate it looks like a bundle ID
                    if bundleID.contains(".") && bundleID.count > 3 && !bundleID.contains(" ") {
                        print("✅ Extracted bundle ID: \(bundleID)")
                        return bundleID
                    }
                }
            }
        }
        
        print("⚠️ Failed to extract bundle ID, using fallback")
        return "unknown.app"
    }
    
    func extractDisplayName(from token: AnyHashable) -> String? {
        // Apple's tokens don't expose display names directly
        // We need to use the token's description or a mapping
        // For now, try to extract from bundle ID
        let bundleID = extractBundleID(from: token)
        
        // If bundle ID extraction failed, return nil (will be handled by caller)
        guard bundleID != "unknown.app" else {
            return nil
        }
        
        // Extract last component of bundle ID as a fallback
        let components = bundleID.split(separator: ".")
        if let last = components.last {
            // Capitalize properly (e.g., "instagram" -> "Instagram")
            let name = String(last)
            return name.prefix(1).uppercased() + name.dropFirst()
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


