import SwiftUI

// MARK: - Video Loading View

/// Loading view with animated character wave for the video feed
struct VideoLoadingView: View {
    let characters = JokeCharacter.allCharacters

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated character circles with wave effect
                TimelineView(.animation(minimumInterval: 0.05)) { timeline in
                    HStack(spacing: 10) {
                        ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                            VideoLoadingCharacterCircle(
                                character: character,
                                index: index,
                                date: timeline.date
                            )
                        }
                    }
                }

                Text("Loading videos...")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

/// A smaller character circle for video loading that bounces in a wave pattern
private struct VideoLoadingCharacterCircle: View {
    let character: JokeCharacter
    let index: Int
    let date: Date

    private let circleSize: CGFloat = 44

    /// Calculate bounce offset based on time and index for wave effect
    private var bounceOffset: CGFloat {
        let timeInterval = date.timeIntervalSinceReferenceDate
        let phase = timeInterval * 4 + Double(index) * 0.8
        return sin(phase) * 6
    }

    /// Scale pulse synchronized with bounce
    private var pulseScale: CGFloat {
        let timeInterval = date.timeIntervalSinceReferenceDate
        let phase = timeInterval * 4 + Double(index) * 0.8
        return 1.0 + sin(phase) * 0.04
    }

    var body: some View {
        ZStack {
            // Outer glow effect
            Circle()
                .fill(character.color.opacity(0.3))
                .frame(width: circleSize + 6, height: circleSize + 6)
                .blur(radius: 3)
                .scaleEffect(pulseScale)

            // Character image
            Image(character.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: circleSize, height: circleSize)
                .clipShape(Circle())
        }
        .overlay(
            Circle()
                .strokeBorder(character.color.opacity(0.5), lineWidth: 2)
                .frame(width: circleSize, height: circleSize)
        )
        .shadow(color: character.color.opacity(0.4), radius: 6, y: 3)
        .offset(y: bounceOffset)
        .scaleEffect(pulseScale)
    }
}

// MARK: - Video Feed View

/// TikTok-style vertical video feed with swipe navigation
struct VideoFeedView: View {
    @ObservedObject var viewModel: VideoViewModel

    /// Show loading screen until videos are fetched AND first video is ready to play
    private var shouldShowLoading: Bool {
        viewModel.isInitialLoading || (!viewModel.videos.isEmpty && !viewModel.isFirstVideoReady)
    }

    var body: some View {
        GeometryReader { geometry in
            if shouldShowLoading {
                // Loading state with character animation
                VideoLoadingView()
            } else if viewModel.videos.isEmpty {
                // Empty state
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 16) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.5))

                        Text("No videos yet")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.white)

                        Text("Check back soon for new content!")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))

                        Button {
                            Task {
                                await viewModel.refresh()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.accessibleYellow)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                }
            } else {
                // Video feed - vertical paging ScrollView
                // Use full screen bounds for true fullscreen video experience
                let screenBounds = UIScreen.main.bounds
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                            VideoPlayerView(
                                video: video,
                                isActive: viewModel.currentIndex == index,
                                preloadedPlayer: index == 0 ? viewModel.consumePreloadedPlayer(for: video.firestoreId) : nil,
                                onLike: {
                                    viewModel.toggleLike(video)
                                },
                                onShare: {
                                    viewModel.shareVideo(video)
                                },
                                onPlayerReady: index == 0 ? {
                                    viewModel.firstVideoDidBecomeReady()
                                } : nil
                            )
                            .frame(width: screenBounds.width, height: screenBounds.height)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $viewModel.scrolledIndex)
                .ignoresSafeArea()
                .onChange(of: viewModel.scrolledIndex) { _, newIndex in
                    if let newIndex = newIndex {
                        viewModel.videoDidAppear(at: newIndex)
                    }
                }

                // Loading more indicator at bottom
                if viewModel.isLoadingMore {
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("Loading more...")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .background(Color.black)
    }
}

// MARK: - Videos Tab Container

/// Container view for the Videos tab with navigation
struct VideosTabView: View {
    @ObservedObject var viewModel: VideoViewModel

    var body: some View {
        ZStack(alignment: .top) {
            VideoFeedView(viewModel: viewModel)
                .ignoresSafeArea()

            // Offline banner
            if viewModel.isOffline {
                VStack {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("You're offline")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(.top, 60)

                    Spacer()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
