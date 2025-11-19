import SwiftUI

struct AnimatedNumber: View {
    let value: Int
    let font: Font
    let color: Color
    
    @State private var displayValue: Int = 0
    
    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onChange(of: value) { newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    displayValue = newValue
                }
            }
            .onAppear {
                displayValue = value
            }
    }
}

// Extension for smooth number transitions
extension View {
    func animatedNumberStyle() -> some View {
        self.contentTransition(.numericText())
    }
}

