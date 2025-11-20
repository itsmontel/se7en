import SwiftUI
import AVKit
import AVFoundation

// Helper class to handle state updates from notification observers
class VideoState: ObservableObject {
    @Published var isVideoFinished = false
    @Published var animateContinue = false
    @Published var videoError: String?
    @Published var showSkipButton = false
}

struct VideoIntroductionView: View {
    @EnvironmentObject var appState: AppState
    let onContinue: () -> Void
    let onBack: (() -> Void)?

    @StateObject private var videoState = VideoState()
    @State private var player: AVPlayer?
    @State private var observers: [NSObjectProtocol] = []
    @State private var timeObserver: Any?

    private var petType: PetType {
        appState.userPet?.type ?? .dog
    }

    private var videoName: String {
        "\(petType.rawValue.lowercased())intro"
    }

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                // Header with back button and progress bar
                OnboardingHeader(currentStep: 3, totalSteps: 9, showBackButton: true, onBack: onBack)

                Spacer()

                // Video Player
                VStack(spacing: 24) {
                    if let player = player {
                        VideoPlayerView(player: player)
                            .frame(height: 300)
                            .cornerRadius(24)
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                            .padding(.horizontal, 24)
                    } else if let error = videoState.videoError {
                        // Error state - show pet image instead
                        VStack(spacing: 16) {
                            Image("\(petType.rawValue.lowercased())fullhealth")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                                .cornerRadius(24)
                            
                            Text("Video unavailable")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(error)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(24)
                        .padding(.horizontal, 24)
                    } else {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("Loading introduction...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(24)
                        .padding(.horizontal, 24)
                    }

                    // Title and description
                    VStack(spacing: 16) {
                        Text("Meet your new pet")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .textCase(.none)

                        Text("Get to know \(appState.userPet?.name ?? "your pet") and see how your screen time habits will affect their well-being.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .lineSpacing(4)
                    }
                }

                Spacer()

                // Continue Button
                VStack(spacing: 16) {
                    if videoState.isVideoFinished || videoState.videoError != nil {
                        Button(action: {
                            HapticFeedback.light.trigger()
                            onContinue()
                        }) {
                            Text("Continue")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .textCase(.none)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(20)
                        }
                        .scaleEffect(videoState.animateContinue ? 1.0 : 0.95)
                        .opacity(videoState.animateContinue ? 1.0 : 0.0)
                        .padding(.horizontal, 24)
                    } else if videoState.showSkipButton {
                        Button(action: {
                            HapticFeedback.light.trigger()
                            videoState.isVideoFinished = true
                            videoState.animateContinue = true
                        }) {
                            Text("Skip Introduction")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 24)
                        
                        Text("Watch the introduction to continue")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 24)
                    } else {
                        Text("Watch the introduction to continue")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            setupVideo()
        }
        .onDisappear {
            player?.pause()
            // Remove time observer
            if let observer = timeObserver, let currentPlayer = player {
                currentPlayer.removeTimeObserver(observer)
                timeObserver = nil
            }
            // Remove notification observers
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
        }
    }

    private func setupVideo() {
        // Configure audio session for video playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        // Try to load the video from the bundle
        guard let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            // Video not found - show error and allow skip
            print("⚠️ Video file '\(videoName).mp4' not found in bundle")
            print("📁 Looking for: \(videoName).mp4")
            print("📦 Bundle path: \(Bundle.main.bundlePath)")
            
            // List available resources for debugging
            if let resourcePath = Bundle.main.resourcePath {
                let fileManager = FileManager.default
                if let files = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                    let videoFiles = files.filter { $0.hasSuffix(".mp4") }
                    print("📹 Available .mp4 files in bundle: \(videoFiles)")
                }
            }
            
            videoState.videoError = "Video file '\(videoName).mp4' not found. Please add the video file to your Xcode project."
            
            // Show continue button after short delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                withAnimation(.easeOut(duration: 0.5)) {
                    videoState.isVideoFinished = true
                    videoState.animateContinue = true
                }
            }
            return
        }
        
        // Create player item and player
        let playerItem = AVPlayerItem(url: videoURL)
        let newPlayer = AVPlayer(playerItem: playerItem)
        // Prevent player from resetting to beginning when video ends
        newPlayer.actionAtItemEnd = .pause
        player = newPlayer
        
        // Add periodic time observer to pause near the end to avoid white screen
        let timeInterval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: timeInterval, queue: .main) { [weak videoState] time in
            guard let videoState = videoState else { return }
            guard let playerItem = newPlayer.currentItem else { return }
            
            let duration = playerItem.duration
            let currentTime = newPlayer.currentTime()
            
            // Check if we're close to the end (within 0.2 seconds)
            if CMTIME_IS_VALID(duration) && CMTIME_IS_VALID(currentTime) {
                let timeRemaining = CMTimeSubtract(duration, currentTime)
                let remainingSeconds = CMTimeGetSeconds(timeRemaining)
                
                // Pause when we're very close to the end to keep the last frame
                if remainingSeconds <= 0.3 && remainingSeconds > 0 && !videoState.isVideoFinished {
                    newPlayer.pause()
                    Task { @MainActor in
                        withAnimation(.easeOut(duration: 0.5)) {
                            videoState.isVideoFinished = true
                            videoState.animateContinue = true
                        }
                    }
                }
            }
        }
        
        // Add fallback observer for when video finishes (in case time observer misses it)
        let finishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak videoState] _ in
            guard let videoState = videoState else { return }
            if !videoState.isVideoFinished {
                Task { @MainActor in
                    withAnimation(.easeOut(duration: 0.5)) {
                        videoState.isVideoFinished = true
                        videoState.animateContinue = true
                    }
                }
            }
        }
        observers.append(finishObserver)
        
        // Add observer for player errors
        let errorObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak videoState] notification in
            guard let videoState = videoState else { return }
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ Video playback error: \(error.localizedDescription)")
                Task { @MainActor in
                    videoState.videoError = "Video playback failed: \(error.localizedDescription)"
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    withAnimation(.easeOut(duration: 0.5)) {
                        videoState.isVideoFinished = true
                        videoState.animateContinue = true
                    }
                }
            }
        }
        observers.append(errorObserver)
        
        // Show skip button after 3 seconds if video is still loading
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !videoState.isVideoFinished && player != nil {
                videoState.showSkipButton = true
            }
        }
        
        // Auto-play the video
        newPlayer.play()
        
        // Check if player is actually playing after a short delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if let currentPlayer = player, currentPlayer.rate == 0 {
                print("⚠️ Video player created but not playing. Rate: \(currentPlayer.rate)")
                // Try to play again
                currentPlayer.play()
            }
        }
    }
}

// Custom Video Player View
struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // Hide controls for onboarding flow
        controller.videoGravity = .resizeAspectFill
        controller.allowsPictureInPicturePlayback = false
        
        // Ensure video plays
        DispatchQueue.main.async {
            if player.rate == 0 {
                player.play()
            }
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update player if needed
        if uiViewController.player != player {
            uiViewController.player = player
        }
    }
}
