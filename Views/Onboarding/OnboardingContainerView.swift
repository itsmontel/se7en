import SwiftUI

enum PetOnboardingStep {
    case welcome
    case petSelection
    case videoIntroduction
    case petPreview
    case motivation
    case didYouKnow
    case screenTimeInput
    case lifetimeCalculation
    case whyChooseSE7EN
    case notificationPermission
    case screenTimeConnection
    case appSelection
}

struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep: PetOnboardingStep = .welcome
    @State private var selectedApps: Set<String> = []
    @State private var appLimits: [String: Int] = [:]
    
    private func goBack() {
        // Use simpler, faster animation for better performance
        withAnimation(.easeOut(duration: 0.15)) {
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
            case .notificationPermission:
                currentStep = .whyChooseSE7EN
            case .screenTimeConnection:
                currentStep = .notificationPermission
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
                        withAnimation(.easeOut(duration: 0.15)) {
                            currentStep = .petSelection
                        }
                        HapticFeedback.light.trigger()
                    })
                    
                case .petSelection:
                    PetSelectionView(
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                currentStep = .videoIntroduction
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )

                case .videoIntroduction:
                    VideoIntroductionView(
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                currentStep = .petPreview
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )

                case .petPreview:
                    PetPreviewView(
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                currentStep = .motivation
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .motivation:
                    MotivationView(
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                currentStep = .didYouKnow
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .didYouKnow:
                    DidYouKnowView(
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                currentStep = .screenTimeInput
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .screenTimeInput:
                    ScreenTimeInputView(
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                currentStep = .lifetimeCalculation
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .lifetimeCalculation:
                    LifetimeCalculationView(
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                currentStep = .whyChooseSE7EN
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .whyChooseSE7EN:
                    WhyChooseSE7ENView(
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                currentStep = .notificationPermission
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    
                case .notificationPermission:
                    NotificationPermissionView(
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                currentStep = .screenTimeConnection
                            }
                            HapticFeedback.light.trigger()
                        },
                        onBack: goBack
                    )
                    .environmentObject(appState)
                    
                case .screenTimeConnection:
                    ScreenTimeConnectionView(
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.15)) {
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
        .withProperTextCase()
    }
    
    private func completeOnboarding() {
        // Apps are already saved by SetGoalsView with real bundle IDs from FamilyActivityPicker
        // Just complete onboarding and persist
        appState.completeOnboarding()
        HapticFeedback.success.trigger()
    }
}

// MARK: - Notification Permission View

struct NotificationPermissionView: View {
    let onContinue: () -> Void
    let onBack: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var isRequesting = false
    @State private var animateIcon = false
    @State private var animateContent = false
    @State private var showSkipConfirmation = false
    
    private var petType: PetType {
        appState.userPet?.type ?? .dog
    }
    
    private var petName: String {
        appState.userPet?.name ?? "your pet"
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header with back button and progress bar
                    OnboardingHeader(currentStep: 10, totalSteps: 13, showBackButton: true, onBack: onBack)
                    
                    // Pet animation at full health
                    PetAnimationView(
                        petType: petType,
                        healthState: .fullHealth,
                        height: 130
                    )
                    .opacity(animateIcon ? 1.0 : 0.0)
                    .scaleEffect(animateIcon ? 1.0 : 0.8)
                    .padding(.top, 32)
                    .padding(.bottom, 32)
                    
                    // Title and subtitle
                    VStack(spacing: 12) {
                        Text("Stay Connected")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .opacity(animateContent ? 1.0 : 0.0)
                        
                        Text("Get reminders to keep \(petName) happy")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .opacity(animateContent ? 1.0 : 0.0)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
                    
                    // Benefits (more spacious)
                    VStack(alignment: .leading, spacing: 20) {
                        NotificationBenefitRow(
                            icon: "puzzlepiece.fill",
                            color: .blue,
                            title: "Puzzle Alerts",
                            description: "Unlock apps by solving puzzles"
                        )
                        .opacity(animateContent ? 1.0 : 0.0)
                        .offset(x: animateContent ? 0 : 30)
                        
                        NotificationBenefitRow(
                            icon: "flame.fill",
                            color: .orange,
                            title: "Streak Reminders",
                            description: "Stay on track with daily goals"
                        )
                        .opacity(animateContent ? 1.0 : 0.0)
                        .offset(x: animateContent ? 0 : 30)
                        
                        NotificationBenefitRow(
                            icon: "heart.fill",
                            color: .pink,
                            title: "Health Updates",
                            description: "Check on \(petName)'s wellbeing"
                        )
                        .opacity(animateContent ? 1.0 : 0.0)
                        .offset(x: animateContent ? 0 : 30)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    
                    // Continue button
                    Button(action: {
                        requestNotificationPermission()
                    }) {
                        HStack(spacing: 10) {
                            if isRequesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Enable Notifications")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.primary, Color.primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: Color.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isRequesting)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                    .opacity(animateContent ? 1.0 : 0.0)
                    
                    // Skip button
                    Button(action: {
                        HapticFeedback.light.trigger()
                        showSkipConfirmation = true
                    }) {
                        Text("Skip for Now")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.bottom, 48)
                    .opacity(animateContent ? 1.0 : 0.0)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateIcon = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateContent = true
            }
        }
        .alert("Skip Notifications?", isPresented: $showSkipConfirmation) {
            Button("Enable Notifications", role: .cancel) {
                requestNotificationPermission()
            }
            Button("Skip Anyway", role: .destructive) {
                // Mark that user skipped notifications
                UserDefaults.standard.set(true, forKey: "skippedNotificationPermission")
                onContinue()
            }
        } message: {
            Text("Notifications are essential for SE7EN to work properly. You'll need them to unlock blocked apps by solving puzzles.\n\nYou can enable notifications later in Settings.")
        }
    }
    
    private func requestNotificationPermission() {
        isRequesting = true
        HapticFeedback.medium.trigger()
        
        Task {
            let granted = await NotificationService.shared.requestNotificationPermission()
            
            await MainActor.run {
                isRequesting = false
                
                if granted {
                    HapticFeedback.success.trigger()
                    UserDefaults.standard.set(false, forKey: "skippedNotificationPermission")
                    print("✅ Notification permission granted")
                } else {
                    HapticFeedback.warning.trigger()
                    print("⚠️ Notification permission denied")
                }
                
                // Continue regardless of result
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onContinue()
                }
            }
        }
    }
}

struct NotificationBenefitRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text(description)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}
