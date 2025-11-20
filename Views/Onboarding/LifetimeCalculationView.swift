import SwiftUI

struct LifetimeCalculationView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var showTitle = false
    @State private var showCalculation = false
    @State private var showPet = false
    @State private var showButton = false
    @State private var backgroundIntensity: Double = 0.0
    @State private var animatedYears: Double = 0.0
    @State private var animationTasks: [Task<Void, Never>] = []
    
    private var hoursPerDay: Int {
        appState.averageScreenTimeHours
    }
    
    // Correct lifetime calculation
    private var yearsOfLife: Double {
        let averageLifespan = 78.0 // years
        let wakingHoursPerDay = 16.0 // assuming 8 hours sleep
        let totalWakingHours = averageLifespan * 365 * wakingHoursPerDay
        let screenTimeHours = averageLifespan * 365 * Double(hoursPerDay)
        return screenTimeHours / (365 * 24) // Convert to years
    }
    
    private var percentageOfLife: Double {
        let wakingHoursPerDay = 16.0
        return (Double(hoursPerDay) / wakingHoursPerDay) * 100
    }
    
    private var petType: String {
        appState.userPet?.type.folderName.lowercased() ?? "dog"
    }
    
    var body: some View {
        ZStack {
            // Dramatic background that gets darker
            Color(.systemBackground)
                .overlay(
                    Color.black.opacity(backgroundIntensity * 0.1)
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button and progress bar
                OnboardingHeader(currentStep: 8, totalSteps: 11, showBackButton: true, onBack: onBack)
                
                Spacer()
                
                VStack(spacing: 40) {
                    // Dramatic title
                    if showTitle {
                        Text("You're on track to spend")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .textCase(.none)
                            .opacity(showTitle ? 1.0 : 0.0)
                            .scaleEffect(showTitle ? 1.0 : 0.8)
                    }
                    
                    // Shocking calculation with number counting animation
                    if showCalculation {
                        VStack(spacing: 16) {
                            Text("\(Int(animatedYears)) years")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                                .scaleEffect(showCalculation ? 1.0 : 0.3)
                                .opacity(showCalculation ? 1.0 : 0.0)
                                .shadow(color: .red.opacity(0.3), radius: 20, x: 0, y: 0)
                            
                            Text("of your life on screens")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .opacity(showCalculation ? 1.0 : 0.0)
                        }
                    }
                    
                    // Sick pet with dramatic entrance
                    if showPet {
                        VStack(spacing: 24) {
                            Image("\(petType)sick")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 200, height: 200)
                                .scaleEffect(showPet ? 1.0 : 0.3)
                                .opacity(showPet ? 1.0 : 0.0)
                                .rotationEffect(.degrees(showPet ? 0 : -180))
                            
                            VStack(spacing: 8) {
                                Text("Projection based on 16 waking hours per day")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                    .opacity(showPet ? 1.0 : 0.0)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Dramatic call to action
                if showButton {
                    Button(action: {
                        HapticFeedback.heavy.trigger()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onContinue()
                        }
                    }) {
                        Text("Next")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .textCase(.none)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(16)
                    }
                    .scaleEffect(showButton ? 1.0 : 0.8)
                    .opacity(showButton ? 1.0 : 0.0)
                    .padding(.horizontal, 24)
                }
                
                Spacer().frame(height: 48)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            // Cancel all pending animations when view disappears
            for task in animationTasks {
                task.cancel()
            }
            animationTasks.removeAll()
        }
    }
    
    private func startAnimations() {
        // Dramatic sequence of animations
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            showTitle = true
            backgroundIntensity = 0.3
        }
        
        // Show calculation container
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.2)) {
            showCalculation = true
            backgroundIntensity = 0.6
            HapticFeedback.heavy.trigger()
        }
        
        // Simplified counting animation for better performance
        let countingTask = Task { @MainActor in
            // Wait for initial delay
            try? await Task.sleep(nanoseconds: 1_300_000_000) // 1.3 seconds
            
            // Check if cancelled
            guard !Task.isCancelled else { return }
            
            let targetYears = yearsOfLife
            let duration: Double = 0.8 // Shorter duration for better performance
            let steps = 20 // Fewer steps to reduce UI updates
            let increment = targetYears / Double(steps)
            
            // Animate counting with fewer updates
            for i in 0...steps {
                // Check if cancelled before each step
                guard !Task.isCancelled else { return }
                
                try? await Task.sleep(nanoseconds: UInt64((duration / Double(steps)) * 1_000_000_000))
                
                // Check again after sleep
                guard !Task.isCancelled else { return }
                
                animatedYears = increment * Double(i)
                
                // Reduced haptic feedback for better performance
                if i == steps {
                    HapticFeedback.heavy.trigger()
                }
            }
        }
        animationTasks.append(countingTask)
        
        // Show pet with delay
        let petTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_200_000_000) // 3.2 seconds
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 1.0, dampingFraction: 0.4)) {
                showPet = true
                backgroundIntensity = 0.9
                HapticFeedback.heavy.trigger()
            }
        }
        animationTasks.append(petTask)
        
        // Show button with delay
        let buttonTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_200_000_000) // 4.2 seconds
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeOut(duration: 0.6)) {
                showButton = true
            }
        }
        animationTasks.append(buttonTask)
    }
}


