import SwiftUI
import Combine

struct SearchView: View {
    @ObservedObject var viewModel: JokeViewModel
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var animateIcon = false
    @State private var cachedResults: [Joke] = []
    @State private var lastJokesHash: Int = 0

    /// Publisher for debouncing search input
    private let searchTextPublisher = PassthroughSubject<String, Never>()

    /// Computed property that returns cached search results
    private var searchResults: [Joke] {
        cachedResults
    }

    /// Performs the actual search and caches results
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            cachedResults = []
            return
        }

        let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !queryLower.isEmpty else {
            cachedResults = []
            return
        }

        cachedResults = viewModel.jokes.filter { joke in
            joke.setup.lowercased().contains(queryLower) ||
            joke.punchline.lowercased().contains(queryLower) ||
            joke.character?.lowercased().contains(queryLower) == true ||
            (joke.tags?.contains { $0.lowercased().contains(queryLower) } ?? false)
        }
        .sorted { $0.popularityScore > $1.popularityScore }
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
        .onChange(of: searchText) { _, newValue in
            searchTextPublisher.send(newValue)
        }
        .onChange(of: viewModel.jokes.count) { _, _ in
            // Re-search when jokes array changes (e.g., after refresh)
            let newHash = viewModel.jokes.count
            if lastJokesHash != newHash {
                lastJokesHash = newHash
                performSearch(query: debouncedSearchText)
            }
        }
        .onReceive(
            searchTextPublisher
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        ) { debouncedValue in
            debouncedSearchText = debouncedValue
            performSearch(query: debouncedValue)
        }
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
