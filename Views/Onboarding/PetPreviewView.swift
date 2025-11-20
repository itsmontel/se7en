import SwiftUI

struct PetPreviewView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var selectedHealthIndex: Double = 4 // Start at full health
    
    private let healthStates: [PetHealthState] = [.sick, .sad, .content, .happy, .fullHealth]
    
    private var currentHealthState: PetHealthState {
        healthStates[Int(selectedHealthIndex)]
    }
    
    private var petName: String {
        appState.userPet?.name ?? "Your Pet"
    }
    
    private var petType: String {
        appState.userPet?.type.folderName.lowercased() ?? "dog"
    }
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            VStack(spacing: 0) {
                // Header with back button and progress bar
                OnboardingHeader(currentStep: 4, totalSteps: 9, showBackButton: true, onBack: onBack)
                
                Spacer()
                
                // Header
                VStack(spacing: 24) {
                    Text("See for yourself")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Your screen time directly affects \(petName)'s health")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Pet Display with Health State
                VStack(spacing: 24) {
                    Image("\(petType)\(currentHealthState.rawValue)")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .id(currentHealthState)
                        .transition(.scale.combined(with: .opacity))
                    
                    // Health State Info
                    VStack(spacing: 12) {
                        Text(currentHealthState.displayName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(currentHealthState.color)
                        
                        Text(currentHealthState.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                Spacer()
                
                // Health Slider
                VStack(spacing: 16) {
                    HStack {
                        Text("Sick")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Text("Full health")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 24)
                    
                    Slider(value: $selectedHealthIndex, in: 0...4, step: 1)
                        .tint(currentHealthState.color)
                        .padding(.horizontal, 24)
                        .onChange(of: selectedHealthIndex) { _ in
                            // Reduce haptic feedback frequency for better performance
                            Task {
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second debounce
                                HapticFeedback.light.trigger()
                            }
                        }
                    
                    // Health Indicators
                    HStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(index <= Int(selectedHealthIndex) ? healthStates[index].color : Color.gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .padding(.vertical, 20)
                
                Spacer()
                
                // Continue Button
                Button(action: {
                    HapticFeedback.light.trigger()
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .animation(.easeOut(duration: 0.2), value: selectedHealthIndex) // Simpler animation for better performance
    }
}


