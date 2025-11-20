import SwiftUI
import FamilyControls

struct ScreenTimeConnectionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @StateObject private var familyActivityService = FamilyActivityService.shared
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var isRequesting = false
    @State private var showFamilyPicker = false
    
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
                OnboardingHeader(currentStep: 10, totalSteps: 11, showBackButton: true, onBack: onBack)
                
                Spacer()
                
                // BrainRot style icons
                VStack(spacing: 32) {
                    HStack(spacing: 16) {
                        // Se7en app icon representation
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(petImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                        }
                        
                        // Screen Time icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.purple)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "hourglass")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack(spacing: 16) {
                        Text("Connect Se7en to Screen Time")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Your data is completely private and never leaves your device.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    if screenTimeService.isAuthorized {
                        // Already authorized
                        Button(action: {
                            HapticFeedback.light.trigger()
                            onContinue()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Connected! Continue")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.green)
                            .cornerRadius(16)
                        }
                    } else {
                        // Request authorization
                        Button(action: requestScreenTimePermissionAndShowPicker) {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Continue")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(16)
                        .disabled(isRequesting)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
            .sheet(isPresented: $showFamilyPicker) {
                NavigationView {
                    FamilyActivityPickerView(
                        selection: $familyActivityService.selection,
                        isPresented: $showFamilyPicker
                    )
                    .navigationTitle("Select Apps to Monitor")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Skip") {
                                showFamilyPicker = false
                                onContinue() // Continue even if skipped
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showFamilyPicker = false
                                onContinue() // Continue to next step
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }
    
    private func requestScreenTimePermissionAndShowPicker() {
        isRequesting = true
        
        Task {
            do {
                // Request notification permission first
                _ = await NotificationService.shared.requestNotificationPermission()
                
                // Then request Screen Time authorization
                try await screenTimeService.requestAuthorization()
                
                await MainActor.run {
                    isRequesting = false
                    if screenTimeService.isAuthorized {
                        HapticFeedback.success.trigger()
                        
                        // Show family picker after successful authorization
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showFamilyPicker = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isRequesting = false
                    print("❌ Failed to request authorization: \(error)")
                    // Optionally show an error message to the user
                }
            }
        }
    }
}


