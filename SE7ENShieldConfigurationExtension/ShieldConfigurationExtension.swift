import ManagedSettings
import ManagedSettingsUI
import UIKit
import FamilyControls

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    private let appGroupID = "group.com.se7en.app"
    
    override init() {
        super.init()
    }
    
    // MARK: - Application Shield Configuration
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // ✅ CRITICAL: Get app name from stored limits first, then fallback to localized name
        let tokenHash = String(application.hashValue)
        let appName = getAppNameFromStoredLimits(tokenHash: tokenHash) ?? 
                     application.localizedDisplayName ?? 
                     "This app"
        
        return createShieldConfiguration(appName: appName)
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        let appName = application.localizedDisplayName ?? category.localizedDisplayName ?? "This app"
        return createShieldConfiguration(appName: appName)
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let domainName = webDomain.domain ?? "This website"
        return createShieldConfiguration(appName: domainName)
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        let domainName = webDomain.domain ?? category.localizedDisplayName ?? "This website"
        return createShieldConfiguration(appName: domainName)
    }
    
    // MARK: - Create Shield Configuration
    
    private func createShieldConfiguration(appName: String) -> ShieldConfiguration {
        // Get user's first name from shared UserDefaults
        let firstName = getUserFirstName()
        
        // Get pet type for sick image
        let petType = getUserPetType()
        
        // Custom colors - light mode
        let backgroundColor = UIColor.systemBackground
        let primaryColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        
        // Get the sick pet image from extension's asset catalog
        let sickPetImage = getSickPetImage(for: petType)
        
        // Build personalized title: "Bad News, [Name]" at top
        let titleText = firstName.isEmpty ? "Bad News" : "Bad News, \(firstName)"
        
        // Subtitle contains "Daily Limit Reached" + heart emoji + app info
        let subtitleText = "Daily Limit Reached ❤️\n\nYou hit your \(appName) limit.\nSolve a puzzle for 15 more minutes!"
        
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: backgroundColor,
            icon: sickPetImage,
            title: ShieldConfiguration.Label(
                text: titleText,
                color: UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitleText,
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "🧩 Start Puzzle",
                color: .white
            ),
            primaryButtonBackgroundColor: primaryColor,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "I'll wait till tomorrow",
                color: UIColor.secondaryLabel
            )
        )
    }
    
    // MARK: - Get User First Name
    
    private func getUserFirstName() -> String {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return ""
        }
        
        // Try dedicated first name key first
        if let firstName = defaults.string(forKey: "user_first_name"), !firstName.isEmpty {
            return firstName
        }
        
        // Fallback: extract first name from full userName
        if let userName = defaults.string(forKey: "userName"), !userName.isEmpty {
            let firstName = userName.components(separatedBy: " ").first ?? userName
            return firstName
        }
        
        return ""
    }
    
    // MARK: - Get User Pet Type
    
    private func getUserPetType() -> String {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return "dog"
        }
        
        return defaults.string(forKey: "user_pet_type")?.lowercased() ?? "dog"
    }
    
    // MARK: - Get Sick Pet Image
    
    private func getSickPetImage(for petType: String) -> UIImage? {
        // Image names match your asset catalog: dogsick, catsick, bunnysick, etc.
        let imageName: String
        
        switch petType.lowercased() {
        case "dog":
            imageName = "dogsick"
        case "cat":
            imageName = "catsick"
        case "bunny":
            imageName = "bunnysick"
        case "hamster":
            imageName = "hamstersick"
        case "horse":
            imageName = "horsesick"
        default:
            imageName = "dogsick"
        }
        
        // Load from extension's asset catalog
        return UIImage(named: imageName)
    }
    
    // MARK: - Get App Name Helper
    
    /// Get app name from stored limits using token hash
    private func getAppNameFromStoredLimits(tokenHash: String) -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        
        // First try: Check if app name was stored directly by monitor extension
        if let storedName = defaults.string(forKey: "limitAppName_\(tokenHash)"), !storedName.isEmpty {
            return storedName
        }
        
        // Second try: Look up in stored_app_limits_v2
        guard let data = defaults.data(forKey: "stored_app_limits_v2"),
              let limits = try? JSONDecoder().decode([StoredAppLimitConfig].self, from: data) else {
            return nil
        }
        
        for limit in limits {
            if let selectionData = limit.selectionData,
               let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData),
               let firstToken = selection.applicationTokens.first {
                let computedHash = String(firstToken.hashValue)
                if computedHash == tokenHash {
                    return limit.appName
                }
            }
        }
        
        return nil
    }
}

// MARK: - Helper Struct

private struct StoredAppLimitConfig: Codable {
    let id: UUID
    let appName: String
    let selectionData: Data?
}
