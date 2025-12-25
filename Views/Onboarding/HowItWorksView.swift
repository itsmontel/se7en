import SwiftUI

struct HowItWorksView: View {
    let onContinue: () -> Void
    @State private var cardAnimations = [false, false, false]
    @State private var titleAnimation = false
    @State private var buttonAnimation = false
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            VStack(spacing: 0) {
                // Progress bar at top
                OnboardingProgressBar(currentStep: 2, totalSteps: 8)
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Enhanced Title Section
                        VStack(spacing: 12) {
                            Text("How it works")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                                .scaleEffect(titleAnimation ? 1.0 : 0.8)
                                .opacity(titleAnimation ? 1.0 : 0.0)
                            
                            Text("Simple steps to digital discipline")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .scaleEffect(titleAnimation ? 1.0 : 0.8)
                                .opacity(titleAnimation ? 1.0 : 0.0)
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 32)
                    
                    // Enhanced Step Cards with progressive animation
                    VStack(spacing: 24) {
                        ForEach(Array(stepData.enumerated()), id: \.offset) { index, step in
                            EnhancedStepCard(
                                number: step.number,
                                title: step.title,
                                description: step.description,
                                icon: step.icon,
                                color: step.color,
                                isAnimated: cardAnimations[index]
                            )
                            .scaleEffect(cardAnimations[index] ? 1.0 : 0.6)
                            .opacity(cardAnimations[index] ? 1.0 : 0.0)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Enhanced CTA Button
                    VStack(spacing: 16) {
                        Button(action: {
                            HapticFeedback.light.trigger()
                            onContinue()
                        }) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(16)
                        }
                        .scaleEffect(buttonAnimation ? 1.0 : 0.95)
                        .opacity(buttonAnimation ? 1.0 : 0.0)
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 60)
                    }
                }
            }
        }
        .onAppear {
            // Staggered entrance animations
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                titleAnimation = true
            }
            
            // Animate cards with progressive delay
            for index in 0..<cardAnimations.count {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3 + Double(index) * 0.2)) {
                    cardAnimations[index] = true
                }
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.0)) {
                buttonAnimation = true
            }
        }
    }
    
    private var stepData: [(number: String, title: String, description: String, icon: String, color: Color)] {
        [
            ("1", "Set your daily app limits", "Choose which apps to monitor and set time limits for each one", "target", .primary),
            ("2", "Stay within limits to keep credits", "Exceed a limit and lose credits: 1st failure = 1 credit, 2nd = 2 credits, and so on. Credits reset to 7 daily at midnight.", "checkmark.circle.fill", .success),
            ("3", "Accountability fee to unblock", "If an app is blocked, you need 7 credits (accountability fee) to unblock it. Once paid, no additional credits are deducted for failures that day.", "creditcard.fill", .warning)
        ]
    }
}

struct EnhancedStepCard: View {
    let number: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isAnimated: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon with gradient background
            ZStack {
                // Outer glow
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .blur(radius: 8)
                
                // Main circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.15), color.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Step number with enhanced styling
                Text("Step \(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.textPrimary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.cardBackground)
                .shadow(color: color.opacity(0.1), radius: 18, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.1), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}