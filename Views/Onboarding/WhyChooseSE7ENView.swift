import SwiftUI

struct WhyChooseSE7ENView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var animateTitle = false
    @State private var animateFeatures = false
    @State private var animateButton = false
    @State private var animatePet = false
    
    private var petImageName: String {
        if let pet = appState.userPet {
            return "\(pet.type.folderName.lowercased())fullhealth"
        }
        return "dogfullhealth"
    }
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            VStack(spacing: 0) {
                // Header with back button and progress bar
                OnboardingHeader(currentStep: 7, totalSteps: 8, showBackButton: true, onBack: onBack)
                
                Spacer()
                
                // Pet and Header
                VStack(spacing: 24) {
                    // Pet image with glow effect
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)
                        
                        Image(petImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                    }
                    .scaleEffect(animatePet ? 1.0 : 0.8)
                    .opacity(animatePet ? 1.0 : 0.0)
                    
                    VStack(spacing: 16) {
                        Text("Why choose SE7EN?")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .opacity(animateTitle ? 1.0 : 0.0)
                        
                        Text("The only app that combines money with habits")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .opacity(animateTitle ? 1.0 : 0.0)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Key differentiators
                VStack(spacing: 20) {
                    DifferentiatorCard(
                        icon: "flame.fill",
                        gradient: [Color.red, Color.orange],
                        title: "Real Accountability",
                        description: "Put your money where your mouth is. Financial stakes create real motivation.",
                        delay: 0.2
                    )
                    
                    DifferentiatorCard(
                        icon: "creditcard.fill",
                        gradient: [Color.green, Color.blue],
                        title: "The 7-Credit System",
                        description: "Start each week with 7 credits. Lose one daily when you exceed limits. Keep all 7 to stay free.",
                        delay: 0.4
                    )
                    
                    DifferentiatorCard(
                        icon: "chart.line.uptrend.xyaxis",
                        gradient: [Color.purple, Color.pink],
                        title: "Designed to be Free",
                        description: "Build healthy habits and never pay. The app rewards good behavior, not addiction.",
                        delay: 0.6
                    )
                }
                .padding(.horizontal, 24)
                .opacity(animateFeatures ? 1.0 : 0.0)
                
                Spacer()
                
                // Call to action
                VStack(spacing: 20) {
                    Text("Ready to take control?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .opacity(animateButton ? 1.0 : 0.0)
                    
                    Button(action: {
                        HapticFeedback.medium.trigger()
                        onContinue()
                    }) {
                        HStack {
                            Text("Let's do this")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .scaleEffect(animateButton ? 1.0 : 0.95)
                    .opacity(animateButton ? 1.0 : 0.0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1)) {
                animatePet = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animateTitle = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                animateFeatures = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.8)) {
                animateButton = true
            }
        }
    }
}

struct DifferentiatorCard: View {
    let icon: String
    let gradient: [Color]
    let title: String
    let description: String
    let delay: Double
    
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(0.2) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                Text(description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .scaleEffect(animate ? 1.0 : 0.95)
        .opacity(animate ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                animate = true
            }
        }
    }
}

