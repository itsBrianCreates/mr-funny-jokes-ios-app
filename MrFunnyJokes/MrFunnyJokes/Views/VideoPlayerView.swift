import SwiftUI
import AVKit
import AVFoundation

/// A full-screen video player view for TikTok-style vertical video playback
struct VideoPlayerView: View {
    let video: Video
    let isActive: Bool
    let onLike: () -> Void
    let onShare: () -> Void

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var progress: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?

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

                // Overlay Controls
                VStack {
                    Spacer()

                    HStack(alignment: .bottom) {
                        // Left side - Video info
                        VStack(alignment: .leading, spacing: 8) {
                            // Character badge
                            if let character = JokeCharacter.find(byId: video.character) {
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
                            }

                            // Title
                            Text(video.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            // Description (if present)
                            if !video.description.isEmpty {
                                Text(video.description)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(2)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)

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
                        .padding(.bottom, 16)
                    }

                    // Progress bar
                    GeometryReader { progressGeometry in
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
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

        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }

        // Time observer for progress
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let duration = newPlayer.currentItem?.duration,
                  duration.isValid,
                  !duration.isIndefinite else { return }

            let durationSeconds = CMTimeGetSeconds(duration)
            let currentSeconds = CMTimeGetSeconds(time)

            self.duration = durationSeconds
            self.progress = durationSeconds > 0 ? currentSeconds / durationSeconds : 0
        }

        player = newPlayer
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
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
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
