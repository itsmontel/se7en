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
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    HStack {
                        Spacer()
                        VStack(spacing: 32) {
                        // Hero Section
                        SettingsHeroCard(streak: appState.currentStreak)
                            .padding(.top, 10)
                        
                        // Settings Groups
                        VStack(spacing: 24) {
                            // Account & Pet
                            SettingsGroup(title: "My Companion") {
                                if let pet = appState.userPet {
                                    SettingRow(
                                        icon: "arrow.triangle.2.circlepath",
                                        color: .blue,
                                        title: "Change Pet",
                                        subtitle: "Switch your companion"
                                    ) {
                                        showingPetSelection = true
                                        HapticFeedback.light.trigger()
                                    }
                                    
                                    SettingRow(
                                        icon: "pencil",
                                        color: .purple,
                                        title: "Rename Pet",
                                        subtitle: "Current: \(pet.name)"
                                    ) {
                                        newPetName = pet.name
                                        showingRenamePet = true
                                        HapticFeedback.light.trigger()
                                    }
                                }
                            }
                            
                            // Preferences
                            SettingsGroup(title: "Preferences") {
                                SettingToggle(
                                    isOn: $remindersEnabled,
                                    icon: "bell.fill",
                                    color: .red,
                                    title: "Notifications",
                                    subtitle: "Get reminded about limits"
                                )
                                
                                SettingToggle(
                                    isOn: $hapticsEnabled,
                                    icon: "hand.tap.fill",
                                    color: .green,
                                    title: "Haptics",
                                    subtitle: "Vibrations on interaction"
                                )
                                
                                SettingToggle(
                                    isOn: $isDarkMode,
                                    icon: "moon.stars.fill",
                                    color: .indigo,
                                    title: "Dark Mode",
                                    subtitle: "Adjust appearance"
                                )
                            }
                            
                            // Support
                            SettingsGroup(title: "Support") {
                                NavigationLink(destination: FAQView()) {
                                    SettingRowContent(
                                        icon: "questionmark.circle.fill",
                                        color: .orange,
                                        title: "FAQ",
                                        subtitle: "Common questions"
                                    )
                                }
                                
                                NavigationLink(destination: SupportView()) {
                                    SettingRowContent(
                                        icon: "envelope.fill",
                                        color: .blue,
                                        title: "Contact Support",
                                        subtitle: "We're here to help"
                                    )
                                }
                                
                                NavigationLink(destination: PrivacyPolicyView()) {
                                    SettingRowContent(
                                        icon: "hand.raised.fill",
                                        color: .gray,
                                        title: "Privacy Policy",
                                        subtitle: nil
                                    )
                                }
                                
                                NavigationLink(destination: TermsOfServiceView()) {
                                    SettingRowContent(
                                        icon: "doc.text.fill",
                                        color: .gray,
                                        title: "Terms of Service",
                                        subtitle: nil
                                    )
                                }
                            }
                            
                            // Follow Us Section
                            VStack(spacing: 16) {
                                Text("Follow us")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                HStack(spacing: 32) {
                                    // Instagram - Official logo
                                    Button(action: {
                                        if let url = URL(string: "https://www.instagram.com/se7enapp") {
                                            UIApplication.shared.open(url)
                                        }
                                        HapticFeedback.light.trigger()
                                    }) {
                                        Image("instagramlogo")
                                            .renderingMode(.original)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50, height: 50)
                                    }
                                    
                                    // TikTok - Official logo
                                    Button(action: {
                                        if let url = URL(string: "https://www.tiktok.com/@se7enapp") {
                                            UIApplication.shared.open(url)
                                        }
                                        HapticFeedback.light.trigger()
                                    }) {
                                        Image("tiktoklogo")
                                            .renderingMode(.original)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50, height: 50)
                                    }
                                }
                            }
                            .padding(.top, 24)
                            .padding(.bottom, 16)
                            
                            // App Info
                            VStack(spacing: 8) {
                                Image("appIcon_preview") // Assuming asset exists, or system icon
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(10)
                                    .opacity(0.0) // Hidden placeholder if no icon
                                
                                Text("SE7EN")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                Text("Version 1.0.0")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 40)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 800 : .infinity)
                    Spacer()
                }
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 34, weight: .bold))
                }
            }
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

// MARK: - Modern Components

struct SettingsHeroCard: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 20) {
            // Streak
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    Text("Day Streak")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 5)
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.textSecondary)
                .padding(.leading, 8)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.cardBackground)
            .cornerRadius(20)
        }
    }
}

struct SettingRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            SettingRowContent(icon: icon, color: color, title: title, subtitle: subtitle)
        }
    }
}

struct SettingRowContent: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String?
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textSecondary.opacity(0.5))
        }
        .padding(16)
        .background(Color.cardBackground) // Ensure tappable area
    }
}

struct SettingToggle: View {
    @Binding var isOn: Bool
    let icon: String
    let color: Color
    let title: String
    let subtitle: String?
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.blue)
        }
        .padding(16)
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
                                        appState.setUserPet(Pet(type: petType, name: currentPet.name, healthState: currentPet.healthState))
                                    } else {
                                        appState.setUserPet(Pet(type: petType, name: petType.rawValue, healthState: .fullHealth))
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
                                appState.setUserPet(updatedPet)
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
