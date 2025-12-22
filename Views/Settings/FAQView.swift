import SwiftUI

struct FAQView: View {
    let faqs = [
        FAQ(question: "What is SE7EN?", answer: "SE7EN is your personal screen time companion that helps you break free from 'brain rot'. By caring for your digital pet, you build healthier habits. When you scroll less, your pet thrives! Block distracting apps, and when you need a break, solve a puzzle to temporarily unblock them."),
        
        FAQ(question: "How does App Blocking work?", answer: "Select the apps you want to block using the multi-select picker on the Limits page. Once selected, these apps are immediately blocked with a shield. To unblock them temporarily, solve a puzzle in SE7EN. The apps stay unblocked for your chosen duration (5-60 minutes), then automatically re-block."),
        
        FAQ(question: "How do I unblock apps?", answer: "When you need access to blocked apps, tap 'Solve Puzzle to Unblock' on the Limits page or from the shield screen. Complete a quick puzzle (Sudoku, Memory, or Pattern), and your blocked apps will be unblocked for your chosen duration. Once time's up, they automatically re-block."),
        
        FAQ(question: "What are the unblock duration options?", answer: "You can choose how long apps stay unblocked after solving a puzzle:\n\n• 5 minutes - Quick break\n• 10 minutes - Short task\n• 15 minutes (default) - Standard break\n• 30 minutes - Longer session\n• 60 minutes - Extended access\n\nChange this anytime in the Limits page settings."),
        
        FAQ(question: "Why does my Pet's health change?", answer: "Your pet's health reflects your screen time habits. Lower screen time = healthier pet! The health is calculated based on your total daily screen time:\n\n• Under 2 hours: Full health (100%)\n• 2-4 hours: Good health (70-100%)\n• 4-6 hours: Fair health (40-70%)\n• 6+ hours: Poor health (<40%)\n\nKeep screen time low to keep your pet happy!"),
        
        FAQ(question: "Can I add or remove blocked apps anytime?", answer: "Yes! Go to the Limits page and tap 'Edit' to modify your blocked apps list. You can add apps, categories, or remove them anytime. Changes take effect immediately."),
        
        FAQ(question: "What types of puzzles are there?", answer: "SE7EN includes three puzzle types:\n\n• Sudoku - Fill in the grid with numbers 1-9\n• Memory Game - Match pairs of cards\n• Pattern Sequence - Remember and repeat the pattern\n\nA random puzzle is selected each time you request to unblock apps."),
        
        FAQ(question: "I'm going on vacation. Can I pause?", answer: "You can simply remove all blocked apps from your list temporarily. When you're back, add them again. We believe in consistency, but we understand life happens!"),
        
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
