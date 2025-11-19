import SwiftUI

struct DidYouKnowView: View {
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var animateText = false
    @State private var animateStats = false
    @State private var animateButton = false
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            VStack(spacing: 0) {
                // Header with back button and progress bar
                OnboardingHeader(currentStep: 6, totalSteps: 11, showBackButton: true, onBack: onBack)
                
                // Header with better spacing
                VStack(spacing: 24) {
                    Text("Did you know?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(animateText ? 1.0 : 0.0)
                }
                .padding(.top, 40)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Clean fact cards matching BrainRot's style
                VStack(spacing: 24) {
                    FactCard(
                        icon: "hourglass.circle.fill",
                        iconColor: Color.red,
                        text: "People spend 7+ years of their lifetime staring at phone screens",
                        delay: 0.2
                    )

                    FactCard(
                        icon: "brain.head.profile",
                        iconColor: Color.purple,
                        text: "Dopamine addiction from endless scrolling rewires your brain permanently",
                        delay: 0.4
                    )

                    FactCard(
                        icon: "moon.zzz.fill",
                        iconColor: Color.blue,
                        text: "Screen time before bed destroys sleep quality and mental health",
                        delay: 0.6
                    )

                    FactCard(
                        icon: "target",
                        iconColor: Color.orange,
                        text: "Only 3% of people successfully limit screen time without accountability",
                        delay: 0.8
                    )
                }
                .padding(.horizontal, 24)
                .opacity(animateStats ? 1.0 : 0.0)
                
                Spacer()
                
                // Bottom text and button like BrainRot
                VStack(spacing: 24) {
                    Text("We're here to help you be more mindful of these habits")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(animateButton ? 1.0 : 0.0)
                    
                    Button(action: {
                        HapticFeedback.light.trigger()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onContinue()
                        }
                    }) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(16)
                    }
                    .scaleEffect(animateButton ? 1.0 : 0.95)
                    .opacity(animateButton ? 1.0 : 0.0)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            // Staggered animations like BrainRot
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animateText = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animateStats = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                animateButton = true
            }
        }
    }
}

struct FactCard: View {
    let icon: String
    let iconColor: Color
    let text: String
    let delay: Double
    
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with circle background like BrainRot
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
    Text(text)
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.textPrimary)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .scaleEffect(animate ? 1.0 : 0.95)
        .opacity(animate ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                animate = true
            }
        }
    }
}


