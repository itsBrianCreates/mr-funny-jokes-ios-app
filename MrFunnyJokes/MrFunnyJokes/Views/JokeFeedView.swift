import SwiftUI

struct JokeFeedView: View {
    @ObservedObject var viewModel: JokeViewModel
    @StateObject private var rankingsViewModel = WeeklyRankingsViewModel()
    let onCharacterTap: (JokeCharacter) -> Void

    /// State for navigating to Weekly Top 10 detail view
    @State private var weeklyTopTenDestination: RankingType?

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

    /// Show YouTube promo card only when viewing "All" jokes
    private var showYouTubePromo: Bool {
        viewModel.selectedCategory == nil
    }

    /// Show Weekly Top 10 carousel only when viewing "All" jokes
    private var showWeeklyTopTen: Bool {
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

                    // Weekly Top 10 carousel (only when "All" is selected)
                    if showWeeklyTopTen {
                        WeeklyTopTenCarouselView(
                            viewModel: rankingsViewModel,
                            onCardTap: { type in
                                weeklyTopTenDestination = type
                            }
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
                            // Track impression for feed freshness
                            viewModel.markJokeImpression(joke)
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

                    // Load More button (when not loading and more jokes available)
                    if !viewModel.isLoadingMore && viewModel.hasMoreJokes && !feedJokes.isEmpty {
                        LoadMoreButton {
                            viewModel.loadMore()
                        }
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
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoadingMore)
            .navigationDestination(item: $weeklyTopTenDestination) { type in
                WeeklyTopTenDetailView(
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
