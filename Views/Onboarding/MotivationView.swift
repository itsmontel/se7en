import SwiftUI

struct MotivationView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var selectedMotivations: Set<DownloadMotivation> = []
    @State private var animateTitle = false
    @State private var animateOptions = false
    @State private var animateButton = false
    
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
                OnboardingHeader(currentStep: 5, totalSteps: 11, showBackButton: true, onBack: onBack)
                
                Spacer()
                
                // Header matching BrainRot style
                VStack(spacing: 24) {
                    Image(petImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .opacity(animateTitle ? 1.0 : 0.0)
                        .scaleEffect(animateTitle ? 1.0 : 0.8)
                    
                    VStack(spacing: 16) {
                        Text("You're here for a reason")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .textCase(.none)
                            .opacity(animateTitle ? 1.0 : 0.0)
                        
                        Text("What is that reason?")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                            .textCase(.none)
                            .opacity(animateTitle ? 1.0 : 0.0)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Motivation options in clean list style like BrainRot
                VStack(spacing: 16) {
                    ForEach(Array(DownloadMotivation.allCases.enumerated()), id: \.element) { index, motivation in
                        MotivationRow(
                            motivation: motivation,
                            isSelected: selectedMotivations.contains(motivation),
                            delay: Double(index) * 0.1
                        ) {
                            toggleMotivation(motivation)
                        }
                        .opacity(animateOptions ? 1.0 : 0.0)
                        .offset(x: animateOptions ? 0 : 50)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    saveMotivations()
                    HapticFeedback.light.trigger()
                    onContinue()
                }) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .textCase(.none)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedMotivations.isEmpty ? 
                                  Color.gray.opacity(0.3) : 
                                  Color.blue.opacity(0.8))
                        .cornerRadius(16)
                }
                .disabled(selectedMotivations.isEmpty)
                .scaleEffect(animateButton ? 1.0 : 0.95)
                .opacity(animateButton ? 1.0 : 0.0)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animateTitle = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animateOptions = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                animateButton = true
            }
        }
    }
    
    private func toggleMotivation(_ motivation: DownloadMotivation) {
        if selectedMotivations.contains(motivation) {
            selectedMotivations.remove(motivation)
        } else {
            selectedMotivations.insert(motivation)
        }
        HapticFeedback.light.trigger()
    }
    
    private func saveMotivations() {
        appState.downloadMotivations = Array(selectedMotivations)
    }
}

struct MotivationRow: View {
    let motivation: DownloadMotivation
    let isSelected: Bool
    let delay: Double
    let action: () -> Void
    
    @State private var animate = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(motivation.rawValue)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .scaleEffect(animate ? 1.0 : 0.95)
        .opacity(animate ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                animate = true
            }
        }
    }
}


