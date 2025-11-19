import SwiftUI
import FamilyControls

struct CategoryAppSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var realAppDiscovery = RealAppDiscoveryService.shared
    
    @State private var showingFamilyPicker = false
    @State private var selectedCategory: AppCategory? = nil
    @State private var selectedApp: RealInstalledApp? = nil
    @State private var dailyLimit: Int = 60
    @State private var customLimit: String = ""
    @State private var showingCustomLimit = false
    @State private var showingConfirmation = false
    @State private var familySelection = FamilyActivitySelection()
    
    let limitOptions = [30, 60, 90, 120, 180]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if selectedApp != nil {
                    // Step 2: Set time limit (after selecting from API)
                    timeLimitView
                } else if selectedCategory != nil {
                    // Step 1b: Select app from category
                    appListView
                } else if !realAppDiscovery.categorizedApps.isEmpty {
                    // Show apps if already loaded
                    categorySelectionView
                } else {
                    // Initially empty - no category selection shown
                    Color.appBackground.ignoresSafeArea()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                if selectedCategory != nil || selectedApp != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Back") {
                            if selectedApp != nil {
                                selectedApp = nil
                            } else if selectedCategory != nil {
                                selectedCategory = nil
                            }
                        }
                        .foregroundColor(.blue)
                    }
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
                // Show the FamilyActivityPicker immediately
                showingFamilyPicker = true
            }
            .confirmationDialog("Confirm App Monitoring", isPresented: $showingConfirmation) {
                Button("Add for monitoring") {
                    addApp()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let app = selectedApp {
                    Text("Add \(app.displayName) with a \(dailyLimit) minute daily limit?")
                }
            }
        }
    }
    
    // MARK: - Category Selection View
    
    private var categorySelectionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Text("Select Category")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    Text("Choose a category to see your installed apps")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    // Refresh button to re-scan apps
                    Button(action: {
                        showingFamilyPicker = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 16))
                            Text("Scan Installed Apps")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Categories Grid
                if realAppDiscovery.isLoading {
                    ProgressView("Loading apps...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if realAppDiscovery.categorizedApps.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "apps.iphone")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.textSecondary.opacity(0.5))
                        
                        Text("No apps loaded yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Tap 'Scan Installed Apps' to load your apps")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(AppCategory.allCases) { category in
                            let appCount = realAppDiscovery.getApps(for: category).count
                            if appCount > 0 {
                                CategoryCard(
                                    category: category,
                                    appCount: appCount,
                                    isSelected: false
                                ) {
                                    selectedCategory = category
                                    HapticFeedback.light.trigger()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - App List View
    
    private var appListView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    if let category = selectedCategory {
                        HStack {
                            Image(systemName: category.icon)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.blue)
                            
                            Text(category.rawValue)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.textPrimary)
                        }
                        
                        Text("Select an app to monitor")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Apps List
                if let category = selectedCategory {
                    let apps = realAppDiscovery.getApps(for: category)
                    
                    VStack(spacing: 12) {
                        ForEach(apps) { app in
                            RealAppRow(
                                app: app,
                                isSelected: false
                            ) {
                                selectedApp = app
                                HapticFeedback.light.trigger()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Time Limit View
    
    private var timeLimitView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with selected app
                if let app = selectedApp {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(app.color).opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: app.iconName)
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(Color(app.color))
                        }
                        
                        Text(app.displayName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Set a daily time limit")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 20)
                }
                
                // Time Limit Options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Daily Time Limit")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(limitOptions, id: \.self) { limit in
                            TimeLimitButton(
                                minutes: limit,
                                isSelected: dailyLimit == limit && !showingCustomLimit
                            ) {
                                dailyLimit = limit
                                showingCustomLimit = false
                                HapticFeedback.light.trigger()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Custom limit option
                    Button(action: {
                        showingCustomLimit = true
                        customLimit = "\(dailyLimit)"
                    }) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .medium))
                            Text("Custom Limit")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(showingCustomLimit ? .white : .blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(showingCustomLimit ? Color.blue : Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    if showingCustomLimit {
                        HStack {
                            TextField("Minutes", text: $customLimit)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: customLimit) { newValue in
                                    if let minutes = Int(newValue), minutes > 0 {
                                        dailyLimit = minutes
                                    }
                                }
                            
                            Text("minutes")
                                .font(.system(size: 14))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Add Button
                Button(action: {
                    showingConfirmation = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Add \(selectedApp?.displayName ?? "App")")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .padding(.bottom, 40)
        }
    }
    
    private func addApp() {
        guard let app = selectedApp else { return }
        
        appState.addAppGoal(
            appName: app.displayName,
            bundleID: app.bundleID,
            dailyLimitMinutes: dailyLimit
        )
        
        HapticFeedback.success.trigger()
        dismiss()
    }
}

// MARK: - Supporting Views

struct CategoryCard: View {
    let category: AppCategory
    let appCount: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(categoryColor)
                }
                
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                Text("\(appCount) app\(appCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private var categoryColor: Color {
        switch category.color {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "gray": return .gray
        default: return .secondary
        }
    }
}

struct RealAppRow: View {
    let app: RealInstalledApp
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(app.color).opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: app.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(app.color))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text(app.category.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
    }
}

struct TimeLimitButton: View {
    let minutes: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text("\(minutes)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(isSelected ? .white : .textPrimary)
                
                Text("min")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isSelected ? Color.blue : Color.cardBackground)
            .cornerRadius(12)
        }
    }
}


