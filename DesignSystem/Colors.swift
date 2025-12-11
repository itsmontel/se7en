import SwiftUI

extension Color {
    // Primary Colors
    static let sevenIndigo = Color(hex: "#4F46E5")
    static let sevenSkyBlue = Color(hex: "#0EA5E9")
    static let sevenEmerald = Color(hex: "#10B981")
    static let sevenAmber = Color(hex: "#F59E0B")
    static let sevenRose = Color(hex: "#F43F5E")
    static let sevenCharcoal = Color(hex: "#111827")
    static let sevenSilver = Color(hex: "#F3F4F6")
    
    // Semantic Colors
    static let primary = sevenIndigo
    static let secondary = sevenSkyBlue
    static let success = sevenEmerald
    static let warning = sevenAmber
    static let error = sevenRose
    
    static var textPrimary: Color {
        Color(UIColor.label)
    }
    
    static var textSecondary: Color {
        Color(UIColor.secondaryLabel)
    }
    
    static var appBackground: Color {
        Color(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0) // Slightly darker charcoal color for dark mode
            } else {
                // Stronger yellow tint: #FFFAE6 (RGB: 255, 250, 230)
                return UIColor(red: 1.0, green: 0.98, blue: 0.9, alpha: 1.0)
            }
        })
    }
    
    static var cardBackground: Color {
        Color(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.22, green: 0.22, blue: 0.23, alpha: 1.0) // Slightly darker charcoal for cards
            } else {
                // Light yellow tint for cards: #FFFCF0 (RGB: 255, 252, 240)
                return UIColor(red: 1.0, green: 0.988, blue: 0.941, alpha: 1.0)
            }
        })
    }
    
    static var elevatedBackground: Color {
        Color(UIColor.tertiarySystemBackground)
    }
    
    // Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


