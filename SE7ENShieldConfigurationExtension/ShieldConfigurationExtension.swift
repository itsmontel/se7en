import ManagedSettings
import ManagedSettingsUI
import UIKit
import FamilyControls
import AVFoundation
import AVKit

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
        
        // Get pet type for sick animation/image
        let petType = getUserPetType()
        
        // Get unblock duration
        let unblockDuration = getUnblockDuration()
        
        // Use yellow background color from app design
        // Light mode: #FFFAE6 (RGB: 255, 250, 230)
        let backgroundColor = UIColor(red: 1.0, green: 0.98, blue: 0.9, alpha: 1.0)
        let primaryColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        
        // Get sick pet image (static for now - extensions have limitations with video)
        let sickPetIcon = getSickPetImage(for: petType)
        
        // Build personalized title
        let titleText = firstName.isEmpty ? "App Blocked" : "Hey \(firstName)!"
        
        // Build subtitle with actual unblock duration
        let durationText = unblockDuration == 60 ? "1 hour" : "\(unblockDuration) minutes"
        let subtitleText = "\(appName) is blocked ❤️\n\nSolve a puzzle in SE7EN to unblock for \(durationText)!"
        
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial, // Use subtle blur over yellow
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
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            #if DEBUG
            print("⚠️ Shield: Could not access shared UserDefaults")
            #endif
            return 15
        }
        
        defaults.synchronize()
        let duration = defaults.integer(forKey: "unblock_duration_minutes")
        
        #if DEBUG
        print("🛡️ Shield: Unblock duration from settings: \(duration) minutes")
        #endif
        
        return duration > 0 ? duration : 15
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
    
    // MARK: - Get Sick Pet Animation Thumbnail
    
    private func getSickPetAnimationThumbnail(for petType: String) -> UIImage? {
        // Detect dark mode
        let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        
        // Animation file names: DogSickAnimation.mp4 (light) or DarkDogSickAnimation.mp4 (dark)
        let baseName: String
        
        switch petType.lowercased() {
        case "dog":
            baseName = "DogSickAnimation"
        case "cat":
            baseName = "CatSickAnimation"
        case "bunny":
            baseName = "BunnySickAnimation"
        case "hamster":
            baseName = "HamsterSickAnimation"
        case "horse":
            baseName = "HorseSickAnimation"
        default:
            baseName = "DogSickAnimation"
        }
        
        // Add "Dark" prefix for dark mode
        let animationName = isDarkMode ? "Dark\(baseName)" : baseName
        
        #if DEBUG
        print("🛡️ Shield: Looking for animation: \(animationName).mp4 (isDarkMode: \(isDarkMode))")
        #endif
        
        // Try to load animation from Animation folder
        if let videoURL = Bundle.main.url(forResource: animationName, withExtension: "mp4", subdirectory: "Animation") {
            #if DEBUG
            print("✅ Shield: Found animation at: \(videoURL.path)")
            #endif
            return generateThumbnail(from: videoURL)
        }
        
        // Fallback: try without subdirectory
        if let videoURL = Bundle.main.url(forResource: animationName, withExtension: "mp4") {
            #if DEBUG
            print("✅ Shield: Found animation (no subdirectory) at: \(videoURL.path)")
            #endif
            return generateThumbnail(from: videoURL)
        }
        
        #if DEBUG
        print("⚠️ Shield: Animation not found, falling back to static image")
        #endif
        
        return nil
    }
    
    // MARK: - Generate Video Thumbnail
    
    private func generateThumbnail(from videoURL: URL) -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Get frame from 0.5 seconds into the video
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            #if DEBUG
            print("⚠️ Failed to generate thumbnail from video: \(error)")
            #endif
            return nil
        }
    }
    
    // MARK: - Get Sick Pet Image (Fallback)
    
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
        
        #if DEBUG
        print("🛡️ Shield: Loading static image: \(imageName)")
        #endif
        
        // Load from extension's asset catalog
        let image = UIImage(named: imageName)
        
        #if DEBUG
        if image != nil {
            print("✅ Shield: Static image loaded successfully")
        } else {
            print("⚠️ Shield: Failed to load static image")
        }
        #endif
        
        return image
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
