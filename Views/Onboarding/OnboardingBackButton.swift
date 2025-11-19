import SwiftUI

struct OnboardingBackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
