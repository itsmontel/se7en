import SwiftUI

struct PaywallView: View {
    let onComplete: () -> Void
    @State private var titleAnimation = false
    @State private var creditsAnimation = false
    @State private var featuresAnimation = false
    @State private var buttonAnimation = false
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            VStack(spacing: 0) {
                // Progress bar at top
                OnboardingProgressBar(currentStep: 7, totalSteps: 7)
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                
                Spacer()
                
                // Free App Header Section
                VStack(spacing: 20) {
                    // Badge
                    Text("Free Forever")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color.sevenEmerald, Color.sevenSkyBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                        .scaleEffect(titleAnimation ? 1.0 : 0.6)
                        .opacity(titleAnimation ? 1.0 : 0.0)
                    
                    VStack(spacing: 16) {
                        Text("Start with 7 credits")
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
                        
                        Text("SE7EN is completely free")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary.opacity(0.7))
                            .scaleEffect(titleAnimation ? 1.0 : 0.8)
                            .opacity(titleAnimation ? 1.0 : 0.0)
                    }
                }
                
                // Credits Display Card
                VStack(spacing: 32) {
                    // Main credits display
                    VStack(spacing: 16) {
                        // Large "7" display
                        Text("7")
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.sevenIndigo, Color.sevenSkyBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(creditsAnimation ? 1.0 : 0.6)
                            .opacity(creditsAnimation ? 1.0 : 0.0)
                        
                        Text("credits to start")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.textPrimary.opacity(0.7))
                            .scaleEffect(creditsAnimation ? 1.0 : 0.6)
                            .opacity(creditsAnimation ? 1.0 : 0.0)
                        
                        // Divider with gradient
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.sevenIndigo.opacity(0.3), Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                            .scaleEffect(creditsAnimation ? 1.0 : 0.0)
                            .opacity(creditsAnimation ? 1.0 : 0.0)
                        
                        // Enhanced Feature List
                        VStack(spacing: 16) {
                            PremiumFeatureBullet(
                                text: "App is completely free",
                                isAnimated: featuresAnimation
                            )
                            PremiumFeatureBullet(
                                text: "Keep all 7 credits = stay free",
                                isAnimated: featuresAnimation,
                                delay: 0.1
                            )
                            PremiumFeatureBullet(
                                text: "Only pay if you lose credits",
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
                            .shadow(color: Color.sevenIndigo.opacity(0.08), radius: 30, x: 0, y: 15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.sevenIndigo.opacity(0.15), Color.clear],
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
                
                // Get Started CTA Section
                VStack(spacing: 20) {
                    Button(action: {
                        HapticFeedback.success.trigger()
                        onComplete()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20, weight: .bold))
                            
                            Text("Get Started Free")
                                .font(.system(size: 20, weight: .bold))
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(
                            LinearGradient(
                                colors: [Color.sevenIndigo, Color.sevenSkyBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: .sevenIndigo.opacity(0.4), radius: 25, x: 0, y: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .scaleEffect(buttonAnimation ? 1.0 : 0.8)
                    .opacity(buttonAnimation ? 1.0 : 0.0)
                    .padding(.horizontal, 32)
                    
                    VStack(spacing: 8) {
                        Text("No subscription. No weekly fees. Only pay for credits you lose.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textPrimary.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 16) {
                            Label("Free", systemImage: "gift.fill")
                            Label("No Subscription", systemImage: "xmark.circle.fill")
                            Label("Pay As You Go", systemImage: "creditcard.fill")
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                titleAnimation = true
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                creditsAnimation = true
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