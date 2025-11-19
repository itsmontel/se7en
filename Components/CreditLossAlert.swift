import SwiftUI

struct CreditLossAlert: View {
    @Binding var isPresented: Bool
    let creditsLost: Int
    let creditsRemaining: Int
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            alertCard
                .padding(.horizontal, 32)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    private var alertCard: some View {
        VStack(spacing: 20) {
            icon
            
            VStack(spacing: 10) {
                Text("You Went Over Your Limit")
                    .font(.h3)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(creditsLost == 1 ? "You lost 1 credit." : "You lost \(creditsLost) credits.")
                    .font(.bodyLarge)
                    .foregroundColor(.error)
                    .multilineTextAlignment(.center)
            }
            
            Divider()
            
            HStack {
                Text("Credits Remaining")
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary.opacity(0.7))
                
                Spacer()
                
                Text("\(creditsRemaining) / 7")
                    .font(.h3)
                    .foregroundColor(.primary)
            }
            
            Button(action: dismiss) {
                Text("Got It")
                    .font(.h4)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary)
                    .cornerRadius(DesignSystem.cornerRadiusMedium)
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(DesignSystem.cornerRadiusLarge)
        .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 20)
        .scaleEffect(isPresented ? 1.0 : 0.85)
        .opacity(isPresented ? 1.0 : 0.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isPresented)
    }
    
    private var icon: some View {
        ZStack {
            Circle()
                .fill(Color.error.opacity(0.2))
                .frame(width: 90, height: 90)
            
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.error)
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}
