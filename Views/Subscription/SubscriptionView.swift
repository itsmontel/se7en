import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingTopUpSheet = false
    @State private var animateRing = false
    
    // No weekly payment - app is free, users only pay for credits they lose
    
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
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    HStack {
                        Spacer()
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
                        
                        // Status Card
                        if appState.currentCredits == 7 {
                            // Perfect Day Card
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
                                    Text("Perfect Day!")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(.sevenEmerald)
                                    
                                    Text("SE7EN stays free")
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
                            // Credits Lost Card
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Credits Lost")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.textSecondary)
                                    
                                    Text("\(7 - appState.currentCredits)")
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundColor(ringColor)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("Reset In")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.textSecondary)
                                    
                                    HStack(spacing: 4) {
                                        Text("Tomorrow")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(.textPrimary)
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
                                    icon: "arrow.clockwise.circle.fill",
                                    iconColor: .sevenIndigo,
                                    title: "Daily Reset",
                                    description: "Credits reset to 7 every day at midnight."
                                )
                                
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                InfoRow(
                                    icon: "chart.line.uptrend.xyaxis",
                                    iconColor: .sevenRose,
                                    title: "Progressive Penalty",
                                    description: "Each failure costs more: 1st = 1 credit, 2nd = 2 credits, 3rd = 3 credits, and so on. Failure count resets every Monday."
                                )
                                
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                InfoRow(
                                    icon: "lock.shield.fill",
                                    iconColor: .sevenAmber,
                                    title: "Accountability Fee",
                                    description: "When an app is blocked, you need 7 credits to unblock it. Once paid, no additional credits are deducted for other failures that same day. Resets daily at midnight."
                                )
                                
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                InfoRow(
                                    icon: "sparkles",
                                    iconColor: .sevenEmerald,
                                    title: "Stay Free",
                                    description: "Keep all 7 credits daily and SE7EN stays free forever."
                                )
                            }
                            .background(Color.cardBackground)
                            .cornerRadius(24)
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 8)
                        
                        Spacer(minLength: 50)
                    }
                    .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 800 : .infinity)
                    Spacer()
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
    
    private func formatPerCreditPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
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
                
                Text("\(formatPerCreditPrice(package.perCreditPrice)) each")
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
    
    private func formatPerCreditPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
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
