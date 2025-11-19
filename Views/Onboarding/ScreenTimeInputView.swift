import SwiftUI

struct ScreenTimeInputView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var selectedHours: Double = 6.0
    @State private var animateIllustration = false
    @State private var animateContent = false
    
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
                OnboardingHeader(currentStep: 7, totalSteps: 11, showBackButton: true, onBack: onBack)
                
                        // Pet illustration with animation
                        VStack(spacing: 32) {
                            Image(petImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .scaleEffect(animateIllustration ? 1.0 : 0.8)
                                .opacity(animateIllustration ? 1.0 : 0.0)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    VStack(spacing: 16) {
                        Text("How much time do you spend on screens daily?")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .opacity(animateContent ? 1.0 : 0.0)
                        
                        Text("You can tell the truth")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .opacity(animateContent ? 1.0 : 0.0)
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.top, 80)
                
                Spacer()
                
                // Hours display matching BrainRot
                VStack(spacing: 32) {
                    Text("\(Int(selectedHours)) hours")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(hoursColor)
                        .opacity(animateContent ? 1.0 : 0.0)
                    
                    // Slider matching BrainRot's style
                    VStack(spacing: 16) {
                        Slider(value: $selectedHours, in: 0...12, step: 1)
                            .accentColor(.blue)
                            .frame(height: 40)
                            .opacity(animateContent ? 1.0 : 0.0)
                        
                        HStack {
                            Text("0h")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("12h+")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .opacity(animateContent ? 1.0 : 0.0)
                    }
                    .padding(.horizontal, 32)
                    
                    // Feedback message with color like BrainRot
                    Text(feedbackMessage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(feedbackColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(animateContent ? 1.0 : 0.0)
                }
                
                Spacer()
                
                // Continue button
                Button(action: {
                    saveScreenTime()
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
                .scaleEffect(animateContent ? 1.0 : 0.95)
                .opacity(animateContent ? 1.0 : 0.0)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateIllustration = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animateContent = true
            }
        }
    }
    
    private var feedbackMessage: String {
        switch Int(selectedHours) {
        case 0:
            return "That's absolutely amazing! You're living in the moment."
        case 1:
            return "That's actually quite good! But even this adds up over time."
        case 2...3:
            return "Not bad, but this is still a significant portion of your day."
        case 4...5:
            return "This is a significant percentage of your life."
        case 6...7:
            return "That's a lot of screen time. This really adds up over years."
        case 8...9:
            return "This is concerning. You're spending most of your waking hours on screens."
        case 10...11:
            return "This is extremely high. Your entire day revolves around screens."
        default: // 12+
            return "This is alarming. You're essentially living your life through a screen."
        }
    }
    
    private var hoursColor: Color {
        let hours = Int(selectedHours)
        
        // Smooth gradient from green (0h) -> yellow (4-6h) -> red (12+h)
        switch hours {
        case 0: return Color(red: 0.0, green: 0.9, blue: 0.2) // Bright green
        case 1: return Color(red: 0.1, green: 0.85, blue: 0.15) // Green
        case 2: return Color(red: 0.3, green: 0.8, blue: 0.1) // Yellow-green
        case 3: return Color(red: 0.5, green: 0.75, blue: 0.05) // Yellow-green
        case 4: return Color(red: 0.7, green: 0.7, blue: 0.0) // Yellow
        case 5: return Color(red: 0.85, green: 0.65, blue: 0.0) // Yellow-orange
        case 6: return Color(red: 0.95, green: 0.55, blue: 0.0) // Orange-yellow
        case 7: return Color(red: 1.0, green: 0.45, blue: 0.0) // Orange
        case 8: return Color(red: 1.0, green: 0.3, blue: 0.0) // Orange-red
        case 9: return Color(red: 1.0, green: 0.2, blue: 0.0) // Red-orange
        case 10: return Color(red: 1.0, green: 0.1, blue: 0.0) // Red
        case 11: return Color(red: 1.0, green: 0.05, blue: 0.0) // Bright red
        default: return Color(red: 1.0, green: 0.0, blue: 0.0) // Super red
        }
    }
    
    private var feedbackColor: Color {
        // Use the same color as hours for consistency
        return hoursColor
    }
    
    private func saveScreenTime() {
        appState.averageScreenTimeHours = Int(selectedHours)
    }
}


