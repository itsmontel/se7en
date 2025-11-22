import SwiftUI

struct StreakCelebrationView: View {
    let streak: Int
    let pet: Pet?
    let onDismiss: () -> Void
    
    @State private var showBackground = false
    @State private var showPet = false
    @State private var petScale: CGFloat = 0.0
    @State private var petRotation: Double = -180
    @State private var petOffset: CGFloat = 200
    @State private var petBounce: CGFloat = 0
    @State private var showStreakNumber = false
    @State private var streakScale: CGFloat = 0.0
    @State private var streakRotation: Double = 360
    @State private var streakGlow: Double = 0
    @State private var showFireIcon = false
    @State private var fireScale: CGFloat = 0.0
    @State private var showMessage = false
    @State private var messageOffset: CGFloat = 50
    @State private var showButton = false
    @State private var buttonScale: CGFloat = 0.0
    @State private var confettiActive = false
    @State private var sparkles: [Sparkle] = []
    @State private var ringPulse: CGFloat = 0
    @State private var backgroundBlur: CGFloat = 0
    
    // Confetti particles
    @State private var confettiParticles: [ConfettiParticle] = []
    
    var body: some View {
        ZStack {
            // Animated background overlay (matching app style)
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
            
            // Outer glow ring (smaller)
            ZStack {
                // Single subtle pulsing ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                streakColor.opacity(0.4),
                                streakColor.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(1.0 + ringPulse * 0.05)
                    .opacity(0.6)
                
                // Main content container
                VStack(spacing: 20) {
                    // Pet animation with enhanced effects
                    if showPet, let pet = pet {
                        petAnimationView(pet: pet)
                            .scaleEffect(petScale)
                            .rotationEffect(.degrees(petRotation))
                            .offset(y: petOffset + petBounce)
                            .shadow(color: streakColor.opacity(0.5), radius: 20, x: 0, y: 10)
                    }
                    
                    // Streak number section
                    if showStreakNumber {
                        streakNumberSection
                            .scaleEffect(streakScale)
                            .rotationEffect(.degrees(streakRotation))
                    }
                    
                    // Celebration message
                    if showMessage {
                        messageSection
                            .offset(y: messageOffset)
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
                        .shadow(color: streakColor.opacity(streakGlow * 0.3), radius: 30, x: 0, y: 10)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 5)
                )
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
    }
    
    private func petAnimationView(pet: Pet) -> some View {
        ZStack {
            // Subtle glow layer (matching app style)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            streakColor.opacity(0.2),
                            streakColor.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 20)
                .opacity(showPet ? 1.0 : 0)
            
            // Pet image with app-style shadow
            Image(petImageName(for: pet))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .shadow(color: streakColor.opacity(0.3), radius: 15, x: 0, y: 5)
        }
    }
    
    private var streakNumberSection: some View {
        VStack(spacing: 12) {
            // Fire icon with animation (smaller, app-style)
            if showFireIcon {
                Image(systemName: streakIcon)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(streakColor)
                    .scaleEffect(fireScale)
                    .shadow(color: streakColor.opacity(0.3), radius: 8, x: 0, y: 2)
            }
            
            // Streak number (smaller, app-style)
            Text("\(streak)")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundColor(streakColor)
                .shadow(color: streakColor.opacity(0.2), radius: 10, x: 0, y: 4)
            
            // "DAY STREAK!" text (app typography)
            Text("DAY STREAK!")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.textSecondary)
                .tracking(2)
        }
    }
    
    private var messageSection: some View {
        VStack(spacing: 8) {
            Text(celebrationMessage)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
            
            if let pet = pet {
                Text("\(pet.name) is proud of you! 🎉")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
        }
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
            .background(streakColor)
            .cornerRadius(20)
            .shadow(color: streakColor.opacity(0.3), radius: 12, x: 0, y: 6)
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
        
        // Stage 2: Pet entrance (dramatic)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                showPet = true
                petOffset = 0
                petRotation = 0
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.4).delay(0.1)) {
                petScale = 1.0
            }
            
            // Pet bounce effect
            withAnimation(.spring(response: 0.4, dampingFraction: 0.3).repeatCount(2, autoreverses: true).delay(0.5)) {
                petBounce = -15
            }
            
            HapticFeedback.medium.trigger()
        }
        
        // Stage 3: Fire icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                showFireIcon = true
                fireScale = 1.0
            }
            
            HapticFeedback.light.trigger()
        }
        
        // Stage 4: Streak number (explosive entrance)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.4)) {
                showStreakNumber = true
                streakScale = 1.0
                streakRotation = 0
            }
            
            // Glow pulse
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.2)) {
                streakGlow = 1.0
            }
            
            // Ring pulse
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.3)) {
                ringPulse = 1.0
            }
            
            HapticFeedback.success.trigger()
        }
        
        // Stage 5: Confetti explosion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                confettiActive = true
            }
            
            HapticFeedback.heavy.trigger()
        }
        
        // Stage 6: Message slide in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                showMessage = true
                messageOffset = 0
            }
        }
        
        // Stage 7: Button pop in
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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
            showPet = false
            showStreakNumber = false
            showMessage = false
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
            streakColor
        ]
        
        confettiParticles = (0..<60).map { _ in
            ConfettiParticle(
                x: Double.random(in: 0...1),
                y: -0.1,
                color: appColors.randomElement() ?? streakColor,
                delay: Double.random(in: 0...2.0)
            )
        }
    }
    
    private func generateSparkles() {
        sparkles = (0..<12).map { _ in
            Sparkle(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...1),
                delay: Double.random(in: 0...2.5)
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var streakColor: Color {
        // Use app's color scheme
        switch streak {
        case 1...2:
            return .sevenEmerald // Success green
        case 3...6:
            return .sevenAmber // Warning amber
        case 7...13:
            return .sevenIndigo // Primary indigo
        case 14...29:
            return .sevenSkyBlue // Secondary sky blue
        case 30...99:
            return .sevenIndigo // Primary indigo for high streaks
        default:
            return .sevenIndigo // Default to primary
        }
    }
    
    private var streakIcon: String {
        switch streak {
        case 1...2:
            return "checkmark.circle.fill"
        case 3...6:
            return "flame.fill"
        case 7...13:
            return "flame.fill"
        case 14...29:
            return "crown.fill"
        case 30...99:
            return "star.circle.fill"
        default:
            return "trophy.fill"
        }
    }
    
    private var celebrationMessage: String {
        switch streak {
        case 1:
            return "Streak Started! 🔥"
        case 2:
            return "You're on Fire! 🔥"
        case 3:
            return "3 Days Strong! 💪"
        case 7:
            return "Perfect Week! 🌟"
        case 14:
            return "Two Weeks! 🎯"
        case 30:
            return "30 Days! Legendary! 👑"
        case 50:
            return "50 Days! Unstoppable! 🚀"
        case 100:
            return "100 Days! You're a Legend! 🏆"
        default:
            return "Amazing Streak! Keep Going! 🔥"
        }
    }
    
    private func petImageName(for pet: Pet) -> String {
        // Construct image name: "dogfullhealth", "cathappy", etc.
        return "\(pet.type.folderName.lowercased())\(pet.healthState.rawValue)"
    }
}

// MARK: - Confetti Particle
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    let color: Color
    let delay: Double
    var rotation: Double = Double.random(in: 0...360)
    var rotationSpeed: Double = Double.random(in: 3...10)
    var xVelocity: Double = Double.random(in: -0.4...0.4)
}

// MARK: - Sparkle
struct Sparkle: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let delay: Double
    @State var opacity: Double = 0
    @State var scale: CGFloat = 0
}

// MARK: - Confetti View
struct ConfettiView: View {
    let particles: [ConfettiParticle]
    @State private var animatedParticles: [ConfettiParticle] = []
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(animatedParticles) { particle in
                RoundedRectangle(cornerRadius: 3)
                    .fill(particle.color)
                    .frame(width: 10, height: 10)
                    .position(
                        x: geometry.size.width * particle.x,
                        y: geometry.size.height * particle.y
                    )
                    .rotationEffect(.degrees(particle.rotation))
            }
        }
        .onAppear {
            animatedParticles = particles
            animateConfetti()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func animateConfetti() {
        // Animate particles falling with physics
        withAnimation(.linear(duration: 4.0).delay(0)) {
            for index in animatedParticles.indices {
                animatedParticles[index].y = 1.2
                animatedParticles[index].x += animatedParticles[index].xVelocity
            }
        }
        
        // Continuous rotation
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            for index in animatedParticles.indices {
                animatedParticles[index].rotation += animatedParticles[index].rotationSpeed
            }
        }
    }
}

// MARK: - Sparkle View
struct SparkleView: View {
    let sparkle: Sparkle
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Image(systemName: "sparkle")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.yellow)
                .opacity(opacity)
                .scaleEffect(scale)
                .position(
                    x: geometry.size.width * sparkle.x,
                    y: geometry.size.height * sparkle.y
                )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + sparkle.delay) {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    opacity = 1.0
                    scale = 1.0
                }
            }
        }
    }
}
