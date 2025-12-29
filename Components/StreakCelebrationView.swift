import SwiftUI
import AVKit

// MARK: - Milestone Streak Celebration View
struct StreakCelebrationView: View {
    let streak: Int
    let pet: Pet?
    let onDismiss: () -> Void
    
    // Animation states
    @State private var showOverlay = false
    @State private var showCard = false
    @State private var cardScale: CGFloat = 0.3
    @State private var cardOpacity: Double = 0
    @State private var showPet = false
    @State private var petScale: CGFloat = 0.5
    @State private var petBounce: CGFloat = 0
    @State private var showFireworks = false
    @State private var showStreakBadge = false
    @State private var badgeScale: CGFloat = 0
    @State private var badgeRotation: Double = -30
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButton = false
    @State private var glowPulse: CGFloat = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var confettiParticles: [MilestoneConfetti] = []
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Check if this is a milestone streak
    static func isMilestoneStreak(_ streak: Int) -> Bool {
        let milestones = [1, 7, 14, 30, 50, 100]
        if milestones.contains(streak) {
            return true
        }
        // Every 100 after 100
        if streak > 100 && streak % 100 == 0 {
            return true
        }
        return false
    }
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black
                .opacity(showOverlay ? 0.85 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't allow tap to dismiss during animation
                    if showButton {
                        dismissWithAnimation()
                    }
                }
            
            // Fireworks/particles layer
            if showFireworks {
                FireworksView(particles: confettiParticles, streakColor: streakColor)
            }
            
            // Main celebration card
            if showCard {
                celebrationCard
                    .scaleEffect(cardScale)
                    .opacity(cardOpacity)
            }
        }
        .onAppear {
            startCelebrationSequence()
        }
    }
    
    // MARK: - Celebration Card
    
    private var celebrationCard: some View {
        VStack(spacing: 12) {
            // Glowing rings behind pet
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [streakColor.opacity(0.6), streakColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 220, height: 220)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)
                
                // Inner glow ring
                Circle()
                    .stroke(streakColor.opacity(0.3), lineWidth: 8)
                    .frame(width: 180, height: 180)
                    .scaleEffect(ringScale * 0.95)
                    .opacity(ringOpacity * 0.7)
                    .blur(radius: 4)
                
                // Pulsing glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [streakColor.opacity(0.4), streakColor.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(1.0 + glowPulse * 0.15)
                    .opacity(0.8)
                
                // Pet animation (Full Health GIF)
                if showPet, let pet = pet {
                    PetAnimationView(
                        petType: pet.type,
                        healthState: .fullHealth, // Always show full health for celebration
                        height: 170
                    )
                    .scaleEffect(petScale)
                    .offset(y: petBounce)
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Streak badge
            if showStreakBadge {
                streakBadgeView
                    .scaleEffect(badgeScale)
                    .rotationEffect(.degrees(badgeRotation))
                    .padding(.bottom, 4)
            }
            
            // Title
            if showTitle {
                Text(milestoneTitle)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .padding(.horizontal, 20)
            }
            
            // Subtitle
            if showSubtitle {
                Text(milestoneSubtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 4)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Continue button
            if showButton {
                Button(action: dismissWithAnimation) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                        Text("Keep Going!")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [streakColor, streakColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: streakColor.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.cardBackground)
                .shadow(color: streakColor.opacity(glowPulse * 0.3), radius: 40, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(
                    LinearGradient(
                        colors: [streakColor.opacity(0.5), streakColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
    
    // MARK: - Streak Badge
    
    private var streakBadgeView: some View {
        VStack(spacing: 4) {
            // Icon
            Image(systemName: streakIcon)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [streakColor, streakColor.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: streakColor.opacity(0.5), radius: 8, x: 0, y: 4)
            
            // Number
            Text("\(streak)")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [streakColor, streakColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: streakColor.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Label
            Text("DAY STREAK")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.textSecondary)
                .tracking(3)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Animation Sequence
    
    private func startCelebrationSequence() {
        // Generate confetti
        generateConfetti()
        
        // Stage 1: Overlay fade in
        withAnimation(.easeOut(duration: 0.4)) {
            showOverlay = true
        }
        
        // Stage 2: Card appears with spring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCard = true
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
        
        // Stage 3: Rings appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                ringScale = 1.0
                ringOpacity = 1.0
            }
            
            // Start glow pulse
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = 1.0
            }
        }
        
        // Stage 4: Pet appears with bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.5)) {
                showPet = true
                petScale = 1.0
            }
            
            HapticFeedback.medium.trigger()
            
            // Pet bounce animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.3).repeatCount(3, autoreverses: true)) {
                    petBounce = -12
                }
            }
        }
        
        // Stage 5: Streak badge with rotation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                showStreakBadge = true
                badgeScale = 1.0
                badgeRotation = 0
            }
            
            HapticFeedback.success.trigger()
        }
        
        // Stage 6: Fireworks!
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showFireworks = true
            }
            
            HapticFeedback.heavy.trigger()
        }
        
        // Stage 7: Title
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showTitle = true
            }
        }
        
        // Stage 8: Subtitle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showSubtitle = true
            }
        }
        
        // Stage 9: Button
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showButton = true
            }
        }
    }
    
    private func dismissWithAnimation() {
        HapticFeedback.light.trigger()
        
        withAnimation(.easeIn(duration: 0.25)) {
            cardScale = 0.8
            cardOpacity = 0
            showOverlay = false
            showFireworks = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
    
    private func generateConfetti() {
        let colors: [Color] = [
            streakColor,
            streakColor.opacity(0.7),
            .yellow,
            .orange,
            .pink,
            .purple,
            .cyan
        ]
        
        confettiParticles = (0..<80).map { _ in
            MilestoneConfetti(
                x: Double.random(in: 0...1),
                y: Double.random(in: -0.3...0),
                color: colors.randomElement() ?? streakColor,
                size: CGFloat.random(in: 6...14),
                delay: Double.random(in: 0...1.5),
                duration: Double.random(in: 3...5)
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var streakColor: Color {
        switch streak {
        case 1:
            return Color(red: 0.4, green: 0.8, blue: 0.6) // Light green
        case 7:
            return Color(red: 0.3, green: 0.7, blue: 0.4) // Fresh green
        case 14:
            return Color(red: 0.2, green: 0.6, blue: 0.9) // Sky blue
        case 30:
            return Color(red: 0.6, green: 0.3, blue: 0.9) // Purple
        case 50:
            return Color(red: 0.9, green: 0.5, blue: 0.2) // Orange gold
        case 100:
            return Color(red: 0.9, green: 0.75, blue: 0.1) // Gold
        default:
            // Every 100 after - rainbow progression
            let hue = Double((streak / 100) % 10) * 0.1
            return Color(hue: hue, saturation: 0.8, brightness: 0.9)
        }
    }
    
    private var streakIcon: String {
        switch streak {
        case 1:
            return "star.circle.fill"
        case 7:
            return "flame.fill"
        case 14:
            return "star.fill"
        case 30:
            return "crown.fill"
        case 50:
            return "bolt.fill"
        case 100:
            return "trophy.fill"
        default:
            return "sparkles"
        }
    }
    
    private var milestoneTitle: String {
        switch streak {
        case 1:
            return "First Day Victory! ⭐"
        case 7:
            return "One Week Champion! 🔥"
        case 14:
            return "Two Weeks Strong! ⭐"
        case 30:
            return "One Month Legend! 👑"
        case 50:
            return "50 Days Unstoppable! ⚡"
        case 100:
            return "100 Days! You're Incredible! 🏆"
        case 200:
            return "200 Days! Absolute Legend! 💎"
        case 300:
            return "300 Days! Unstoppable Force! 🌟"
        case 365:
            return "ONE FULL YEAR! 🎉"
        default:
            if streak % 100 == 0 {
                return "\(streak) Days! Phenomenal! ✨"
            }
            return "Amazing Milestone! 🎯"
        }
    }
    
    private var milestoneSubtitle: String {
        guard let pet = pet else {
            return "Your dedication is truly inspiring!"
        }
        
        switch streak {
        case 1:
            return "Amazing start! \(pet.name) is already smiling!"
        case 7:
            return "\(pet.name) is proud of your first week!"
        case 14:
            return "Two weeks strong! \(pet.name) is thriving!"
        case 30:
            return "A whole month! \(pet.name) couldn't be happier!"
        case 50:
            return "50 days! \(pet.name) thinks you're amazing!"
        case 100:
            return "100 days! You and \(pet.name) are an unstoppable team!"
        default:
            if streak % 100 == 0 {
                return "\(pet.name) is in awe of your \(streak)-day journey!"
            }
            return "\(pet.name) celebrates this milestone with you!"
        }
    }
}

// MARK: - Milestone Confetti Particle

struct MilestoneConfetti: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    let color: Color
    let size: CGFloat
    let delay: Double
    let duration: Double
    var rotation: Double = Double.random(in: 0...360)
    var rotationSpeed: Double = Double.random(in: 180...540)
    var xVelocity: Double = Double.random(in: -0.3...0.3)
}

// MARK: - Fireworks View

struct FireworksView: View {
    let particles: [MilestoneConfetti]
    let streakColor: Color
    
    @State private var animatedParticles: [MilestoneConfetti] = []
    @State private var particleRotations: [UUID: Double] = [:]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(animatedParticles) { particle in
                    RoundedRectangle(cornerRadius: particle.size / 3)
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size * 1.5)
                        .rotationEffect(.degrees(particleRotations[particle.id] ?? particle.rotation))
                        .position(
                            x: geometry.size.width * particle.x,
                            y: geometry.size.height * particle.y
                        )
                        .opacity(particle.y < 1.2 ? 1.0 : 0)
                }
            }
        }
        .onAppear {
            animatedParticles = particles
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Initialize rotations
        for particle in animatedParticles {
            particleRotations[particle.id] = particle.rotation
        }
        
        // Animate each particle falling
        for index in animatedParticles.indices {
            let particle = animatedParticles[index]
            
            withAnimation(
                .easeIn(duration: particle.duration)
                .delay(particle.delay)
            ) {
                animatedParticles[index].y = 1.3
                animatedParticles[index].x += particle.xVelocity
            }
        }
        
        // Continuous rotation animation
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            for index in animatedParticles.indices {
                let particle = animatedParticles[index]
                let currentRotation = particleRotations[particle.id] ?? 0
                particleRotations[particle.id] = currentRotation + (particle.rotationSpeed * 0.016)
            }
        }
    }
}

// MARK: - Preview

struct StreakCelebrationView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            StreakCelebrationView(
                streak: 30,
                pet: Pet(type: .dog, name: "Buddy", healthState: .fullHealth),
                onDismiss: {}
            )
        }
    }
}
