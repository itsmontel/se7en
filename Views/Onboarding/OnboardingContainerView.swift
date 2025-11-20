import SwiftUI

enum PetOnboardingStep {
    case welcome
    case petSelection
    case videoIntroduction
    case petPreview
    case motivation
    case didYouKnow
    case lifetimeCalculation
    case whyChooseSE7EN
    case screenTimeInput
    case screenTimeConnection
    case appSelection
}

struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep: PetOnboardingStep = .welcome
    @State private var selectedApps: Set<String> = []
    @State private var appLimits: [String: Int] = [:]
    
    private func goBack() {
        withAnimation {
            switch currentStep {
            case .welcome:
                break // No back from welcome
            case .petSelection:
                currentStep = .welcome
            case .videoIntroduction:
                currentStep = .petSelection
            case .petPreview:
                currentStep = .videoIntroduction
            case .motivation:
                currentStep = .petPreview
            case .didYouKnow:
                currentStep = .motivation
            case .screenTimeInput:
                currentStep = .didYouKnow
            case .lifetimeCalculation:
                currentStep = .screenTimeInput
            case .whyChooseSE7EN:
                currentStep = .lifetimeCalculation
            case .screenTimeConnection:
                currentStep = .whyChooseSE7EN
            case .appSelection:
                currentStep = .screenTimeConnection
            }
        }
        HapticFeedback.light.trigger()
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack {
                switch currentStep {
                case .welcome:
                    WelcomeView(onContinue: {
                        withAnimation {
                            currentStep = .petSelection
                        }
                        HapticFeedback.light.trigger()
                    })
                    
                case .petSelection:
                    PetSelectionView(
                        onContinue: {
                            withAnimation {
                                currentStep = .videoIntroduction
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )

                case .videoIntroduction:
                    VideoIntroductionView(
                        onContinue: {
                            withAnimation {
                                currentStep = .petPreview
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )

                case .petPreview:
                    PetPreviewView(
                        onContinue: {
                            withAnimation {
                                currentStep = .motivation
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .motivation:
                    MotivationView(
                        onContinue: {
                            withAnimation {
                                currentStep = .didYouKnow
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .didYouKnow:
                    DidYouKnowView(
                        onContinue: {
                            withAnimation {
                                currentStep = .screenTimeInput
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .screenTimeInput:
                    ScreenTimeInputView(
                        onContinue: {
                            withAnimation {
                                currentStep = .lifetimeCalculation
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .lifetimeCalculation:
                    LifetimeCalculationView(
                        onContinue: {
                            withAnimation {
                                currentStep = .whyChooseSE7EN
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .whyChooseSE7EN:
                    WhyChooseSE7ENView(
                        onContinue: {
                            withAnimation {
                                currentStep = .screenTimeConnection
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .screenTimeConnection:
                    ScreenTimeConnectionView(
                        onContinue: {
                            withAnimation {
                                currentStep = .appSelection
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .appSelection:
                    SetGoalsView(
                        selectedApps: $selectedApps,
                        appLimits: $appLimits,
                        onContinue: {
                            completeOnboarding()
                        },
                        onBack: goBack
                    )
                }
            }
        }
        .environment(\.textCase, .none)
    }
    
    private func completeOnboarding() {
        // Save selected apps and limits
        for (appName, limit) in appLimits {
            if selectedApps.contains(appName) {
                // Get bundle ID for the app
                let bundleID = "com.example.\(appName.lowercased())" // Placeholder
                appState.addAppGoal(appName: appName, bundleID: bundleID, dailyLimitMinutes: limit)
            }
        }
        
        // Complete onboarding
        appState.isOnboarding = false
        HapticFeedback.success.trigger()
    }
}
