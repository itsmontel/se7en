import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    @State private var petAnimation = false
    @State private var textAnimation = false
    @State private var nameFieldAnimation = false
    @State private var buttonAnimation = false
    @State private var userName: String = ""
    @State private var showNameError = false
    
    var isNameValid: Bool {
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            VStack(spacing: 0) {
                // Progress bar at top
                OnboardingProgressBar(currentStep: 1, totalSteps: 8)
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                
                Spacer()
                
                // Pet illustration - bigger size
                VStack(spacing: 32) {
                    Image("dogfullhealth")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 240, height: 240)
                        .scaleEffect(petAnimation ? 1.0 : 0.8)
                        .opacity(petAnimation ? 1.0 : 0.0)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    
                    VStack(spacing: 16) {
                        Text("Welcome to Se7en")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .opacity(textAnimation ? 1.0 : 0.0)
                        
                        Text("Your personal companion for digital wellness and healthier screen time habits")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .lineSpacing(4)
                            .opacity(textAnimation ? 1.0 : 0.0)
                    }
                }
                
                Spacer()
                
                // Name input section
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's your name?")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 36, alignment: .center)
                            
                            TextField("Enter your name", text: $userName)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.textPrimary)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.done)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    showNameError ? Color.red : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .padding(.horizontal, 24)
                    .opacity(nameFieldAnimation ? 1.0 : 0.0)
                    
                    if showNameError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                            
                            Text("Please enter your name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .opacity(nameFieldAnimation ? 1.0 : 0.0)
                    }
                }
                
                Spacer()
                
                // Button with soft blue
                VStack(spacing: 16) {
                    Button(action: {
                        if isNameValid {
                            appState.userName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                            showNameError = false
                            HapticFeedback.light.trigger()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                onContinue()
                            }
                        } else {
                            showNameError = true
                            HapticFeedback.warning.trigger()
                        }
                    }) {
                        Text("Get started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isNameValid ? Color.blue.opacity(0.8) : Color.blue.opacity(0.4))
                            .cornerRadius(16)
                    }
                    .disabled(!isNameValid)
                    .scaleEffect(buttonAnimation ? 1.0 : 0.95)
                    .opacity(buttonAnimation ? 1.0 : 0.0)
                    .padding(.horizontal, 24)
                    
                    Text("Takes less than 2 minutes")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                        .opacity(buttonAnimation ? 1.0 : 0.0)
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                petAnimation = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                textAnimation = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                nameFieldAnimation = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.9)) {
                buttonAnimation = true
            }
        }
    }
}

// Progress bar component for onboarding
struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var progress: Double {
        Double(currentStep) / Double(totalSteps)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
        }
    }
}

// Subtle tinted background for onboarding
struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // Subtle gradient overlay for depth
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.02),
                    Color.clear,
                    Color.purple.opacity(0.015)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}
