import SwiftUI

extension View {
    /// Adds a pulsing animation effect
    func pulseEffect(isActive: Bool = true) -> some View {
        self.scaleEffect(isActive ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true),
                value: isActive
            )
    }
    
    /// Adds a spring animation on appear
    func springOnAppear(delay: Double = 0) -> some View {
        self.modifier(SpringAppearModifier(delay: delay))
    }
    
    /// Adds a conditional modifier
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Prevents automatic text uppercasing
    func preventTextUppercasing() -> some View {
        self.textCase(.none)
    }
    
    /// Applies proper text case environment to all child views
    /// This ensures text case is correct from the very first render
    func withProperTextCase() -> some View {
        self.modifier(ProperTextCaseModifier())
    }
}

/// A modifier that ensures .textCase(.none) is applied at the earliest possible moment
struct ProperTextCaseModifier: ViewModifier {
    @State private var isReady = false
    
    func body(content: Content) -> some View {
        content
            .environment(\.textCase, .none)
            .opacity(isReady ? 1 : 0.99) // Tiny opacity change forces re-render
            .onAppear {
                // Force a very quick re-render to ensure environment propagates
                DispatchQueue.main.async {
                    isReady = true
                }
            }
    }
}

struct SpringAppearModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        isVisible = true
                    }
                }
            }
    }
}

// Custom transitions
extension AnyTransition {
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .scale.combined(with: .opacity)
    }
}

