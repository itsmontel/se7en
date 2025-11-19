import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingCreditLossAlert = false
    @State private var showingSuccessToast = false
    @State private var creditsLostInAlert = 0
    @State private var showingAddAppSheet = false
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    private var healthScore: Int {
        // Calculate health based on actual app usage
        let totalUsageToday = appState.monitoredApps.reduce(0) { $0 + $1.usedToday }
        let totalLimits = appState.monitoredApps.reduce(0) { $0 + $1.dailyLimit }
        
        guard totalLimits > 0 else { return 100 }
        
        let usagePercentage = Double(totalUsageToday) / Double(totalLimits)
        
        // Convert usage percentage to health score (inverse relationship)
        switch usagePercentage {
        case 0...0.5: return 100 // Under 50% usage = perfect health
        case 0.5...0.7: return 80 // 50-70% usage = good health
        case 0.7...0.9: return 60 // 70-90% usage = okay health
        case 0.9...1.1: return 40 // 90-110% usage = poor health
        default: return 20 // Over 110% usage = very poor health
        }
    }
    
    private var healthColor: Color {
        switch healthScore {
        case 0..<25: return .red
        case 25..<50: return .orange
        case 50..<75: return .yellow
        case 75...100: return .green
        default: return .green
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header with greeting and date selection
                        VStack(alignment: .leading, spacing: 12) {
                            // Time-based greeting
                            Text(timeBasedGreeting(userName: appState.userName))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                            
                            // Date selector - clickable to show picker
                            HStack {
                                Button(action: {
                                    showingDatePicker = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.system(size: 16, weight: .semibold))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(20)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        
                        // Pet name and credits on same line
                        HStack(alignment: .center) {
                            // Pet name (actual name, not type)
                            if let pet = appState.userPet {
                                Text(pet.name)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                            }
                            
                            Spacer()
                            
                            // Circular credits display
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                VStack(spacing: 2) {
                                    Text("\(appState.currentCredits)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("credits")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                        
                        // Large pet illustration
                        if appState.userPet != nil {
                            let petImageName = "\(appState.userPet!.type.folderName.lowercased())fullhealth"
                            Image(petImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 280)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 40)
                        }
                        
                        // Health score number (correlated with actual health)
                        Text("\(healthScore)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .padding(.bottom, 16)
                        
                        // Health bar (color based on score)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(healthColor)
                            .frame(height: 8)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                        
                        // Health label and message
                        VStack(spacing: 12) {
                            HStack {
                                Spacer()
                                Text("Health")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                Spacer()
                            }
                            
                            // Health message based on score
                            if let pet = appState.userPet {
                                Text(healthMessage(petName: pet.name, score: healthScore))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(healthColor)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 40)
                        
                        // Divider
                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        
                        // App Usage
                        VStack(alignment: .leading, spacing: 16) {
                            Text("App Usage")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(appState.monitoredApps, id: \.id) { app in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(spacing: 12) {
                                            // App Icon
                                            ZStack {
                                                Circle()
                                                    .fill(app.color.opacity(0.15))
                                                    .frame(width: 48, height: 48)
                                                
                                                Image(systemName: app.icon)
                                                    .font(.system(size: 22))
                                                    .foregroundColor(app.color)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(app.name)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.textPrimary)
                                                
                                                HStack(spacing: 4) {
                                                    Text(formatMinutes(app.usedToday))
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(app.statusColor)
                                                    
                                                    Text("/ \(formatMinutes(app.dailyLimit))")
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.textSecondary)
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                        
                                        // Progress Bar
                                        GeometryReader { geometry in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color.gray.opacity(0.15))
                                                    .frame(height: 6)
                                                
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(app.statusColor)
                                                    .frame(width: geometry.size.width * min(app.percentageUsed, 1.0), height: 6)
                                            }
                                        }
                                        .frame(height: 6)
                                        
                                        // Time Remaining
                                        HStack {
                                            if app.isOverLimit {
                                                Text("Over by \(formatMinutes(app.usedToday - app.dailyLimit))")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.error)
                                            } else {
                                                Text("\(formatMinutes(app.remainingMinutes)) remaining")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.success)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .padding(16)
                                    .background(Color.cardBackground)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 20)
                                }
                                
                                // Add App Button
                                Button(action: {
                                    showingAddAppSheet = true
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.blue)
                                        
                                        Text("Add App")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.blue)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
                
                // Overlays
                if showingCreditLossAlert {
                    CreditLossAlert(
                        isPresented: $showingCreditLossAlert,
                        creditsLost: creditsLostInAlert,
                        creditsRemaining: appState.currentCredits
                    )
                }
                
                if showingSuccessToast {
                    SuccessToast(
                        message: "Great job staying on track!",
                        isPresented: $showingSuccessToast
                    )
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CompactStreakView(streak: appState.currentStreak)
                }
            }
            .sheet(isPresented: $showingAddAppSheet) {
                CategoryAppSelectionView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingDatePicker) {
                DateHistoryPicker(
                    selectedDate: $selectedDate,
                    isPresented: $showingDatePicker,
                    appState: appState
                )
            }
        }
    }
    
    // Helper function to generate time-based greeting
    private func timeBasedGreeting(userName: String) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let displayName = userName.isEmpty ? "there" : userName
        
        switch hour {
        case 5..<12:
            return "Good Morning, \(displayName)"
        case 12..<17:
            return "Good Afternoon, \(displayName)"
        case 17..<21:
            return "Good Evening, \(displayName)"
        default:
            return "Good Night, \(displayName)"
        }
    }
    
    // Helper function to format minutes
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    // Helper function to generate health message
    private func healthMessage(petName: String, score: Int) -> String {
        switch score {
        case 100:
            return "\(petName)'s health is amazing, you're doing a great job today!"
        case 80...99:
            return "\(petName) is feeling great! Keep it up!"
        case 60...79:
            return "\(petName) is doing well. A little more restraint today!"
        case 40...59:
            return "\(petName) isn't feeling great. Try to use your apps less."
        case 20...39:
            return "\(petName) is struggling. Please limit your screen time."
        default:
            return "\(petName) is very sick. You need to take a break!"
        }
    }
    
    // Demo function to simulate credit loss
    private func simulateCreditLoss() {
        creditsLostInAlert = 1
        appState.deductCredit(for: "Demo App", reason: "Simulation")
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingCreditLossAlert = true
        }
    }
}

struct EmptyAppsView: View {
    let onAddApp: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.textPrimary.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("No apps being monitored")
                    .font(.h4)
                    .foregroundColor(.textPrimary)
                
                Text("Add apps to start tracking your usage")
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onAddApp) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Your First App")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.primary)
                .cornerRadius(25)
            }
        }
        .padding(32)
        .cardStyle()
    }
}

struct AddAppSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var appDiscovery = AppDiscoveryService.shared
    @State private var selectedApp: InstalledApp?
    @State private var dailyLimit: Int = 60
    @State private var customLimit: String = ""
    @State private var showingCustomLimit = false
    @State private var showingConfirmation = false
    @State private var lockDuration: LockDuration = .oneDay
    
    enum LockDuration: String, CaseIterable {
        case oneDay = "1 Day"
        case oneWeek = "1 Week"
        case custom = "Custom"
    }
    
    // Computed property to avoid complex inline expressions
    private var monitorableApps: [InstalledApp] {
        appDiscovery.installedApps.filter { appDiscovery.canMonitorApp($0.bundleID) }
    }
    
    // Helper methods to avoid complex boolean expressions
    private func isAppSelected(_ app: InstalledApp) -> Bool {
        return selectedApp?.bundleID == app.bundleID
    }
    
    private func isLimitSelected(_ limit: Int) -> Bool {
        return dailyLimit == limit && !showingCustomLimit
    }
    
    // Computed properties for button styling
    private var customButtonTextColor: Color {
        showingCustomLimit ? .white : .primary
    }
    
    private var customButtonBackgroundColor: Color {
        showingCustomLimit ? Color.primary : Color.primary.opacity(0.1)
    }
    
    // Computed property for confirmation message
    private var confirmationMessage: String {
        let appName = selectedApp?.displayName ?? ""
        return "Are you sure you want to monitor \(appName)? This setting cannot be changed today once set."
    }
    
    // Computed property for add button text
    private var addButtonText: String {
        if let app = selectedApp {
            return "Add \(app.displayName)"
        } else {
            return "Select an App"
        }
    }
    
    let limitOptions = [30, 60, 90, 120, 180]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Add App to Monitor")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    Text("Choose an app and set a daily time limit")
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // App Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Select App")
                                .font(.h4)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 20)
                            
                            VStack {
                                if appDiscovery.isLoading {
                                    ProgressView("Scanning installed apps...")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                        ForEach(monitorableApps) { app in
                                            RealAppSelectionCard(
                                                app: app,
                                                isSelected: isAppSelected(app)
                                            ) {
                                                selectedApp = app
                                                HapticFeedback.light.trigger()
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Time Limit Selection
                        if selectedApp != nil {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Daily Time Limit")
                                    .font(.h4)
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 20)
                                
                                VStack(spacing: 12) {
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                        ForEach(limitOptions, id: \.self) { limit in
                                            TimeLimitCard(
                                                minutes: limit,
                                                isSelected: isLimitSelected(limit)
                                            ) {
                                                dailyLimit = limit
                                                showingCustomLimit = false
                                                HapticFeedback.light.trigger()
                                            }
                                        }
                                    }
                                    
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
                                        .foregroundColor(customButtonTextColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(customButtonBackgroundColor)
                                        .cornerRadius(12)
                                    }
                                    
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
                                                .font(.bodyMedium)
                                                .foregroundColor(.textPrimary.opacity(0.7))
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
                
                // Add Button
                if selectedApp != nil {
                    VStack {
                        Button(action: { showingConfirmation = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(addButtonText)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary)
                            .cornerRadius(25)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(Color.appBackground)
                }
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                appDiscovery.discoverInstalledApps()
            }
            .confirmationDialog("Confirm App Monitoring", isPresented: $showingConfirmation) {
                Button("Add for 1 Day") {
                    addApp(duration: .oneDay)
                }
                Button("Add for 1 Week") {
                    addApp(duration: .oneWeek)
                }
                Button("Custom Duration") {
                    // For now, default to 1 week - you can expand this later
                    addApp(duration: .oneWeek)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(confirmationMessage)
            }
        }
    }
    
    private func addApp(duration: LockDuration) {
        guard let app = selectedApp else { return }
        
        appState.addAppGoal(
            appName: app.displayName, 
            bundleID: app.bundleID, 
            dailyLimitMinutes: dailyLimit
        )
        
        // TODO: Store duration information for future use
        print("Added \(app.displayName) with \(dailyLimit) minute limit for \(duration.rawValue)")
        
        HapticFeedback.success.trigger()
        dismiss()
    }
}

struct RealAppSelectionCard: View {
    let app: InstalledApp
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(app.color).opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    if let icon = app.icon {
                        Image(uiImage: icon)
                            .resizable()
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Image(systemName: app.iconName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(app.color))
                    }
                }
                
                Text(app.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.primary.opacity(0.1) : Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct AppSelectionCard: View {
    let appName: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(appName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.primary.opacity(0.1) : Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct TimeLimitCard: View {
    let minutes: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? .white : .textPrimary)
                
                Text("min")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .textPrimary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.primary : Color.cardBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Compact Streak View for Toolbar

struct CompactStreakView: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(streakColor.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Image(systemName: streakIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(streakColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("\(streak)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                Text("streak")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground.opacity(0.8))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private var streakColor: Color {
        switch streak {
        case 0:
            return .gray
        case 1...2:
            return .green
        case 3...6:
            return .orange
        case 7...13:
            return .red
        case 14...29:
            return .purple
        case 30...99:
            return .blue
        default:
            return .yellow
        }
    }
    
    private var streakIcon: String {
        switch streak {
        case 0:
            return "minus.circle.fill"
        case 1...2:
            return "checkmark.circle.fill"
        case 3...6:
            return "flame.fill"
        case 7...13:
            return "flame.fill"
        case 14...29:
            return "crown.fill"
        case 30...99:
            return "star.circle.fill"
        default:
            return "trophy.fill"
        }
    }
}

// MARK: - Date History Picker

struct DateHistoryPicker: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    let appState: AppState
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Health History")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Text("View your pet's health on different days")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            // Show last 30 days
                            ForEach((0..<30).reversed(), id: \.self) { daysAgo in
                                let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
                                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                                let healthData = getHealthData(for: date)
                                
                                Button(action: {
                                    selectedDate = date
                                    isPresented = false
                                }) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.textPrimary)
                                            
                                            Text(dayName(date))
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Health indicator
                                        VStack(alignment: .trailing, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "heart.fill")
                                                    .font(.system(size: 12, weight: .semibold))
                                                Text("\(healthData.score)")
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            .foregroundColor(healthData.color)
                                            
                                            Text(healthData.status)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.textSecondary)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.textSecondary.opacity(0.5))
                                    }
                                    .padding(16)
                                    .background(isSelected ? Color.blue.opacity(0.1) : Color.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    
                    // Close button
                    Button(action: { isPresented = false }) {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func getHealthData(for date: Date) -> (score: Int, color: Color, status: String) {
        // Calculate health score based on historical data
        // For now, simulate based on how recent the date is
        let daysAgo = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        
        let score: Int
        let color: Color
        let status: String
        
        // Simulate health data - in real app, this would come from CoreData
        switch daysAgo {
        case 0: // Today
            score = 100
            color = .green
            status = "Full Health"
        case 1...2:
            score = Int.random(in: 80...95)
            color = .green
            status = "Great"
        case 3...7:
            score = Int.random(in: 60...85)
            color = .orange
            status = "Good"
        case 8...14:
            score = Int.random(in: 40...70)
            color = .yellow
            status = "Okay"
        case 15...21:
            score = Int.random(in: 20...50)
            color = .orange
            status = "Poor"
        default:
            score = Int.random(in: 10...40)
            color = .red
            status = "Sick"
        }
        
        return (score, color, status)
    }
}


