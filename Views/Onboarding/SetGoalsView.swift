import SwiftUI
import FamilyControls

struct SetGoalsView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedApps: Set<String>
    @Binding var appLimits: [String: Int]
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var titleAnimation = false
    @State private var contentAnimation = false
    @State private var buttonAnimation = false
    @State private var showingFamilyPicker = false
    @State private var familySelection = FamilyActivitySelection()
    @StateObject private var realAppDiscovery = RealAppDiscoveryService.shared
    
    private var petImageName: String {
        if let pet = appState.userPet {
            return "\(pet.type.folderName.lowercased())fullhealth"
        }
        return "dogfullhealth"
    }
    
    var body: some View {
        ZStack {
            // Light tint background
            Color(.systemBackground)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.03),
                            Color.purple.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button and progress bar
                OnboardingHeader(currentStep: 8, totalSteps: 8, showBackButton: true, onBack: onBack)
                
                Spacer()
                
                // Pet illustration
                Image(petImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .opacity(titleAnimation ? 1.0 : 0.0)
                    .scaleEffect(titleAnimation ? 1.0 : 0.8)
                    .padding(.bottom, 40)
                
                // Title and subtitle
                VStack(spacing: 16) {
                    Text("Select Your Brainrot Apps")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(titleAnimation ? 1.0 : 0.0)
                    
                    Text("Choose which apps you want to limit or block")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .opacity(titleAnimation ? 1.0 : 0.0)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
                
                // App selection card
                VStack(spacing: 20) {
                    if realAppDiscovery.isLoading {
                        ProgressView("Loading apps...")
                            .frame(maxWidth: .infinity)
                    } else if realAppDiscovery.categorizedApps.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "apps.iphone")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.textSecondary.opacity(0.5))
                            
                            Text("No apps selected yet")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            
                            Text("Tap the button below to select your apps")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(minHeight: 120)
                    } else {
                        // Show selected apps
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Selected Apps: \(realAppDiscovery.selectedApps.count)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            
                            VStack(spacing: 8) {
                                ForEach(Array(realAppDiscovery.getAllCategories()), id: \.self) { category in
                                    let appsInCategory = realAppDiscovery.getApps(for: category)
                                    if !appsInCategory.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(category.rawValue)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.textSecondary)
                                            
                                            HStack(spacing: 8) {
                                                ForEach(appsInCategory, id: \.id) { app in
                                                    VStack(spacing: 4) {
                                                        ZStack {
                                                            Circle()
                                                                .fill(Color(app.color).opacity(0.2))
                                                                .frame(width: 44, height: 44)
                                                            
                                                            Image(systemName: app.iconName)
                                                                .font(.system(size: 18, weight: .medium))
                                                                .foregroundColor(Color(app.color))
                                                        }
                                                        
                                                        Text(app.displayName)
                                                            .font(.system(size: 10, weight: .medium))
                                                            .foregroundColor(.textPrimary)
                                                            .lineLimit(2)
                                                            .multilineTextAlignment(.center)
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Select/Update apps button
                    Button(action: {
                        showingFamilyPicker = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: realAppDiscovery.selectedApps.isEmpty ? "plus.circle.fill" : "pencil.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text(realAppDiscovery.selectedApps.isEmpty ? "Select Apps from Device" : "Update App Selection")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .opacity(contentAnimation ? 1.0 : 0.0)
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Bottom text
                Text("You can update this later in Settings")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .opacity(buttonAnimation ? 1.0 : 0.0)
                    .padding(.bottom, 40)
                
                // Continue button
                Button(action: {
                    saveSelectedApps()
                    HapticFeedback.light.trigger()
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .textCase(.none)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                }
                .scaleEffect(buttonAnimation ? 1.0 : 0.95)
                .opacity(buttonAnimation ? 1.0 : 0.0)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showingFamilyPicker) {
            FamilyActivityPicker(selection: $familySelection)
                .onChange(of: familySelection) { newSelection in
                    realAppDiscovery.processSelectedApps(newSelection)
                    showingFamilyPicker = false
                }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                titleAnimation = true
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4)) {
                contentAnimation = true
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7)) {
                buttonAnimation = true
            }
        }
    }
    
    private func saveSelectedApps() {
        // Save selected apps to AppState and establish limits
        for app in realAppDiscovery.categorizedApps.values.flatMap({ $0 }) {
            selectedApps.insert(app.displayName)
            if appLimits[app.displayName] == nil {
                appLimits[app.displayName] = 60 // Default 60 minute limit
            }
            
            // Also add to AppState for tracking
            appState.addAppGoal(
                appName: app.displayName,
                bundleID: app.bundleID,
                dailyLimitMinutes: appLimits[app.displayName] ?? 60
            )
        }
    }
}
