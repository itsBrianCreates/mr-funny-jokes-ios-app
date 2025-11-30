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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Invisible anchor at the top for scroll-to-top functionality
                    Color.clear
                        .frame(height: 0)
                        .id("top")

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
            .onChange(of: viewModel.selectedCategory) {
                // Scroll to top when the filter category changes
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
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
