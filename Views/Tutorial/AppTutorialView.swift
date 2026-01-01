//
//  AppTutorialView.swift
//  VirtuPet
//
//  Light, non-intrusive coach marks tutorial with arrows
//  Guides users through Screen Time features after onboarding
//

import SwiftUI

// MARK: - Tutorial Step
enum TutorialStep: Int, CaseIterable {
    case welcome
    case petHero
    case screenTimeDisplay
    case topDistractions
    case tabLimits
    case focusMode
    case puzzleUnlock
    case tabStats
    case tabAchievements
    case tabSettings
    case complete
    
    var tabIndex: Int {
        switch self {
        case .welcome, .petHero, .screenTimeDisplay, .topDistractions:
            return 0 // Home (Dashboard)
        case .tabLimits, .focusMode, .puzzleUnlock:
            return 1 // Limits
        case .tabStats:
            return 2 // Stats
        case .tabAchievements:
            return 3 // Achievements
        case .tabSettings:
            return 4 // Settings
        case .complete:
            return 0
        }
    }
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to VirtuPet"
        case .petHero: return "Meet Your Pet"
        case .screenTimeDisplay: return "Today's Screen Time"
        case .topDistractions: return "Top Distractions"
        case .tabLimits: return "Focus Mode"
        case .focusMode: return "Block Distracting Apps"
        case .puzzleUnlock: return "Puzzle Unlock"
        case .tabStats: return "Your Stats"
        case .tabAchievements: return "Achievements"
        case .tabSettings: return "Settings"
        case .complete: return "You're All Set!"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "Take control of your screen time while caring for your virtual pet. Let's take a quick tour!"
        case .petHero:
            return "This is your virtual pet! Their health reflects your daily screen time. Less screen time means a happier, healthier pet!"
        case .screenTimeDisplay:
            return "See your total screen time for today updated in real-time. Watch your usage and keep your pet healthy!"
        case .topDistractions:
            return "These are your most used apps today. Knowing your distractions is the first step to managing them!"
        case .tabLimits:
            return "This is your Focus Mode control center. Block distracting apps to stay focused and productive."
        case .focusMode:
            return "Select apps you want to block. When blocked, you'll need to solve a puzzle to unlock them temporarily!"
        case .puzzleUnlock:
            return "Need a break? Solve a quick puzzle to temporarily unlock your blocked apps. It's mindful friction that helps you stay intentional! 🧩"
        case .tabStats:
            return "Track your weekly progress, streaks, and see detailed insights about your screen time habits."
        case .tabAchievements:
            return "Unlock achievements by building healthy habits! Earn badges for streaks, low screen time days, and more. 🏆"
        case .tabSettings:
            return "Customize your experience! Change your pet, adjust notifications, and manage your account."
        case .complete:
            return "You're ready to build healthier digital habits! Remember: Care for your VirtuPet by caring for yourself."
        }
    }
    
    var highlightID: String {
        switch self {
        case .welcome: return ""
        case .petHero: return "tutorial_pet_section"
        case .screenTimeDisplay: return "tutorial_screen_time"
        case .topDistractions: return "tutorial_top_distractions"
        case .tabLimits: return "tutorial_tab_limits"
        case .focusMode: return "tutorial_focus_mode"
        case .puzzleUnlock: return "tutorial_puzzle_button"
        case .tabStats: return "tutorial_tab_stats"
        case .tabAchievements: return "tutorial_tab_achievements"
        case .tabSettings: return "tutorial_tab_settings"
        case .complete: return ""
        }
    }
    
    var arrowDirection: ArrowDirection {
        switch self {
        case .welcome, .complete: return .none
        // For elements that are ABOVE tooltip (tooltip appears below them)
        // Arrow points UP from tooltip toward the element
        case .petHero: return .up
        case .screenTimeDisplay: return .up
        case .topDistractions: return .up
        case .focusMode: return .up
        case .puzzleUnlock: return .up
        // For tab bar items (at BOTTOM of screen)
        // Tooltip appears ABOVE tab bar, arrow points DOWN toward tabs
        case .tabLimits, .tabStats, .tabAchievements, .tabSettings: return .down
        }
    }
    
    var icon: String {
        switch self {
        case .welcome: return "sparkles"
        case .petHero: return "pawprint.fill"
        case .screenTimeDisplay: return "hourglass"
        case .topDistractions: return "chart.bar.fill"
        case .tabLimits: return "hand.raised.fill"
        case .focusMode: return "lock.shield.fill"
        case .puzzleUnlock: return "puzzlepiece.fill"
        case .tabStats: return "chart.line.uptrend.xyaxis"
        case .tabAchievements: return "trophy.fill"
        case .tabSettings: return "gearshape.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .welcome: return Color(red: 0.4, green: 0.8, blue: 0.6)
        case .petHero: return Color(red: 0.95, green: 0.6, blue: 0.4)
        case .screenTimeDisplay: return Color(red: 0.3, green: 0.7, blue: 0.9)
        case .topDistractions: return Color(red: 0.9, green: 0.5, blue: 0.3)
        case .tabLimits: return Color(red: 0.9, green: 0.3, blue: 0.4)
        case .focusMode: return Color(red: 0.8, green: 0.2, blue: 0.3)
        case .puzzleUnlock: return Color(red: 0.6, green: 0.4, blue: 0.9)
        case .tabStats: return Color(red: 0.4, green: 0.6, blue: 0.9)
        case .tabAchievements: return Color(red: 0.95, green: 0.7, blue: 0.3)
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
    static let shared = TutorialManager()
    
    @Published var isActive: Bool = false
    @Published var currentStep: TutorialStep = .welcome
    @Published var showTooltip: Bool = false
    @Published var scrollToSection: String? = nil
    
    private init() {}
    
    func start() {
        isActive = true
        currentStep = .welcome
        showTooltip = false
        scrollToSection = nil
        
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
        case .topDistractions:
            // Scroll to top distractions section
            scrollToSection = "topDistractions"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scrollToSection = nil
            }
        case .focusMode, .puzzleUnlock:
            // These are on the Limits tab, scroll handling if needed
            break
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
    @ObservedObject var tutorialManager = TutorialManager.shared
    @EnvironmentObject var appState: AppState
    @AppStorage("hasCompletedAppTutorial") private var hasCompletedAppTutorial = false
    
    let highlightAnchors: [String: Anchor<CGRect>]
    
    // Entrance animation states
    @State private var showEntrance = false
    @State private var sparkleOpacity: [Double] = [0, 0, 0, 0, 0, 0, 0, 0]
    @State private var sparkleScale: [CGFloat] = [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3]
    @State private var sparkleOffset: [CGFloat] = [0, 0, 0, 0, 0, 0, 0, 0]
    
    // Steps that should show a circle highlight around the element
    private var shouldShowCircleHighlight: Bool {
        [.screenTimeDisplay, .topDistractions, .puzzleUnlock].contains(tutorialManager.currentStep)
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
        .onChange(of: tutorialManager.showTooltip) { newValue in
            // Trigger entrance animation when tooltip first appears
            if newValue && tutorialManager.currentStep == .welcome {
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
                .foregroundColor(Color.blue)
                .scaleEffect(sparkleScale[index])
                .opacity(sparkleOpacity[index])
                .position(x: centerX + CGFloat(offsetX), y: centerY + CGFloat(offsetY))
        }
        
        // Central glow
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.blue.opacity(0.3), Color.clear],
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
            hasCompletedAppTutorial = true
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
                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 140, height: 140)
                
                // Pet Animation
                if let pet = appState.userPet {
                    PetAnimationView(
                        petType: pet.type,
                        healthState: .fullHealth,
                        height: 100
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color.orange)
                }
            }
            
            // Title
            VStack(spacing: 8) {
                Text(step.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                
                if step == .welcome {
                    Text("Screen Time Manager")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                }
            }
            
            Text(step.description)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.textSecondary)
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
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.blue.opacity(0.4), radius: 10, y: 5)
                )
            }
            .padding(.top, 4)
            
            if step == .welcome {
                Button(action: {
                    hasCompletedAppTutorial = true
                    tutorialManager.skip()
                }) {
                    Text("Skip Tutorial")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.cardBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 25, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
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
                            .foregroundColor(.textPrimary)
                        
                        // Step counter
                        Text("Step \(step.rawValue) of \(TutorialStep.allCases.count - 2)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                }
                
                Text(step.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
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
                    .foregroundColor(step.iconColor)
                }
                .padding(.top, 2)
            }
            .padding(18)
            .frame(width: tooltipWidth)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackground)
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
                    ArrowShape(direction: .up)
                        .fill(color)
                        .frame(width: 16, height: 10)
                        .position(x: clampedX, y: -8)
                    
                case .down:
                    // Arrow pointing down (highlight is below tooltip)
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
            if step == .topDistractions {
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
                hasCompletedAppTutorial = true
                tutorialManager.skip()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Skip")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Progress dots
            HStack(spacing: 3) {
                ForEach(1..<TutorialStep.allCases.count - 1, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= tutorialManager.currentStep.rawValue ? Color.blue : Color.gray.opacity(0.25))
                        .frame(width: index == tutorialManager.currentStep.rawValue ? 16 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: tutorialManager.currentStep)
                }
            }
            
            Spacer()
            
            // Step counter text
            Text("\(tutorialManager.currentStep.rawValue)/\(TutorialStep.allCases.count - 2)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
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
            .environmentObject(AppState())
    }
}

