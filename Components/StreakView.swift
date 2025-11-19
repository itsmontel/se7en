import SwiftUI

struct StreakView: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(streakColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: streakIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(streakColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                Text("day\(streak == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textPrimary.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .shadow(color: streakColor.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private var streakColor: Color {
        switch streak {
        case 0:
            return .gray
        case 1...2:
            return .success
        case 3...6:
            return .warning
        case 7...13:
            return .error
        case 14...29:
            return .secondary
        case 30...99:
            return .purple
        default:
            return .yellow
        }
    }
    
    private var streakIcon: String {
        switch streak {
        case 0:
            return "minus.circle.fill"
        case 1...2:
            return "checkmark.circle.fill"
        case 3...6:
            return "flame.fill"
        case 7...13:
            return "flame.fill"
        case 14...29:
            return "crown.fill"
        case 30...99:
            return "star.circle.fill"
        default:
            return "trophy.fill"
        }
    }
}

