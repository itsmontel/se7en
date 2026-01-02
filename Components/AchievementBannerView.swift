//
//  AchievementBannerView.swift
//  VirtuPet
//
//  Subtle achievement notification banner that appears at the top of the screen
//

import SwiftUI

struct AchievementBannerView: View {
    let achievement: Achievement
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var offset: CGFloat = -150
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            if isVisible {
                bannerContent
                    .offset(y: offset)
                    .opacity(opacity)
                    .onTapGesture {
                        HapticFeedback.light.trigger()
                        dismissBanner()
                        onTap()
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                // Swipe up to dismiss
                                if value.translation.height < -20 {
                                    dismissBanner()
                                }
                            }
                    )
            }
            
            Spacer()
        }
        .onAppear {
            showBanner()
        }
    }
    
    private var bannerContent: some View {
        HStack(spacing: 14) {
            // Achievement icon
            ZStack {
                Circle()
                    .fill(achievementColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(achievementColor)
            }
            
            // Achievement info
            VStack(alignment: .leading, spacing: 3) {
                Text("Achievement Unlocked!")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(achievementColor)
                    .textCase(.uppercase)
                
                Text(achievement.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                Text(achievement.description)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Arrow indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardBackground)
                .shadow(color: achievementColor.opacity(0.25), radius: 20, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(achievementColor.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var achievementColor: Color {
        if achievement.color == .success {
            return .sevenEmerald
        } else if achievement.color == .warning {
            return .sevenAmber
        } else if achievement.color == .error {
            return .sevenRose
        } else if achievement.color == .primary {
            return .sevenIndigo
        } else if achievement.color == .secondary {
            return .sevenSkyBlue
        } else {
            return achievement.color
        }
    }
    
    private func showBanner() {
        // Animate in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isVisible = true
            offset = 0
            opacity = 1.0
        }
        
        // Haptic feedback
        HapticFeedback.success.trigger()
        
        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            dismissBanner()
        }
    }
    
    private func dismissBanner() {
        guard isVisible else { return }
        
        // Animate out (fade up and out)
        withAnimation(.easeOut(duration: 0.4)) {
            offset = -30
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isVisible = false
            onDismiss()
        }
    }
}

// MARK: - Achievement Banner Manager
class AchievementBannerManager: ObservableObject {
    static let shared = AchievementBannerManager()
    
    @Published var currentAchievement: Achievement? = nil
    @Published var shouldNavigateToAchievements = false
    
    private init() {}
    
    func showAchievement(_ achievement: Achievement) {
        // Only show if no achievement is currently showing
        guard currentAchievement == nil else { return }
        
        DispatchQueue.main.async {
            self.currentAchievement = achievement
        }
    }
    
    func dismissAchievement() {
        DispatchQueue.main.async {
            self.currentAchievement = nil
        }
    }
    
    func navigateToAchievements() {
        shouldNavigateToAchievements = true
        // Reset after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.shouldNavigateToAchievements = false
        }
    }
}

// MARK: - View Modifier for Achievement Banner
struct AchievementBannerModifier: ViewModifier {
    @ObservedObject var bannerManager = AchievementBannerManager.shared
    let onNavigate: () -> Void
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let achievement = bannerManager.currentAchievement {
                AchievementBannerView(
                    achievement: achievement,
                    onTap: {
                        bannerManager.dismissAchievement()
                        onNavigate()
                    },
                    onDismiss: {
                        bannerManager.dismissAchievement()
                    }
                )
                .zIndex(1000)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

extension View {
    func achievementBanner(onNavigate: @escaping () -> Void) -> some View {
        self.modifier(AchievementBannerModifier(onNavigate: onNavigate))
    }
}

#Preview {
    VStack {
        Color.appBackground.ignoresSafeArea()
        
        AchievementBannerView(
            achievement: Achievement(
                id: "test",
                title: "First Steps",
                description: "Complete your first day",
                icon: "star.fill",
                color: .sevenAmber,
                category: .gettingStarted,
                rarity: .common,
                isUnlocked: { _ in true }
            ),
            onTap: {},
            onDismiss: {}
        )
    }
}

