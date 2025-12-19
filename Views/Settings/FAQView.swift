import SwiftUI

struct FAQView: View {
    let faqs = [
        FAQ(question: "What is SE7EN?", answer: "SE7EN is your personal screen time companion that helps you break free from 'brain rot'. By caring for your digital pet, you build healthier habits. When you scroll less, your pet thrives! Set daily limits for apps, and when you hit a limit, solve a puzzle to unlock more time."),
        
        FAQ(question: "How does the Puzzle Unlock work?", answer: "When you exceed an app's daily limit, that app gets blocked with a shield. Tap 'Open SE7EN to Solve' on the shield, then solve a puzzle in the SE7EN app to unlock the blocked app. You can choose between two unlock modes: Extra Time (+15 minutes) or One Session (unlocks until you leave the app)."),
        
        FAQ(question: "What's the difference between Extra Time and One Session?", answer: "Extra Time Mode: After solving a puzzle, you get +15 minutes added to your daily limit. Your usage continues from where you left off. Example: If you used 60 of 60 minutes, after solving you'll have 60 of 75 minutes.\n\nOne Session Mode: After solving a puzzle, the app unlocks until you close it or switch away. Once you leave the app, it re-locks until tomorrow. Perfect for finishing a task without time pressure."),
        
        FAQ(question: "Which apps get blocked?", answer: "Only the specific app that exceeded its daily limit gets blocked. Other apps continue working normally. This way, you can still use apps you haven't exceeded limits on."),
        
        FAQ(question: "Why does my Pet's health change?", answer: "Your pet's health reflects your screen time habits. When you stay within your limits, your pet stays happy and healthy. When you exceed limits frequently, your pet may become sick. Keep them healthy by managing your screen time!"),
        
        FAQ(question: "Can I change my App Limits?", answer: "Yes! Go to the Limits page and tap on any app in your list to adjust its daily limit. You can also set custom schedules for different days of the week. Changes take effect immediately."),
        
        FAQ(question: "How does app blocking work?", answer: "When you exceed an app's daily limit, that specific app is blocked with a shield. Tap 'Open SE7EN to Solve' on the shield, then solve a puzzle in SE7EN to unlock it. You can choose Extra Time (+15 minutes) or One Session (unlocks until you leave the app). Alternatively, wait until midnight when limits reset automatically. Other apps that haven't exceeded their limits continue working normally."),
        
        FAQ(question: "I'm going on vacation. Can I pause?", answer: "We believe in consistency, but we understand life happens. You can toggle 'Monitoring' off in Settings, but try to stick to your habits!"),
        
        FAQ(question: "Is my data private?", answer: "Absolutely. SE7EN uses Apple's Screen Time API, which means all your usage data stays on your device. We never see your browsing history or personal app data. Your privacy is our priority.")
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
