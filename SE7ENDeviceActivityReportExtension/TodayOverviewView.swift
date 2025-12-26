//
//  TodayOverviewView.swift
//  SE7ENDeviceActivityReportExtension
//

import SwiftUI
import AVKit
import FamilyControls

struct TodayOverviewView: View {
    let summary: UsageSummary
    
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
    
    // Get pet info from shared container
    private var petType: PetType {
        let appGroupID = "group.com.se7en.app"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return .dog  // Default fallback
        }
        sharedDefaults.synchronize()
        guard let petTypeString = sharedDefaults.string(forKey: "user_pet_type"),
              let type = PetType(rawValue: petTypeString) else {
            return .dog
        }
        return type
    }
    
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
            // Pet Animation Section (at the top) - same style as dashboard
            PetAnimationPlayerView(
                petType: petType,
                healthState: petHealthState,
                colorScheme: colorScheme,
                height: 220
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
            
            // Health Score Section (below pet animation)
            VStack(spacing: 0) {
                Text("\(healthScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
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
                .padding(.horizontal, 24) // Reduced padding to make health bar longer
                .padding(.bottom, 10)
                
                Text("Health")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 12) // Reduced padding to make wider
            
            // Today's Dashboard header with green dot (center justified)
            HStack(alignment: .center, spacing: 0) {
                Spacer()
                
                Text("Today's Dashboard")
                    .font(.system(size: 16, weight: .bold)) // Smaller text
                    .foregroundColor(.primary)
                
                // Green circular dot (smaller, further right)
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                    .padding(.leading, 16) // Push dot further right
                
                Spacer()
            }
                .padding(.horizontal, 12) // Reduced padding to make wider
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
            .padding(.horizontal, 12) // Reduced padding to make wider
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 12) // Reduced padding to make wider
            
            // Top 10 Distractions list
            if !summary.topApps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top 10 Distractions")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12) // Reduced padding to make wider
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
                            .padding(.horizontal, 12) // Reduced padding to make wider
                            .padding(.vertical, 12)
                            
                            // Divider between items (but not after last item)
                            if index < min(summary.topApps.count, 10) - 1 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.horizontal, 12) // Reduced padding to make wider
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
            let totalMinutes = Int(summary.totalDuration / 60)
            let healthScore = calculateHealthScore(totalMinutes: totalMinutes)
            
            print("📊 TodayOverviewView appeared: \(summary.appCount) apps, \(totalMinutes) min, health: \(healthScore)%")
            
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
    
    /// Calculate health score based on total screen time
    private func calculateHealthScore(totalMinutes: Int) -> Int {
        let totalHours = Double(totalMinutes) / 60.0
        
        let healthScore: Int
        switch totalHours {
        case 0..<2: 
            healthScore = 100
        case 2..<4: 
            // 2-4 hours: 100-80 health (linear decrease: -10 per hour)
            healthScore = Int(100.0 - (10.0 * (totalHours - 2.0)))
        case 4..<6: 
            // 4-6 hours: 80-60 health (linear decrease: -10 per hour)
            healthScore = Int(80.0 - (10.0 * (totalHours - 4.0)))
        case 6..<8: 
            // 6-8 hours: 60-40 health (linear decrease: -10 per hour)
            healthScore = Int(60.0 - (10.0 * (totalHours - 6.0)))
        case 8..<10: 
            // 8-10 hours: 40-20 health (linear decrease: -10 per hour)
            healthScore = Int(40.0 - (10.0 * (totalHours - 8.0)))
        case 10..<12: 
            // 10-12 hours: 20-0 health (linear decrease: -10 per hour)
            healthScore = Int(20.0 - (10.0 * (totalHours - 10.0)))
        default: 
            // 12+ hours: 0 health
            healthScore = 0
        }
        
        return max(0, min(100, healthScore))
    }
    
    private func format(duration: TimeInterval) -> String {
        // Show sub-minute usage as "<1m" when there is non-zero activity.
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

// MARK: - Pet Animation Player View (same style as dashboard)
struct PetAnimationPlayerView: View {
    let petType: PetType
    let healthState: PetHealthState
    let colorScheme: ColorScheme
    let height: CGFloat
    
    @State private var player: AVPlayer?
    @State private var hasVideo = false
    
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
        Group {
            if hasVideo, let player = player {
                // Use TransparentVideoPlayer (same as dashboard)
                TransparentVideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height)
            } else {
                // Fallback to static image if video not found
                let imageName = "\(petType.folderName.lowercased())\(healthState.rawValue)"
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height)
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: healthState) { _ in
            setupPlayer()
        }
        .onChange(of: colorScheme) { _ in
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        let fileName = animationFileName()
        
        // Try multiple ways to find the video (handles different bundle configurations)
        let videoURL = Bundle.main.url(forResource: fileName, withExtension: "mp4", subdirectory: "Animation")
            ?? Bundle.main.url(forResource: "Animation/\(fileName)", withExtension: "mp4")
            ?? Bundle.main.url(forResource: fileName, withExtension: "mp4")
        
        guard let url = videoURL else {
            #if DEBUG
            print("⚠️ PetAnimationPlayerView: Video not found for \(fileName).mp4")
            print("   Tried: subdirectory 'Animation', 'Animation/\(fileName)', and root")
            #endif
            hasVideo = false
            return
        }
        
        #if DEBUG
        print("✅ PetAnimationPlayerView: Loading video from \(url.path)")
        #endif
        
        let newPlayerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: newPlayerItem)
        newPlayer.actionAtItemEnd = .none
        
        // Mute the video
        newPlayer.isMuted = true
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayerItem,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }
        
        // Start playing immediately and retry if needed
        newPlayer.play()
        
        // Also try playing after delays (extensions sometimes need this)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if newPlayer.rate == 0 {
                newPlayer.play()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if newPlayer.rate == 0 && newPlayerItem.status == .readyToPlay {
                newPlayer.play()
            }
        }
        
        self.player = newPlayer
        self.hasVideo = true
    }
}

// MARK: - Transparent Video Player (same as dashboard)
struct TransparentVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = false
        controller.updatesNowPlayingInfoCenter = false
        
        // Make the background transparent
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false
        
        // Also make the content overlay view transparent
        if let contentOverlayView = controller.contentOverlayView {
            contentOverlayView.backgroundColor = .clear
            contentOverlayView.isOpaque = false
        }
        
        // Find and make the AVPlayerLayer's superview transparent
        DispatchQueue.main.async {
            // Remove all shadows from the main view layer
            controller.view.layer.shadowOpacity = 0
            controller.view.layer.shadowRadius = 0
            controller.view.layer.shadowOffset = .zero
            controller.view.layer.shadowColor = nil
            
            if let playerLayer = controller.view.layer.sublayers?.first(where: { $0 is AVPlayerLayer }) {
                playerLayer.backgroundColor = UIColor.clear.cgColor
                playerLayer.shadowOpacity = 0
                playerLayer.shadowRadius = 0
                playerLayer.shadowOffset = .zero
                playerLayer.shadowColor = nil
            }
            
            // Make all subviews transparent and remove shadows, hide play buttons
            controller.view.subviews.forEach { subview in
                subview.backgroundColor = .clear
                subview.isOpaque = false
                subview.layer.shadowOpacity = 0
                subview.layer.shadowRadius = 0
                subview.layer.shadowOffset = .zero
                subview.layer.shadowColor = nil
                
                // Hide any play button overlays
                if subview is UIButton {
                    subview.isHidden = true
                    subview.alpha = 0
                }
                subview.subviews.forEach { buttonSubview in
                    if buttonSubview is UIButton {
                        buttonSubview.isHidden = true
                        buttonSubview.alpha = 0
                    }
                }
            }
            
            // Hide play button in content overlay
            if let contentOverlay = controller.contentOverlayView {
                contentOverlay.subviews.forEach { overlaySubview in
                    if overlaySubview is UIButton {
                        overlaySubview.isHidden = true
                        overlaySubview.alpha = 0
                    }
                    overlaySubview.subviews.forEach { buttonSubview in
                        if buttonSubview is UIButton {
                            buttonSubview.isHidden = true
                            buttonSubview.alpha = 0
                        }
                    }
                }
            }
            
            // Remove shadows from all sublayers
            controller.view.layer.sublayers?.forEach { layer in
                layer.shadowOpacity = 0
                layer.shadowRadius = 0
                layer.shadowOffset = .zero
                layer.shadowColor = nil
            }
            
            // Force play after a delay (extensions sometimes need this)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if player.rate == 0 {
                    player.play()
                }
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player != player {
            uiViewController.player = player
        }
        
        // Ensure controls are hidden
        uiViewController.showsPlaybackControls = false
        
        // Ensure transparency is maintained
        uiViewController.view.backgroundColor = .clear
        uiViewController.view.isOpaque = false
        
        // Ensure shadows remain removed
        uiViewController.view.layer.shadowOpacity = 0
        uiViewController.view.layer.shadowRadius = 0
        uiViewController.view.layer.shadowOffset = .zero
        uiViewController.view.layer.shadowColor = nil
        
        // Hide play buttons in content overlay
        DispatchQueue.main.async {
            if let contentOverlay = uiViewController.contentOverlayView {
                contentOverlay.subviews.forEach { overlaySubview in
                    if overlaySubview is UIButton {
                        overlaySubview.isHidden = true
                        overlaySubview.alpha = 0
                    }
                    overlaySubview.subviews.forEach { buttonSubview in
                        if buttonSubview is UIButton {
                            buttonSubview.isHidden = true
                            buttonSubview.alpha = 0
                        }
                    }
                }
            }
            
            // Force play if not playing
            if let player = uiViewController.player, player.rate == 0 {
                player.play()
            }
        }
    }
}
