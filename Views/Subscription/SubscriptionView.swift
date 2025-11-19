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
        // Calculate the start of current week (Monday)
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Balance Card
                        VStack(spacing: 20) {
                            Text("Your Balance")
                                .font(.h3)
                                .foregroundColor(.textPrimary.opacity(0.7))
                            
                            // Large Credit Display
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(appState.currentCredits)")
                                    .font(.system(size: 72, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("/ 7")
                                    .font(.system(size: 36, weight: .medium, design: .rounded))
                                    .foregroundColor(.textPrimary.opacity(0.4))
                            }
                            
                            Text("credits")
                                .font(.h4)
                                .foregroundColor(.textPrimary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .cardStyle()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Next Payment Info
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 24))
                                    .foregroundColor(.primary)
                                
                                Text("Next Payment")
                                    .font(.h3)
                                    .foregroundColor(.textPrimary)
                            }
                            
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Amount Due")
                                        .font(.bodyMedium)
                                        .foregroundColor(.textPrimary.opacity(0.7))
                                    
                                    Text(String(format: "$%.2f", nextPaymentAmount))
                                        .font(.h2)
                                        .foregroundColor(nextPaymentAmount == 0 ? .success : .primary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Due In")
                                        .font(.bodyMedium)
                                        .foregroundColor(.textPrimary.opacity(0.7))
                                    
                                    Text("\(daysUntilReset) days")
                                        .font(.h2)
                                        .foregroundColor(.textPrimary)
                                }
                            }
                            
                            if nextPaymentAmount == 0 {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.success)
                                    
                                    Text("Perfect week! No charge.")
                                        .font(.bodyMedium)
                                        .foregroundColor(.success)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(20)
                        .cardStyle()
                        .padding(.horizontal, 20)
                        
                        // Top-Up Button
                        Button(action: {
                            showingTopUpSheet = true
                            HapticFeedback.medium.trigger()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                
                                Text("Add Credits Early")
                                    .font(.h4)
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.horizontal, 20)
                        
                        // Credit Packages Preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Credit Packages")
                                .font(.h3)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 12) {
                                ForEach(CreditPackage.packages) { package in
                                    PackagePreviewCard(package: package)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Subscription Info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Subscription Details")
                                .font(.h3)
                                .foregroundColor(.textPrimary)
                            
                            VStack(spacing: 12) {
                                InfoRow(icon: "checkmark.circle", 
                                       text: "Weekly subscription active")
                                InfoRow(icon: "arrow.clockwise", 
                                       text: "Resets every Sunday")
                                InfoRow(icon: "creditcard", 
                                       text: "Pay only for lost credits")
                            }
                        }
                        .padding(20)
                        .cardStyle()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingTopUpSheet) {
                TopUpSheet()
            }
        }
    }
}

struct PackagePreviewCard: View {
    let package: CreditPackage
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(package.credits)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("credits")
                .font(.caption)
                .foregroundColor(.textPrimary.opacity(0.6))
            
            Divider()
            
            Text(package.priceString)
                .font(.h4)
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .cardStyle(padding: 12)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 24)
            
            Text(text)
                .font(.bodyMedium)
                .foregroundColor(.textPrimary)
            
            Spacer()
        }
    }
}


