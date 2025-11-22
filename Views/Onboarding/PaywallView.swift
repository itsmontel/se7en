import SwiftUI

struct PaywallView: View {
    let onComplete: () -> Void
    @StateObject private var storeKitService = StoreKitService.shared
    @State private var titleAnimation = false
    @State private var creditsAnimation = false
    @State private var featuresAnimation = false
    @State private var buttonAnimation = false
    @State private var isPurchasing = false
    @State private var subscriptionPrice: String = "$6.99"
    @State private var subscriptionPeriod: String = "14 days"
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            VStack(spacing: 0) {
                // Progress bar at top
                OnboardingProgressBar(currentStep: 7, totalSteps: 7)
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                
                Spacer()
                
                // Subscription Header Section
                VStack(spacing: 20) {
                    // Badge
                    Text("7-Day Free Trial")
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
                        Text("Start your free trial")
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
                        
                        Text("Then \(subscriptionPrice) every \(subscriptionPeriod)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary.opacity(0.7))
                            .scaleEffect(titleAnimation ? 1.0 : 0.8)
                            .opacity(titleAnimation ? 1.0 : 0.0)
                    }
                }
                
                // Subscription Pricing Card
                VStack(spacing: 32) {
                    // Main pricing display
                    VStack(spacing: 16) {
                        // Price with enhanced styling
                        Text(subscriptionPrice)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.sevenIndigo, Color.sevenSkyBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(creditsAnimation ? 1.0 : 0.6)
                            .opacity(creditsAnimation ? 1.0 : 0.0)
                        
                        Text("every \(subscriptionPeriod)")
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
                                text: "7 days free, then \(subscriptionPrice) every \(subscriptionPeriod)",
                                isAnimated: featuresAnimation
                            )
                            PremiumFeatureBullet(
                                text: "Start with 7 credits",
                                isAnimated: featuresAnimation,
                                delay: 0.1
                            )
                            PremiumFeatureBullet(
                                text: "Cancel anytime",
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
                
                // Subscribe CTA Section
                VStack(spacing: 20) {
                    Button(action: purchaseSubscription) {
                        HStack(spacing: 16) {
                            if isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            
                            Text(isPurchasing ? "Processing..." : "Start Free Trial")
                                .font(.system(size: 20, weight: .bold))
                            
                            if !isPurchasing {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                            }
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
                    .disabled(isPurchasing)
                    .scaleEffect(buttonAnimation ? 1.0 : 0.8)
                    .opacity(buttonAnimation ? 1.0 : 0.0)
                    .padding(.horizontal, 32)
                    
                    VStack(spacing: 8) {
                        Text("7-day free trial, then \(subscriptionPrice) every \(subscriptionPeriod). Cancel anytime.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textPrimary.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 16) {
                            Label("Free Trial", systemImage: "gift.fill")
                            Label("Cancel Anytime", systemImage: "xmark.circle.fill")
                            Label("Auto-Renews", systemImage: "arrow.clockwise")
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
            // Load subscription info
            Task {
                await storeKitService.loadProducts()
                if let subscriptionInfo = storeKitService.getSubscriptionInfo() {
                    subscriptionPrice = subscriptionInfo.price
                    subscriptionPeriod = subscriptionInfo.period
                }
            }
            
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
    
    private func purchaseSubscription() {
        isPurchasing = true
        HapticFeedback.medium.trigger()
        
        Task {
            let success = await storeKitService.purchaseSubscription()
            
            await MainActor.run {
                isPurchasing = false
                
                if success {
                    HapticFeedback.success.trigger()
                    onComplete()
                } else {
                    HapticFeedback.error.trigger()
                }
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