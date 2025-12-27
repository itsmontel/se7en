//
//  TodayOverviewView.swift
//  SE7ENDeviceActivityReportExtension
//

import SwiftUI
import ImageIO
import FamilyControls

struct TodayOverviewView: View {
    let summary: UsageSummary
    
    // Use @State for pet type so it refreshes
    @State private var currentPetType: PetType = .dog
    
    // Calculate health score from total screen time (direct from DeviceActivity data)
    private var healthScore: Int {
        let totalMinutes = Int(summary.totalDuration / 60)
        return calculateHealthScore(totalMinutes: totalMinutes)
    }
    
    // Health score color based on value
    private var healthColor: Color {
        switch healthScore {
        case 60...100: return .green
        case 40..<60: return .orange  // Amber
        default: return .red  // 0-39
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    // Calculate health state from health score
    private var petHealthState: PetHealthState {
        switch healthScore {
        case 90...100: return .fullHealth
        case 70..<90: return .happy
        case 50..<70: return .content
        case 20..<50: return .sad
        default: return .sick
        }
    }
    
    var body: some View {
        // App background color that adapts to light/dark mode
        let appBackground = Color(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0)
            } else {
                return UIColor(red: 1.0, green: 0.98, blue: 0.9, alpha: 1.0)
            }
        })
        
        VStack(alignment: .leading, spacing: 16) {
            // Pet Animation Section (at the top) - using GIF animation
            GIFAnimationView(
                petType: currentPetType,
                healthState: petHealthState,
                colorScheme: colorScheme,
                height: 340
            )
            .id("\(currentPetType.rawValue)-\(petHealthState.rawValue)-\(colorScheme == .dark ? "dark" : "light")")
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 0)
            .padding(.bottom, 0)
            
            // Health Score Section (below pet animation)
            VStack(spacing: 0) {
                Text("\(healthScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, -20)
                    .padding(.bottom, 12)
                
                // Health bar with full border and proportional fill
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Full track/border (always visible from 0-100)
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.1))
                            )
                        
                        // Fill based on healthScore (0-100) - only colored portion
                        RoundedRectangle(cornerRadius: 6)
                            .fill(healthColor)
                            .frame(width: max(0, geometry.size.width * CGFloat(healthScore) / 100))
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
                
                Text("Health")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 0)
            .padding(.bottom, 8)
            
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 12)
            
            // Today's Dashboard header with green dot (center justified)
            HStack(alignment: .center, spacing: 0) {
                Spacer()
                
                Text("Today's Dashboard")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                // Green circular dot
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                    .padding(.leading, 16)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)
            
            // Summary stats - side by side
            HStack(alignment: .top, spacing: 0) {
                // Today's Screen Time
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Screen...")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Text(format(duration: summary.totalDuration))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Apps Used
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Apps Used")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Text("\(summary.appCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 12)
            
            // Top 10 Distractions list
            if !summary.topApps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top 10 Distractions")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(summary.topApps.prefix(10).enumerated()), id: \.offset) { index, app in
                            HStack(spacing: 16) {
                                // Number (1-10)
                                Text("\(index + 1)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(width: 30, alignment: .leading)
                                
                                // App icon (if available)
                                if let application = app.application,
                                   let token = application.token {
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .frame(width: 32, height: 32)
                                } else {
                                    // Fallback icon if token not available
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                        .frame(width: 32, height: 32)
                                }
                                
                                // App name
                                Text(app.name)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // Usage time
                                Text(format(duration: app.duration))
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            
                            // Divider between items (but not after last item)
                            if index < min(summary.topApps.count, 10) - 1 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                }
            } else if summary.appCount > 0 {
                Text("Individual app breakdown not available")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .background(appBackground)
        .cornerRadius(16)
        .onAppear {
            // Load pet type from shared container
            loadPetType()
            
            let totalMinutes = Int(summary.totalDuration / 60)
            let healthScore = calculateHealthScore(totalMinutes: totalMinutes)
            
            print("📊 TodayOverviewView appeared: \(summary.appCount) apps, \(totalMinutes) min, health: \(healthScore)%, pet: \(currentPetType.rawValue)")
            
            // CRITICAL: Ensure data is written to shared container when view appears
            let appGroupID = "group.com.se7en.app"
            if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
                sharedDefaults.set(totalMinutes, forKey: "total_usage")
                sharedDefaults.set(summary.appCount, forKey: "apps_count")
                sharedDefaults.set(healthScore, forKey: "health_score")
                sharedDefaults.set(Date().timeIntervalSince1970, forKey: "last_updated")
                sharedDefaults.synchronize()
                print("💾 TodayOverviewView: Saved - \(totalMinutes) min, health: \(healthScore)%")
            }
        }
    }
    
    /// Load pet type from shared container
    private func loadPetType() {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            currentPetType = .dog
            return
        }
        sharedDefaults.synchronize()
        if let petTypeString = sharedDefaults.string(forKey: "user_pet_type"),
           let type = PetType(rawValue: petTypeString) {
            currentPetType = type
            print("🐾 TodayOverviewView: Loaded pet type '\(type.rawValue)' from shared container")
        } else {
            currentPetType = .dog
            print("🐾 TodayOverviewView: No pet type found, using default 'dog'")
        }
    }
    
    /// Calculate health score based on total screen time
    private func calculateHealthScore(totalMinutes: Int) -> Int {
        let totalHours = Double(totalMinutes) / 60.0
        
        let healthScore: Int
        switch totalHours {
        case 0..<2: 
            healthScore = 100
        case 2..<4: 
            healthScore = Int(100.0 - (10.0 * (totalHours - 2.0)))
        case 4..<6: 
            healthScore = Int(80.0 - (10.0 * (totalHours - 4.0)))
        case 6..<8: 
            healthScore = Int(60.0 - (10.0 * (totalHours - 6.0)))
        case 8..<10: 
            healthScore = Int(40.0 - (10.0 * (totalHours - 8.0)))
        case 10..<12: 
            healthScore = Int(20.0 - (10.0 * (totalHours - 10.0)))
        default: 
            healthScore = 0
        }
        
        return max(0, min(100, healthScore))
    }
    
    private func format(duration: TimeInterval) -> String {
        if duration > 0 && duration < 60 {
            return "<1m"
        }
        
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - GIF Animation View
struct GIFAnimationView: View {
    let petType: PetType
    let healthState: PetHealthState
    let colorScheme: ColorScheme
    let height: CGFloat
    
    private func animationFileName() -> String {
        let petName = petType.folderName
        let healthName: String
        switch healthState {
        case .fullHealth: healthName = "FullHealth"
        case .happy: healthName = "Happy"
        case .content: healthName = "Content"
        case .sad: healthName = "Sad"
        case .sick: healthName = "Sick"
        }
        let prefix = colorScheme == .dark ? "Dark" : ""
        return "\(prefix)\(petName)\(healthName)Animation"
    }
    
    var body: some View {
        GIFImageView(fileName: animationFileName(), height: height, petType: petType, healthState: healthState)
            .frame(height: height)
    }
}

// MARK: - GIF Image View with Animation using UIViewRepresentable
struct GIFImageView: UIViewRepresentable {
    let fileName: String
    let height: CGFloat
    let petType: PetType
    let healthState: PetHealthState
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(imageView)
        
        // Pin imageView to container edges
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        loadGIF(into: imageView)
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let imageView = uiView.subviews.first as? UIImageView else { return }
        loadGIF(into: imageView)
    }
    
    private func loadGIF(into imageView: UIImageView) {
        // Try multiple ways to find the GIF
        let gifURL = Bundle.main.url(forResource: fileName, withExtension: "gif", subdirectory: "AnimationGIF")
            ?? Bundle.main.url(forResource: "AnimationGIF/\(fileName)", withExtension: "gif")
            ?? Bundle.main.url(forResource: fileName, withExtension: "gif")
        
        if let url = gifURL,
           let data = try? Data(contentsOf: url),
           let source = CGImageSourceCreateWithData(data as CFData, nil) {
            
            let frameCount = CGImageSourceGetCount(source)
            var images: [UIImage] = []
            var totalDuration: Double = 0
            
            for i in 0..<frameCount {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    images.append(UIImage(cgImage: cgImage))
                    
                    // Get frame duration
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                        let delay = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                            ?? gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double
                            ?? 0.1
                        totalDuration += max(0.02, delay)
                    } else {
                        totalDuration += 0.1
                    }
                }
            }
            
            if !images.isEmpty {
                imageView.animationImages = images
                imageView.animationDuration = totalDuration
                imageView.animationRepeatCount = 0 // Infinite loop
                imageView.startAnimating()
                
                // Also set the first frame as the static image
                imageView.image = images.first
                
                print("✅ GIFImageView: Loaded \(frameCount) frames for \(fileName).gif, duration: \(totalDuration)s")
                return
            }
        }
        
        // Fallback to static image
        let imageName = "\(petType.folderName.lowercased())\(healthState.rawValue)"
        if let staticImage = UIImage(named: imageName) {
            imageView.image = staticImage
            imageView.animationImages = nil
            print("⚠️ GIFImageView: Using static fallback image '\(imageName)' for \(fileName).gif")
        } else {
            // Ultimate fallback - use system image
            imageView.image = UIImage(systemName: "pawprint.fill")
            imageView.tintColor = .secondaryLabel
            print("⚠️ GIFImageView: GIF not found for \(fileName).gif, using pawprint fallback")
        }
    }
}
