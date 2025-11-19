import SwiftUI

struct FAQView: View {
    let faqs = [
        FAQ(question: "How does SE7EN work?", answer: "SE7EN gives you 7 credits each week. Every time you exceed a daily app limit, you lose 1 credit. At the end of the week, you pay $1 for each lost credit."),
        FAQ(question: "When do I get charged?", answer: "You're only charged at the end of each week for the credits you lost. If you keep all 7 credits, the week is completely free!"),
        FAQ(question: "Can I get my credits back?", answer: "No, once you exceed a limit and lose a credit, it's gone for that week. This creates real accountability for your screen time goals."),
        FAQ(question: "What happens if I lose all 7 credits?", answer: "You'll be charged $7 at the end of the week. The apps you've set limits for will remain blocked until the week resets on Monday."),
        FAQ(question: "How do I change my app limits?", answer: "Go to the Goals tab and tap on any app to adjust its daily time limit. Changes take effect immediately."),
        FAQ(question: "Can I pause SE7EN?", answer: "You can disable monitoring in Settings, but any credits already lost that week will still be charged. SE7EN works best with consistent use."),
        FAQ(question: "What if I need to use a blocked app?", answer: "Once you exceed a limit, the app is blocked for the rest of the day. This is intentional - it helps build better digital habits through accountability."),
        FAQ(question: "Do you track my app activity?", answer: "SE7EN only monitors the apps you choose to set limits for. We don't track your activity in other apps or share your data with third parties."),
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(faqs, id: \.question) { faq in
                    FAQCard(faq: faq)
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("faq")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct FAQ {
    let question: String
    let answer: String
}

struct FAQCard: View {
    let faq: FAQ
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(faq.question)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
            }
            
            if isExpanded {
                Text(faq.answer)
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

#Preview {
    NavigationView {
        FAQView()
    }
}

