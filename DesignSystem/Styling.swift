import SwiftUI

// MARK: - Corner Radius
struct DesignSystem {
    static let cornerRadiusSmall: CGFloat = 12
    static let cornerRadiusMedium: CGFloat = 20
    static let cornerRadiusLarge: CGFloat = 28
    
    static let shadowRadius: CGFloat = 20
    static let shadowOpacity: Double = 0.08
    
    static let animationDuration: Double = 0.35
    static let springResponse: Double = 0.35
    static let springDamping: Double = 0.7
}

// MARK: - Card Modifier
struct CardModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.cornerRadiusMedium
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBackground)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(DesignSystem.shadowOpacity), 
                   radius: DesignSystem.shadowRadius, x: 0, y: 4)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = DesignSystem.cornerRadiusMedium, 
                  padding: CGFloat = 16) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.h4)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isEnabled ? Color.primary : Color.gray)
            .cornerRadius(DesignSystem.cornerRadiusMedium)
            .shadow(color: Color.primary.opacity(0.3), 
                   radius: configuration.isPressed ? 5 : 10, 
                   x: 0, y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: DesignSystem.springResponse, 
                             dampingFraction: DesignSystem.springDamping), 
                      value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.h4)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(DesignSystem.cornerRadiusMedium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: DesignSystem.springResponse, 
                             dampingFraction: DesignSystem.springDamping), 
                      value: configuration.isPressed)
    }
}

// MARK: - Haptic Feedback
enum HapticFeedback {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    
    func trigger() {
        switch self {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

extension View {
    func hapticFeedback(_ style: HapticFeedback) -> some View {
        self.onAppear {
            style.trigger()
        }
    }
}


