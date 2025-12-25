import SwiftUI

struct WhyItWorksView: View {
    let onContinue: () -> Void
    @State private var titleAnimation = false
    @State private var cardAnimations = [false, false]
    @State private var buttonAnimation = false
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Progress bar at top
                    OnboardingProgressBar(currentStep: 6, totalSteps: 8)
                        .padding(.top, 60)
                        .padding(.horizontal, 24)
                    
                    // Enhanced Title Section
                    VStack(spacing: 12) {
                        Text("Why this works")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .scaleEffect(titleAnimation ? 1.0 : 0.8)
                            .opacity(titleAnimation ? 1.0 : 0.0)
                        
                        Text("Psychology meets technology")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .scaleEffect(titleAnimation ? 1.0 : 0.8)
                            .opacity(titleAnimation ? 1.0 : 0.0)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Enhanced Illustration Cards
                    VStack(spacing: 20) {
                        PremiumIllustrationCard(
                            icon: "brain.head.profile",
                            title: "Accountability Creates Change",
                            description: "When there's something on the line, you follow through.",
                            color: .primary,
                            isAnimated: cardAnimations[0]
                        )
                        
                        PremiumIllustrationCard(
                            icon: "dollarsign.circle.fill",
                            title: "Pay Only For What You Lose",
                            description: "7 credits = a free week.\nLess than 7 = you pay the difference.",
                            color: .success,
                            isAnimated: cardAnimations[1]
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    
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
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                titleAnimation = true
            }
            
            for index in 0..<cardAnimations.count {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3 + Double(index) * 0.3)) {
                    cardAnimations[index] = true
                }
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.9)) {
                buttonAnimation = true
            }
        }
    }
}

struct PremiumIllustrationCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let isAnimated: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon Section
            ZStack {
                // Outer glow effect
                Circle()
                    .fill(color.opacity(0.08))
                    .frame(width: 90, height: 90)
                    .blur(radius: 12)
                
                // Icon background with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.15), color.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [color.opacity(0.2), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(isAnimated ? 1.0 : 0.6)
            .opacity(isAnimated ? 1.0 : 0.0)
            
            // Enhanced Text Section
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .scaleEffect(isAnimated ? 1.0 : 0.8)
                    .opacity(isAnimated ? 1.0 : 0.0)
                
                Text(description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textPrimary.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .scaleEffect(isAnimated ? 1.0 : 0.8)
                    .opacity(isAnimated ? 1.0 : 0.0)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.cardBackground)
                .shadow(color: color.opacity(0.08), radius: 20, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
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
        .scaleEffect(isAnimated ? 1.0 : 0.85)
        .opacity(isAnimated ? 1.0 : 0.0)
    }
}