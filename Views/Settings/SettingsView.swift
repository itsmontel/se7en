import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var remindersEnabled = true
    @State private var weeklySummaryEnabled = true
    @State private var hapticsEnabled = true
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showingPetSelection = false
    @State private var showingRenamePet = false
    @State private var newPetName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        SettingsHeroCard(streak: appState.currentStreak, credits: appState.currentCredits)
                            .padding(.top, 20)
                        
                        SettingSection(title: "Notifications", icon: "bell.badge.fill") {
                            SettingToggleRow(
                                isOn: $remindersEnabled,
                                title: "App Reminders",
                                subtitle: "Heads up when you're close to limits",
                                icon: "wave.3.right",
                                onToggle: { isOn in
                                    remindersEnabled = isOn
                                    if isOn {
                                        HapticFeedback.light.trigger()
                                    } else {
                                        HapticFeedback.warning.trigger()
                                    }
                                }
                            )
                            
                            SettingToggleRow(
                                isOn: $weeklySummaryEnabled,
                                title: "Weekly Summary",
                                subtitle: "Sunday delivery with progress insights",
                                icon: "calendar.badge.clock",
                                onToggle: { isOn in
                                    weeklySummaryEnabled = isOn
                                    HapticFeedback.light.trigger()
                                }
                            )
                        }
                        
                        SettingSection(title: "Experience", icon: "sparkles") {
                            SettingToggleRow(
                                isOn: $hapticsEnabled,
                                title: "Haptic Feedback",
                                subtitle: "Tactile responses for interactions",
                                icon: "hand.tap.fill",
                                onToggle: { isOn in
                                    hapticsEnabled = isOn
                                    if isOn {
                                        HapticFeedback.success.trigger()
                                    } else {
                                        HapticFeedback.warning.trigger()
                                    }
                                }
                            )
                            
                            SettingToggleRow(
                                isOn: $isDarkMode,
                                title: "Dark Appearance",
                                subtitle: "Automatically switch the palette",
                                icon: "moon.stars.fill",
                                onToggle: { isOn in
                                    isDarkMode = isOn
                                    HapticFeedback.light.trigger()
                                }
                            )
                        }
                        
                        SettingSection(title: "Account", icon: "person.crop.circle") {
                            SettingNavigationRow(
                                title: "Manage Subscription",
                                subtitle: "Top up credits or change plan",
                                icon: "creditcard.fill"
                            ) {
                                SubscriptionView()
                            }
                            
                            SettingButtonRow(
                                title: "Restore Purchases",
                                subtitle: "Re-activate previous credit packs",
                                icon: "arrow.clockwise.circle.fill",
                                action: {}
                            )
                        }
                        
                        SettingSection(title: "Pet", icon: "pawprint.fill") {
                            if let pet = appState.userPet {
                                SettingButtonRow(
                                    title: "Change Pet",
                                    subtitle: "Choose a different companion",
                                    icon: "arrow.left.arrow.right.circle.fill",
                                    action: {
                                        showingPetSelection = true
                                        HapticFeedback.light.trigger()
                                    }
                                )
                                
                                SettingButtonRow(
                                    title: "Rename Pet",
                                    subtitle: "Currently named '\(pet.name)'",
                                    icon: "pencil.circle.fill",
                                    action: {
                                        newPetName = pet.name
                                        showingRenamePet = true
                                        HapticFeedback.light.trigger()
                                    }
                                )
                            }
                        }
                        
                        SettingSection(title: "Support", icon: "lifepreserver") {
                            SettingNavigationRow(
                                title: "FAQ",
                                subtitle: "Answers to the most common questions",
                                icon: "questionmark.circle.fill",
                                completion: {
                                    HapticFeedback.light.trigger()
                                }
                            ) {
                                FAQView()
                            }
                            
                            SettingNavigationRow(
                                title: "Contact Support",
                                subtitle: "Talk to a real human in under 24h",
                                icon: "envelope.fill",
                                completion: {
                                    HapticFeedback.medium.trigger()
                                }
                            ) {
                                SupportView()
                            }
                            
                            SettingNavigationRow(
                                title: "Privacy Policy",
                                subtitle: "Understand how we treat your data",
                                icon: "hand.raised.fill",
                                completion: { HapticFeedback.light.trigger() }
                            ) {
                                PrivacyPolicyView()
                            }
                            
                            SettingNavigationRow(
                                title: "Terms of Service",
                                subtitle: "The agreement that keeps SE7EN fair",
                                icon: "doc.text.fill",
                                completion: { HapticFeedback.light.trigger() }
                            ) {
                                TermsOfServiceView()
                            }
                        }
                        
                        SettingSection(title: "App Info", icon: "info.circle.fill") {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Version")
                                        .font(.bodyLarge)
                                    Text("Build 1.0.0")
                                        .font(.caption)
                                        .foregroundColor(.textPrimary.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                Capsule()
                                    .fill(Color.primary.opacity(0.15))
                                    .frame(width: 60, height: 28)
                                    .overlay(
                                        Text("Live")
                                            .font(.captionBold)
                                            .foregroundColor(.primary)
                                    )
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingPetSelection) {
                PetSelectionSheet(isPresented: $showingPetSelection)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingRenamePet) {
                RenamePetSheet(isPresented: $showingRenamePet, petName: $newPetName)
                    .environmentObject(appState)
            }
        }
    }
}

// MARK: - Settings Components

struct SettingsHeroCard: View {
    let streak: Int
    let credits: Int
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SE7EN Profile")
                        .font(.captionBold)
                        .foregroundColor(.white.opacity(0.8))
                    Text("Keep the streak alive.")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Text("7")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Streak")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(streak) days")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Credits")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(credits)/7")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Text("Upgrade Plan")
                        .font(.captionBold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.primary, Color.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(32)
        .shadow(color: Color.primary.opacity(0.25), radius: 30, x: 0, y: 15)
    }
}

struct SettingSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(.primary)
                Text(title)
                    .font(.captionBold)
                    .foregroundColor(.textPrimary.opacity(0.7))
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 16) {
                content
            }
            .padding(20)
            .cardStyle()
        }
    }
}

struct QuickToggleButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isOn: Bool
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .foregroundColor(.white)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: gradient.last?.opacity(0.3) ?? .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingToggleRow: View {
    @Binding var isOn: Bool
    let title: String
    let subtitle: String
    let icon: String
    var onToggle: ((Bool) -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            SettingIcon(icon: icon, tint: .primary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.textPrimary.opacity(0.6))
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(get: {
                isOn
            }, set: { newValue in
                isOn = newValue
                onToggle?(newValue)
            }))
                .labelsHidden()
                .tint(.primary)
        }
    }
}

struct SettingNavigationRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let destination: Destination
    var completion: (() -> Void)? = nil
    
    init(title: String, subtitle: String, icon: String, completion: (() -> Void)? = nil, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.destination = destination()
        self.completion = completion
    }
    
    var body: some View {
        NavigationLink(
            destination: destination
                .onAppear {
                    completion?()
                }
        ) {
            HStack(spacing: 16) {
                SettingIcon(icon: icon, tint: .primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.bodyLarge)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textPrimary.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.captionBold)
                    .foregroundColor(.textPrimary.opacity(0.4))
            }
        }
    }
}

struct SettingButtonRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                SettingIcon(icon: icon, tint: .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.bodyLarge)
                        .foregroundColor(.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textPrimary.opacity(0.6))
                }
                
                Spacer()
            }
        }
    }
}

struct SettingIcon: View {
    let icon: String
    let tint: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(tint.opacity(0.12))
                .frame(width: 44, height: 44)
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(tint)
        }
    }
}

// MARK: - Pet Selection Sheet

struct PetSelectionSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Text("Choose Your Pet")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(PetType.allCases, id: \.self) { petType in
                                Button(action: {
                                    if let currentPet = appState.userPet {
                                        appState.userPet = Pet(type: petType, name: currentPet.name, healthState: currentPet.healthState)
                                    } else {
                                        appState.userPet = Pet(type: petType, name: petType.rawValue, healthState: .fullHealth)
                                    }
                                    HapticFeedback.medium.trigger()
                                    isPresented = false
                                }) {
                                    HStack(spacing: 16) {
                                        Image("\(petType.folderName.lowercased())fullhealth")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 60)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(petType.rawValue)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.textPrimary)
                                            
                                            Text(petType.description)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.textSecondary)
                                                .lineLimit(2)
                                        }
                                        
                                        Spacer()
                                        
                                        if appState.userPet?.type == petType {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(16)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

// MARK: - Rename Pet Sheet

struct RenamePetSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @Binding var petName: String
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Rename Your Pet")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .padding(.top, 24)
                    
                    if let pet = appState.userPet {
                        Image("\(pet.type.folderName.lowercased())fullhealth")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .padding(.vertical, 20)
                        
                        VStack(spacing: 8) {
                            Text("New Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("Enter pet name", text: $petName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textPrimary)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: { isPresented = false }) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            if !petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               var updatedPet = appState.userPet {
                                updatedPet.name = petName.trimmingCharacters(in: .whitespacesAndNewlines)
                                appState.userPet = updatedPet
                                HapticFeedback.success.trigger()
                            }
                            isPresented = false
                        }) {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
