import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingTopUpSheet = false
    
    private var nextPaymentAmount: Double {
        let creditsNeeded = max(0, 7 - appState.currentCredits)
        return Double(creditsNeeded) * 0.99
    }
    
    private var daysUntilReset: Int {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let daysFromMonday = (weekday - 2 + 7) % 7
        
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: now) else {
            return 0
        }
        
        if let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) {
            let components = calendar.dateComponents([.day], from: now, to: endOfWeek)
            return max(0, (components.day ?? 0) + 1)
        }
        return 0
    }
    
    private var creditPercentage: Double {
        Double(appState.currentCredits) / 7.0
    }
    
    private var creditColor: Color {
        if appState.currentCredits >= 6 {
            return .green
        } else if appState.currentCredits >= 4 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Credit Balance Card
                        CreditHeroCard(
                            credits: appState.currentCredits,
                            percentage: creditPercentage,
                            color: creditColor
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Payment Summary Card
                        PaymentSummaryCard(
                            amount: nextPaymentAmount,
                            daysUntil: daysUntilReset,
                            creditsRemaining: appState.currentCredits
                        )
                        .padding(.horizontal, 20)
                        
                        // Top-Up Button
                        Button(action: {
                            showingTopUpSheet = true
                            HapticFeedback.medium.trigger()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                
                                Text("Add Credits")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 20)
                        
                        // Credit Packages Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                
                                Text("Credit Packages")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(CreditPackage.packages) { package in
                                        CreditPackageCard(package: package)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // How It Works Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                
                                Text("How It Works")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                InfoRow(
                                    icon: "checkmark.circle.fill",
                                    iconColor: .green,
                                    text: "Weekly subscription active",
                                    subtitle: "7 credits reset every Monday"
                                )
                                
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                InfoRow(
                                    icon: "dollarsign.circle.fill",
                                    iconColor: .blue,
                                    text: "Pay only for lost credits",
                                    subtitle: "$1 per credit lost"
                                )
                                
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                InfoRow(
                                    icon: "arrow.clockwise.circle.fill",
                                    iconColor: .orange,
                                    text: "Resets every Sunday",
                                    subtitle: "Fresh start each week"
                                )
                            }
                            .padding(.vertical, 20)
                            .background(Color.cardBackground)
                            .cornerRadius(20)
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingTopUpSheet) {
                TopUpSheet()
                    .environmentObject(appState)
            }
        }
    }
}

// MARK: - Hero Credit Card

struct CreditHeroCard: View {
    let credits: Int
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 24) {
            // Circular Progress Indicator
            ZStack {
                // Background Circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)
                
                // Progress Circle
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: percentage)
                
                // Center Content
                VStack(spacing: 4) {
                    Text("\(credits)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    Text("/ 7")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
            }
            
            // Status Text
            VStack(spacing: 8) {
                Text(statusText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                
                Text(statusSubtext)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            LinearGradient(
                colors: [
                    color.opacity(0.1),
                    color.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(Color.cardBackground)
        .cornerRadius(28)
        .shadow(color: color.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private var statusText: String {
        if credits >= 7 {
            return "Perfect Week!"
        } else if credits >= 5 {
            return "Doing Great"
        } else if credits >= 3 {
            return "Stay Focused"
        } else {
            return "Keep Going"
        }
    }
    
    private var statusSubtext: String {
        if credits >= 7 {
            return "You've kept all your credits this week"
        } else if credits >= 5 {
            return "You're on track to save money"
        } else if credits >= 3 {
            return "Every credit counts"
        } else {
            return "You can still turn this around"
        }
    }
}

// MARK: - Payment Summary Card

struct PaymentSummaryCard: View {
    let amount: Double
    let daysUntil: Int
    let creditsRemaining: Int
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                
                Text("Payment Summary")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            if amount == 0 {
                // Perfect Week State
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Charge")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                            
                            Text("You kept all \(creditsRemaining) credits")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(Color.green.opacity(0.1))
                .cornerRadius(16)
            } else {
                // Payment Due State
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount Due")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textSecondary)
                        
                        Text(String(format: "$%.2f", amount))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Due In")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textSecondary)
                        
                        HStack(spacing: 4) {
                            Text("\(daysUntil)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                            
                            Text("days")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
}

// MARK: - Credit Package Card

struct CreditPackageCard: View {
    let package: CreditPackage
    
    var body: some View {
        VStack(spacing: 16) {
            // Package Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Text("\(package.credits)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 6) {
                Text("\(package.credits) Credits")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                Text(package.priceString)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("$\(String(format: "%.2f", package.perCreditPrice)) each")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(width: 140)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    let subtitle: String?
    
    init(icon: String, iconColor: Color, text: String, subtitle: String? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.text = text
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
