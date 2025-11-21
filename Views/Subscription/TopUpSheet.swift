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
                            
                            // Package Selection
                            VStack {
                                if availablePackages.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(.success)
                                        
                                        Text("You're all set!")
                                            .font(.h3)
                                            .foregroundColor(.textPrimary)
                                        
                                        Text("You already have the maximum 7 credits. No need to top up!")
                                            .font(.bodyMedium)
                                            .foregroundColor(.textPrimary.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(32)
                                    .cardStyle()
                                } else {
                                    VStack(spacing: 20) {
                                        Text("Credit Pricing")
                                            .font(.h4)
                                            .foregroundColor(.textPrimary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        // Pricing Information
                                        VStack(spacing: 16) {
                                            HStack {
                                                Image(systemName: "dollarsign.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.success)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("1 Credit = \(formatPrice(0.99))")
                                                        .font(.h4)
                                                        .foregroundColor(.textPrimary)
                                                    
                                                    Text("Pay only for credits you lose")
                                                        .font(.bodyMedium)
                                                        .foregroundColor(.textPrimary.opacity(0.7))
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding(16)
                                            .cardStyle()
                                            
                                            // Credits needed calculation
                                            let creditsNeeded = 7 - appState.currentCredits
                                            if creditsNeeded > 0 {
                                                VStack(spacing: 12) {
                                                    Text("Credits Needed: \(creditsNeeded)")
                                                        .font(.h4)
                                                        .foregroundColor(.textPrimary)
                                                    
                                                    Text("Total Cost: \(formatPrice(Double(creditsNeeded) * 0.99))")
                                                        .font(.h3)
                                                        .foregroundColor(.primary)
                                                    
                                                    Text("This will restore you to 7/7 credits")
                                                        .font(.bodyMedium)
                                                        .foregroundColor(.textPrimary.opacity(0.6))
                                                        .multilineTextAlignment(.center)
                                                }
                                                .padding(20)
                                                .frame(maxWidth: .infinity)
                                                .background(Color.primary.opacity(0.1))
                                                .cornerRadius(16)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100) // Extra space for button
                        }
                    }
                    
                    // Fixed Bottom Button
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.appBackground.opacity(0.95))
                            .frame(height: 1)
                            .blur(radius: 0.5)
                        
                        Button(action: purchaseCredits) {
                            let creditsNeeded = 7 - appState.currentCredits
                            if creditsNeeded > 0 {
                                Text("Purchase \(creditsNeeded) Credit\(creditsNeeded == 1 ? "" : "s") for \(formatPrice(Double(creditsNeeded) * 0.99))")
                            } else {
                                Text("No Credits Needed")
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
    
    private func purchaseCredits() {
        let creditsNeeded = 7 - appState.currentCredits
        guard creditsNeeded > 0 else { return }
        
        // In a real app, this would process the in-app purchase
        appState.addCredits(amount: creditsNeeded, reason: "Credit Top-up Purchase")
        
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


