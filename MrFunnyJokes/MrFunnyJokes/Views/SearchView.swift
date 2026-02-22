import SwiftUI
import Combine

struct SearchView: View {
    @ObservedObject var viewModel: JokeViewModel
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var animateIcon = false
    @State private var lastJokesHash: Int = 0

    /// Cached firestoreIds of matching jokes (stable across refreshes)
    @State private var cachedResultIds: [String] = []

    /// Publisher for debouncing search input
    private let searchTextPublisher = PassthroughSubject<String, Never>()

    /// Returns fresh jokes from viewModel.jokes matching the cached IDs
    /// This ensures ratings and other updates are reflected immediately
    private var searchResults: [Joke] {
        guard !cachedResultIds.isEmpty else { return [] }

        // Create a lookup dictionary for O(1) access
        let jokesById = Dictionary(
            viewModel.jokes.compactMap { joke -> (String, Joke)? in
                guard let id = joke.firestoreId else { return nil }
                return (id, joke)
            },
            uniquingKeysWith: { first, _ in first }
        )

        // Return jokes in the original search order, with fresh data
        return cachedResultIds.compactMap { jokesById[$0] }
    }

    /// Performs the actual search and caches matching joke IDs
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            cachedResultIds = []
            return
        }

        let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !queryLower.isEmpty else {
            cachedResultIds = []
            return
        }

        // Filter and sort jokes, then extract their firestoreIds
        cachedResultIds = viewModel.jokes.filter { joke in
            joke.setup.lowercased().contains(queryLower) ||
            joke.punchline.lowercased().contains(queryLower) ||
            joke.character?.lowercased().contains(queryLower) == true ||
            (joke.tags?.contains { $0.lowercased().contains(queryLower) } ?? false)
        }
        .sorted { $0.popularityScore > $1.popularityScore }
        .compactMap { $0.firestoreId }
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
        // Listen for rating changes from other ViewModels (e.g., CharacterDetailViewModel)
        // This ensures search results refresh when ratings are made elsewhere
        .onReceive(NotificationCenter.default.publisher(for: .jokeRatingDidChange)) { _ in
            if !debouncedSearchText.isEmpty {
                performSearch(query: debouncedSearchText)
            }
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
                        onRate: { rating in viewModel.rateJoke(joke, rating: rating) },
                        onSave: { viewModel.saveJoke(joke) },
                        onView: {}
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
