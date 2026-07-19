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

    /// In-flight semantic ranking task, cancelled when a newer query arrives
    @State private var searchTask: Task<Void, Never>?

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

    /// Performs a hybrid semantic + keyword search and caches matching joke IDs.
    ///
    /// Ranking runs off the main thread (embeddings + cosine similarity) via
    /// `SemanticSearchService`; results are assigned back on the main actor.
    private func performSearch(query: String) {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)

        searchTask?.cancel()

        guard !queryLower.isEmpty else {
            cachedResultIds = []
            return
        }

        let snapshot = viewModel.jokes
        searchTask = Task { @MainActor in
            let ids = await SemanticSearchService.shared.rankedResultIds(for: query, in: snapshot)
            guard !Task.isCancelled else { return }
            cachedResultIds = ids
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
        .searchable(text: $searchText, prompt: "Search jokes by topic or keyword")
        .onAppear {
            // Load the full catalog so search covers every joke (not just the
            // initial feed), and pre-warm embeddings so the first query is fast.
            viewModel.triggerBackgroundLoadIfNeeded()
            let snapshot = viewModel.jokes
            Task { await SemanticSearchService.shared.warmUp(with: snapshot) }
        }
        .onChange(of: searchText) { _, newValue in
            searchTextPublisher.send(newValue)
        }
        .onChange(of: viewModel.jokes.count) { _, _ in
            // Re-search when jokes array changes (e.g., as the catalog streams
            // in) and warm up embeddings for the newly added jokes.
            let newHash = viewModel.jokes.count
            if lastJokesHash != newHash {
                lastJokesHash = newHash
                let snapshot = viewModel.jokes
                Task { await SemanticSearchService.shared.warmUp(with: snapshot) }
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

            Text("Search by topic like \u{201C}food\u{201D} or \u{201C}sports\u{201D} \u{2014} not just exact words.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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
