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
                    
                    Text("Last updated: November 2024")
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
                        "You start each week with 7 credits at no charge",
                        "Exceeding daily app limits costs 1 credit each time",
                        "You pay $1 for each credit lost at week's end",
                        "Perfect weeks (all 7 credits kept) are completely free"
                    ]
                )
                
                TermsSectionView(
                    title: "Billing and Payments",
                    icon: "creditcard",
                    content: [
                        "Charges are processed weekly for lost credits only",
                        "Payments are handled securely through Apple's App Store",
                        "All sales are final - no refunds for intentional limit violations",
                        "Subscription cancellation doesn't affect current week charges"
                    ]
                )
                
                TermsSectionView(
                    title: "App Monitoring",
                    icon: "eye.circle",
                    content: [
                        "SE7EN requires Screen Time permissions to function",
                        "Only apps you explicitly select are monitored",
                        "Monitoring data is used solely for limit enforcement",
                        "You can modify or remove app limits at any time"
                    ]
                )
                
                TermsSectionView(
                    title: "User Responsibilities",
                    icon: "person.circle",
                    content: [
                        "Provide accurate account and payment information",
                        "Use the service in accordance with its intended purpose",
                        "Respect system limitations and don't attempt workarounds",
                        "Report technical issues or billing concerns promptly"
                    ]
                )
                
                TermsSectionView(
                    title: "Prohibited Uses",
                    icon: "exclamationmark.triangle",
                    content: [
                        "Attempting to circumvent app limits or monitoring",
                        "Sharing your account with other users",
                        "Using automated scripts or bots with the service",
                        "Reverse engineering or modifying the app"
                    ]
                )
                
                TermsSectionView(
                    title: "Service Availability",
                    icon: "antenna.radiowaves.left.and.right",
                    content: [
                        "SE7EN requires internet connection for full functionality",
                        "We strive for 99.9% uptime but don't guarantee continuous service",
                        "Scheduled maintenance will be announced in advance",
                        "Service interruptions don't excuse overages or pause billing"
                    ]
                )
                
                TermsSectionView(
                    title: "Limitation of Liability",
                    icon: "shield.lefthalf.filled",
                    content: [
                        "SE7EN is provided 'as is' without warranties",
                        "We're not liable for indirect or consequential damages",
                        "Maximum liability is limited to amount paid in past 12 months",
                        "Some jurisdictions don't allow these limitations"
                    ]
                )
                
                TermsSectionView(
                    title: "Account Termination",
                    icon: "person.crop.circle.badge.xmark",
                    content: [
                        "You may cancel your account at any time in Settings",
                        "We may suspend accounts for terms violations",
                        "Outstanding charges remain due after cancellation",
                        "Account data is deleted within 30 days of termination"
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
                    
                    Text("If you have questions about these Terms of Service, please contact us at legal@se7en.app or through the Support section in Settings.")
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

