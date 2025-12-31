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
        
        // Get pet type for sick animation/image
        let petType = getUserPetType()
        
        // Get unblock duration
        let unblockDuration = getUnblockDuration()
        
        // Use yellow background color from app design
        let backgroundColor = UIColor(red: 1.0, green: 0.98, blue: 0.9, alpha: 1.0)
        let primaryColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        
        // Get sick pet image
        let sickPetIcon = getSickPetImage(for: petType)
        
        // Build personalized title
        let titleText = firstName.isEmpty ? "App Blocked" : "Hey \(firstName)!"
        
        // Build subtitle with actual unblock duration
        let durationText = unblockDuration == 60 ? "1 hour" : "\(unblockDuration) minutes"
        let subtitleText = "\(appName) is blocked ❤️\n\nSolve a puzzle in SE7EN to unblock for \(durationText)!"
        
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: backgroundColor,
            icon: sickPetIcon,
            title: ShieldConfiguration.Label(
                text: titleText,
                color: UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitleText,
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "🧩 Solve Puzzle to Unblock",
                color: .white
            ),
            primaryButtonBackgroundColor: primaryColor,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Stay Focused",
                color: UIColor.secondaryLabel
            )
        )
    }
    
    // MARK: - Get Unblock Duration
    
    private func getUnblockDuration() -> Int {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return 15 }
        defaults.synchronize()
        let duration = defaults.integer(forKey: "unblock_duration_minutes")
        return duration > 0 ? duration : 15
    }
    
    // MARK: - Get User First Name
    
    private func getUserFirstName() -> String {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return "" }
        
        if let firstName = defaults.string(forKey: "user_first_name"), !firstName.isEmpty {
            return firstName
        }
        
        if let userName = defaults.string(forKey: "userName"), !userName.isEmpty {
            return userName.components(separatedBy: " ").first ?? userName
        }
        
        return ""
    }
    
    // MARK: - Get User Pet Type
    
    private func getUserPetType() -> String {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return "dog" }
        return defaults.string(forKey: "user_pet_type")?.lowercased() ?? "dog"
    }
    
    // MARK: - Get Sick Pet Image
    
    private func getSickPetImage(for petType: String) -> UIImage? {
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
        
        return UIImage(named: imageName)
    }
    
    // MARK: - Get App Name Helper
    
    private func getAppNameFromStoredLimits(tokenHash: String) -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        
        if let storedName = defaults.string(forKey: "limitAppName_\(tokenHash)"), !storedName.isEmpty {
            return storedName
        }
        
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
