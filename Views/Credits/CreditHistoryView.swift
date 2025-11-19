import SwiftUI

struct CreditHistoryView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Week Summary
                    WeekSummaryCard(currentCredits: appState.currentCredits)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Daily Breakdown
                    DailyBreakdownSection(dailyHistory: appState.dailyHistory)
                    
                    // Stats Card
                    StatsCard(dailyHistory: appState.dailyHistory)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WeekSummaryCard: View {
    let currentCredits: Int
    
    var body: some View {
        VStack(spacing: 16) {
            Text("This Week")
                .font(.h3)
                .foregroundColor(.textPrimary)
            
            // Credits Bar
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    CreditBarItem(index: index, currentCredits: currentCredits)
                }
            }
            
            Text("You kept \(currentCredits) out of 7 credits")
                .font(.bodyLarge)
                .foregroundColor(.textPrimary.opacity(0.7))
        }
        .padding(20)
        .cardStyle()
    }
}

struct CreditBarItem: View {
    let index: Int
    let currentCredits: Int
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(fillColor)
                .frame(height: 60)
            
            Text("\(index + 1)")
                .font(.h4)
                .foregroundColor(textColor)
        }
    }
    
    private var fillColor: Color {
        if index < currentCredits {
            return Color.primary
        } else {
            return Color.gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        if index < currentCredits {
            return .white
        } else {
            return .textPrimary.opacity(0.4)
        }
    }
}

struct DailyBreakdownSection: View {
    let dailyHistory: [DailyHistory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.h3)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 20)
            
            ForEach(dailyHistory) { record in
                DailyHistoryRow(record: record)
                    .padding(.horizontal, 20)
            }
        }
    }
}

struct DailyHistoryRow: View {
    let record: DailyHistory
    
    var body: some View {
        HStack(spacing: 16) {
            // Day Icon
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            // Day Info
            VStack(alignment: .leading, spacing: 4) {
                Text(dayName)
                    .font(.h4)
                    .foregroundColor(.textPrimary)
                
                Text(statusText)
                    .font(.bodySmall)
                    .foregroundColor(.textPrimary.opacity(0.6))
            }
            
            Spacer()
            
            // Credit Change
            Text(creditText)
                .font(.h3)
                .foregroundColor(iconColor)
        }
        .padding(16)
        .cardStyle()
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: record.date)
    }
    
    private var backgroundColor: Color {
        if record.isSuccess {
            return Color.success.opacity(0.15)
        } else {
            return Color.error.opacity(0.15)
        }
    }
    
    private var iconName: String {
        if record.isSuccess {
            return "checkmark"
        } else {
            return "xmark"
        }
    }
    
    private var iconColor: Color {
        if record.isSuccess {
            return .success
        } else {
            return .error
        }
    }
    
    private var statusText: String {
        if record.isSuccess {
            return "Kept credit"
        } else {
            return "Lost 1 credit"
        }
    }
    
    private var creditText: String {
        if record.creditChange == 0 {
            return "+0"
        } else {
            return "\(record.creditChange)"
        }
    }
}

struct StatsCard: View {
    let dailyHistory: [DailyHistory]
    
    var body: some View {
        HStack(spacing: 20) {
            CreditStatItem(
                title: "Credits Kept",
                value: "\(creditsKept)",
                color: .success
            )
            
            Divider()
                .frame(height: 60)
            
            CreditStatItem(
                title: "Credits Lost",
                value: "\(creditsLost)",
                color: .error
            )
        }
        .padding(20)
        .cardStyle()
    }
    
    private var creditsKept: Int {
        var count = 0
        for record in dailyHistory {
            if record.isSuccess {
                count += 1
            }
        }
        return count
    }
    
    private var creditsLost: Int {
        var count = 0
        for record in dailyHistory {
            if !record.isSuccess {
                if record.creditChange == -1 {
                    count += 1
                }
            }
        }
        return count
    }
}

struct CreditStatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.numberSmall)
                .foregroundColor(color)
            
            Text(title)
                .font(.captionBold)
                .foregroundColor(.textPrimary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}