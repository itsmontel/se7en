import SwiftUI

struct DailySummaryCard: View {
    @EnvironmentObject var appState: AppState
    
    private var totalUsed: Int {
        appState.monitoredApps.reduce(0) { $0 + $1.usedToday }
    }
    
    private var totalLimit: Int {
        appState.monitoredApps.reduce(0) { $0 + $1.dailyLimit }
    }
    
    private var remaining: Int {
        max(0, totalLimit - totalUsed)
    }
    
    private var progress: Double {
        guard totalLimit > 0 else { return 0 }
        return Double(totalUsed) / Double(totalLimit)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Summary")
                    .font(.h3)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if progress >= 1.0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.error)
                } else if progress >= 0.8 {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.warning)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.success)
                }
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Used")
                        .font(.caption)
                        .foregroundColor(.textPrimary.opacity(0.6))
                    
                    Text(formatMinutes(totalUsed))
                        .font(.h2)
                        .foregroundColor(.textPrimary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Limit")
                        .font(.caption)
                        .foregroundColor(.textPrimary.opacity(0.6))
                    
                    Text(formatMinutes(totalLimit))
                        .font(.h2)
                        .foregroundColor(.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.textPrimary.opacity(0.6))
                    
                    Text(formatMinutes(remaining))
                        .font(.h2)
                        .foregroundColor(progress >= 1.0 ? .error : .success)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: progressGradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(progress, 1.0), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .cardStyle()
        .padding(.horizontal, 20)
    }
    
    private var progressGradientColors: [Color] {
        if progress >= 1.0 {
            return [.error, .error.opacity(0.7)]
        } else if progress >= 0.8 {
            return [.warning, .warning.opacity(0.7)]
        } else {
            return [.success, .success.opacity(0.7)]
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}


