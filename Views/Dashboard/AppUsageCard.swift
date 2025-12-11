import SwiftUI

struct AppUsageCard: View {
    let app: MonitoredApp
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // App Icon
                ZStack {
                    Circle()
                        .fill(app.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    // Use Instagram logo PNG if app is Instagram, otherwise use SF Symbol
                    if app.name == "Instagram" {
                        Image("instagramlogo")
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                    } else {
                    Image(systemName: app.icon)
                        .font(.system(size: 22))
                        .foregroundColor(app.color)
                    }
                }
                
                // App Name and Status
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.h4)
                        .foregroundColor(.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text("\(formatMinutes(app.usedToday))")
                            .font(.bodyMedium)
                            .foregroundColor(app.statusColor)
                        
                        Text("/ \(formatMinutes(app.dailyLimit))")
                            .font(.bodyMedium)
                            .foregroundColor(.textPrimary.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Status Icon
                if app.isOverLimit {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.error)
                } else if app.isNearLimit {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.warning)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.success)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(app.statusColor)
                        .frame(width: geometry.size.width * min(app.percentageUsed, 1.0), height: 6)
                }
            }
            .frame(height: 6)
            
            // Time Remaining / Status
            HStack {
                if app.isOverLimit {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Over by \(formatMinutes(app.usedToday - app.dailyLimit))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.error)
                        
                        Text("🚫 App is blocked")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.error)
                    }
                } else {
                    Text("\(formatMinutes(app.remainingMinutes)) remaining")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.success)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}


