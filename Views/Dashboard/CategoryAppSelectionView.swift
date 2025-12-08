import SwiftUI
import FamilyControls

struct CategoryAppSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @StateObject private var realAppDiscovery = RealAppDiscoveryService.shared
    @State private var familySelection = FamilyActivitySelection()
    @State private var showingFamilyPicker = false
    @State private var selectedAppIndex: Int? = nil
    @State private var dailyLimit: Int = 60
    @State private var showingCustomLimit = false
    @State private var customLimitText: String = ""
    @State private var step: SelectionStep = .pickApps
    
    private let screenTimeService = ScreenTimeService.shared
    private let limitOptions = [15, 30, 60, 90, 120, 180]
    
    enum SelectionStep {
        case pickApps
        case setLimit
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if !screenTimeService.isAuthorized {
                    notAuthorizedView
                } else {
                    switch step {
                    case .pickApps:
                        appPickerView
                    case .setLimit:
                        limitSelectionView
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
                
                if step == .setLimit {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Back") {
                            step = .pickApps
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingFamilyPicker) {
                FamilyActivityPickerWrapper(
                    selection: $familySelection,
                    onDone: {
                        if !familySelection.applicationTokens.isEmpty {
                            print("✅ Selected \(familySelection.applicationTokens.count) apps")
                            // Process the selection to extract bundle IDs properly
                            realAppDiscovery.processSelectedApps(familySelection)
                            showingFamilyPicker = false
                            step = .setLimit
                        }
                    },
                    onSkip: {
                        showingFamilyPicker = false
                    },
                    isOnboarding: false
                )
            }
            .onAppear {
                if screenTimeService.isAuthorized {
                showingFamilyPicker = true
            }
            }
        }
    }
    
    // MARK: - Not Authorized View
    
    private var notAuthorizedView: some View {
            VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("Screen Time Not Authorized")
                .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
            Text("Please enable Screen Time permissions to add apps for monitoring.")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
                            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Color.blue)
            .cornerRadius(12)
        }
    }
    
    // MARK: - App Picker View
    
    private var appPickerView: some View {
            VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "apps.iphone")
                    .font(.system(size: 64, weight: .light))
                                .foregroundColor(.blue)
                            
                Text("Select Apps to Monitor")
                    .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.textPrimary)
                        
                Text("Choose which apps you want to set limits for")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            Button(action: { showingFamilyPicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("Open App Picker")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(14)
                    }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Limit Selection View
    
    private var limitSelectionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.blue)
                        
                    Text("Set Daily Limit")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                    let appCount = realAppDiscovery.categorizedApps.values.flatMap { $0 }.count
                    Text("\(appCount) app\(appCount == 1 ? "" : "s") selected")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 20)
                
                // Limit options
                VStack(spacing: 12) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(limitOptions, id: \.self) { limit in
                            TimeLimitOptionButton(
                                minutes: limit,
                                isSelected: dailyLimit == limit && !showingCustomLimit,
                                action: {
                                dailyLimit = limit
                                showingCustomLimit = false
                            }
                            )
                        }
                    }
                    
                    // Custom limit
                    Button(action: {
                        showingCustomLimit = true
                        customLimitText = "\(dailyLimit)"
                    }) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Custom Limit")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(showingCustomLimit ? .white : .blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(showingCustomLimit ? Color.blue : Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    if showingCustomLimit {
                        HStack {
                            TextField("Minutes", text: $customLimitText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: customLimitText) { value in
                                    if let minutes = Int(value), minutes > 0 {
                                        dailyLimit = minutes
                                    }
                                }
                            
                            Text("minutes")
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Add button
                Button(action: addApps) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        let appCount = realAppDiscovery.categorizedApps.values.flatMap { $0 }.count
                        Text("Add \(appCount) App\(appCount == 1 ? "" : "s")")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Add Apps
    
    private func addApps() {
        // Get all apps from RealAppDiscoveryService (already processed with correct bundle IDs)
        let allApps = realAppDiscovery.categorizedApps.values.flatMap { $0 }
        print("🔄 Adding \(allApps.count) apps with \(dailyLimit) minute limit")
        
        guard !allApps.isEmpty else {
            print("❌ No apps to add")
            return
        }
        
        // Use the stored selection from RealAppDiscoveryService
        let selection = realAppDiscovery.currentSelection
        
        // For each app, create a goal with the correct bundle ID and token
        for app in allApps {
            print("📱 Processing app: \(app.displayName) (\(app.bundleID))")
            
            // Use the full selection for each app
            // Since tokens are opaque and we track by bundle ID, this works correctly
            // Each app will be monitored individually based on its bundle ID
            let singleAppSelection = selection
            print("✅ Using selection with \(selection.applicationTokens.count) token(s) for \(app.displayName)")
            
            // Add to service with the REAL bundle ID from RealAppDiscoveryService
            screenTimeService.addAppForMonitoring(
                selection: singleAppSelection,
            appName: app.displayName,
                bundleID: app.bundleID, // Use the extracted bundle ID from RealAppDiscoveryService
            dailyLimitMinutes: dailyLimit
        )
            
            print("✅ Added \(app.displayName) with bundle ID: \(app.bundleID)")
        }
        
        // Refresh app state
        appState.loadAppGoals()
        
        // Post notification to refresh UI
        NotificationCenter.default.post(name: .screenTimeDataUpdated, object: nil)
        
        HapticFeedback.success.trigger()
        dismiss()
    }
    
    // MARK: - Helpers
}

// MARK: - Supporting Views

struct TimeLimitOptionButton: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.system(size: 20, weight: .bold))
                Text("min")
                    .font(.system(size: 12))
            }
            .foregroundColor(isSelected ? .white : .textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue : Color.cardBackground)
            .cornerRadius(12)
        }
    }
}

#Preview {
    CategoryAppSelectionView()
        .environmentObject(AppState())
}
