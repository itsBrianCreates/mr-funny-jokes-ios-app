import SwiftUI

struct JokeFeedView: View {
    @ObservedObject var viewModel: JokeViewModel

    /// Show Joke of the Day only when viewing "All" jokes (no category filter)
    private var showJokeOfTheDay: Bool {
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
        ScrollView {
            LazyVStack(spacing: 16) {
                // Joke of the Day hero section (only when "All" is selected)
                if showJokeOfTheDay, let jokeOfTheDay = viewModel.jokeOfTheDay {
                    VStack(alignment: .leading, spacing: 12) {
                        JokeOfTheDayView(
                            joke: jokeOfTheDay,
                            isCopied: viewModel.copiedJokeId == jokeOfTheDay.id,
                            onShare: { viewModel.shareJoke(jokeOfTheDay) },
                            onCopy: { viewModel.copyJoke(jokeOfTheDay) },
                            onRate: { rating in viewModel.rateJoke(jokeOfTheDay, rating: rating) }
                        )
                    }

                    // Divider between hero and feed
                    HStack {
                        VStack { Divider() }
                        Text("More Jokes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        VStack { Divider() }
                    }
                    .padding(.vertical, 8)
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
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .refreshable {
            await viewModel.refresh()
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
