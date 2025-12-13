import SwiftUI

/// Detail view showing the Weekly Top 10 countdown with pill tabs for switching between Hilarious and Horrible
struct WeeklyTopTenDetailView: View {
    @ObservedObject var viewModel: WeeklyRankingsViewModel
    @ObservedObject var jokeViewModel: JokeViewModel
    @State var selectedType: RankingType

    /// Computed date range that uses viewModel data or fallback
    private var dateRange: String {
        if !viewModel.weekDateRange.isEmpty {
            return viewModel.weekDateRange
        }
        // Fallback to current week
        let calendar = Calendar(identifier: .iso8601)
        var easternCalendar = calendar
        easternCalendar.timeZone = TimeZone(identifier: "America/New_York")!

        let now = Date()
        guard let weekInterval = easternCalendar.dateInterval(of: .weekOfYear, for: now) else {
            return "This Week"
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"

        let startMonth = easternCalendar.component(.month, from: weekInterval.start)
        let endMonth = easternCalendar.component(.month, from: weekInterval.end)
        let startMonthStr = monthFormatter.string(from: weekInterval.start)
        let startDayStr = dayFormatter.string(from: weekInterval.start)
        let endDayStr = dayFormatter.string(from: weekInterval.end.addingTimeInterval(-1))

        if startMonth == endMonth {
            return "\(startMonthStr) \(startDayStr) - \(endDayStr)"
        } else {
            let endMonthStr = monthFormatter.string(from: weekInterval.end)
            return "\(startMonthStr) \(startDayStr) - \(endMonthStr) \(endDayStr)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date range subtitle
            Text(dateRange)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 4)

            // Segmented control
            Picker("Category", selection: $selectedType) {
                ForEach(RankingType.allCases) { type in
                    Text("\(type.emoji) \(type.rawValue)").tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
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
