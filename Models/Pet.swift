import SwiftUI

// MARK: - Pet Type
enum PetType: String, CaseIterable, Codable {
    case dog = "Dog"
    case cat = "Cat"
    case bunny = "Bunny"
    case hamster = "Hamster"
    case horse = "Horse"
    
    var folderName: String {
        switch self {
        case .dog: return "Dog"
        case .cat: return "Cat"
        case .bunny: return "Bunny"
        case .hamster: return "Hamster"
        case .horse: return "Horse"
        }
    }
}

// MARK: - Pet Health State
enum PetHealthState: String, CaseIterable, Codable {
    case sick = "sick"
    case sad = "sad"
    case content = "content"
    case happy = "happy"
    case fullHealth = "fullhealth"
    
    var displayName: String {
        switch self {
        case .sick: return "Sick"
        case .sad: return "Sad"
        case .content: return "Content"
        case .happy: return "Happy"
        case .fullHealth: return "Full Health"
        }
    }
    
    var description: String {
        switch self {
        case .sick: return "Your pet needs urgent care! Reduce screen time now."
        case .sad: return "Your pet is feeling down. Time to cut back on screen time."
        case .content: return "Your pet is doing okay, but could be happier."
        case .happy: return "Your pet is happy! Keep up the good work."
        case .fullHealth: return "Your pet is thriving! Excellent screen time habits."
        }
    }
    
    var color: Color {
        switch self {
        case .sick: return .red
        case .sad: return .orange
        case .content: return .yellow
        case .happy: return .green
        case .fullHealth: return .blue
        }
    }
    
    // Calculate health state based on screen time percentage (0-100)
    static func from(healthPercentage: Double) -> PetHealthState {
        switch healthPercentage {
        case 80...100:
            return .fullHealth
        case 60..<80:
            return .happy
        case 40..<60:
            return .content
        case 20..<40:
            return .sad
        default:
            return .sick
        }
    }
}

// MARK: - Pet Model
struct Pet: Codable {
    var type: PetType
    var name: String
    var healthState: PetHealthState
    
    init(type: PetType, name: String, healthState: PetHealthState = .fullHealth) {
        self.type = type
        self.name = name
        self.healthState = healthState
    }
    
    // Get the image name for current state
    var imageName: String {
        return "\(type.folderName.lowercased())\(healthState.rawValue)"
    }
    
    // Get the full image path
    var imagePath: String {
        return "Pets/\(type.folderName)/\(type.folderName.lowercased())\(healthState.rawValue)"
    }
    
    // Update health based on screen time performance
    mutating func updateHealth(screenTimePercentage: Double) {
        self.healthState = PetHealthState.from(healthPercentage: screenTimePercentage)
    }
}

// MARK: - Download Motivation
enum DownloadMotivation: String, CaseIterable, Identifiable {
    case improveFocus = "Improve focus"
    case sleepBetter = "Sleep better"
    case moreProductive = "More productive"
    case reduceAnxiety = "Reduce anxiety"
    case betterHabits = "Better habits"
    case curious = "Just curious"
    case recommended = "Recommended by someone"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .improveFocus: return "scope"
        case .sleepBetter: return "moon.stars.fill"
        case .moreProductive: return "chart.line.uptrend.xyaxis"
        case .reduceAnxiety: return "heart.fill"
        case .betterHabits: return "sparkles"
        case .curious: return "magnifyingglass"
        case .recommended: return "person.2.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}


