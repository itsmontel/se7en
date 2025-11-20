import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingTopUpSheet = false
    @State private var animateRing = false
    
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
    
    private var progress: Double {
        Double(appState.currentCredits) / 7.0
    }
    
    private var ringColor: Color {
        Color.creditColor(for: appState.currentCredits)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Section - Large Credit Display
                        VStack(spacing: 20) {
                            // Large circular progress ring
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 16)
                                    .frame(width: 200, height: 200)
                                
                                Circle()
                                    .trim(from: 0, to: animateRing ? progress : 0)
                                    .stroke(
                                        LinearGradient(
                                            colors: [ringColor, ringColor.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                                    )
                                    .frame(width: 200, height: 200)
                                    .rotationEffect(.degrees(-90))
                                    .shadow(color: ringColor.opacity(0.3), radius: 12, x: 0, y: 4)
                                
                                VStack(spacing: 4) {
                                    Text("\(appState.currentCredits)")
                                        .font(.system(size: 56, weight: .bold, design: .rounded))
                                        .foregroundColor(ringColor)
                                    
                                    Text("of 7 credits")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            .padding(.top, 20)
                            
                            // Status badge
                            HStack(spacing: 8) {
                                Image(systemName: statusIcon)
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text(statusText)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(statusColor.opacity(0.15))
                            .cornerRadius(20)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(
                            LinearGradient(
                                colors: [ringColor.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .background(Color.cardBackground)
                        .cornerRadius(28)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Quick Stats Row
                        HStack(spacing: 12) {
                            StatCard(
                                icon: "checkmark.circle.fill",
                                value: "\(appState.currentCredits)",
                                label: "Kept",
                                color: .sevenEmerald
                            )
                            
                            StatCard(
                                icon: "xmark.circle.fill",
                                value: "\(7 - appState.currentCredits)",
                                label: "Lost",
                                color: .sevenRose
                            )
                            
                            StatCard(
                                icon: "calendar",
                                value: "\(daysUntilReset)",
                                label: "Days Left",
                                color: .sevenSkyBlue
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Payment Status Card
                        if nextPaymentAmount == 0 {
                            // Perfect Week Card
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.sevenEmerald.opacity(0.2), Color.sevenEmerald.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.sevenEmerald)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Perfect Week!")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(.sevenEmerald)
                                    
                                    Text("No payment required")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.textSecondary)
                                }
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(Color.cardBackground)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.sevenEmerald.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        } else {
                            // Payment Due Card
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Amount Due")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.textSecondary)
                                    
                                    Text(String(format: "$%.2f", nextPaymentAmount))
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundColor(ringColor)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("Due In")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.textSecondary)
                                    
                                    HStack(spacing: 4) {
                                        Text("\(daysUntilReset)")
                                            .font(.system(size: 40, weight: .bold, design: .rounded))
                                            .foregroundColor(.textPrimary)
                                        
                                        Text("days")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.textSecondary)
                                            .offset(y: 2)
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color.cardBackground)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(ringColor.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Add Credits Button
                        Button(action: {
                            showingTopUpSheet = true
                            HapticFeedback.medium.trigger()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                
                                Text("Add Credits")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .textCase(.none)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [Color.sevenIndigo, Color.sevenSkyBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                            .shadow(color: Color.sevenIndigo.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .padding(.horizontal, 20)
                        
                        // Credit Packages Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 10) {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.sevenIndigo)
                                
                                Text("Credit Packages")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                    .textCase(.none)
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
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.sevenIndigo)
                                
                                Text("How It Works")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                    .textCase(.none)
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                InfoRow(
                                    icon: "calendar.badge.clock",
                                    iconColor: .sevenIndigo,
                                    title: "Weekly Reset",
                                    description: "Every Monday, you start with 7 credits. You need all 7 to use SE7EN throughout the week."
                                )
                                
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                InfoRow(
                                    icon: "xmark.circle.fill",
                                    iconColor: .sevenRose,
                                    title: "Lose Credits",
                                    description: "Go over any app limit and you lose 1 credit that day. Credits are deducted automatically at midnight."
                                )
                                
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                InfoRow(
                                    icon: "exclamationmark.triangle.fill",
                                    iconColor: .sevenAmber,
                                    title: "Restore to Continue",
                                    description: "If you end the week with less than 7 credits, pay $0.99 per missing credit to restore them and continue using SE7EN."
                                )
                                
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                InfoRow(
                                    icon: "sparkles",
                                    iconColor: .sevenEmerald,
                                    title: "Stay Free Forever",
                                    description: "Keep all 7 credits every week and SE7EN stays completely free. Build healthy habits, never pay a dollar."
                                )
                            }
                            .background(Color.cardBackground)
                            .cornerRadius(24)
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 8)
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Credits")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .textCase(.none)
                }
            }
            .sheet(isPresented: $showingTopUpSheet) {
                TopUpSheet()
                    .environmentObject(appState)
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                    animateRing = true
                }
            }
            .onChange(of: appState.currentCredits) { _ in
                animateRing = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    animateRing = true
                }
            }
        }
    }
    
    private var statusText: String {
        switch appState.currentCredits {
        case 7: return "Perfect Week!"
        case 6: return "Almost Perfect"
        case 5: return "Doing Great"
        case 4: return "Stay Focused"
        case 3: return "Keep Going"
        default: return "Turn It Around"
        }
    }
    
    private var statusIcon: String {
        switch appState.currentCredits {
        case 7: return "sparkles"
        case 6...7: return "checkmark.circle.fill"
        case 4...5: return "exclamationmark.triangle.fill"
        default: return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch appState.currentCredits {
        case 7: return .sevenEmerald
        case 6: return .sevenEmerald
        case 5: return .sevenSkyBlue
        case 4: return .sevenAmber
        default: return .sevenRose
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Credit Package Card

struct CreditPackageCard: View {
    let package: CreditPackage
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.sevenIndigo, Color.sevenSkyBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.sevenIndigo.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Text("\(package.credits)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 6) {
                Text("\(package.credits) Credits")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .textCase(.none)
                
                Text(package.priceString)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.sevenIndigo)
                
                Text("$\(String(format: "%.2f", package.perCreditPrice)) each")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(width: 140)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.cardBackground)
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color.sevenIndigo.opacity(0.25), Color.sevenSkyBlue.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.2), iconColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .textCase(.none)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
}
