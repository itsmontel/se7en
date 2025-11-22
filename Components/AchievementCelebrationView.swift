import SwiftUI

struct AchievementCelebrationView: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    
    @State private var showBackground = false
    @State private var showIcon = false
    @State private var iconScale: CGFloat = 0.0
    @State private var iconRotation: Double = 360
    @State private var iconBounce: CGFloat = 0
    @State private var showTitle = false
    @State private var titleOffset: CGFloat = 30
    @State private var showDescription = false
    @State private var descriptionOffset: CGFloat = 20
    @State private var showButton = false
    @State private var buttonScale: CGFloat = 0.0
    @State private var confettiActive = false
    @State private var sparkles: [Sparkle] = []
    @State private var ringPulse: CGFloat = 0
    @State private var backgroundBlur: CGFloat = 0
    @State private var glowIntensity: Double = 0
    
    // Confetti particles
    @State private var confettiParticles: [ConfettiParticle] = []
    
    var body: some View {
        ZStack {
            // Animated background overlay
            Color.black
                .opacity(showBackground ? 0.6 : 0)
                .ignoresSafeArea()
                .blur(radius: backgroundBlur)
                .animation(.easeOut(duration: 0.4), value: showBackground)
                .onTapGesture {
                    dismissCelebration()
                }
            
            // Main celebration content
            if showBackground {
                celebrationContent
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Confetti layer
            if confettiActive {
                ConfettiView(particles: confettiParticles)
            }
            
            // Sparkles
            ForEach(sparkles) { sparkle in
                SparkleView(sparkle: sparkle)
            }
        }
        .onAppear {
            startCelebration()
        }
    }
    
    private var celebrationContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Outer glow ring
            ZStack {
                // Subtle pulsing ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                achievementColor.opacity(0.4),
                                achievementColor.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 220, height: 220)
                    .scaleEffect(1.0 + ringPulse * 0.05)
                    .opacity(0.6)
                
                // Main content container
                VStack(spacing: 20) {
                    // Achievement icon with animation
                    if showIcon {
                        iconView
                            .scaleEffect(iconScale)
                            .rotationEffect(.degrees(iconRotation))
                            .offset(y: iconBounce)
                            .shadow(color: achievementColor.opacity(0.5), radius: 20, x: 0, y: 10)
                    }
                    
                    // Title
                    if showTitle {
                        titleView
                            .offset(y: titleOffset)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Description
                    if showDescription {
                        descriptionView
                            .offset(y: descriptionOffset)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Continue button
                    if showButton {
                        continueButton
                            .scaleEffect(buttonScale)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.cardBackground)
                        .shadow(color: achievementColor.opacity(glowIntensity * 0.3), radius: 30, x: 0, y: 10)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 5)
                )
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
    }
    
    private var iconView: some View {
        ZStack {
            // Subtle glow layer
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            achievementColor.opacity(0.2),
                            achievementColor.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 20)
            
            // Achievement icon
            ZStack {
                Circle()
                    .fill(achievementColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundColor(achievementColor)
            }
            .shadow(color: achievementColor.opacity(0.3), radius: 15, x: 0, y: 5)
        }
    }
    
    private var titleView: some View {
        VStack(spacing: 8) {
            // Rarity badge
            Text(rarityText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(achievementColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(achievementColor.opacity(0.15))
                .cornerRadius(12)
            
            // Achievement title
            Text(achievement.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var descriptionView: some View {
        Text(achievement.description)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
    
    private var continueButton: some View {
        Button(action: dismissCelebration) {
            HStack(spacing: 8) {
                Text("Awesome!")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(achievementColor)
            .cornerRadius(20)
            .shadow(color: achievementColor.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Animation Functions
    
    private func startCelebration() {
        // Generate confetti and sparkles
        generateConfetti()
        generateSparkles()
        
        // Stage 1: Background fade in
        withAnimation(.easeOut(duration: 0.4)) {
            showBackground = true
            backgroundBlur = 10
        }
        
        // Stage 2: Icon entrance (dramatic)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                showIcon = true
                iconRotation = 0
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.4).delay(0.1)) {
                iconScale = 1.0
            }
            
            // Icon bounce effect
            withAnimation(.spring(response: 0.4, dampingFraction: 0.3).repeatCount(2, autoreverses: true).delay(0.5)) {
                iconBounce = -15
            }
            
            HapticFeedback.medium.trigger()
        }
        
        // Stage 3: Glow pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.2)) {
                glowIntensity = 1.0
            }
            
            // Ring pulse
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.3)) {
                ringPulse = 1.0
            }
            
            HapticFeedback.success.trigger()
        }
        
        // Stage 4: Confetti explosion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                confettiActive = true
            }
            
            HapticFeedback.heavy.trigger()
        }
        
        // Stage 5: Title slide in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                showTitle = true
                titleOffset = 0
            }
        }
        
        // Stage 6: Description slide in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                showDescription = true
                descriptionOffset = 0
            }
        }
        
        // Stage 7: Button pop in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                showButton = true
                buttonScale = 1.0
            }
        }
    }
    
    private func dismissCelebration() {
        // Animate out
        withAnimation(.easeIn(duration: 0.3)) {
            showBackground = false
            showIcon = false
            showTitle = false
            showDescription = false
            showButton = false
            confettiActive = false
            backgroundBlur = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
    
    private func generateConfetti() {
        // Use app's color palette
        let appColors: [Color] = [
            .sevenIndigo,
            .sevenSkyBlue,
            .sevenEmerald,
            .sevenAmber,
            .sevenRose,
            achievementColor
        ]
        
        confettiParticles = (0..<50).map { _ in
            ConfettiParticle(
                x: Double.random(in: 0...1),
                y: -0.1,
                color: appColors.randomElement() ?? achievementColor,
                delay: Double.random(in: 0...2.0)
            )
        }
    }
    
    private func generateSparkles() {
        sparkles = (0..<10).map { _ in
            Sparkle(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...1),
                delay: Double.random(in: 0...2.5)
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var achievementColor: Color {
        // Map achievement color to app colors
        if achievement.color == .success {
            return .sevenEmerald
        } else if achievement.color == .warning {
            return .sevenAmber
        } else if achievement.color == .error {
            return .sevenRose
        } else if achievement.color == .primary {
            return .sevenIndigo
        } else if achievement.color == .secondary {
            return .sevenSkyBlue
        } else {
            // Use the achievement's color if it's a custom color
            return achievement.color
        }
    }
    
    private var rarityText: String {
        switch achievement.rarity {
        case .common:
            return "COMMON"
        case .uncommon:
            return "UNCOMMON"
        case .rare:
            return "RARE"
        case .epic:
            return "EPIC"
        case .legendary:
            return "LEGENDARY"
        }
    }
}

