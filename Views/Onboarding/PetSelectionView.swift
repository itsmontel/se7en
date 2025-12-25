import SwiftUI

struct PetSelectionView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var selectedPetType: PetType = .dog
    @State private var petName: String = ""
    @State private var showNameInput = false
    @State private var animatePawPrints = false
    @State private var animateTitle = false
    @State private var animatePets = false
    @State private var animateButton = false
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            if showNameInput {
                // Pet naming screen like BrainRot
                ScrollView {
                    VStack(spacing: 0) {
                        // Back button for naming screen
                        HStack {
                            OnboardingBackButton(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showNameInput = false
                                }
                                HapticFeedback.light.trigger()
                            })
                            .padding(.top, 60)
                            .padding(.leading, 24)
                            Spacer()
                        }
                        
                        VStack(spacing: 32) {
                            // Selected pet display - bigger
                            Image("\(selectedPetType.folderName.lowercased())fullhealth")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 220, height: 220)
                                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                                .padding(.top, 20)
                            
                            VStack(spacing: 16) {
                                Text("Name your \(selectedPetType.rawValue.lowercased())")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .textCase(.none)
                                    .padding(.horizontal, 24)
                                
                                VStack(spacing: 8) {
                                    Text("Give your new companion a")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text("special name! This \(selectedPetType.rawValue.lowercased())")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text("will be your motivation buddy.")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            }
                            
                            // Name input field
                            VStack(spacing: 8) {
                                TextField("", text: $petName)
                                    .font(.system(size: 24, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                    )
                                    .padding(.horizontal, 32)
                                
                                Text("Choose a name that makes you smile")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 32)
                            }
                            
                            // Pet description
                            Text(selectedPetType.description)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.top, 8)
                            
                            // Centered continue button
                            Button(action: {
                                if !petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    savePet()
                                    HapticFeedback.light.trigger()
                                    onContinue()
                                }
                            }) {
                                Text("Continue")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .textCase(.none)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                              Color.gray.opacity(0.3) : 
                                              Color.blue.opacity(0.8))
                                    .cornerRadius(20)
                            }
                            .disabled(petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .padding(.horizontal, 24)
                            .padding(.top, 32)
                            .padding(.bottom, 60)
                        }
                    }
                }
            } else {
                // Pet selection screen
                VStack(spacing: 0) {
                    // Header with back button and progress bar
                    OnboardingHeader(currentStep: 2, totalSteps: 11, showBackButton: true, onBack: onBack)
                    
                    // Paw prints header like BrainRot
                    VStack(spacing: 24) {
                        HStack(spacing: 16) {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                                .scaleEffect(animatePawPrints ? 1.0 : 0.5)
                                .opacity(animatePawPrints ? 1.0 : 0.0)
                            
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.7))
                                .scaleEffect(animatePawPrints ? 1.0 : 0.5)
                                .opacity(animatePawPrints ? 1.0 : 0.0)
                        }
                        .padding(.top, 60)
                        
                        VStack(spacing: 16) {
                            Text("Choose your pet")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                                .multilineTextAlignment(.center)
                                .textCase(.none)
                                .opacity(animateTitle ? 1.0 : 0.0)
                            
                            Text("Select one of five adorable pets to\naccompany you on your digital wellness\njourney! Your pet's health will reflect\nyour daily screen time habits.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .lineSpacing(4)
                                .opacity(animateTitle ? 1.0 : 0.0)
                        }
                    }
                    
                    Spacer()
                    
                    // Horizontal scrollable pet selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(Array(PetType.allCases.enumerated()), id: \.element) { index, petType in
                                PetCard(
                                    petType: petType,
                                    isSelected: selectedPetType == petType,
                                    delay: Double(index) * 0.1
                                ) {
                                    withAnimation(.spring(response: 0.4)) {
                                        selectedPetType = petType
                                        HapticFeedback.light.trigger()
                                    }
                                }
                                .opacity(animatePets ? 1.0 : 0.0)
                                .scaleEffect(animatePets ? 1.0 : 0.8)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Centered continue button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showNameInput = true
                        }
                        HapticFeedback.light.trigger()
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .textCase(.none)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(20)
                    }
                    .scaleEffect(animateButton ? 1.0 : 0.95)
                    .opacity(animateButton ? 1.0 : 0.0)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            if !showNameInput {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animatePawPrints = true
                }
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    animateTitle = true
                }
                withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                    animatePets = true
                }
                withAnimation(.easeOut(duration: 0.8).delay(0.7)) {
                    animateButton = true
                }
            }
        }
    }
    
    private func savePet() {
        let finalName = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.setUserPet(Pet(type: selectedPetType, name: finalName, healthState: .fullHealth))
    }
    
    private func petSystemIcon(for petType: PetType) -> String {
        switch petType {
        case .dog: return "dog.fill"
        case .cat: return "cat.fill"
        case .bunny: return "rabbit.fill"
        case .hamster: return "circle.fill" // No hamster icon, use circle
        case .horse: return "horse.fill"
        }
    }
}

struct PetCard: View {
    let petType: PetType
    let isSelected: Bool
    let delay: Double
    let action: () -> Void
    
    @State private var animate = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Pet image - larger
                Image("\(petType.folderName.lowercased())fullhealth")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)

                // Pet name only (no icons/emojis)
                VStack(spacing: 8) {
                    Text(petType.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? .blue : .textPrimary)

                    Text(petType.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(width: 180, height: 220)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
            )
        }
        .scaleEffect(animate ? 1.0 : 0.9)
        .opacity(animate ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                animate = true
            }
        }
    }
    
    private func petSystemIcon(for petType: PetType) -> String {
        switch petType {
        case .dog: return "dog.fill"
        case .cat: return "cat.fill"
        case .bunny: return "rabbit.fill"
        case .hamster: return "circle.fill" // No hamster icon, use circle
        case .horse: return "horse.fill"
        }
    }
}


