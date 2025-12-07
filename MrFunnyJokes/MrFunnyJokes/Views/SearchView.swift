import SwiftUI
import Combine

struct SearchView: View {
    @ObservedObject var viewModel: JokeViewModel
    @State private var searchText = ""
    @State private var animateIcon = false
    @State private var searchResults: [Joke] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private let firestoreService = FirestoreService.shared

    var body: some View {
        Group {
            if searchText.isEmpty {
                emptyState
            } else if isSearching {
                searchingState
            } else if searchResults.isEmpty {
                noResultsState
            } else {
                resultsList
            }
        }
        .searchable(text: $searchText, prompt: "Search jokes")
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
    }

    /// Performs search with debouncing to avoid excessive API calls
    private func performSearch(query: String) {
        // Cancel any pending search
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        // Debounce: wait 300ms before searching
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            do {
                let results = try await firestoreService.searchJokes(searchText: query, limit: 50)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    // On error, fall back to local search
                    let queryLower = query.lowercased()
                    searchResults = viewModel.jokes.filter { joke in
                        joke.setup.lowercased().contains(queryLower) ||
                        joke.punchline.lowercased().contains(queryLower) ||
                        (joke.tags?.contains { $0.lowercased().contains(queryLower) } ?? false)
                    }
                    isSearching = false
                }
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

    private var searchingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
