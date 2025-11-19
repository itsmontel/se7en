import SwiftUI

struct Se7enWordmark: View {
    var fontSize: CGFloat = 32
    var weight: Font.Weight = .bold
    var color: Color = .textPrimary
    var spacing: CGFloat = 0
    
    var body: some View {
        HStack(spacing: spacing) {
            Text("SE")
                .font(.system(size: fontSize, weight: weight, design: .rounded))
            
            Text("7")
                .font(.system(size: fontSize * 1.25, weight: weight, design: .rounded))
                .baselineOffset(fontSize * 0.05)
            
            Text("EN")
                .font(.system(size: fontSize, weight: weight, design: .rounded))
        }
        .foregroundColor(color)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .fixedSize()
        .accessibilityLabel("S E seven E N")
    }
}


