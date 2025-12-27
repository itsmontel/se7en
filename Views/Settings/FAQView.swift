import SwiftUI

struct FAQView: View {
    @EnvironmentObject var appState: AppState
    @State private var expandedIndex: Int? = nil
    
    let faqs = [
        FAQ(question: "What is SE7EN?", answer: "SE7EN is your personal screen time companion that helps you break free from 'brain rot'. By caring for your digital pet, you build healthier habits. When you scroll less, your pet thrives! Block distracting apps, and when you need a break, solve a puzzle to temporarily unblock them."),
        
        FAQ(question: "How does App Blocking work?", answer: "Select the apps you want to block using the multi-select picker on the Limits page. Once selected, these apps are immediately blocked with a shield. To unblock them temporarily, solve a puzzle in SE7EN. The apps stay unblocked for your chosen duration (5-60 minutes), then automatically re-block."),
        
        FAQ(question: "How do I unblock apps?", answer: "When you need access to blocked apps, tap 'Solve Puzzle to Unblock' on the Limits page or from the shield screen. Complete a puzzle (Sudoku, Memory Game, Pattern Sequence, or Jigsaw Puzzle), and your blocked apps will be unblocked for your chosen duration. Once time's up, they automatically re-block. You can also permanently unblock apps by removing them from your blocked list in Settings."),
        
        FAQ(question: "What are the unblock duration options?", answer: "You can choose how long apps stay unblocked after solving a puzzle:\n\n• 5 minutes - Quick break\n• 10 minutes - Short task\n• 15 minutes (default) - Standard break\n• 30 minutes - Longer session\n• 60 minutes - Extended access\n\nChange this anytime in the Limits page settings."),
        
        FAQ(question: "Why does my Pet's health change?", answer: "Your pet's health reflects your screen time habits. Lower screen time = healthier pet! The health is calculated based on your total daily screen time:\n\n• Under 2 hours: Full health (100%)\n• 2-4 hours: Excellent health (80-100%)\n• 4-6 hours: Good health (60-80%)\n• 6-8 hours: Fair health (40-60%)\n• 8-10 hours: Moderate health (20-40%)\n• 10-12 hours: Poor health (0-20%)\n• 12+ hours: Sick (0%)\n\nThe health percentage decreases linearly within each range. For example, at 3 hours you'd have 90% health, and at 7 hours you'd have 50% health."),
        
        FAQ(question: "Can I add or remove blocked apps anytime?", answer: "Yes! Go to the Limits page and tap 'Edit' to modify your blocked apps list. You can add apps, categories, or remove them anytime. Changes take effect immediately. Removing an app from the blocked list permanently unblocks it."),
        
        FAQ(question: "What types of puzzles are there?", answer: "SE7EN includes four puzzle types:\n\n• Sudoku - Fill in the grid with numbers 1-6\n• Memory Game - Match pairs of cards\n• Pattern Sequence - Remember and repeat the pattern\n• Jigsaw Puzzle - Complete the puzzle by placing pieces correctly\n\nA random puzzle is selected each time you request to unblock apps."),
        
        FAQ(question: "Is my data private?", answer: "Absolutely. SE7EN uses Apple's Screen Time API, which means all your usage data stays on your device. We never see your browsing history or personal app data. Your privacy is our priority.")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    // Pet image instead of question mark
                    if let pet = appState.userPet {
                        let imageName = "\(pet.type.folderName.lowercased())fullhealth"
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .padding(.top, 20)
                    } else {
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
                    }
                    
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
                    ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                        FAQCard(faq: faq, index: index, expandedIndex: $expandedIndex)
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
    let index: Int
    @Binding var expandedIndex: Int?
    @State private var isProcessingTap = false
    
    private var isExpanded: Bool {
        expandedIndex == index
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                // Prevent multiple rapid taps
                guard !isProcessingTap else { return }
                isProcessingTap = true
                
                // Trigger haptic immediately for responsiveness
                HapticFeedback.light.trigger()
                
                // Update state with animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if expandedIndex == index {
                        expandedIndex = nil
                    } else {
                        expandedIndex = index
                    }
                }
                
                // Reset tap processing after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isProcessingTap = false
                }
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
                .contentShape(Rectangle()) // Make entire area tappable
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(faq.answer)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.textSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
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
