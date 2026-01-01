import SwiftUI

struct VirtuPetWordmark: View {
    var fontSize: CGFloat = 32
    var weight: Font.Weight = .bold
    var color: Color = .textPrimary
    var spacing: CGFloat = 2
    
    var body: some View {
        VStack(spacing: 2) {
            Text("VirtuPet")
                .font(.system(size: fontSize, weight: weight, design: .rounded))
                .foregroundColor(color)
            
            Text("Screen Time")
                .font(.system(size: fontSize * 0.5, weight: .medium, design: .rounded))
                .foregroundColor(color.opacity(0.7))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .fixedSize()
        .accessibilityLabel("VirtuPet Screen Time")
    }
}


