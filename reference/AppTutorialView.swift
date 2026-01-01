//
//  AppTutorialView.swift
//  VirtuPet
//
//  Light, non-intrusive coach marks tutorial with arrows
//

import SwiftUI

// MARK: - Tutorial Step
enum TutorialStep: Int, CaseIterable {
    case welcome
    case petHero
    case stepProgress
    case streakBadge
    case creditsBadge
    case weeklyGraph
    case tabInsights
    case tabActivity
    case tabHistory
    case tabChallenges
    case challengesAchievements
    case challengesPetCare
    case challengesGames
    case tabSettings
    case complete
    
    var tabIndex: Int {
        switch self {
        case .welcome, .petHero, .stepProgress, .streakBadge, .creditsBadge, .weeklyGraph:
            return 2 // Today (center)
        case .tabInsights:
            return 1 // Insights
        case .tabActivity, .tabHistory:
            return 0 // Activity
        case .tabChallenges, .challengesGames, .challengesPetCare, .challengesAchievements:
            return 3 // Challenges
        case .tabSettings:
            return 4 // Settings
        case .complete:
            return 2
        }
    }
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to VirtuPet"
        case .petHero: return "Meet Your Pet"
        case .stepProgress: return "Step Counter"
        case .streakBadge: return "Streak Tracker"
        case .creditsBadge: return "Play Credits"
        case .weeklyGraph: return "Weekly Progress"
        case .tabInsights: return "Insights"
        case .tabActivity: return "Activity Tracking"
        case .tabHistory: return "Activity History"
        case .tabChallenges: return "Challenges Hub"
        case .challengesAchievements: return "Achievements"
        case .challengesPetCare: return "Pet Care"
        case .challengesGames: return "Minigames"
        case .tabSettings: return "Settings"
        case .complete: return "You're All Set!"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "Care for your VirtuPet by caring for yourself. Let's take a quick tour!"
        case .petHero:
            return "This is your virtual pet! Their health reflects your daily steps. Keep walking to keep them happy and healthy!"
        case .stepProgress:
            return "Your live step count updates in real-time. Watch the progress ring fill up as you walk towards your daily goal!"
        case .streakBadge:
            return "Tap here to see your awards! Build streaks by hitting your daily step goal. 🔥"
        case .creditsBadge:
            return "Tap to use play credits! Feed, play ball, or watch TV with your pet for an instant +20 health boost."
        case .weeklyGraph:
            return "See your last 7 days at a glance. Tap any day to view that day's detailed stats!"
        case .tabInsights:
            return "Deep analytics! See weekly trends, monthly patterns, and detailed statistics about your activity."
        case .tabActivity:
            return "Start tracked walks here! Beautiful maps, real-time weather, calories, pace - everything you need."
        case .tabHistory:
            return "Your activity journal! View all your previous walks, see your routes, and track your progress over time."
        case .tabChallenges:
            return "Your one-stop hub for achievements, pet care, and games. Swipe to explore each section!"
        case .challengesAchievements:
            return "See your journey through VirtuPet! Unlock achievements, earn badges, and track your milestones. 🏆"
        case .challengesPetCare:
            return "Having a low step day? No worries! Use credits to Feed, Play Ball, or Watch TV with your pet. Each gives +20 health instantly! ⚡"
        case .challengesGames:
            return "Play fun minigames with your pet! Bubble Pop, Memory Match, Pattern Match and more. Great for bonding! 🎮"
        case .tabSettings:
            return "Customize everything! Switch themes, rename your pet, adjust goals, and manage notifications."
        case .complete:
            return "You're ready to start your journey! Remember: Care for your VirtuPet by caring for yourself."
        }
    }
    
    var highlightID: String {
        switch self {
        case .welcome: return ""
        case .petHero: return "tutorial_pet_hero"
        case .stepProgress: return "tutorial_step_count"
        case .streakBadge: return "tutorial_streak_badge"
        case .creditsBadge: return "tutorial_credits_badge"
        case .weeklyGraph: return "tutorial_weekly_graph"
        case .tabInsights: return "tutorial_tab_insights"
        case .tabActivity: return "tutorial_tab_activity"
        case .tabHistory: return "tutorial_history_button"
        case .tabChallenges: return "tutorial_tab_challenges"
        case .challengesAchievements: return "tutorial_tab_challenges"
        case .challengesPetCare: return "tutorial_tab_challenges"
        case .challengesGames: return "tutorial_tab_challenges"
        case .tabSettings: return "tutorial_tab_settings"
        case .complete: return ""
        }
    }
    
    var arrowDirection: ArrowDirection {
        switch self {
        case .welcome, .complete: return .none
        case .petHero, .stepProgress: return .up
        case .streakBadge, .creditsBadge: return .up
        case .weeklyGraph: return .up
        case .tabHistory: return .up // History button is at top right
        case .tabInsights, .tabActivity, .tabChallenges, .challengesAchievements, .challengesPetCare, .challengesGames, .tabSettings: return .down
        }
    }
    
    var icon: String {
        switch self {
        case .welcome: return "sparkles"
        case .petHero: return "pawprint.fill"
        case .stepProgress: return "figure.walk"
        case .streakBadge: return "flame.fill"
        case .creditsBadge: return "bolt.heart.fill"
        case .weeklyGraph: return "chart.bar.fill"
        case .tabInsights: return "chart.line.uptrend.xyaxis"
        case .tabActivity: return "map.fill"
        case .tabHistory: return "book.fill"
        case .tabChallenges: return "star.fill"
        case .challengesAchievements: return "trophy.fill"
        case .challengesPetCare: return "heart.circle.fill"
        case .challengesGames: return "gamecontroller.fill"
        case .tabSettings: return "gearshape.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .welcome: return Color(red: 0.4, green: 0.8, blue: 0.6)
        case .petHero: return Color(red: 0.95, green: 0.6, blue: 0.4)
        case .stepProgress: return Color(red: 0.4, green: 0.8, blue: 0.6)
        case .streakBadge: return Color.orange
        case .creditsBadge: return Color.yellow
        case .weeklyGraph: return Color(red: 0.5, green: 0.7, blue: 0.9)
        case .tabInsights: return Color(red: 0.6, green: 0.5, blue: 0.9)
        case .tabActivity: return Color(red: 0.3, green: 0.8, blue: 0.7)
        case .tabHistory: return Color(red: 0.7, green: 0.5, blue: 0.4)
        case .tabChallenges: return Color(red: 0.9, green: 0.6, blue: 0.3)
        case .challengesAchievements: return Color(red: 0.8, green: 0.5, blue: 0.9)
        case .challengesPetCare: return Color(red: 0.95, green: 0.7, blue: 0.3)
        case .challengesGames: return Color(red: 0.9, green: 0.4, blue: 0.5)
        case .tabSettings: return Color(red: 0.5, green: 0.5, blue: 0.55)
        case .complete: return Color(red: 0.4, green: 0.8, blue: 0.6)
        }
    }
}

enum ArrowDirection {
    case up, down, left, right, none
}

// MARK: - Tutorial Manager
class TutorialManager: ObservableObject {
    @Published var isActive: Bool = false
    @Published var currentStep: TutorialStep = .welcome
    @Published var showTooltip: Bool = false
    @Published var scrollToWeekly: Bool = false
    @Published var challengesSegment: Int = 0 // 0 = Minigames, 1 = Pet Care, 2 = Awards
    
    func start() {
        isActive = true
        currentStep = .welcome
        showTooltip = false
        scrollToWeekly = false
        challengesSegment = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.showTooltip = true
            }
        }
    }
    
    func nextStep() {
        withAnimation(.easeOut(duration: 0.15)) {
            showTooltip = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let nextIndex = TutorialStep.allCases.firstIndex(of: self.currentStep)?.advanced(by: 1),
               nextIndex < TutorialStep.allCases.count {
                self.currentStep = TutorialStep.allCases[nextIndex]
                
                // Handle special navigation
                self.handleStepNavigation()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.showTooltip = true
                    }
                }
            }
        }
    }
    
    private func handleStepNavigation() {
        switch currentStep {
        case .weeklyGraph:
            // Scroll down to weekly graph
            scrollToWeekly = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scrollToWeekly = false
            }
        case .tabHistory:
            // Just point to the history button, don't open it
            break
        case .challengesAchievements:
            challengesSegment = 2
        case .challengesPetCare:
            challengesSegment = 1
        case .challengesGames:
            challengesSegment = 0
        default:
            break
        }
    }
    
    func skip() {
        withAnimation(.easeOut(duration: 0.2)) {
            showTooltip = false
            isActive = false
        }
    }
    
    func complete() {
        withAnimation(.easeOut(duration: 0.2)) {
            showTooltip = false
            isActive = false
        }
    }
}

// MARK: - Tutorial Highlight Preference Key
struct TutorialHighlightKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Tutorial Highlight Modifier
struct TutorialHighlight: ViewModifier {
    let id: String
    
    func body(content: Content) -> some View {
        content
            .anchorPreference(key: TutorialHighlightKey.self, value: .bounds) { anchor in
                [id: anchor]
            }
    }
}

extension View {
    func tutorialHighlight(_ id: String) -> some View {
        modifier(TutorialHighlight(id: id))
    }
}

// MARK: - Tutorial Overlay View
struct TutorialOverlay: View {
    @EnvironmentObject var tutorialManager: TutorialManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var userSettings: UserSettings
    
    let highlightAnchors: [String: Anchor<CGRect>]
    
    // Entrance animation states
    @State private var showEntrance = false
    @State private var sparkleOpacity: [Double] = [0, 0, 0, 0, 0, 0, 0, 0]
    @State private var sparkleScale: [CGFloat] = [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3]
    @State private var sparkleOffset: [CGFloat] = [0, 0, 0, 0, 0, 0, 0, 0]
    
    // Steps that should show a circle highlight around the element
    private var shouldShowCircleHighlight: Bool {
        [.streakBadge, .creditsBadge, .tabHistory].contains(tutorialManager.currentStep)
    }
    
    var body: some View {
        GeometryReader { geo in
            let currentHighlightID = tutorialManager.currentStep.highlightID
            let highlightRect: CGRect? = {
                if let anchor = highlightAnchors[currentHighlightID] {
                    return geo[anchor]
                }
                return nil
            }()
            
            ZStack {
                // Full screen tap catcher - tapping ANYWHERE continues tutorial
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                
                // Sparkle entrance animation (only on welcome step)
                if tutorialManager.currentStep == .welcome && showEntrance {
                    sparkleEntranceView(in: geo)
                }
                
                // Circle highlight for certain elements
                if shouldShowCircleHighlight, let rect = highlightRect, tutorialManager.showTooltip {
                    Circle()
                        .stroke(tutorialManager.currentStep.iconColor, lineWidth: 3)
                        .frame(width: rect.width + 20, height: rect.height + 20)
                        .position(x: rect.midX, y: rect.midY)
                    
                    // Pulsing outer circle
                    Circle()
                        .stroke(tutorialManager.currentStep.iconColor.opacity(0.4), lineWidth: 2)
                        .frame(width: rect.width + 30, height: rect.height + 30)
                        .position(x: rect.midX, y: rect.midY)
                }
                
                // Tooltip with arrow
                if tutorialManager.showTooltip {
                    tooltipView(highlightRect: highlightRect, in: geo)
                        .scaleEffect(showEntrance ? 1.0 : 0.5)
                        .opacity(showEntrance ? 1.0 : 0.0)
                }
                
                // Progress indicator at top
                if tutorialManager.currentStep != .welcome && tutorialManager.currentStep != .complete {
                    VStack {
                        progressBar
                            .padding(.top, 50)
                        Spacer()
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
        }
        .onChange(of: tutorialManager.showTooltip) { oldValue, newValue in
            // Trigger entrance animation when tooltip first appears (after HealthKit permission is granted)
            if newValue && !oldValue && tutorialManager.currentStep == .welcome {
                // Small delay to ensure UI is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Trigger entrance animation
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showEntrance = true
                    }
                    
                    // Animate sparkles with staggered timing
                    for i in 0..<8 {
                        let delay = Double(i) * 0.08
                        withAnimation(.easeOut(duration: 0.5).delay(delay)) {
                            sparkleOpacity[i] = 1.0
                            sparkleScale[i] = 1.0
                            sparkleOffset[i] = CGFloat.random(in: 20...60)
                        }
                        withAnimation(.easeIn(duration: 0.4).delay(delay + 0.5)) {
                            sparkleOpacity[i] = 0.0
                        }
                    }
                }
            } else if newValue && !showEntrance {
                // For non-welcome steps, just show entrance without sparkles
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showEntrance = true
                }
            }
        }
    }
    
    // MARK: - Sparkle Entrance Animation
    @ViewBuilder
    private func sparkleEntranceView(in geo: GeometryProxy) -> some View {
        let centerX = geo.size.width / 2
        let centerY = geo.size.height / 2 - 50
        
        // 8 sparkles radiating outward
        ForEach(0..<8, id: \.self) { index in
            let angle = Double(index) * (360.0 / 8.0) * .pi / 180.0
            let offsetX = cos(angle) * Double(sparkleOffset[index])
            let offsetY = sin(angle) * Double(sparkleOffset[index])
            
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(themeManager.accentColor)
                .scaleEffect(sparkleScale[index])
                .opacity(sparkleOpacity[index])
                .position(x: centerX + CGFloat(offsetX), y: centerY + CGFloat(offsetY))
        }
        
        // Central glow
        Circle()
            .fill(
                RadialGradient(
                    colors: [themeManager.accentColor.opacity(0.3), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 100
                )
            )
            .frame(width: 200, height: 200)
            .position(x: centerX, y: centerY)
            .scaleEffect(showEntrance ? 1.2 : 0.5)
            .opacity(showEntrance ? 0.0 : 0.8)
            .animation(.easeOut(duration: 0.8), value: showEntrance)
    }
    
    private func handleTap() {
        HapticFeedback.light.trigger()
        if tutorialManager.currentStep == .complete {
            userSettings.hasCompletedAppTutorial = true
            tutorialManager.complete()
        } else {
            tutorialManager.nextStep()
        }
    }
    
    @ViewBuilder
    private func tooltipView(highlightRect: CGRect?, in geo: GeometryProxy) -> some View {
        let step = tutorialManager.currentStep
        let isFullScreen = step == .welcome || step == .complete
        
        if isFullScreen {
            // Centered card for welcome/complete
            fullScreenCard(step: step, in: geo)
        } else {
            // Positioned tooltip with arrow
            positionedTooltip(step: step, highlightRect: highlightRect, in: geo)
        }
    }
    
    private func fullScreenCard(step: TutorialStep, in geo: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            // Pet Animation instead of emoji
            ZStack {
                // Glow background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [themeManager.accentColor.opacity(0.3), themeManager.accentColor.opacity(0)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)
                
                // Pet Animation
                AnimatedPetVideoView(
                    petType: userSettings.pet.type,
                    moodState: .fullHealth
                )
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            
            // Title
            VStack(spacing: 8) {
                Text(step.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.primaryTextColor)
                    .multilineTextAlignment(.center)
                
                if step == .welcome {
                    Text("Step Tracker")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(themeManager.accentColor.opacity(0.15))
                        )
                }
            }
            
            Text(step.description)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 16)
            
            // Button
            Button(action: handleTap) {
                HStack(spacing: 8) {
                    Text(step == .complete ? "Start Exploring" : "Let's Go")
                        .font(.system(size: 16, weight: .bold))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: themeManager.accentColor.opacity(0.4), radius: 10, y: 5)
                )
            }
            .padding(.top, 4)
            
            if step == .welcome {
                Button(action: {
                    userSettings.hasCompletedAppTutorial = true
                    tutorialManager.skip()
                }) {
                    Text("Skip Tutorial")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(themeManager.tertiaryTextColor)
                }
                .padding(.top, 2)
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(themeManager.cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.15), radius: 25, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(themeManager.accentColor.opacity(0.1), lineWidth: 1)
        )
        .frame(maxWidth: 340)
        .position(x: geo.size.width / 2, y: geo.size.height / 2 - 20)
    }
    
    private func positionedTooltip(step: TutorialStep, highlightRect: CGRect?, in geo: GeometryProxy) -> some View {
        let tooltipWidth: CGFloat = min(320, geo.size.width - 32)
        let tooltipHeight: CGFloat = 160
        let padding: CGFloat = 16
        
        // Calculate position
        let position = calculateTooltipPosition(
            highlightRect: highlightRect,
            tooltipSize: CGSize(width: tooltipWidth, height: tooltipHeight),
            arrowDirection: step.arrowDirection,
            geo: geo,
            padding: padding,
            step: step
        )
        
        return ZStack {
            // Tooltip card
            VStack(alignment: .leading, spacing: 10) {
                // Header with icon and title
                HStack(spacing: 12) {
                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(step.iconColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: step.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(step.iconColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        // Step counter
                        Text("Step \(step.rawValue) of \(TutorialStep.allCases.count - 2)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.tertiaryTextColor)
                    }
                    
                    Spacer()
                }
                
                Text(step.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Tap hint
                HStack {
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Tap to continue")
                            .font(.system(size: 12, weight: .semibold))
                        
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(themeManager.accentColor)
                }
                .padding(.top, 2)
            }
            .padding(18)
            .frame(width: tooltipWidth)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(themeManager.cardBackgroundColor)
                    .shadow(color: Color.black.opacity(0.12), radius: 20, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(step.iconColor.opacity(0.2), lineWidth: 1.5)
            )
            .overlay(
                // Arrow pointer
                arrowPointer(direction: step.arrowDirection, highlightRect: highlightRect, tooltipRect: CGRect(origin: position, size: CGSize(width: tooltipWidth, height: tooltipHeight)), color: step.iconColor, in: geo)
            )
        }
        .position(x: position.x + tooltipWidth / 2, y: position.y + tooltipHeight / 2)
    }
    
    @ViewBuilder
    private func arrowPointer(direction: ArrowDirection, highlightRect: CGRect?, tooltipRect: CGRect, color: Color, in geo: GeometryProxy) -> some View {
        if let highlight = highlightRect, direction != .none {
            GeometryReader { tooltipGeo in
                let tooltipFrame = tooltipGeo.frame(in: .global)
                
                // Calculate arrow position pointing to highlight center
                let highlightCenterX = highlight.midX
                let arrowOffsetX = highlightCenterX - tooltipFrame.minX
                let clampedX = max(40, min(arrowOffsetX, tooltipFrame.width - 40))
                
                switch direction {
                case .up:
                    // Arrow pointing up (highlight is above tooltip)
                    // Just the arrow, no long line
                    ArrowShape(direction: .up)
                        .fill(color)
                        .frame(width: 16, height: 10)
                        .position(x: clampedX, y: -8)
                    
                case .down:
                    // Arrow pointing down (highlight is below tooltip)
                    // Just the arrow, no long line
                    ArrowShape(direction: .down)
                        .fill(color)
                        .frame(width: 16, height: 10)
                        .position(x: clampedX, y: tooltipGeo.size.height + 8)
                    
                default:
                    EmptyView()
                }
            }
        }
    }
    
    private func calculateTooltipPosition(highlightRect: CGRect?, tooltipSize: CGSize, arrowDirection: ArrowDirection, geo: GeometryProxy, padding: CGFloat, step: TutorialStep) -> CGPoint {
        guard let highlight = highlightRect else {
            // Center if no highlight
            return CGPoint(
                x: (geo.size.width - tooltipSize.width) / 2,
                y: (geo.size.height - tooltipSize.height) / 2
            )
        }
        
        var x: CGFloat
        var y: CGFloat
        
        // Center horizontally relative to highlight
        x = highlight.midX - tooltipSize.width / 2
        // Clamp to screen bounds
        x = max(padding, min(x, geo.size.width - tooltipSize.width - padding))
        
        switch arrowDirection {
        case .up:
            // Tooltip below highlight
            // Weekly graph needs to be higher up
            if step == .weeklyGraph {
                y = highlight.maxY + 20
            } else {
                y = highlight.maxY + 35
            }
        case .down:
            // Tooltip above highlight
            y = highlight.minY - tooltipSize.height - 35
        default:
            y = geo.size.height / 2 - tooltipSize.height / 2
        }
        
        // Clamp Y to screen
        y = max(100, min(y, geo.size.height - tooltipSize.height - 120))
        
        return CGPoint(x: x, y: y)
    }
    
    private var progressBar: some View {
        HStack(spacing: 16) {
            // Skip button
            Button(action: {
                userSettings.hasCompletedAppTutorial = true
                tutorialManager.skip()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Skip")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(themeManager.secondaryTextColor)
            }
            
            Spacer()
            
            // Progress dots
            HStack(spacing: 3) {
                ForEach(1..<TutorialStep.allCases.count - 1, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= tutorialManager.currentStep.rawValue ? themeManager.accentColor : Color.gray.opacity(0.25))
                        .frame(width: index == tutorialManager.currentStep.rawValue ? 16 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: tutorialManager.currentStep)
                }
            }
            
            Spacer()
            
            // Step counter text
            Text("\(tutorialManager.currentStep.rawValue)/\(TutorialStep.allCases.count - 2)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 3)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Arrow Shape
struct ArrowShape: Shape {
    let direction: ArrowDirection
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        case .down:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        case .right:
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        case .none:
            break
        }
        
        return path
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(red: 1, green: 0.98, blue: 0.9)
        
        TutorialOverlay(highlightAnchors: [:])
            .environmentObject({
                let tm = TutorialManager()
                tm.isActive = true
                tm.showTooltip = true
                return tm
            }())
            .environmentObject(ThemeManager())
            .environmentObject(UserSettings())
    }
}
