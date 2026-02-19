import SwiftUI

struct JokeFeedView: View {
    @ObservedObject var viewModel: JokeViewModel
    @StateObject private var rankingsViewModel = AllTimeRankingsViewModel()
    let onCharacterTap: (JokeCharacter) -> Void

    /// State for navigating to All-Time Top 10 detail view
    @State private var allTimeTopTenDestination: RankingType?

    /// Persistent state for YouTube promo dismissal
    @AppStorage("youtubePromoDismissed") private var youtubePromoDismissed = false

    /// Unique identifier for the top anchor - used for reliable scroll-to-top
    private let topAnchorID = "feed-top-anchor"

    /// Show character carousel only when viewing "All" jokes (no category filter)
    private var showCharacterCarousel: Bool {
        viewModel.selectedCategory == nil
    }

    /// Show Joke of the Day only when viewing "All" jokes (no category filter)
    private var showJokeOfTheDay: Bool {
        viewModel.selectedCategory == nil
    }

    /// Show YouTube promo card only when viewing "All" jokes and not dismissed
    private var showYouTubePromo: Bool {
        viewModel.selectedCategory == nil && !youtubePromoDismissed
    }

    /// Show All-Time Top 10 carousel only when viewing "All" jokes
    private var showAllTimeTopTen: Bool {
        viewModel.selectedCategory == nil
    }


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

                    // Character carousel (only when "All" is selected)
                    if showCharacterCarousel {
                        CharacterCarouselView(onCharacterTap: onCharacterTap)
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
                        .onAppear {
                            viewModel.markJokeImpression(jokeOfTheDay)
                        }
                    }

                    // All-Time Top 10 carousel (only when "All" is selected)
                    if showAllTimeTopTen {
                        AllTimeTopTenCarouselView(
                            viewModel: rankingsViewModel,
                            onCardTap: { type in
                                allTimeTopTenDestination = type
                            }
                        )
                    }

                    // YouTube promo card (only when "All" is selected and not dismissed)
                    if showYouTubePromo {
                        YouTubePromoCardView(onDismiss: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                youtubePromoDismissed = true
                            }
                        })
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    }

                    // Regular joke feed
                    ForEach(feedJokes) { joke in
                        JokeCardView(
                            joke: joke,
                            isCopied: viewModel.copiedJokeId == joke.id,
                            onShare: { viewModel.shareJoke(joke) },
                            onCopy: { viewModel.copyJoke(joke) },
                            onRate: { rating in viewModel.rateJoke(joke, rating: rating) }
                        )
                        .onAppear {
                            // Track impression for feed freshness
                            viewModel.markJokeImpression(joke)
                            // Trigger infinite scroll loading when approaching end
                            viewModel.loadMoreIfNeeded(currentItem: joke)
                        }
                    }

                    // Loading more indicator (skeleton cards at bottom)
                    if viewModel.isLoadingMore {
                        LoadingMoreView()
                            .transition(.opacity)
                    }

                    // End of feed message (when no more jokes)
                    if !viewModel.hasMoreJokes && !feedJokes.isEmpty {
                        EndOfFeedView()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .refreshable {
                // Full reset per CONTEXT.md
                await viewModel.refresh()
                // Scroll to top after refresh - delay needed for SwiftUI refresh animation to complete
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(topAnchorID, anchor: .top)
                }
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
            .navigationDestination(item: $allTimeTopTenDestination) { type in
                AllTimeTopTenDetailView(
                    viewModel: rankingsViewModel,
                    jokeViewModel: viewModel,
                    selectedType: type
                )
            }
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

// MARK: - Load More Button

struct LoadMoreButton: View {
    let action: () -> Void

    /// Primary yellow color matching app branding
    private let primaryYellow = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("Load More Jokes")
                    .font(.headline.weight(.semibold))
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(primaryYellow)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}

// MARK: - End of Feed View

struct EndOfFeedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("🎉")
                .font(.largeTitle)
            Text("You've seen all the jokes!")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Check back later for more laughs")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#Preview {
    NavigationStack {
        JokeFeedView(
            viewModel: JokeViewModel(),
            onCharacterTap: { character in
                print("Tapped: \(character.name)")
            }
        )
        .navigationTitle("All Jokes")
        .navigationBarTitleDisplayMode(.large)
    }
}
