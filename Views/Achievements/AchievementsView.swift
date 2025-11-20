import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: AchievementCategory? = nil
    @State private var showingUnlockedOnly = false
    
    private var filteredAchievements: [Achievement] {
        let achievements = selectedCategory == nil ? 
            appState.achievements : 
            appState.achievements.filter { $0.category == selectedCategory }
        
        return showingUnlockedOnly ? 
            achievements.filter { appState.unlockedAchievements.contains($0.id) } : 
            achievements
    }
    
    private var unlockedCount: Int {
        appState.unlockedAchievements.count
    }
    
    private var totalCount: Int {
        appState.achievements.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    HStack {
                        Spacer()
                        VStack(spacing: 0) {
                    // Progress Header
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Achievements")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                
                                Text("\(unlockedCount) of \(totalCount) unlocked")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textPrimary.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            AchievementProgressRing(
                                progress: Double(unlockedCount) / Double(totalCount),
                                unlockedCount: unlockedCount,
                                totalCount: totalCount
                            )
                        }
                        
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [.success, .secondary, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geometry.size.width * (Double(unlockedCount) / Double(totalCount)),
                                        height: 8
                                    )
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: unlockedCount)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(20)
                    .background(Color.cardBackground)
                    
                    // Filter Controls
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterChip(
                                title: "All",
                                isSelected: selectedCategory == nil,
                                count: appState.achievements.count
                            ) {
                                selectedCategory = nil
                            }
                            
                            ForEach(AchievementCategory.allCases, id: \.self) { category in
                                let categoryAchievements = appState.achievements.filter { $0.category == category }
                                if !categoryAchievements.isEmpty {
                                    FilterChip(
                                        title: category.rawValue,
                                        isSelected: selectedCategory == category,
                                        count: categoryAchievements.count,
                                        icon: category.icon,
                                        color: category.color
                                    ) {
                                        selectedCategory = selectedCategory == category ? nil : category
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)
                    
                    // Toggle Filter
                    HStack {
                        Text("Show unlocked only")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $showingUnlockedOnly)
                            .tint(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    // Achievements Grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(filteredAchievements) { achievement in
                                AchievementCard(
                                    achievement: achievement,
                                    isUnlocked: appState.unlockedAchievements.contains(achievement.id)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                    }
                    .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 800 : .infinity)
                    Spacer()
                }
            }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AchievementProgressRing: View {
    let progress: Double
    let unlockedCount: Int
    let totalCount: Int
    
    var body: some View {
        ZStack {
            // Background Ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                .frame(width: 60, height: 60)
            
            // Progress Ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.success, .secondary, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
            
            // Percentage Text
            Text("\(Int(progress * 100))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.textPrimary)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    var icon: String? = nil
    var color: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text("(\(count))")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.7)
            }
            .foregroundColor(isSelected ? .white : (color == .primary ? .textPrimary : color))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color : color.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon with rarity background
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(achievement.rarity.backgroundColor)
                    .frame(height: 80)
                
                // Unlock glow effect
                if isUnlocked {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(achievement.color.opacity(0.1))
                        .frame(height: 80)
                        .blur(radius: 10)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                
                VStack(spacing: 8) {
                    Image(systemName: achievement.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(isUnlocked ? achievement.color : Color.gray.opacity(0.5))
                        .scaleEffect(isUnlocked ? 1.0 : 0.8)
                    
                    // Rarity Badge
                    Text(achievement.rarity.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(achievement.rarity.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(achievement.rarity.color.opacity(0.2))
                        )
                }
            }
            
            // Achievement Info
            VStack(spacing: 6) {
                Text(achievement.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isUnlocked ? .textPrimary : .textPrimary.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(achievement.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isUnlocked ? .textPrimary.opacity(0.7) : .textPrimary.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Lock/Unlock Status
            HStack {
                if isUnlocked {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.success)
                    Text("Unlocked")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.success)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                    Text("Locked")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Category indicator
                Image(systemName: achievement.category.icon)
                    .font(.system(size: 12))
                    .foregroundColor(achievement.category.color)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .shadow(
                    color: isUnlocked ? achievement.color.opacity(0.2) : Color.black.opacity(0.05),
                    radius: isUnlocked ? 12 : 6,
                    x: 0, y: isUnlocked ? 6 : 3
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isUnlocked ? 
                                LinearGradient(
                                    colors: [achievement.color.opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isUnlocked ? 1 : 0
                        )
                )
        )
        .scaleEffect(isUnlocked ? 1.0 : 0.95)
        .saturation(isUnlocked ? 1.0 : 0.6)
        .onAppear {
            if isUnlocked {
                isAnimating = true
            }
        }
    }
}
