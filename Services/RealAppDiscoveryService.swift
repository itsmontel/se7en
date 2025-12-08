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
        // Update UI state immediately on main thread
        DispatchQueue.main.async {
            self.isLoading = true
            self.currentSelection = selection
        }
        
        // Process heavy work on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
        
        var apps: [RealInstalledApp] = []
            var tokenMap: [String: AnyHashable] = [:]
            
            print("📱 Processing \(selection.applicationTokens.count) app tokens")
        
        // Process selected application tokens
        for token in selection.applicationTokens {
                // Extract app information from token - these never fail now
                let bundleID = self.extractBundleID(from: token)
                let displayName = self.extractDisplayName(from: token)
            let category = AppCategory.category(for: bundleID)
                
                print("   → \(displayName) (\(bundleID))")
                
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
            self.appTokenMap = tokenMap
        
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
        
            // Update UI on main thread
        DispatchQueue.main.async {
            self.categorizedApps = categorized
            self.selectedApps = selection.applicationTokens
            self.isLoading = false
        }
            
            print("✅ Processed \(apps.count) apps into \(categorized.keys.count) categories")
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
    
    // MARK: - Bulletproof Bundle ID Extraction
    // This NEVER fails - always returns a unique, usable identifier
    
    /// Cache for token -> bundleID mappings to avoid repeated extraction
    /// Thread-safe access using serial queue
    private var tokenBundleIDCache: [Int: String] = [:]
    
    /// Cache for token -> displayName mappings
    /// Thread-safe access using serial queue
    private var tokenDisplayNameCache: [Int: String] = [:]
    
    /// Serial queue for thread-safe cache access
    private let cacheQueue = DispatchQueue(label: "com.se7en.appDiscovery.cache")
    
    func extractBundleID(from token: AnyHashable) -> String {
        let tokenHash = token.hashValue
        
        // Thread-safe cache read
        var cached: String?
        cacheQueue.sync {
            cached = tokenBundleIDCache[tokenHash]
        }
        
        if let cached = cached {
            return cached
        }
        
        let description = String(describing: token)
        print("🔍 Token description for extraction: \(description)")
        
        // Try to extract bundle ID using multiple strategies
        let bundleID: String
        if let extracted = extractBundleIDFromDescription(description) {
            bundleID = extracted
            print("✅ Extracted bundle ID: \(bundleID)")
        } else {
            // If all extraction methods fail, create a unique identifier from the token
            // This ensures we NEVER have duplicate identifiers
            bundleID = "app.token.\(abs(tokenHash))"
            print("🔄 Created unique ID from token hash: \(bundleID)")
        }
        
        // Thread-safe cache write
        cacheQueue.async {
            self.tokenBundleIDCache[tokenHash] = bundleID
        }
        
        return bundleID
    }
    
    /// Extract bundle ID from token description using multiple patterns
    private func extractBundleIDFromDescription(_ description: String) -> String? {
        // Comprehensive list of patterns to try, ordered by reliability
        let patterns: [(pattern: String, captureGroup: Int)] = [
            // Standard bundle identifier patterns
            (#"bundleIdentifier:\s*"([^"]+)""#, 1),
            (#"bundleIdentifier:\s*([^\s,\)]+)"#, 1),
            (#"bundleID:\s*"([^"]+)""#, 1),
            (#"bundleID:\s*([^\s,\)]+)"#, 1),
            (#"identifier:\s*"([^"]+)""#, 1),
            (#"identifier:\s*([^\s,\)]+)"#, 1),
            
            // ApplicationToken specific patterns
            (#"ApplicationToken\(bundleIdentifier:\s*"([^"]+)""#, 1),
            (#"Application\(bundleIdentifier:\s*"([^"]+)""#, 1),
            
            // Common bundle ID formats (com.company.app, net.company.app, etc.)
            (#"(com\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)"#, 1),
            (#"(net\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)"#, 1),
            (#"(org\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)"#, 1),
            (#"(io\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)"#, 1),
            (#"(tv\.[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)"#, 1),
            (#"(me\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)"#, 1),
            (#"(ph\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)"#, 1),
            (#"(co\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)"#, 1),
            (#"(app\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+)*)"#, 1),
            
            // Generic pattern: any.thing.here format
            (#"([a-zA-Z][a-zA-Z0-9_\-]*\.[a-zA-Z][a-zA-Z0-9_\-]*\.[a-zA-Z][a-zA-Z0-9_\-]+)"#, 1),
            
            // Quoted strings that look like bundle IDs
            (#""([a-zA-Z][a-zA-Z0-9_\-]*\.[a-zA-Z0-9_\-\.]+)""#, 1),
        ]
        
        for (pattern, group) in patterns {
            if let bundleID = extractWithRegex(pattern: pattern, from: description, captureGroup: group) {
                // Validate it's a proper bundle ID
                if isValidBundleID(bundleID) {
                    return bundleID
                }
            }
        }
        
        return nil
    }
    
    /// Extract using regex pattern
    private func extractWithRegex(pattern: String, from text: String, captureGroup: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        
        let groupIndex = min(captureGroup, match.numberOfRanges - 1)
        guard groupIndex >= 0, let swiftRange = Range(match.range(at: groupIndex), in: text) else {
            return nil
        }
        
        return String(text[swiftRange])
    }
    
    /// Validate that a string looks like a valid bundle ID
    private func isValidBundleID(_ candidate: String) -> Bool {
        // Must have at least 2 parts separated by dots
        let parts = candidate.split(separator: ".")
        guard parts.count >= 2 else { return false }
        
        // Must be reasonable length
        guard candidate.count >= 5 && candidate.count <= 150 else { return false }
        
        // Must not contain spaces or special characters
        let invalidChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_")).inverted
        guard candidate.rangeOfCharacter(from: invalidChars) == nil else { return false }
        
        // First part should be a valid TLD-like prefix
        let validPrefixes = ["com", "net", "org", "io", "tv", "me", "ph", "co", "app", "cloud", "dev", "ai", "uk", "de", "fr", "jp", "kr", "cn", "au", "ca", "us", "edu"]
        let firstPart = String(parts[0]).lowercased()
        
        // Either starts with valid prefix OR is at least 2 chars (could be country code)
        if !validPrefixes.contains(firstPart) && firstPart.count < 2 {
            return false
        }
        
        return true
    }
    
    // Mapping of common bundle IDs to app display names
    // Using static to avoid initialization issues with large dictionary
    private static let bundleIDToAppName: [String: String] = [
        // Social Media
        "com.burbn.instagram": "Instagram",
        "com.atebits.Tweetie2": "Twitter",
        "com.tinyspeck.chatlyio": "Slack",
        "com.facebook.Facebook": "Facebook",
        "com.facebook.Messenger": "Messenger",
        "com.snapchat.snapchat": "Snapchat",
        "com.zhiliaoapp.musically": "TikTok",
        "net.whatsapp.WhatsApp": "WhatsApp",
        "ph.telegra.Telegraph": "Telegram",
        "com.reddit.Reddit": "Reddit",
        "com.linkedin.LinkedIn": "LinkedIn",
        "pinterest": "Pinterest",
        "com.tumblr.tumblr": "Tumblr",
        "com.discord.Discord": "Discord",
        
        // Entertainment
        "com.google.YouTube": "YouTube",
        "com.netflix.Netflix": "Netflix",
        "com.hulu.plus": "Hulu",
        "com.spotify.client": "Spotify",
        "com.apple.Music": "Apple Music",
        "com.apple.TV": "Apple TV",
        "com.amazon.AmazonVideo": "Prime Video",
        "com.hbo.hbonow": "HBO",
        "com.disney.disneynow": "Disney+",
        "tv.twitch": "Twitch",
        
        // Productivity
        "com.microsoft.Office.Outlook": "Outlook",
        "com.google.Gmail": "Gmail",
        "com.apple.mail": "Mail",
        "com.apple.Notes": "Notes",
        "com.apple.Reminders": "Reminders",
        "com.apple.Calendar": "Calendar",
        "com.apple.Pages": "Pages",
        "com.apple.Keynote": "Keynote",
        "com.apple.Numbers": "Numbers",
        "com.dropbox.Dropbox": "Dropbox",
        "com.google.Drive": "Google Drive",
        "com.microsoft.Office.Word": "Word",
        "com.microsoft.Office.Excel": "Excel",
        "com.microsoft.Office.PowerPoint": "PowerPoint",
        "com.notion.id": "Notion",
        "com.evernote.iPhone.Evernote": "Evernote",
        "com.trello.trello": "Trello",
        
        // Games
        "com.supercell.clashofclans": "Clash of Clans",
        "com.supercell.clashroyale": "Clash Royale",
        "com.king.candycrushsaga": "Candy Crush Saga",
        "com.rovio.angrybirds": "Angry Birds",
        "com.epicgames.fortnite": "Fortnite",
        "com.roblox.Roblox": "Roblox",
        "com.mojang.minecraftpe": "Minecraft",
        
        // Shopping
        "com.amazon.Amazon": "Amazon",
        "com.ebay.iphone": "eBay",
        "com.etsy.etsyapp": "Etsy",
        "com.wish.wish": "Wish",
        "com.target.TargetApp": "Target",
        "com.walmart.ios": "Walmart",
        
        // Health & Fitness
        "com.apple.Health": "Health",
        "com.apple.Fitness": "Fitness",
        "com.strava.strava": "Strava",
        "com.myfitnesspal.mfp": "MyFitnessPal",
        "com.fitbit.Fitbit": "Fitbit",
        "com.headspace.headspace": "Headspace",
        "com.calm.calm": "Calm",
        
        // Education
        "com.duolingo.Duolingo": "Duolingo",
        "org.khanacademy.Khan-Academy": "Khan Academy",
        "com.coursera.coursera": "Coursera",
        "com.udemy": "Udemy",
        
        // News & Reading
        "com.nytimes.NYTimes": "NYTimes",
        "com.cnn.iphone": "CNN",
        "com.bbc.news": "BBC News",
        "com.medium.reader": "Medium",
        "com.flipboard.flipboard": "Flipboard",
        "com.apple.news": "News",
        "com.apple.Books": "Books",
        
        // Photo & Video
        "com.apple.Photos": "Photos",
        "com.apple.camera": "Camera",
        "com.vsco.cam": "VSCO",
        "com.adobe.LightroomMobile": "Lightroom",
        "com.google.Pixelmator": "Pixelmator",
        "com.apple.iMovie": "iMovie",
        
        // Travel & Local
        "com.google.Maps": "Google Maps",
        "com.apple.Maps": "Maps",
        "com.ubercab.UberClient": "Uber",
        "com.lyft.Lyft": "Lyft",
        "com.airbnb.app": "Airbnb",
        "com.booking.BookingApp": "Booking.com",
        "com.expedia.Expedia": "Expedia",
        "com.waze.ios": "Waze",
        
        // Utilities
        "com.apple.weather": "Weather",
        "com.apple.calculator": "Calculator",
        "com.apple.files": "Files",
        "com.apple.Settings": "Settings",
        "com.apple.Safari": "Safari",
        "com.google.Chrome": "Chrome",
        "com.mozilla.ios.Firefox": "Firefox",
        
        // Communication
        "com.apple.MobilePhone": "Phone",
        "com.apple.MobileSMS": "Messages",
        "com.apple.FaceTime": "FaceTime",
        "com.skype.skype": "Skype",
        "com.zoom.Zoom": "Zoom",
        "com.microsoft.teams": "Teams"
    ]
    
    // MARK: - Bulletproof Display Name Extraction
    // This NEVER returns nil - always returns a readable app name
    
    func extractDisplayName(from token: AnyHashable) -> String {
        let tokenHash = token.hashValue
        
        // Thread-safe cache read
        var cached: String?
        cacheQueue.sync {
            cached = tokenDisplayNameCache[tokenHash]
        }
        
        if let cached = cached {
            return cached
        }
        
        let description = String(describing: token)
        
        // Strategy 1: Try to extract localizedDisplayName from token description
        let displayName: String
        if let extracted = extractDisplayNameFromDescription(description) {
            displayName = extracted
            print("✅ Extracted display name: \(displayName)")
        } else {
            // Strategy 2: Get bundle ID and convert to readable name
        let bundleID = extractBundleID(from: token)
        
            // Check if bundle ID is in our mapping
            if let appName = Self.bundleIDToAppName[bundleID] {
                displayName = appName
            } else if let appName = findPartialMatch(for: bundleID) {
                // Check for partial matches in our mapping
                displayName = appName
            } else {
                // Strategy 3: Generate readable name from bundle ID
                displayName = generateReadableName(from: bundleID)
            }
        }
        
        // Thread-safe cache write
        cacheQueue.async {
            self.tokenDisplayNameCache[tokenHash] = displayName
        }
        
        return displayName
    }
    
    /// Extract display name directly from token description
    private func extractDisplayNameFromDescription(_ description: String) -> String? {
        // Patterns to extract localized display name
        let patterns: [(pattern: String, captureGroup: Int)] = [
            (#"localizedDisplayName:\s*"([^"]+)""#, 1),
            (#"localizedDisplayName:\s*([^,\)\s]+)"#, 1),
            (#"displayName:\s*"([^"]+)""#, 1),
            (#"displayName:\s*([^,\)\s]+)"#, 1),
            (#"name:\s*"([^"]+)""#, 1),
            (#"label:\s*"([^"]+)""#, 1),
            (#"title:\s*"([^"]+)""#, 1),
            // ApplicationToken with name
            (#"ApplicationToken\([^)]*name:\s*"([^"]+)""#, 1),
        ]
        
        for (pattern, group) in patterns {
            if let name = extractWithRegex(pattern: pattern, from: description, captureGroup: group) {
                // Validate it's a proper name (not a bundle ID or UUID)
                if isValidDisplayName(name) {
                    return name
                }
            }
        }
        
        return nil
    }
    
    /// Check if a string is a valid display name
    private func isValidDisplayName(_ name: String) -> Bool {
        // Must not be empty
        guard !name.isEmpty else { return false }
        
        // Must not look like a bundle ID
        if name.contains(".") && name.filter({ $0 == "." }).count >= 2 {
            return false
        }
        
        // Must not be a UUID
        if UUID(uuidString: name) != nil {
            return false
        }
        
        // Must be reasonable length
        guard name.count >= 1 && name.count <= 50 else { return false }
        
        return true
    }
    
    /// Find partial match in bundle ID mapping
    private func findPartialMatch(for bundleID: String) -> String? {
        let lowerBundleID = bundleID.lowercased()
        
        // Try exact match with lowercase
        for (mappedID, appName) in Self.bundleIDToAppName {
            if mappedID.lowercased() == lowerBundleID {
                return appName
            }
        }
        
        // Try partial matches using the last component
        let components = bundleID.split(separator: ".")
        if let lastComponent = components.last {
            let lastLower = String(lastComponent).lowercased()
            
            for (mappedID, appName) in Self.bundleIDToAppName {
                let mappedComponents = mappedID.split(separator: ".")
                if let mappedLast = mappedComponents.last {
                    let mappedLastLower = String(mappedLast).lowercased()
                    
                    // Check if last components match
                    if lastLower == mappedLastLower {
                        return appName
                    }
                    
                    // Check if one contains the other
                    if lastLower.contains(mappedLastLower) || mappedLastLower.contains(lastLower) {
                        return appName
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Generate a readable name from bundle ID
    private func generateReadableName(from bundleID: String) -> String {
        // Handle token-generated IDs
        if bundleID.hasPrefix("app.token.") {
            let hashPart = bundleID.replacingOccurrences(of: "app.token.", with: "")
            return "App \(hashPart.prefix(6))"
        }
        
        // Split bundle ID and get the most meaningful part
        let components = bundleID.split(separator: ".")
        
        // Try to find the best component (usually not the first one which is com/net/etc)
        var bestComponent: String = ""
        
        for component in components.reversed() {
            let str = String(component)
            let lower = str.lowercased()
            
            // Skip common non-meaningful parts
            let skipParts = ["app", "ios", "iphone", "ipad", "mobile", "client", "main", "prod", "release", "beta", "alpha", "debug", "com", "net", "org", "io", "tv", "me", "co"]
            
            if !skipParts.contains(lower) && str.count >= 2 {
                bestComponent = str
                break
            }
        }
        
        // If no good component found, use the last one
        if bestComponent.isEmpty, let last = components.last {
            bestComponent = String(last)
        }
        
        // Clean up the component
        let cleaned = cleanAppName(bestComponent)
        
        // Capitalize properly
        return formatAppName(cleaned)
    }
    
    /// Clean up an app name string
    private func cleanAppName(_ name: String) -> String {
        var result = name
        
        // Remove common suffixes
        let suffixes = ["App", "iOS", "iPhone", "iPad", "Mobile", "Client", "Official", "Plus", "Pro", "Free", "Lite"]
        for suffix in suffixes {
            if result.hasSuffix(suffix) && result.count > suffix.count {
                result = String(result.dropLast(suffix.count))
            }
        }
        
        // Remove underscores and dashes, replace with spaces
        result = result.replacingOccurrences(of: "_", with: " ")
        result = result.replacingOccurrences(of: "-", with: " ")
        
        // Trim whitespace
        result = result.trimmingCharacters(in: .whitespaces)
        
        return result.isEmpty ? name : result
    }
    
    /// Format app name with proper capitalization
    private func formatAppName(_ name: String) -> String {
        // Handle camelCase or PascalCase
        var result = ""
        var prevWasLower = false
        
        for char in name {
            if char.isUppercase && prevWasLower {
                result += " "
            }
            result += String(char)
            prevWasLower = char.isLowercase
        }
        
        // Capitalize first letter of each word
        let words = result.split(separator: " ")
        let formatted = words.map { word -> String in
            let lower = word.lowercased()
            // Keep some words lowercase
            if ["the", "a", "an", "and", "or", "of", "for", "in", "on", "at", "to"].contains(lower) && word != words.first {
                return lower
            }
            return word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
        
        return formatted.isEmpty ? "App" : formatted
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


