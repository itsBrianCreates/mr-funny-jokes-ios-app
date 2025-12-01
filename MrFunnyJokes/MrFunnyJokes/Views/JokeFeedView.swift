import SwiftUI

struct JokeFeedView: View {
    @ObservedObject var viewModel: JokeViewModel

    /// Unique identifier for the top anchor - used for reliable scroll-to-top
    private let topAnchorID = "feed-top-anchor"

    /// Show Joke of the Day only when viewing "All" jokes (no category filter)
    private var showJokeOfTheDay: Bool {
        viewModel.selectedCategory == nil
    }

    /// Show YouTube promo card only when viewing "All" jokes
    private var showYouTubePromo: Bool {
        viewModel.selectedCategory == nil
    }

    /// Position to insert YouTube promo card (after 4 jokes, so 5th item)
    private let youtubePromoPosition = 4

    /// Filtered jokes excluding the Joke of the Day to avoid duplicates
    private var feedJokes: [Joke] {
        guard showJokeOfTheDay, let jotd = viewModel.jokeOfTheDay else {
            return viewModel.filteredJokes
        }
        return viewModel.filteredJokes.filter { $0.id != jotd.id }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Invisible top anchor for reliable scroll-to-top
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchorID)

                    // Offline indicator banner
                    if viewModel.isOffline {
                        OfflineBannerView()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Joke of the Day hero section (only when "All" is selected)
                    if showJokeOfTheDay, let jokeOfTheDay = viewModel.jokeOfTheDay {
                        JokeOfTheDayView(
                            joke: jokeOfTheDay,
                            isCopied: viewModel.copiedJokeId == jokeOfTheDay.id,
                            onShare: { viewModel.shareJoke(jokeOfTheDay) },
                            onCopy: { viewModel.copyJoke(jokeOfTheDay) },
                            onRate: { rating in viewModel.rateJoke(jokeOfTheDay, rating: rating) }
                        )
                    }

                    // Regular joke feed with YouTube promo card inserted
                    ForEach(Array(feedJokes.enumerated()), id: \.element.id) { index, joke in
                        // Insert YouTube promo card at position 4 (5th item)
                        if showYouTubePromo && index == youtubePromoPosition {
                            YouTubePromoCardView()
                        }

                        JokeCardView(
                            joke: joke,
                            isCopied: viewModel.copiedJokeId == joke.id,
                            onShare: { viewModel.shareJoke(joke) },
                            onCopy: { viewModel.copyJoke(joke) },
                            onRate: { rating in viewModel.rateJoke(joke, rating: rating) }
                        )
                        .onAppear {
                            // Trigger load more when this joke appears
                            viewModel.loadMoreIfNeeded(currentItem: joke)
                        }
                    }

                    // If we have fewer jokes than the promo position, show promo at the end
                    if showYouTubePromo && feedJokes.count > 0 && feedJokes.count <= youtubePromoPosition {
                        YouTubePromoCardView()
                    }

                    // Loading more indicator (skeleton cards at bottom)
                    if viewModel.isLoadingMore {
                        LoadingMoreView()
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onChange(of: viewModel.selectedCategory) {
                // Scroll to top when filter changes
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(topAnchorID, anchor: .top)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isOffline)
        }
    }
}

// MARK: - Offline Banner View

struct OfflineBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("You're offline")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text("Showing saved jokes")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Loading More View (Skeleton cards at bottom)

struct LoadingMoreView: View {
    var body: some View {
        VStack(spacing: 16) {
            SkeletonCardView(lineCount: 2, lastLineWidth: 0.6)
            SkeletonCardView(lineCount: 1, lastLineWidth: 0.8)
        }
    }
}

#Preview {
    NavigationStack {
        JokeFeedView(viewModel: JokeViewModel())
            .navigationTitle("All Jokes")
            .navigationBarTitleDisplayMode(.large)
    }
}
