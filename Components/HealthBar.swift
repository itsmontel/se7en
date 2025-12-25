import SwiftUI

struct HealthBar: View {
    let healthValue: Int
    let animated: Bool
    
    @State private var animatedValue: CGFloat = 0
    
    init(healthValue: Int, animated: Bool = true) {
        self.healthValue = healthValue
        self.animated = animated
    }
    
    private var healthColor: Color {
        switch healthValue {
        case 80...100:
            return .success
        case 60..<80:
            return Color(red: 0.5, green: 0.85, blue: 0.7) // Watery green like happy state
        case 40..<60:
            return .warning
        case 20..<40:
            return .orange
        default:
            return .error
        }
    }
    
    private var brighterHealthColor: Color {
        switch healthValue {
        case 80...100:
            // Brighter, more vibrant green
            return Color(red: 0.2, green: 0.9, blue: 0.4)
        case 60..<80:
            return Color(red: 0.4, green: 0.9, blue: 0.6) // Brighter light green
        case 40..<60:
            return .warning
        case 20..<40:
            return .orange
        default:
            return .error
        }
    }
    
    private var healthText: String {
        switch healthValue {
        case 80...100:
            return "Excellent"
        case 60..<80:
            return "Good"
        case 40..<60:
            return "Fair"
        case 20..<40:
            return "Poor"
        default:
            return "Critical"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Health Value Display - Smaller number centered
            Text("\(healthValue)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
                .onAppear {
                    print("🏥 [HEALTH_BAR] HealthBar rendered with value: \(healthValue)")
                }
                .onChange(of: healthValue) { newValue in
                    print("🏥 [HEALTH_BAR] HealthBar value changed to: \(newValue)")
                }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    // Progress Fill - Brighter green
                    RoundedRectangle(cornerRadius: 6)
                        .fill(brighterHealthColor)
                        .frame(
                            width: geometry.size.width * (animatedValue / 100),
                            height: 12
                        )
                        .animation(
                            animated ? .spring(response: 1.0, dampingFraction: 0.6) : nil,
                            value: animatedValue
                        )
                }
            }
            .frame(height: 12)
            
            // Health label below bar (not caps)
            Text("Health")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textSecondary)
                .tracking(1)
                .padding(.top, 4)
        }
        .onAppear {
            if animated {
                // Delay the animation slightly for a nice reveal effect
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animatedValue = CGFloat(healthValue)
                }
            } else {
                animatedValue = CGFloat(healthValue)
            }
        }
        .onChange(of: healthValue) { newValue in
            animatedValue = CGFloat(newValue)
        }
    }
}

// MARK: - Preview
struct HealthBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HealthBar(healthValue: 100)
                .cardStyle()
            
            HealthBar(healthValue: 75)
                .cardStyle()
            
            HealthBar(healthValue: 50)
                .cardStyle()
            
            HealthBar(healthValue: 25)
                .cardStyle()
            
            HealthBar(healthValue: 5)
                .cardStyle()
        }
        .padding()
        .background(Color.appBackground)
        .previewLayout(.sizeThatFits)
    }
}
