import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: JokeViewModel
    @State private var searchText = ""

    private var searchResults: [Joke] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return viewModel.jokes.filter { joke in
            joke.setup.lowercased().contains(query) ||
            joke.punchline.lowercased().contains(query)
        }
    }

    var body: some View {
        Group {
            if searchText.isEmpty {
                emptyState
            } else if searchResults.isEmpty {
                noResultsState
            } else {
                resultsList
            }
        }
        .searchable(text: $searchText, prompt: "Search jokes")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Search for Jokes",
            systemImage: "magnifyingglass",
            description: Text("Search by keyword in setup or punchline")
        )
    }

    private var noResultsState: some View {
        ContentUnavailableView.search(text: searchText)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(searchResults) { joke in
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
    }
}

#Preview {
    NavigationStack {
        SearchView(viewModel: JokeViewModel())
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
    }
}
