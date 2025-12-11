import SwiftUI
import AVKit
import AVFoundation

/// A full-screen video player view for TikTok-style vertical video playback
struct VideoPlayerView: View {
    let video: Video
    let isActive: Bool
    /// Preloaded player passed from VideoViewModel for instant playback (first video only)
    let preloadedPlayer: AVPlayer?
    let onLike: () -> Void
    let onShare: () -> Void
    var onPlayerReady: (() -> Void)?

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var progress: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?
    @State private var statusObserver: NSKeyValueObservation?
    @State private var loopObserver: NSObjectProtocol?
    @State private var didUsePreloadedPlayer = false
    @State private var isCleanedUp = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Player
                if let player = player {
                    VideoPlayerRepresentable(player: player)
                        .ignoresSafeArea()
                } else {
                    // Loading placeholder
                    Rectangle()
                        .fill(Color.black)
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }

                // Bottom gradient overlay for text/icon accessibility
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0),
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 280)
                }
                .ignoresSafeArea()

                // Overlay Controls
                VStack {
                    Spacer()

                    HStack(alignment: .bottom) {
                        // Left side - Video info
                        VStack(alignment: .leading, spacing: 8) {
                            // Character badge(s)
                            CharacterBadgesView(characterIds: video.allCharacters)

                            // Title
                            Text(video.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Above tab bar

                        Spacer()

                        // Right side - Action buttons
                        VStack(spacing: 20) {
                            // Like button
                            Button(action: onLike) {
                                VStack(spacing: 4) {
                                    Image(systemName: video.isLiked ? "heart.fill" : "heart")
                                        .font(.title)
                                        .foregroundStyle(video.isLiked ? .red : .white)

                                    Text(formatCount(video.likes))
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                }
                            }

                            // Share button
                            Button(action: onShare) {
                                VStack(spacing: 4) {
                                    Image(systemName: "arrowshape.turn.up.right.fill")
                                        .font(.title)
                                        .foregroundStyle(.white)

                                    Text("Share")
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                }
                            }

                            // Views count
                            VStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.7))

                                Text(formatCount(video.views))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding(.trailing)
                        .padding(.bottom, 100) // Above tab bar
                    }

                    // Progress bar
                    GeometryReader { progressGeometry in
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(height: 3)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: progressGeometry.size.width * progress, height: 3)
                            }
                    }
                    .frame(height: 3)
                }

                // Play/Pause overlay
                if showControls && !isPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .background(Color.black)
            .contentShape(Rectangle())
            .onTapGesture {
                togglePlayPause()
            }
        }
        .onAppear {
            setupPlayer()
            if isActive {
                play()
            }
        }
        .onDisappear {
            pause()
            cleanup()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                play()
            } else {
                pause()
            }
        }
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        // Use preloaded player if available (for instant first video playback)
        if let preloadedPlayer = preloadedPlayer, !didUsePreloadedPlayer {
            didUsePreloadedPlayer = true
            setupWithExistingPlayer(preloadedPlayer)
            // Preloaded player is already ready, notify immediately
            onPlayerReady?()
            return
        }

        guard let url = video.playbackURL else { return }

        // Configure audio session for video playback (enables audio even in silent mode)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }

        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.isMuted = false

        // Observe player item status to know when video is ready to play
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak playerItem] item, _ in
            guard let playerItem = playerItem else { return }
            DispatchQueue.main.async {
                if playerItem.status == .readyToPlay {
                    self.onPlayerReady?()
                    self.statusObserver?.invalidate()
                    self.statusObserver = nil
                }
            }
        }

        setupLoopingAndProgress(for: newPlayer, playerItem: playerItem)
        player = newPlayer
    }

    /// Set up an existing (preloaded) player with looping and progress tracking
    private func setupWithExistingPlayer(_ existingPlayer: AVPlayer) {
        guard let playerItem = existingPlayer.currentItem else { return }

        setupLoopingAndProgress(for: existingPlayer, playerItem: playerItem)
        player = existingPlayer
    }

    /// Configure looping and progress observer for a player
    private func setupLoopingAndProgress(for newPlayer: AVPlayer, playerItem: AVPlayerItem) {
        // Loop video - store observer reference for cleanup
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }

        // Time observer for progress
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            // Skip updates if view has been cleaned up
            guard !self.isCleanedUp else { return }

            guard let itemDuration = newPlayer.currentItem?.duration,
                  itemDuration.isValid,
                  !itemDuration.isIndefinite else { return }

            let durationSeconds = CMTimeGetSeconds(itemDuration)
            let currentSeconds = CMTimeGetSeconds(time)
            let newProgress = durationSeconds > 0 ? currentSeconds / durationSeconds : 0

            self.duration = durationSeconds
            self.progress = newProgress
        }
    }

    private func play() {
        player?.play()
        isPlaying = true
        showControls = false
    }

    private func pause() {
        player?.pause()
        isPlaying = false
        showControls = true
    }

    private func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func cleanup() {
        isCleanedUp = true

        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }

        statusObserver?.invalidate()
        statusObserver = nil
        player?.pause()
        player = nil
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Character Badges View

/// Displays one or more character avatars with their names
/// For multi-character videos, avatars overlap slightly
struct CharacterBadgesView: View {
    let characterIds: [String]

    private var characters: [JokeCharacter] {
        characterIds.compactMap { JokeCharacter.find(byId: $0) }
    }

    var body: some View {
        if characters.isEmpty {
            EmptyView()
        } else if characters.count == 1, let character = characters.first {
            // Single character - original layout
            HStack(spacing: 6) {
                Image(character.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())

                Text(character.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        } else {
            // Multiple characters - overlapping avatars with combined names
            HStack(spacing: 8) {
                // Overlapping avatars
                HStack(spacing: -10) {
                    ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                        Image(character.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            .zIndex(Double(characters.count - index))
                    }
                }

                // Character names (e.g., "Mr. Funny & Mr. Bad")
                Text(characterNames)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
    }

    private var characterNames: String {
        let names = characters.map { $0.name }
        if names.count == 2 {
            return names.joined(separator: " & ")
        } else {
            return names.joined(separator: ", ")
        }
    }
}

// MARK: - AVPlayer UIKit Wrapper

struct VideoPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
