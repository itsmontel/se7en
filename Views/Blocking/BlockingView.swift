import SwiftUI

struct BlockingView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Blocking coming soon")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Use the Dashboard to set limits and monitor your screen time.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Blocking")
                        }
                    }
                }
                
struct BlockingView_Previews: PreviewProvider {
    static var previews: some View {
        BlockingView()
    }
}

