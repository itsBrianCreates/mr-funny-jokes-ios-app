import SwiftUI

/// Detail view showing the All-Time Top 10 countdown with pill tabs for switching between Hilarious and Horrible
struct AllTimeTopTenDetailView: View {
    @ObservedObject var viewModel: AllTimeRankingsViewModel
    @ObservedObject var jokeViewModel: JokeViewModel
    @State var selectedType: RankingType

    var body: some View {
        ScrollView {
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

                // Content
                if viewModel.isLoading {
                    LoadingView()
                        .frame(minHeight: 300)
                } else if viewModel.hasDataFor(type: selectedType) {
                    ForEach(viewModel.getJokesForCountdown(type: selectedType)) { rankedJoke in
                        RankedJokeCard(
                            rankedJoke: rankedJoke,
                            rankingType: selectedType,
                            isCopied: jokeViewModel.copiedJokeId == rankedJoke.joke.id,
                            onShare: { jokeViewModel.shareJoke(rankedJoke.joke) },
                            onCopy: { jokeViewModel.copyJoke(rankedJoke.joke) },
                            onRate: { rating in jokeViewModel.rateJoke(rankedJoke.joke, rating: rating) },
                            onSave: { jokeViewModel.saveJoke(rankedJoke.joke) }
                        )
                    }
                } else {
                    EmptyStateView(type: selectedType)
                        .frame(minHeight: 300)
                }

                // Bottom padding for scroll
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal)
        }
        .navigationTitle("All-Time Top 10")
        .navigationBarTitleDisplayMode(.large)
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
