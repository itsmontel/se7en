import SwiftUI

struct TopUpSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedPackage: CreditPackage?
    
    // Only show packages that would bring user to 7 credits or less
    var availablePackages: [CreditPackage] {
        let currentCredits = appState.currentCredits
        let maxCredits = 7
        let creditsNeeded = maxCredits - currentCredits
        
        // If already at 7 credits, show no packages
        if currentCredits >= maxCredits {
            return []
        }
        
        // Filter packages to only show those that won't exceed 7 credits
        return CreditPackage.packages.filter { package in
            package.credits <= creditsNeeded
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Add credits")
                            .font(.displaySmall)
                            .foregroundColor(.textPrimary)
                        
                        Text("Top up your balance anytime")
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    
                    // Scrollable Content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Current Balance
                            HStack(spacing: 8) {
                                Text("Current Balance:")
                                    .font(.bodyLarge)
                                    .foregroundColor(.textPrimary.opacity(0.7))
                                
                                Text("\(appState.currentCredits) / 7")
                                    .font(.h2)
                                    .foregroundColor(.primary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .cardStyle()
                            .padding(.horizontal, 20)
                            
                            // Accountability Fee Option (if credits < 7)
                            let creditsNeeded = 7 - appState.currentCredits
                            if creditsNeeded > 0 {
                                VStack(spacing: 16) {
                                    // Accountability Fee Card
                                    VStack(spacing: 12) {
                                        HStack {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .font(.system(size: 24))
                                                .foregroundColor(.primary)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Accountability Fee")
                                                    .font(.h4)
                                                    .foregroundColor(.textPrimary)
                                                
                                                Text("Restore credits for today")
                                                    .font(.bodyMedium)
                                                    .foregroundColor(.textSecondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(formatPrice(0.99))
                                                .font(.h2)
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Divider()
                                        
                                        Text("Pay 99¢ to restore your 7 credits and continue using apps today. Credits reset to 7 daily at midnight.")
                                            .font(.bodySmall)
                                            .foregroundColor(.textSecondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(20)
                                    .cardStyle()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadiusMedium)
                                            .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                                    )
                                }
                                .padding(.horizontal, 20)
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.success)
                                    
                                    Text("You're all set!")
                                        .font(.h3)
                                        .foregroundColor(.textPrimary)
                                    
                                    Text("You already have 7 credits. No payment needed!")
                                        .font(.bodyMedium)
                                        .foregroundColor(.textPrimary.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(32)
                                .cardStyle()
                                .padding(.horizontal, 20)
                            }
                            
                            Spacer()
                                .frame(height: 100) // Extra space for button
                        }
                    }
                    
                    // Fixed Bottom Button
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.appBackground.opacity(0.95))
                            .frame(height: 1)
                            .blur(radius: 0.5)
                        
                        Button(action: purchaseAccountabilityFee) {
                            let creditsNeeded = 7 - appState.currentCredits
                            if creditsNeeded > 0 {
                                Text("Pay 99¢ to Restore Credits")
                            } else {
                                Text("No Payment Needed")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: appState.currentCredits < 7))
                        .disabled(appState.currentCredits >= 7)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                        .background(Color.appBackground)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
    }
    
    private func purchaseAccountabilityFee() {
        let creditsNeeded = 7 - appState.currentCredits
        guard creditsNeeded > 0 else { return }
        
        // Pay accountability fee (99 cents) - this restores credits to 7
        CoreDataManager.shared.payAccountabilityFee()
        appState.loadCurrentWeekData()
        
        HapticFeedback.success.trigger()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

struct PackageCard: View {
    let package: CreditPackage
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isBestValue: Bool {
        package.credits == 7
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Best Value Badge
                if isBestValue {
                    HStack {
                        Spacer()
                        Text("Best Value")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.success)
                            .cornerRadius(8, corners: [.topLeft, .topRight])
                        Spacer()
                    }
                    .padding(.bottom, 12)
                }
                
                HStack(spacing: 20) {
                    // Credit Amount
                    VStack(spacing: 4) {
                        Text("\(package.credits)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("credits")
                            .font(.bodyMedium)
                            .foregroundColor(.textPrimary.opacity(0.7))
                    }
                    
                    Divider()
                        .frame(height: 60)
                    
                    // Price Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(package.priceString)
                            .font(.h2)
                            .foregroundColor(.textPrimary)
                        
                        Text("\(formatPrice(package.perCreditPrice)) per credit")
                            .font(.bodySmall)
                            .foregroundColor(.textPrimary.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Selection Indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? .success : .gray.opacity(0.3))
                }
            }
            .padding(20)
        }
        .buttonStyle(PlainButtonStyle())
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadiusMedium)
                .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
        )
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
    }
}

// Helper extension for custom corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}


