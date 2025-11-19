import SwiftUI

struct PetHealthCard: View {
    @EnvironmentObject var appState: AppState
    
    private var currentPet: Pet? {
        appState.userPet
    }
    
    private var petHealthState: PetHealthState {
        // Calculate health based on credits
        switch appState.currentCredits {
        case 7: return .fullHealth
        case 5...6: return .happy
        case 3...4: return .content
        case 1...2: return .sad
        default: return .sick
        }
    }
    
    private var petName: String {
        currentPet?.name ?? "Your Pet"
    }
    
    private var petType: String {
        currentPet?.type.folderName.lowercased() ?? "dog"
    }
    
    private var petImageName: String {
        "\(petType)\(petHealthState.rawValue)"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Pet Image
            Image(petImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .id(petHealthState) // Force re-render on state change
                .transition(.scale.combined(with: .opacity))
            
            // Pet Info
            VStack(spacing: 8) {
                Text(petName)
                    .font(.h3)
                    .foregroundColor(.textPrimary)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(petHealthState.color)
                        .frame(width: 8, height: 8)
                    
                    Text(petHealthState.displayName)
                        .font(.bodyMedium)
                        .foregroundColor(petHealthState.color)
                }
            }
            
            // Health Message
            Text(healthMessage)
                .font(.bodyMedium)
                .foregroundColor(.textPrimary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyle()
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: petHealthState)
    }
    
    private var healthMessage: String {
        switch petHealthState {
        case .fullHealth:
            return "\(petName) is thriving! Keep up the great work! 🌟"
        case .happy:
            return "\(petName) is doing well. Stay on track!"
        case .content:
            return "\(petName) is okay, but needs your attention."
        case .sad:
            return "\(petName) is struggling. Be careful!"
        case .sick:
            return "\(petName) needs help! Time to top up credits."
        }
    }
}


