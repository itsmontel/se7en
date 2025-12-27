import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Card
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.below.ecg")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Terms of Service")
                        .font(.title2.bold())
                        .foregroundColor(.textPrimary)
                    
                    Text("Last updated: December 27, 2025")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(20)
                
                TermsSectionView(
                    title: "Acceptance of Terms",
                    icon: "checkmark.seal",
                    content: [
                        "By using SE7EN, you agree to these Terms of Service",
                        "You must be 18 years or older to use this service",
                        "These terms are legally binding and enforceable",
                        "Continued use indicates ongoing acceptance"
                    ]
                )
                
                TermsSectionView(
                    title: "How SE7EN Works",
                    icon: "app.badge",
                    content: [
                        "Select apps to block using the multi-select picker",
                        "Selected apps are immediately blocked with a shield",
                        "To unblock: Solve a puzzle in SE7EN",
                        "Apps stay unblocked for your chosen duration (5-60 min)",
                        "After the unblock period, apps automatically re-block",
                        "Remove apps from the blocked list anytime to unblock permanently"
                    ]
                )
                
                TermsSectionView(
                    title: "App Blocking & Puzzles",
                    icon: "eye.circle",
                    content: [
                        "SE7EN requires Screen Time permissions to function",
                        "Only apps you explicitly select are blocked",
                        "Blocked apps display iOS Screen Time shields",
                        "Solving puzzles grants temporary unblock access",
                        "Four puzzle types available: Sudoku, Memory Game, Pattern Sequence, and Jigsaw Puzzle",
                        "Unblock duration is configurable (5, 10, 15, 30, or 60 minutes)",
                        "You can modify or remove blocked apps at any time"
                    ]
                )
                
                TermsSectionView(
                    title: "User Responsibilities",
                    icon: "person.circle",
                    content: [
                        "Use the service in accordance with its intended purpose",
                        "Respect system limitations and don't attempt workarounds",
                        "Report technical issues promptly through Support",
                        "Keep your device and iOS updated for best experience"
                    ]
                )
                
                TermsSectionView(
                    title: "Prohibited Uses",
                    icon: "exclamationmark.triangle",
                    content: [
                        "Attempting to circumvent app blocking or shields",
                        "Sharing your account with other users",
                        "Using automated scripts or bots with the service",
                        "Reverse engineering or modifying the app",
                        "Attempting to bypass puzzle requirements"
                    ]
                )
                
                TermsSectionView(
                    title: "Service Availability",
                    icon: "antenna.radiowaves.left.and.right",
                    content: [
                        "SE7EN requires internet connection for full functionality",
                        "We strive for 99.9% uptime but don't guarantee continuous service",
                        "Scheduled maintenance will be announced in advance",
                        "Service interruptions may temporarily affect blocking"
                    ]
                )
                
                TermsSectionView(
                    title: "Limitation of Liability",
                    icon: "shield.lefthalf.filled",
                    content: [
                        "SE7EN is provided 'as is' without warranties",
                        "We're not liable for indirect or consequential damages",
                        "We're not responsible for data loss or blocking errors",
                        "Some jurisdictions don't allow these limitations"
                    ]
                )
                
                TermsSectionView(
                    title: "Account Termination",
                    icon: "person.crop.circle.badge.xmark",
                    content: [
                        "You may stop using SE7EN at any time",
                        "We may suspend accounts for terms violations",
                        "Account data is deleted within 30 days of termination",
                        "You can reinstall and start fresh anytime"
                    ]
                )
                
                TermsSectionView(
                    title: "Changes to Terms",
                    icon: "doc.text.magnifyingglass",
                    content: [
                        "We may modify these terms with reasonable notice",
                        "Material changes will be communicated via email",
                        "Continued use after changes constitutes acceptance",
                        "If you disagree with changes, you may cancel your account"
                    ]
                )
                
                // Contact Information
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "envelope.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        Text("Questions About These Terms")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                    }
                    
                    Text("If you have questions about these Terms of Service, please contact us through the Support section in Settings.")
                        .font(.body)
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(16)
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Terms of Service")
                    .font(.system(size: 34, weight: .bold))
            }
        }
    }
}

struct TermsSectionView: View {
    let title: String
    let icon: String
    let content: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(content, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.textSecondary)
                            .font(.body)
                        
                        Text(item)
                            .font(.body)
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}

#Preview {
    NavigationView {
        TermsOfServiceView()
    }
}
