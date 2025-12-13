import SwiftUI

/// Detail view showing the Weekly Top 10 countdown with pill tabs for switching between Hilarious and Horrible
struct WeeklyTopTenDetailView: View {
    @ObservedObject var viewModel: WeeklyRankingsViewModel
    @ObservedObject var jokeViewModel: JokeViewModel
    @State var selectedType: RankingType

    var body: some View {
        VStack(spacing: 0) {
            // Pill tab selector
            PillTabSelector(selectedType: $selectedType)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // Content
            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.hasDataFor(type: selectedType) {
                CountdownList(
                    rankedJokes: viewModel.getJokesForCountdown(type: selectedType),
                    rankingType: selectedType,
                    jokeViewModel: jokeViewModel
                )
            } else {
                EmptyStateView(type: selectedType)
            }
        }
        .navigationTitle("Weekly Top 10")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Pill Tab Selector

/// Apple Fitness-style pill tab selector
struct PillTabSelector: View {
    @Binding var selectedType: RankingType

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RankingType.allCases) { type in
                PillTab(
                    type: type,
                    isSelected: selectedType == type
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedType = type
                    }
                    HapticManager.shared.selection()
                }
            }
        }
        .padding(4)
        .background(
            Color(.systemGray5),
            in: Capsule()
        )
    }
}

/// Individual pill tab button
struct PillTab: View {
    let type: RankingType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(type.emoji)
                    .font(.subheadline)
                Text(type.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color(.systemBackground)
                    : Color.clear,
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Countdown List

/// The scrollable list of ranked jokes, displayed from #10 to #1
struct CountdownList: View {
    let rankedJokes: [RankedJoke]
    let rankingType: RankingType
    @ObservedObject var jokeViewModel: JokeViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(rankedJokes) { rankedJoke in
                    RankedJokeCard(
                        rankedJoke: rankedJoke,
                        rankingType: rankingType,
                        isCopied: jokeViewModel.copiedJokeId == rankedJoke.joke.id,
                        onShare: { jokeViewModel.shareJoke(rankedJoke.joke) },
                        onCopy: { jokeViewModel.copyJoke(rankedJoke.joke) },
                        onRate: { rating in jokeViewModel.rateJoke(rankedJoke.joke, rating: rating) }
                    )
                }

                // Bottom padding for scroll
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal)
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
            Text("Be one of the first to rate jokes this week!\nJokes rated \(type == .hilarious ? "5 stars" : "1 star") will appear here.")
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
        WeeklyTopTenDetailView(
            viewModel: WeeklyRankingsViewModel(),
            jokeViewModel: JokeViewModel(),
            selectedType: .hilarious
        )
    }
}

#Preview("Empty State") {
    EmptyStateView(type: .hilarious)
}

#Preview("Pill Tabs") {
    VStack {
        PillTabSelector(selectedType: .constant(.hilarious))
            .padding()
        Spacer()
    }
}
