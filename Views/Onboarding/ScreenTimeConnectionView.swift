import SwiftUI
import FamilyControls
import Combine
import DeviceActivity

struct ScreenTimeConnectionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var screenTimeService = ScreenTimeService.shared
    @StateObject private var familyActivityService = FamilyActivityService.shared
    let onContinue: () -> Void
    let onBack: (() -> Void)?
    
    @State private var isRequesting = false
    @State private var showFamilyPicker = false
    @State private var shouldTriggerReport = false
    
    private var petImageName: String {
        if let pet = appState.userPet {
            return "\(pet.type.folderName.lowercased())fullhealth"
        }
        return "dogfullhealth"
    }
    
    @ViewBuilder
    private var hiddenReportTrigger: some View {
        if shouldTriggerReport {
            let dateInterval = DateInterval(
                start: Calendar.current.startOfDay(for: Date()),
                end: Date()
            )
            let filter = DeviceActivityFilter(
                segment: .daily(during: dateInterval),
                users: .all,
                devices: .init([.iPhone, .iPad])
            )
            
            // This triggers TotalActivityReport extension which writes to shared container
            DeviceActivityReport(.totalActivity, filter: filter)
                .frame(width: 1, height: 1)
                .opacity(0)
                .allowsHitTesting(false)
        }
    }
    
    var body: some View {
        ZStack {
            OnboardingBackground()
            
            // Hidden report trigger
            hiddenReportTrigger
            
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
                        Text("Connect Se7en\nto Screen Time")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                        
                        Text("Select ALL apps to track your screen time. This is required for the app to work properly.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Show message if authorization is not approved
                    if screenTimeService.authorizationStatus != .approved {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            
                            Text("Screen Time access is required to see your daily screen time and top apps")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    if screenTimeService.isAuthorized {
                        // Check if apps are already selected
                        if let allApps = screenTimeService.allAppsSelection,
                           (!allApps.applicationTokens.isEmpty || !allApps.categoryTokens.isEmpty) {
                            // Already have apps selected - can continue
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
                            // Authorized but no apps selected - show picker
                            Button(action: {
                                HapticFeedback.light.trigger()
                                showFamilyPicker = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "apps.iphone")
                                    Text("Select Apps")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.blue)
                                .cornerRadius(16)
                            }
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
            .onAppear {
                // Request authorization when view appears (if not already authorized)
                if !screenTimeService.isAuthorized {
                    Task {
                        do {
                            await screenTimeService.requestAuthorization()
                            // After authorization, show picker
                            if screenTimeService.isAuthorized {
                                await MainActor.run {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        showFamilyPicker = true
                                    }
                                }
                            }
                        } catch {
                            print("❌ Failed to request authorization: \(error)")
                        }
                    }
                } else {
                    // Already authorized - check if we need to show picker
                    if screenTimeService.allAppsSelection == nil ||
                       (screenTimeService.allAppsSelection?.applicationTokens.isEmpty ?? true &&
                        screenTimeService.allAppsSelection?.categoryTokens.isEmpty ?? true) {
                        // No apps selected yet - show picker automatically
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showFamilyPicker = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showFamilyPicker) {
                // Use a wrapper view to properly handle the picker with buttons
                // Require selecting ALL apps - no skip option during onboarding
                FamilyActivityPickerWrapper(
                        selection: $familyActivityService.selection,
                    onDone: {
                        print("🎯 onDone called with \(familyActivityService.selection.applicationTokens.count) apps")
                        
                        // Require at least some apps OR categories selected
                        // Categories are actually preferred as they auto-include all apps in those categories
                        guard !familyActivityService.selection.applicationTokens.isEmpty || !familyActivityService.selection.categoryTokens.isEmpty else {
                            print("⚠️ No apps or categories selected, keeping picker open")
                            return
                        }
                        
                        print("🔄 Processing selection:")
                        print("   Apps: \(familyActivityService.selection.applicationTokens.count)")
                        print("   Categories: \(familyActivityService.selection.categoryTokens.count)")
                        
                        // Categories are better - they automatically include all apps in those categories
                        if !familyActivityService.selection.categoryTokens.isEmpty {
                            print("✅ Using category-based selection - this will track ALL apps in selected categories")
                        }
                        
                        // Ensure we're on main thread for UI updates
                        DispatchQueue.main.async {
                            // Save selection to allAppsSelection for dashboard FIRST
                            screenTimeService.allAppsSelection = familyActivityService.selection
                            print("💾 Saved allAppsSelection with \(familyActivityService.selection.applicationTokens.count) apps and \(familyActivityService.selection.categoryTokens.count) categories")
                            
                            // Verify it was saved
                            if let saved = screenTimeService.allAppsSelection {
                                print("✅ Verification: allAppsSelection now has \(saved.applicationTokens.count) apps and \(saved.categoryTokens.count) categories")
                            } else {
                                print("❌ ERROR: allAppsSelection is still nil after saving!")
                            }
                            
                            // Process the apps using RealAppDiscoveryService
                            let realAppDiscovery = RealAppDiscoveryService.shared
                            realAppDiscovery.processSelectedApps(familyActivityService.selection)
                            print("🔄 Processed apps with RealAppDiscoveryService")
                            
                            // Close picker
                            showFamilyPicker = false
                            
                            // ✅ CRITICAL FIX: Trigger DeviceActivityReport to fetch today's FULL usage
                            // This includes usage from BEFORE the app was installed
                            shouldTriggerReport = true
                            print("📊 Triggered DeviceActivityReport to fetch historical usage for today")
                            
                            // Force immediate update of usage from reports in background
                            Task {
                                await screenTimeService.updateUsageFromReport()
                                print("📊 Updated usage from reports")
                                
                                // Post notification to refresh dashboard
                                await MainActor.run {
                                    NotificationCenter.default.post(name: .screenTimeDataUpdated, object: nil)
                                }
                            }
                            
                            print("✅ Completed app selection processing, continuing...")
                            
                            // Give the report extension time to run and write to shared container
                            // Then continue to next step
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                // Force AppState to preload the new data
                                // AppState will be refreshed via notification
                                onContinue()
                            }
                        }
                    },
                    onSkip: {
                        // Don't allow skip during onboarding - require selection
                        print("⚠️ Skip not allowed during onboarding")
                    },
                    isOnboarding: true
                )
            }
        }
    }
    
    private func requestScreenTimePermissionAndShowPicker() {
        isRequesting = true
        
        Task {
            // Request Screen Time authorization
            await screenTimeService.requestAuthorization()
            
            await MainActor.run {
                isRequesting = false
                if screenTimeService.isAuthorized {
                    HapticFeedback.success.trigger()
                    
                    // Show family picker after successful authorization
                    // Give a bit more time for authorization to fully complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("🔐 Authorization complete, showing picker")
                        showFamilyPicker = true
                    }
                }
            }
        }
    }
}


