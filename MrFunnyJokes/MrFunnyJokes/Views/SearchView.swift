import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: JokeViewModel
    @State private var searchText = ""
    @State private var animateIcon = false

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
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
                .scaleEffect(animateIcon ? 1.0 : 0.8)
                .rotationEffect(.degrees(animateIcon ? 0 : -10))
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0)
                        .delay(0.1),
                    value: animateIcon
                )

            Text("Looking for a laugh?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            animateIcon = true
        }
        .onDisappear {
            animateIcon = false
        }
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
