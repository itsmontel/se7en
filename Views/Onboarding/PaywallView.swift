import SwiftUI

struct PaywallView: View {
    let onSubscribe: () -> Void
    @State private var titleAnimation = false
    @State private var priceAnimation = false
    @State private var featuresAnimation = false
    @State private var buttonAnimation = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            VStack(spacing: 0) {
                // Progress bar at top
                OnboardingProgressBar(currentStep: 7, totalSteps: 8)
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                
                Spacer()
                
                // Premium Header Section
                VStack(spacing: 20) {
                    // Badge
                    Text("Premium")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color.primary, Color.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                        .scaleEffect(titleAnimation ? 1.0 : 0.6)
                        .opacity(titleAnimation ? 1.0 : 0.0)
                    
                    VStack(spacing: 16) {
                        Text("Start with 7 credits today")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.textPrimary, Color.textPrimary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 32)
                            .scaleEffect(titleAnimation ? 1.0 : 0.8)
                            .opacity(titleAnimation ? 1.0 : 0.0)
                        
                        Text("One week of accountability")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary.opacity(0.7))
                            .scaleEffect(titleAnimation ? 1.0 : 0.8)
                            .opacity(titleAnimation ? 1.0 : 0.0)
                    }
                }
                
                // Premium Pricing Card
                VStack(spacing: 32) {
                    // Main pricing display
                    VStack(spacing: 16) {
                        // Price with enhanced styling
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("$")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.textPrimary)
                            
                            Text("7")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.primary, Color.secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .scaleEffect(priceAnimation ? 1.0 : 0.6)
                        .opacity(priceAnimation ? 1.0 : 0.0)
                        
                        Text("per week")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.textPrimary.opacity(0.7))
                            .scaleEffect(priceAnimation ? 1.0 : 0.6)
                            .opacity(priceAnimation ? 1.0 : 0.0)
                        
                        // Divider with gradient
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.primary.opacity(0.3), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                            .scaleEffect(priceAnimation ? 1.0 : 0.0)
                            .opacity(priceAnimation ? 1.0 : 0.0)
                        
                        // Enhanced Feature List
                        VStack(spacing: 16) {
                            PremiumFeatureBullet(
                                text: "Start with 7 credits",
                                isAnimated: featuresAnimation
                            )
                            PremiumFeatureBullet(
                                text: "Keep 7 = next week free",
                                isAnimated: featuresAnimation,
                                delay: 0.1
                            )
                            PremiumFeatureBullet(
                                text: "Lose credits = pay only the difference",
                                isAnimated: featuresAnimation,
                                delay: 0.2
                            )
                        }
                        .padding(.top, 8)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.cardBackground)
                            .shadow(color: Color.primary.opacity(0.08), radius: 30, x: 0, y: 15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.primary.opacity(0.15), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                
                Spacer()
                
                // Premium CTA Section
                VStack(spacing: 20) {
                    Button(action: {
                        HapticFeedback.success.trigger()
                        onSubscribe()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 20, weight: .bold))
                            
                            Text("Start for $7")
                                .font(.system(size: 20, weight: .bold))
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(
                            LinearGradient(
                                colors: [Color.primary, Color.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: .primary.opacity(0.4), radius: 25, x: 0, y: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .scaleEffect(buttonAnimation ? 1.0 : 0.8)
                    .opacity(buttonAnimation ? 1.0 : 0.0)
                    .padding(.horizontal, 32)
                    
                    VStack(spacing: 8) {
                        Text("Cancel anytime. No charges for perfect weeks.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textPrimary.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 16) {
                            Label("Secure", systemImage: "lock.shield.fill")
                            Label("Private", systemImage: "eye.slash.fill")
                            Label("Cancel Anytime", systemImage: "xmark.circle.fill")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textPrimary.opacity(0.5))
                    }
                    .opacity(buttonAnimation ? 1.0 : 0.0)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            pulseAnimation = true
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                titleAnimation = true
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                priceAnimation = true
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5)) {
                featuresAnimation = true
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8)) {
                buttonAnimation = true
            }
        }
    }
}

struct PremiumFeatureBullet: View {
    let text: String
    let isAnimated: Bool
    let delay: Double
    
    init(text: String, isAnimated: Bool, delay: Double = 0) {
        self.text = text
        self.isAnimated = isAnimated
        self.delay = delay
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.success.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.success)
            }
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .scaleEffect(isAnimated ? 1.0 : 0.6)
        .opacity(isAnimated ? 1.0 : 0.0)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(delay), value: isAnimated)
    }
}