//
//  ShieldConfigurationExtension.swift
//  SE7ENShieldConfigurationExtension
//
//  Customizes the shield UI when apps are blocked
//  Matches LimitReachedPuzzleView styling exactly
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Get app name
        let appName = application.localizedDisplayName ?? "this app"
        
        // Create pink-tinted heart icon to match LimitReachedPuzzleView
        let heartIcon = UIImage(systemName: "heart.fill")?
            .withTintColor(UIColor.systemPink, renderingMode: .alwaysOriginal)
        
        // Match the exact text from LimitReachedPuzzleView
        // Title: "Daily Limit Reached"
        // Subtitle: "That's okay, it happens 😊\nYou've reached your limit for \(appName)"
        let subtitleText = "That's okay, it happens 😊\nYou've reached your limit for \(appName)"
        
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor.systemBackground,
            icon: heartIcon,
            title: ShieldConfiguration.Label(
                text: "Daily Limit Reached",
                color: UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitleText,
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Start Puzzle",
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor.label, // Matches the gradient button in LimitReachedPuzzleView
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "I CAN WAIT TILL TOMORROW",
                color: UIColor.secondaryLabel
            )
        )
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Same configuration for category-based shields
        return configuration(shielding: application)
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let domainName = webDomain.domain ?? "this website"
        
        // Create pink-tinted heart icon
        let heartIcon = UIImage(systemName: "heart.fill")?
            .withTintColor(UIColor.systemPink, renderingMode: .alwaysOriginal)
        
        let subtitleText = "That's okay, it happens 😊\nYou've reached your limit for \(domainName)"
        
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor.systemBackground,
            icon: heartIcon,
            title: ShieldConfiguration.Label(
                text: "Daily Limit Reached",
                color: UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitleText,
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Start Puzzle",
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor.label,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "I CAN WAIT TILL TOMORROW",
                color: UIColor.secondaryLabel
            )
        )
    }
}
