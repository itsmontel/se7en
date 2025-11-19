import SwiftUI

extension Font {
    // Display - SF Pro Rounded
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 36, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 28, weight: .semibold, design: .rounded)
    
    // Headers - SF Pro Text
    static let h1 = Font.system(size: 32, weight: .bold)
    static let h2 = Font.system(size: 24, weight: .bold)
    static let h3 = Font.system(size: 20, weight: .semibold)
    static let h4 = Font.system(size: 18, weight: .semibold)
    
    // Body - SF Pro Text
    static let bodyLarge = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)
    
    // Numbers - SF Mono
    static let numberLarge = Font.system(size: 72, weight: .medium, design: .monospaced)
    static let numberMedium = Font.system(size: 48, weight: .medium, design: .monospaced)
    static let numberSmall = Font.system(size: 24, weight: .medium, design: .monospaced)
    
    // Caption
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionBold = Font.system(size: 12, weight: .semibold)
}


