import SwiftUI

/// TikTok-style vertical video feed with swipe navigation
struct VideoFeedView: View {
    @ObservedObject var viewModel: VideoViewModel

    var body: some View {
        GeometryReader { geometry in
            if viewModel.isInitialLoading {
                // Loading state
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)

                        Text("Loading videos...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
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
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                            VideoPlayerView(
                                video: video,
                                isActive: viewModel.currentIndex == index,
                                onLike: {
                                    viewModel.toggleLike(video)
                                },
                                onShare: {
                                    viewModel.shareVideo(video)
                                }
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
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
    @StateObject private var viewModel = VideoViewModel()
    @State private var showingCharacterFilter = false

    var body: some View {
        ZStack(alignment: .top) {
            VideoFeedView(viewModel: viewModel)

            // Top bar overlay
            VStack {
                HStack {
                    // Character filter button
                    Menu {
                        Button {
                            viewModel.selectCharacter(nil)
                        } label: {
                            Label("All Characters", systemImage: "sparkles")
                        }

                        Divider()

                        ForEach(JokeCharacter.allCharacters) { character in
                            Button {
                                viewModel.selectCharacter(character.id)
                            } label: {
                                Label(character.name, systemImage: "person.fill")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let characterId = viewModel.selectedCharacter,
                               let character = JokeCharacter.find(byId: characterId) {
                                Image(character.imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())

                                Text(character.name)
                                    .font(.subheadline.weight(.medium))
                            } else {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.title3)

                                Text("All")
                                    .font(.subheadline.weight(.medium))
                            }

                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    // Refresh button
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.5 : 1)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()
            }

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
    }
}
