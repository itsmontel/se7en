import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Card
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Your Privacy Matters")
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
                
                PrivacySectionView(
                    title: "Information We Collect",
                    icon: "doc.text.magnifyingglass",
                    content: [
                        "App usage data for apps you choose to monitor",
                        "Account information (email, subscription status)",
                        "Device information (iOS version, device model)",
                        "Payment information (processed securely by Apple)"
                    ]
                )
                
                PrivacySectionView(
                    title: "How We Use Your Information",
                    icon: "gearshape.2",
                    content: [
                        "Monitor your chosen apps to enforce time limits",
                        "Calculate credit usage and billing",
                        "Provide customer support and app improvements",
                        "Send important account and billing notifications"
                    ]
                )
                
                PrivacySectionView(
                    title: "Data Sharing",
                    icon: "person.2.badge.key",
                    content: [
                        "We never sell your personal information",
                        "We don't share usage data with third parties",
                        "Anonymous analytics may be used to improve our service",
                        "Legal compliance may require limited data sharing"
                    ]
                )
                
                PrivacySectionView(
                    title: "Data Security",
                    icon: "lock.shield",
                    content: [
                        "All data is encrypted in transit and at rest",
                        "Screen time data stays on your device when possible",
                        "Regular security audits and updates",
                        "Secure payment processing through Apple"
                    ]
                )
                
                PrivacySectionView(
                    title: "Your Rights",
                    icon: "hand.raised",
                    content: [
                        "Request a copy of your data",
                        "Delete your account and associated data",
                        "Opt out of non-essential communications",
                        "Control which apps are monitored"
                    ]
                )
                
                PrivacySectionView(
                    title: "Children's Privacy",
                    icon: "figure.and.child.holdinghands",
                    content: [
                        "SE7EN is designed for users 18 and older",
                        "We don't knowingly collect data from children under 13",
                        "Parents should supervise app usage on shared devices",
                        "Contact us if you believe a child has created an account"
                    ]
                )
                
                PrivacySectionView(
                    title: "Changes to This Policy",
                    icon: "arrow.triangle.2.circlepath",
                    content: [
                        "We may update this policy from time to time",
                        "Significant changes will be communicated via email",
                        "Continued use constitutes acceptance of updates",
                        "Previous versions are available upon request"
                    ]
                )
                
                // Contact Information
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "envelope.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        Text("Contact Us")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                    }
                    
                    Text("If you have questions about this Privacy Policy, please contact us at privacy@se7en.app or through the Support section in Settings.")
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
        .navigationTitle("privacy policy")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct PrivacySectionView: View {
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
        PrivacyPolicyView()
    }
}

