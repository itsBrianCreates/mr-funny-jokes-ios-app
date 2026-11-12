import SwiftUI

/// Detail view showing the All-Time Top 10 countdown: a segmented control switches between
/// Hilarious and Horrible on compact widths; wide windows show both lists side by side
struct AllTimeTopTenDetailView: View {
    @ObservedObject var viewModel: AllTimeRankingsViewModel
    @ObservedObject var jokeViewModel: JokeViewModel
    @State var selectedType: RankingType

    /// At this width both lists show side by side instead of behind a segmented control
    /// (iPhone Duo inner display, landscape Max). Matches the feed's list-detail threshold.
    private let sideBySideMinWidth: CGFloat = 700

    @State private var containerWidth: CGFloat = 0

    private var showsBothLists: Bool {
        containerWidth >= sideBySideMinWidth
    }

    var body: some View {
        ScrollView {
            Group {
                if showsBothLists {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(RankingType.allCases) { type in
                            LazyVStack(spacing: 12) {
                                Text("\(type.emoji) \(type.rawValue)")
                                    .font(.title3.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)

                                rankingList(for: type)
                            }
                        }
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        // Segmented control
                        Picker("Category", selection: $selectedType) {
                            ForEach(RankingType.allCases) { type in
                                Text("\(type.emoji) \(type.rawValue)").tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                        rankingList(for: selectedType)
                    }
                }
            }
            .padding(.horizontal)
            // Bottom padding for scroll
            .padding(.bottom, 32)
        }
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            containerWidth = width
        }
        .navigationTitle("All-Time Top 10")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Countdown cards for one ranking, or its loading / empty state
    @ViewBuilder
    private func rankingList(for type: RankingType) -> some View {
        if viewModel.isLoading {
            LoadingView()
                .frame(minHeight: 300)
        } else if viewModel.hasDataFor(type: type) {
            ForEach(viewModel.getJokesForCountdown(type: type)) { rankedJoke in
                RankedJokeCard(
                    rankedJoke: rankedJoke,
                    rankingType: type,
                    isCopied: jokeViewModel.copiedJokeId == rankedJoke.joke.id,
                    onShare: { jokeViewModel.shareJoke(rankedJoke.joke) },
                    onCopy: { jokeViewModel.copyJoke(rankedJoke.joke) },
                    onRate: { rating in jokeViewModel.rateJoke(rankedJoke.joke, rating: rating) },
                    onSave: { jokeViewModel.saveJoke(rankedJoke.joke) }
                )
            }
        } else {
            EmptyStateView(type: type)
                .frame(minHeight: 300)
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading rankings...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let type: RankingType

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Large emoji
            Text(type.emoji)
                .font(.system(size: 64))

            // Title
            Text("No \(type.rawValue) Jokes Yet")
                .font(.title2.weight(.semibold))

            // Description
            Text("Be one of the first to rate jokes!\nJokes rated \(type == .hilarious ? "Hilarious 😂" : "Horrible 🫠") will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("With Data") {
    NavigationStack {
        AllTimeTopTenDetailView(
            viewModel: AllTimeRankingsViewModel(),
            jokeViewModel: JokeViewModel(),
            selectedType: .hilarious
        )
    }
}

#Preview("Empty State") {
    EmptyStateView(type: .hilarious)
}
