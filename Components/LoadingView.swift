import SwiftUI

struct LoadingView: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            Color.appBackground.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated Logo
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [Color.primary, Color.secondary],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotationAngle))
                    
                    Text("7")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        rotationAngle = 360
                    }
                }
                
                Text("Loading...")
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary.opacity(0.7))
            }
        }
    }
}

