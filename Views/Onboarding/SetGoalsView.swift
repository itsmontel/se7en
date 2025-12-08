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
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @StateObject private var familyActivityService = FamilyActivityService.shared
    @State private var hasAutoLoadedApps = false
    
    private var petImageName: String {
        if let pet = appState.userPet {
            return "\(pet.type.folderName.lowercased())fullhealth"
        }
        return "dogfullhealth"
    }
    
    // Get the current selection
    private var currentSelection: FamilyActivitySelection {
        if !familyActivityService.selection.applicationTokens.isEmpty || !familyActivityService.selection.categoryTokens.isEmpty {
            return familyActivityService.selection
        } else if let allApps = screenTimeService.allAppsSelection {
            return allApps
        } else {
            return familySelection
        }
    }
    
    var body: some View {
        ZStack {
            // Light tint background
            Color.appBackground
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
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header with back button and progress bar
                    OnboardingHeader(currentStep: 11, totalSteps: 11, showBackButton: true, onBack: onBack)
                    
                    // Pet illustration
                    Image(petImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .opacity(titleAnimation ? 1.0 : 0.0)
                        .scaleEffect(titleAnimation ? 1.0 : 0.8)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                    
                    // Title and subtitle
                    VStack(spacing: 16) {
                        Text("Your Selected Apps")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .textCase(.none)
                            .opacity(titleAnimation ? 1.0 : 0.0)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(hasAutoLoadedApps ? "Apps selected from Screen Time authorization" : "Choose which apps you want to limit or block")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .opacity(titleAnimation ? 1.0 : 0.0)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    
                    // App selection card
                    VStack(spacing: 20) {
                        if realAppDiscovery.isLoading {
                            ProgressView("Loading apps...")
                                .frame(maxWidth: .infinity)
                        } else if currentSelection.applicationTokens.isEmpty && currentSelection.categoryTokens.isEmpty {
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
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(minHeight: 120)
                        } else {
                            // Show selected apps using Label tokens
                            selectedAppsDisplay(selection: currentSelection)
                        }
                        
                        // Select/Update apps button
                        Button(action: {
                            if screenTimeService.isAuthorized {
                                showingFamilyPicker = true
                            } else {
                                print("⚠️ Screen Time not authorized - cannot show app picker")
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: currentSelection.applicationTokens.isEmpty && currentSelection.categoryTokens.isEmpty ? "plus.circle.fill" : "pencil.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                
                                Text(currentSelection.applicationTokens.isEmpty && currentSelection.categoryTokens.isEmpty ? "Select Apps from Device" : "Update App Selection")
                                    .font(.system(size: 16, weight: .semibold))
                                    .textCase(.none)
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
                    
                    // Bottom text
                    Text("You can update this later in Settings")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .opacity(buttonAnimation ? 1.0 : 0.0)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    
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
                    .padding(.bottom, 60)
                }
            }
        }
        .sheet(isPresented: $showingFamilyPicker) {
            if screenTimeService.isAuthorized {
                FamilyActivityPickerWrapper(
                    selection: $familySelection,
                    onDone: {
                        realAppDiscovery.processSelectedApps(familySelection)
                        screenTimeService.allAppsSelection = familySelection
                        showingFamilyPicker = false
                    },
                    onSkip: {
                        showingFamilyPicker = false
                    },
                    isOnboarding: true
                )
            }
        }
        .onAppear {
            // Automatically load apps from Screen Time authorization if available
            if !hasAutoLoadedApps {
                if !familyActivityService.selection.applicationTokens.isEmpty || !familyActivityService.selection.categoryTokens.isEmpty {
                    realAppDiscovery.processSelectedApps(familyActivityService.selection)
                    screenTimeService.allAppsSelection = familyActivityService.selection
                    hasAutoLoadedApps = true
                    print("✅ Auto-loaded \(familyActivityService.selection.applicationTokens.count) apps and \(familyActivityService.selection.categoryTokens.count) categories")
                } else if let allApps = screenTimeService.allAppsSelection,
                          (!allApps.applicationTokens.isEmpty || !allApps.categoryTokens.isEmpty) {
                    realAppDiscovery.processSelectedApps(allApps)
                    hasAutoLoadedApps = true
                    print("✅ Auto-loaded \(allApps.applicationTokens.count) apps and \(allApps.categoryTokens.count) categories from allAppsSelection")
                }
            }
            
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
    
    // Display selected apps using Label tokens - no ApplicationToken type references
    @ViewBuilder
    private func selectedAppsDisplay(selection: FamilyActivitySelection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            let appCount = selection.applicationTokens.count
            let categoryCount = selection.categoryTokens.count
            
            if appCount > 0 || categoryCount > 0 {
                // Show better message when only categories are selected
                if categoryCount > 0 && appCount == 0 {
                    // Estimate apps in categories (typically 10-20 apps per category)
                    let estimatedApps = categoryCount * 15
                    Text("Selected: \(categoryCount) categor\(categoryCount == 1 ? "y" : "ies") (tracking ~\(estimatedApps) apps)")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                } else if appCount > 0 && categoryCount > 0 {
                    Text("Selected: \(appCount) app\(appCount == 1 ? "" : "s"), \(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                } else {
                    Text("Selected: \(appCount) app\(appCount == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                }
            }
            
            if !selection.applicationTokens.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Use tokens directly in ForEach - Label accepts ApplicationToken without explicit typing
                        ForEach(Array(selection.applicationTokens), id: \.self) { token in
                            // Label works directly with tokens from FamilyActivitySelection.applicationTokens
                            Label(token)
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 14, weight: .medium))
                                .padding(10)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            if !selection.categoryTokens.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Categories:")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(selection.categoryTokens), id: \.self) { categoryToken in
                                HStack(spacing: 8) {
                                    Image(systemName: "square.grid.2x2.fill")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Category")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .padding(10)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    private func saveSelectedApps() {
        let selection = currentSelection
        
        // Ensure allAppsSelection is set for dashboard
        screenTimeService.allAppsSelection = selection
        
        // Process apps if not already processed
        if realAppDiscovery.categorizedApps.isEmpty && !selection.applicationTokens.isEmpty {
            realAppDiscovery.processSelectedApps(selection)
        }
        
        // Save selected apps to AppState and establish limits
        for app in realAppDiscovery.categorizedApps.values.flatMap({ $0 }) {
            selectedApps.insert(app.displayName)
            if appLimits[app.displayName] == nil {
                appLimits[app.displayName] = 60 // Default 60 minute limit
            }
            
            // Add to AppState with Screen Time integration
            appState.addAppGoal(
                appName: app.displayName,
                bundleID: app.bundleID,
                dailyLimitMinutes: appLimits[app.displayName] ?? 60
            )
        }
    }
}
