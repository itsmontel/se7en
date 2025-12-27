import SwiftUI
import AVKit

/// A view that plays looping pet animations based on pet type and health state
struct PetAnimationView: View {
    let petType: PetType
    let healthState: PetHealthState
    let height: CGFloat
    
    @State private var player: AVPlayer?
    @State private var hasVideo = false
    @Environment(\.colorScheme) private var colorScheme
    
    private func animationFileName(for scheme: ColorScheme) -> String {
        let petName = petType.folderName
        let healthName: String
        
        switch healthState {
        case .fullHealth:
            healthName = "FullHealth"
        case .happy:
            healthName = "Happy"
        case .content:
            healthName = "Content"
        case .sad:
            healthName = "Sad"
        case .sick:
            healthName = "Sick"
        }
        
        // Add "Dark" prefix for dark mode
        let prefix = scheme == .dark ? "Dark" : ""
        return "\(prefix)\(petName)\(healthName)Animation"
    }
    
    var body: some View {
        Group {
            if hasVideo, let player = player {
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
            // Reload video when health state changes
            setupPlayer()
        }
        .onChange(of: colorScheme) { _ in
            // Reload video when color scheme changes
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        let fileName = animationFileName(for: colorScheme)
        
        // Try subdirectory first (folder reference)
        var videoURL = Bundle.main.url(forResource: fileName, withExtension: "mp4", subdirectory: "Animation")
        
        // Fallback: try without subdirectory (for different bundle configurations)
        if videoURL == nil {
            videoURL = Bundle.main.url(forResource: fileName, withExtension: "mp4")
        }
        
        guard let url = videoURL else {
            #if DEBUG
            print("⚠️ PetAnimationView: Video not found for \(fileName).mp4")
            #endif
            hasVideo = false
            return
        }
        
        #if DEBUG
        print("✅ PetAnimationView: Loading video from \(url.path) (colorScheme: \(colorScheme))")
        #endif
        
        let newPlayer = AVPlayer(url: url)
        newPlayer.actionAtItemEnd = .none
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
        
        // Mute the video
        newPlayer.isMuted = true
        
        // Start playing
        newPlayer.play()
        
        self.player = newPlayer
        self.hasVideo = true
    }
}

// MARK: - Transparent Video Player

/// A custom video player view with transparent background
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
                // Remove shadows from player layer
                playerLayer.shadowOpacity = 0
                playerLayer.shadowRadius = 0
                playerLayer.shadowOffset = .zero
                playerLayer.shadowColor = nil
            }
            
            // Make all subviews transparent and remove shadows
            controller.view.subviews.forEach { subview in
                subview.backgroundColor = .clear
                subview.isOpaque = false
                subview.layer.shadowOpacity = 0
                subview.layer.shadowRadius = 0
                subview.layer.shadowOffset = .zero
                subview.layer.shadowColor = nil
            }
            
            // Remove shadows from all sublayers
            controller.view.layer.sublayers?.forEach { layer in
                layer.shadowOpacity = 0
                layer.shadowRadius = 0
                layer.shadowOffset = .zero
                layer.shadowColor = nil
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player != player {
            uiViewController.player = player
        }
        
        // Ensure transparency is maintained
        uiViewController.view.backgroundColor = .clear
        uiViewController.view.isOpaque = false
        
        // Ensure shadows remain removed
        uiViewController.view.layer.shadowOpacity = 0
        uiViewController.view.layer.shadowRadius = 0
        uiViewController.view.layer.shadowOffset = .zero
        uiViewController.view.layer.shadowColor = nil
    }
}
