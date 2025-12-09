import Foundation
import FamilyControls
import ManagedSettings
import UIKit

// MARK: - App Category Enum
// Used for organizing apps by category in the UI
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
    
    /// Determine category from token type (fallback categorization)
    /// Note: Real categorization should use Label(token) to get actual app info
    static func category(for tokenType: TokenType) -> AppCategory {
        switch tokenType {
        case .application:
            return .other  // Default - use Label(token) for real category
        case .category:
            return .other  // Categories can contain multiple app types
        case .webDomain:
            return .other  // Web domains default to other
        }
    }
    
    /// Token type enum for categorization
    enum TokenType {
        case application
        case category
        case webDomain
    }
}

// MARK: - Real Installed App
// Simplified structure using tokens only (no bundle ID extraction)
struct RealInstalledApp: Identifiable, Equatable {
    let id: UUID
    let token: AnyHashable  // ApplicationToken, ActivityCategoryToken, or WebDomainToken
    let tokenHash: String   // ✅ Token hash as unique identifier
    let tokenType: AppCategory.TokenType
    let category: AppCategory
    
    // Optional: Store a custom name if user provides one
    var customName: String?
    
    init(token: AnyHashable, tokenType: AppCategory.TokenType, customName: String? = nil) {
        self.id = UUID()
        self.token = token
        self.tokenHash = String(token.hashValue)  // ✅ Use token hash as identifier
        self.tokenType = tokenType
        self.category = AppCategory.category(for: tokenType)
        self.customName = customName
    }
    
    // Equatable conformance - compare by token hash
    static func == (lhs: RealInstalledApp, rhs: RealInstalledApp) -> Bool {
        return lhs.tokenHash == rhs.tokenHash
    }
    
    var iconName: String {
        return category.icon
    }
    
    var color: UIColor {
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

// MARK: - Real App Discovery Service
// ✅ Token-based approach - no bundle ID extraction
@MainActor
class RealAppDiscoveryService: ObservableObject {
    static let shared = RealAppDiscoveryService()
    
    @Published var selectedApps: Set<AnyHashable> = []
    @Published var categorizedApps: [AppCategory: [RealInstalledApp]] = [:]
    @Published var isLoading = false
    
    // ✅ Store the full selection for creating individual app selections
    @Published var currentSelection: FamilyActivitySelection = FamilyActivitySelection()
    
    // ✅ Map token hash to token for quick lookup
    private var tokenHashToTokenMap: [String: AnyHashable] = [:]
    
    // ✅ Map token hash to selection for individual apps
    private var tokenHashToSelectionMap: [String: FamilyActivitySelection] = [:]
    
    private init() {}
    
    // MARK: - Process Selected Apps
    // ✅ Process FamilyActivitySelection and organize by category
    // Uses tokens directly - no bundle ID extraction needed
    func processSelectedApps(_ selection: FamilyActivitySelection) {
        // Update UI state immediately on main thread
        isLoading = true
        currentSelection = selection
        
        // Process on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
        
        var apps: [RealInstalledApp] = []
            var tokenHashMap: [String: AnyHashable] = [:]
            
            print("📱 Processing selection:")
            print("   Application tokens: \(selection.applicationTokens.count)")
            print("   Category tokens: \(selection.categoryTokens.count)")
            print("   Web domain tokens: \(selection.webDomainTokens.count)")
            
            // ✅ Process ApplicationToken (individual apps)
        for token in selection.applicationTokens {
                let tokenHash = String(token.hashValue)
                tokenHashMap[tokenHash] = token
                
                let app = RealInstalledApp(
                    token: token,
                    tokenType: .application
                )
                apps.append(app)
                
                print("   ✅ App token: hash=\(tokenHash)")
            }
            
            // ✅ Process ActivityCategoryToken (app categories)
            for token in selection.categoryTokens {
                let tokenHash = String(token.hashValue)
                tokenHashMap[tokenHash] = token
                
                let app = RealInstalledApp(
                    token: token,
                    tokenType: .category
                )
                apps.append(app)
                
                print("   ✅ Category token: hash=\(tokenHash)")
            }
            
            // ✅ Process WebDomainToken (websites)
            for token in selection.webDomainTokens {
                let tokenHash = String(token.hashValue)
                tokenHashMap[tokenHash] = token
            
            let app = RealInstalledApp(
                token: token,
                    tokenType: .webDomain
            )
            apps.append(app)
                
                print("   ✅ Web domain token: hash=\(tokenHash)")
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
                categorized[category]?.sort { $0.tokenHash < $1.tokenHash }
        }
        
            // Update UI on main thread
        DispatchQueue.main.async {
            self.categorizedApps = categorized
            self.selectedApps = selection.applicationTokens
                self.tokenHashToTokenMap = tokenHashMap
            self.isLoading = false
        }
            
            print("✅ Processed \(apps.count) items into \(categorized.keys.count) categories")
        }
    }
    
    // MARK: - Get Selection for Token Hash
    // ✅ Get a FamilyActivitySelection for a specific token hash
    func getSelectionForTokenHash(_ tokenHash: String) -> FamilyActivitySelection? {
        // Check if we have a stored selection for this token hash
        if let selection = tokenHashToSelectionMap[tokenHash] {
            return selection
        }
        
        // Otherwise, try to create one from current selection
        guard let token = tokenHashToTokenMap[tokenHash] else {
            return nil
        }
        
        // Create a selection with just this token
        var selection = FamilyActivitySelection()
        
        // Determine token type and add to appropriate collection
        // Note: We can't directly check token type, so we try all collections
        // The system will handle which one is valid
        
        // Try as application token
        if let appToken = token as? ApplicationToken {
            selection.applicationTokens = [appToken]
            tokenHashToSelectionMap[tokenHash] = selection
            return selection
        }
        
        // Try as category token
        if let categoryToken = token as? ActivityCategoryToken {
            selection.categoryTokens = [categoryToken]
            tokenHashToSelectionMap[tokenHash] = selection
            return selection
        }
        
        // Try as web domain token
        if let webToken = token as? WebDomainToken {
            selection.webDomainTokens = [webToken]
            tokenHashToSelectionMap[tokenHash] = selection
            return selection
        }
        
        // Fallback: Use current selection if token is in it
        // Check if token exists in current selection
        let currentHash = String(token.hashValue)
        if currentHash == tokenHash {
            // Token is in current selection, return it
            return currentSelection
        }
        
        return nil
    }
    
    // MARK: - Get Token by Hash
    // ✅ Get the actual token object from its hash
    func getToken(for tokenHash: String) -> AnyHashable? {
        return tokenHashToTokenMap[tokenHash]
    }
    
    // MARK: - Store Selection for Token Hash
    // ✅ Store a FamilyActivitySelection for a specific token hash
    func storeSelection(_ selection: FamilyActivitySelection, forTokenHash tokenHash: String) {
        tokenHashToSelectionMap[tokenHash] = selection
    }
    
    // MARK: - Get Apps by Category
    func getApps(for category: AppCategory) -> [RealInstalledApp] {
        return categorizedApps[category] ?? []
    }
    
    // MARK: - Get All Categories
    func getAllCategories() -> [AppCategory] {
        return AppCategory.allCases.filter { !getApps(for: $0).isEmpty }
    }
    
    // MARK: - Get Token Hash from Selection
    // ✅ Extract token hash from a FamilyActivitySelection
    // Returns the first application token hash, or nil if none
    func getFirstTokenHash(from selection: FamilyActivitySelection) -> String? {
        if let firstToken = selection.applicationTokens.first {
            return String(firstToken.hashValue)
        }
        if let firstToken = selection.categoryTokens.first {
            return String(firstToken.hashValue)
        }
        if let firstToken = selection.webDomainTokens.first {
            return String(firstToken.hashValue)
        }
        return nil
    }
    
    // MARK: - Create Selection from Token Hash
    // ✅ Create a FamilyActivitySelection containing only the specified token
    func createSelection(for tokenHash: String) -> FamilyActivitySelection? {
        guard let token = tokenHashToTokenMap[tokenHash] else {
            return nil
        }
        
        var selection = FamilyActivitySelection()
        
        // Try to add as application token
        if let appToken = token as? ApplicationToken {
            selection.applicationTokens = [appToken]
            return selection
        }
        
        // Try to add as category token
        if let categoryToken = token as? ActivityCategoryToken {
            selection.categoryTokens = [categoryToken]
            return selection
        }
        
        // Try to add as web domain token
        if let webToken = token as? WebDomainToken {
            selection.webDomainTokens = [webToken]
            return selection
        }
        
        return nil
    }
    
    // MARK: - Check if Token Hash Exists
    // ✅ Check if we have a token for the given hash
    func hasToken(for tokenHash: String) -> Bool {
        return tokenHashToTokenMap[tokenHash] != nil
    }
    
    // MARK: - Clear All Data
    // ✅ Clear all stored selections and mappings
    func clearAll() {
        currentSelection = FamilyActivitySelection()
        categorizedApps = [:]
        selectedApps = []
        tokenHashToTokenMap = [:]
        tokenHashToSelectionMap = [:]
        isLoading = false
    }
}

// MARK: - Token Type Helpers
extension RealAppDiscoveryService {
    /// Determine if a token is an ApplicationToken, ActivityCategoryToken, or WebDomainToken
    func getTokenType(for token: AnyHashable) -> AppCategory.TokenType? {
        if token is ApplicationToken {
            return .application
        } else if token is ActivityCategoryToken {
            return .category
        } else if token is WebDomainToken {
            return .webDomain
        }
        return nil
    }
    
    /// Get all application tokens from a selection
    func getApplicationTokens(from selection: FamilyActivitySelection) -> [ApplicationToken] {
        return Array(selection.applicationTokens)
    }
    
    /// Get all category tokens from a selection
    func getCategoryTokens(from selection: FamilyActivitySelection) -> [ActivityCategoryToken] {
        return Array(selection.categoryTokens)
    }
    
    /// Get all web domain tokens from a selection
    func getWebDomainTokens(from selection: FamilyActivitySelection) -> [WebDomainToken] {
        return Array(selection.webDomainTokens)
    }
}

// MARK: - Backward Compatibility Helpers
// ⚠️ These methods are for logging/debugging only
// ✅ For UI display, use Label(token) instead!
extension RealAppDiscoveryService {
    /// Get a display name for logging/debugging purposes
    /// ⚠️ DO NOT use this for UI - use Label(token) instead!
    /// This returns a placeholder string based on token type
    func extractDisplayName(from token: AnyHashable) -> String {
        if token is ApplicationToken {
            return "App (hash: \(token.hashValue))"
        } else if token is ActivityCategoryToken {
            return "Category (hash: \(token.hashValue))"
        } else if token is WebDomainToken {
            return "Web Domain (hash: \(token.hashValue))"
        }
        return "Unknown Token (hash: \(token.hashValue))"
    }
    
    /// ⚠️ DEPRECATED: Bundle ID extraction is not possible
    /// Returns nil - use token hash instead
    func extractBundleID(from token: AnyHashable) -> String? {
        // Bundle IDs cannot be extracted from tokens in the main app
        // Use token hash as identifier instead
        return nil
    }
    
    /// ⚠️ DEPRECATED: Bundle ID validation is not needed
    /// Returns false - use token hash instead
    func isValidBundleID(_ bundleID: String?) -> Bool {
        // Bundle IDs are not used - tokens are the source of truth
        return false
    }
}

