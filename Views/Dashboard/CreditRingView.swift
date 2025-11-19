import SwiftUI

struct CreditRingView: View {
    let credits: Int
    @State private var animateRing = false
    
    private var progress: Double {
        Double(credits) / 7.0
    }
    
    private var ringColor: Color {
        Color.creditColor(for: credits)
    }
    
    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ringColor.opacity(0.2),
                            ringColor.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 10)
            
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 20)
                .frame(width: 200, height: 200)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: animateRing ? progress : 0)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.5), radius: 8, x: 0, y: 0)
            
            // Center content
            VStack(spacing: 8) {
                Text("\(credits)")
                    .font(.numberMedium)
                    .foregroundColor(ringColor)
                
                Text("Credits")
                    .font(.h4)
                    .foregroundColor(.textPrimary.opacity(0.7))
                
                Text("Remaining This Week")
                    .font(.caption)
                    .foregroundColor(.textPrimary.opacity(0.5))
            }
        }
        .frame(height: 280)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                animateRing = true
            }
        }
        .onChange(of: credits) { _ in
            animateRing = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animateRing = true
            }
        }
    }
}


