import SwiftUI

struct OnboardingHeader: View {
    let currentStep: Int
    let totalSteps: Int
    let showBackButton: Bool
    let onBack: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 16) {
            if showBackButton, let onBack = onBack {
                OnboardingBackButton(action: onBack)
            } else {
                // Spacer to maintain alignment when no back button
                Spacer()
                    .frame(width: 44)
            }
            
            // Progress bar takes remaining space
            OnboardingProgressBar(currentStep: currentStep, totalSteps: totalSteps)
        }
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }
}
