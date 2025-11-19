import SwiftUI

struct SuccessToast: View {
    let message: String
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.success)
                
                Text(message)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            .padding(16)
            .cardStyle()
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            HapticFeedback.success.trigger()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPresented = false
                }
            }
        }
    }
}

struct WarningToast: View {
    let message: String
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.warning)
                
                Text(message)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            .padding(16)
            .cardStyle()
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            HapticFeedback.warning.trigger()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPresented = false
                }
            }
        }
    }
}

