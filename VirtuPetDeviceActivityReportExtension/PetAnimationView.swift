import SwiftUI

/// A view that displays pet status based on pet type and health state
/// Note: Extensions cannot reliably play videos, so this uses static images
struct PetAnimationView: View {
    let petType: PetType
    let healthState: PetHealthState
    let height: CGFloat
    
    // Pet emoji fallback
    private var petEmoji: String {
        switch petType {
        case .dog: return "🐕"
        case .cat: return "🐈"
        case .bunny: return "🐰"
        case .hamster: return "🐹"
        case .horse: return "🐴"
        }
    }
    
    // Image name in asset catalog: dogfullhealth, doghappy, etc.
    private var imageName: String {
        "\(petType.folderName.lowercased())\(healthState.rawValue)"
    }
    
    var body: some View {
        ZStack {
            // Background with health color
            RoundedRectangle(cornerRadius: 16)
                .fill(healthState.color.opacity(0.15))
                .frame(height: height)
            
            // Try to load the static image from asset catalog
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height * 0.9)
            } else {
                // Fallback: Pet emoji with pulsing animation
                VStack(spacing: 12) {
                    Text(petEmoji)
                        .font(.system(size: 80))
                    
                    Text(healthState.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(healthState.color)
                }
            }
        }
        .frame(height: height)
    }
}
