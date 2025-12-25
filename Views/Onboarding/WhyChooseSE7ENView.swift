import SwiftUI
import UIKit

struct WhyChooseSE7ENView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var animateTitle = false
    @State private var animateFeatures = false
    @State private var animateButton = false
    @State private var animatePet = false
    
    private var petImageName: String {
        // Safely get pet image name with fallback
        guard let pet = appState.userPet else {
            return "dogfullhealth"
        }
        let petType = pet.type.folderName.lowercased()
        return "\(petType)fullhealth"
    }
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header with back button and progress bar
                    OnboardingHeader(currentStep: 9, totalSteps: 11, showBackButton: true, onBack: onBack)
                    
                    // Pet and Header
                    VStack(spacing: 24) {
                        // Pet image with glow effect
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 140, height: 140)
                                .blur(radius: 20)
                            
                            if let image = UIImage(named: petImageName) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                            } else {
                                // Fallback to system image if pet image not found
                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue)
                            }
                        }
                        .scaleEffect(animatePet ? 1.0 : 0.8)
                        .opacity(animatePet ? 1.0 : 0.0)
                        .padding(.top, 20)
                        
                        VStack(spacing: 16) {
                            Text("Why choose SE7EN?")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                                .multilineTextAlignment(.center)
                                .textCase(.none)
                                .opacity(animateTitle ? 1.0 : 0.0)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Build better habits through engaging challenges")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                                .textCase(.none)
                                .multilineTextAlignment(.center)
                                .opacity(animateTitle ? 1.0 : 0.0)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                    
                    // Key differentiators
                    VStack(spacing: 20) {
                        DifferentiatorCard(
                            icon: "pawprint.fill",
                            gradient: [Color.blue, Color.purple],
                            title: "Your Digital Companion",
                            description: "Care for your virtual pet by staying within your limits. Watch it thrive as you build better habits.",
                            delay: 0.2
                        )
                        
                        DifferentiatorCard(
                            icon: "puzzlepiece.fill",
                            gradient: [Color.green, Color.blue],
                            title: "Puzzle-Based Extensions",
                            description: "Hit your limit? Solve fun puzzles to earn extra time. Sudoku, memory games, and pattern challenges make earning time engaging.",
                            delay: 0.4
                        )
                        
                        DifferentiatorCard(
                            icon: "chart.line.uptrend.xyaxis",
                            gradient: [Color.purple, Color.pink],
                            title: "Gamified Accountability",
                            description: "Build healthy habits through engaging challenges and puzzles. Your pet's health reflects your progress, making screen time management fun and rewarding.",
                            delay: 0.6
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .opacity(animateFeatures ? 1.0 : 0.0)
                    
                    // Call to action
                    VStack(spacing: 20) {
                        Text("Ready to take control?")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .textCase(.none)
                            .opacity(animateButton ? 1.0 : 0.0)
                        
                        Button(action: {
                            HapticFeedback.medium.trigger()
                            // Prevent multiple taps
                            DispatchQueue.main.async {
                                onContinue()
                            }
                        }) {
                            HStack {
                                Text("Let's do this")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .textCase(.none)
                                
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
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            // Animate elements with delays
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
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appBackground)
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

