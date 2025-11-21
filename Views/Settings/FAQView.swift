import SwiftUI

struct FAQView: View {
    let faqs = [
        FAQ(question: "What is SE7EN?", answer: "SE7EN is your personal screen time companion that helps you break free from 'brain rot'. By caring for your digital pet, you build healthier habits. When you scroll less, your pet thrives!"),
        
        FAQ(question: "How do the Credits work?", answer: "You start each day with 7 credits (reset at midnight). When you exceed an app limit, you lose credits based on a progressive penalty: 1st failure = 1 credit, 2nd failure = 2 credits, 3rd = 3 credits, and so on. The failure count resets weekly on Monday. Credits reset to 7 daily at midnight."),
        
        FAQ(question: "What is the Accountability Fee?", answer: "When an app is blocked for exceeding its limit, you need 7 credits to unblock it. This is called the 'accountability fee'. Once you pay it (reach 7 credits), no additional credits are deducted for other failures that same day. The accountability fee resets daily at midnight."),
        
        FAQ(question: "Which apps get blocked?", answer: "Only the specific app that exceeded its daily limit gets blocked. Other apps continue working normally, even if your credits are below 7. This way, you can still use apps you haven't exceeded limits on."),
        
        FAQ(question: "Why does my Pet's health change?", answer: "Your pet's health is directly tied to your credits. If you stay within your limits and keep your credits, your pet stays happy and healthy. Losing credits makes your pet sick. Keep them healthy by staying off your phone!"),
        
        FAQ(question: "What happens if I lose all my Credits?", answer: "Credits reset to 7 every day at midnight, so you'll never permanently lose all credits. However, if you have less than 7 credits and an app is blocked, you'll need to buy credits to reach 7 (the accountability fee) to unblock it."),
        
        FAQ(question: "Can I change my App Limits?", answer: "Yes! Go to the Stats page and tap on any app in your list to adjust its daily limit. Changes take effect immediately for the next day."),
        
        FAQ(question: "How does app blocking work?", answer: "When you exceed an app's daily limit, that specific app is blocked until midnight or until you unblock it by paying the accountability fee (reaching 7 credits). Other apps that haven't exceeded their limits continue working normally."),
        
        FAQ(question: "I'm going on vacation. Can I pause?", answer: "We believe in consistency, but we understand life happens. You can toggle 'Monitoring' off in Settings, but try to stick to your habits!"),
        
        FAQ(question: "Is my data private?", answer: "Absolutely. SE7EN uses Apple's Screen Time API, which means all your usage data stays on your device. We never see your browsing history or personal app data.")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 20)
                    
                    Text("Frequently Asked Questions")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    Text("Everything you need to know about SE7EN")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 10)
                
                // FAQ List
                LazyVStack(spacing: 16) {
                    ForEach(faqs, id: \.question) { faq in
                        FAQCard(faq: faq)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
                HapticFeedback.light.trigger()
            }) {
                HStack(alignment: .top, spacing: 16) {
                    Text(faq.question)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(faq.answer)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.textSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isExpanded ? Color.blue.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationView {
        FAQView()
            .environmentObject(AppState())
    }
}
