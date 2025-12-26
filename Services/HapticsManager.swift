import UIKit
import SwiftUI

/// Manages haptic feedback throughout the app
class HapticsManager {
    static let shared = HapticsManager()
    
    // User preference key
    private let hapticsEnabledKey = "hapticsEnabled"
    
    private init() {}
    
    /// Check if haptics are enabled
    var isEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: hapticsEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hapticsEnabledKey)
        }
    }
    
    // MARK: - Haptic Feedback Methods
    
    /// Light impact - for subtle interactions (e.g., button taps, toggles)
    func light() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Medium impact - for standard interactions (e.g., selections, deletions)
    func medium() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Heavy impact - for important actions (e.g., completing tasks, confirmations)
    func heavy() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// Soft impact - for very subtle feedback (iOS 13+)
    func soft() {
        guard isEnabled else { return }
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        } else {
            light()
        }
    }
    
    /// Rigid impact - for precise interactions (iOS 13+)
    func rigid() {
        guard isEnabled else { return }
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
        } else {
            medium()
        }
    }
    
    /// Selection feedback - for picker/segmented control changes
    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    /// Success notification - for successful actions
    func success() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Warning notification - for warnings
    func warning() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// Error notification - for errors
    func error() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

// MARK: - SwiftUI View Extension for Easy Access

extension View {
    /// Add haptic feedback to button tap
    func hapticFeedback(_ style: HapticStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                HapticsManager.shared.trigger(style)
            }
        )
    }
}

enum HapticStyle {
    case light, medium, heavy, soft, rigid, selection, success, warning, error
}

extension HapticsManager {
    func trigger(_ style: HapticStyle) {
        switch style {
        case .light: light()
        case .medium: medium()
        case .heavy: heavy()
        case .soft: soft()
        case .rigid: rigid()
        case .selection: selection()
        case .success: success()
        case .warning: warning()
        case .error: error()
        }
    }
}

