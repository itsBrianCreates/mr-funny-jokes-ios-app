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

    /// Feed columns adapt to available width: one column on a closed iPhone,
    /// two or more on wide windows (iPhone Duo inner display, landscape Max, Mirroring).
    /// Width-based rather than size-class-based so it reflows during live resizing.
    private let feedColumns = [GridItem(.adaptive(minimum: 340), spacing: 16, alignment: .top)]

    /// Joke currently anchored at the top of the viewport. Keeps the reader's place
    /// when the column count changes (fold/unfold, rotation, window resize).
    @State private var scrollPosition = ScrollPosition(idType: UUID.self)

    /// True while the header is in view, so a width change leaves the user at the top
    /// instead of snapping to the first joke card.
    @State private var isNearTop = true

    /// Where the reader settled after their last scroll. Captured only when a scroll comes
    /// to rest, because a resize rewrites `scrollPosition` from the stale raw offset before
    /// the width-change handler runs.
    @State private var readingAnchorId: UUID?

    /// Joke shown in the detail pane or sheet. Stored as an ID so ratings and saves
    /// always read fresh view-model data.
    @State private var selectedJokeId: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            JokeListDetailView(viewModel: viewModel, selectedJokeId: $selectedJokeId) { isSplit in
                feedScrollView(proxy: proxy, isSplit: isSplit)
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

    /// The scrolling feed: full-width header, joke grid, footer
    private func feedScrollView(proxy: ScrollViewProxy, isSplit: Bool) -> some View {
        ScrollView {
            LazyVGrid(columns: feedColumns, spacing: 16) {
                Section {
                    // Regular joke feed
                    ForEach(feedJokes) { joke in
                        JokeCardView(
                            joke: joke,
                            isCopied: viewModel.copiedJokeId == joke.id,
                            onShare: { viewModel.shareJoke(joke) },
                            onCopy: { viewModel.copyJoke(joke) },
                            onRate: { rating in viewModel.rateJoke(joke, rating: rating) },
                            onSave: { viewModel.saveJoke(joke) },
                            onView: { viewModel.markJokeViewed(joke) },
                            onSelect: { selectedJokeId = joke.id },
                            isSelected: isSplit && selectedJokeId == joke.id
                        )
                        .onAppear {
                            // Track impression for feed freshness
                            viewModel.markJokeImpression(joke)
                            // Trigger infinite scroll loading when approaching end
                            viewModel.loadMoreIfNeeded(currentItem: joke)
                        }
                    }
                } header: {
                    feedHeader(isSplit: isSplit)
                } footer: {
                    feedFooter
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollPosition($scrollPosition, anchor: .top)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top < 200
        } action: { _, nearTop in
            isNearTop = nearTop
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            // Only user-driven scrolls move the anchor; resizes and programmatic
            // scrolls settle through other phases and must not overwrite it.
            guard newPhase == .idle,
                  oldPhase == .interacting || oldPhase == .decelerating else { return }
            readingAnchorId = isNearTop ? nil : scrollPosition.viewID(type: UUID.self)
        }
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { _ in
            // The scroll view keeps its raw offset across a width change, which lands
            // on a different joke once the column count changes. Re-anchor explicitly.
            guard let anchorId = readingAnchorId else { return }
            scrollPosition.scrollTo(id: anchorId, anchor: .top)
            // Lazy rows above the anchor are only estimated on the first pass;
            // repeat once the new layout has measured them.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                scrollPosition.scrollTo(id: anchorId, anchor: .top)
            }
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
    }

    /// Full-width content above the joke grid
    @ViewBuilder
    private func feedHeader(isSplit: Bool) -> some View {
        VStack(spacing: 16) {
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
                    onRate: { rating in viewModel.rateJoke(jokeOfTheDay, rating: rating) },
                    onSave: { viewModel.saveJoke(jokeOfTheDay) },
                    onSelect: { selectedJokeId = jokeOfTheDay.id },
                    isSelected: isSplit && selectedJokeId == jokeOfTheDay.id
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
        }
    }

    /// Full-width content below the joke grid
    @ViewBuilder
    private var feedFooter: some View {
        VStack(spacing: 16) {
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
