import SwiftUI

@MainActor
final class JokeViewModel: ObservableObject {
    @Published var jokes: [Joke] = []
    @Published var selectedCategory: JokeCategory? = nil
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var copiedJokeId: UUID?

    /// Tracks initial app launch loading state for skeleton display
    @Published var isInitialLoading = true

    /// Tracks if more jokes are being loaded (for infinite scroll)
    @Published var isLoadingMore = false

    /// Indicates if we're currently offline (showing cached content)
    @Published var isOffline = false

    /// Indicates if we've reached the end and no more jokes are available
    @Published var hasMoreJokes = true

    private let storage = LocalStorageService.shared
    private let api = JokeAPIService.shared
    private var copyTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?

    /// Number of jokes to fetch per batch
    private let batchSize = 6
    /// Number of jokes to fetch per category on initial load
    private let initialLoadPerCategory = 5

    var filteredJokes: [Joke] {
        guard let category = selectedCategory else {
            return jokes
        }
        return jokes.filter { $0.category == category }
    }

    // Jokes that have been rated by the user
    var ratedJokes: [Joke] {
        jokes.filter { $0.userRating != nil }
    }

    // Jokes grouped by rating (1-4 scale)
    var hilariousJokes: [Joke] {
        jokes.filter { $0.userRating == 4 }
    }

    var funnyJokes: [Joke] {
        jokes.filter { $0.userRating == 3 }
    }

    var mehJokes: [Joke] {
        jokes.filter { $0.userRating == 2 }
    }

    var groanJokes: [Joke] {
        jokes.filter { $0.userRating == 1 }
    }

    /// Joke of the Day - deterministically selected based on the current date
    var jokeOfTheDay: Joke? {
        guard !jokes.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % jokes.count
        let sortedJokes = jokes.sorted { $0.id.uuidString < $1.id.uuidString }
        return sortedJokes[index]
    }

    init() {
        loadInitialContent()
    }

    // MARK: - Initial Load

    /// Load content on app start - first from cache/fallback, then fetch from APIs
    private func loadInitialContent() {
        // First, load cached + fallback jokes immediately for instant display
        loadLocalJokes()

        // Then fetch fresh content from APIs in background
        initialLoadTask = Task {
            await fetchInitialAPIContent()
        }
    }

    /// Load jokes from local storage (cached + hardcoded fallback)
    private func loadLocalJokes() {
        let cached = storage.loadAllCachedJokes()
        let fallback = storage.loadHardcodedJokes()

        // Combine: use cached if available, fallback otherwise
        var allJokes: [Joke] = []

        // Add cached jokes first (they're fresher)
        allJokes.append(contentsOf: cached)

        // Add fallback jokes that aren't duplicates
        for joke in fallback {
            if !allJokes.contains(where: { $0.setup == joke.setup }) {
                allJokes.append(joke)
            }
        }

        jokes = allJokes.shuffled()
    }

    /// Fetch initial content from all APIs
    private func fetchInitialAPIContent() async {
        // Check connectivity first
        let isConnected = await api.checkConnectivity()

        if !isConnected {
            // We're offline - mark it and complete initial loading
            isOffline = true
            await completeInitialLoading()
            return
        }

        isOffline = false

        // Fetch jokes from all categories
        let newJokes = await api.fetchInitialJokes(countPerCategory: initialLoadPerCategory)

        guard !Task.isCancelled else { return }

        if !newJokes.isEmpty {
            // Cache the new jokes by category
            let grouped = Dictionary(grouping: newJokes, by: { $0.category })
            for (category, categoryJokes) in grouped {
                storage.saveCachedJokes(categoryJokes, for: category)
            }

            // Add new jokes to our list, avoiding duplicates
            var updatedJokes = jokes
            for joke in newJokes {
                if !updatedJokes.contains(where: { $0.setup == joke.setup }) {
                    updatedJokes.append(joke)
                }
            }
            jokes = updatedJokes.shuffled()
        }

        await completeInitialLoading()
    }

    private func completeInitialLoading() async {
        // Small delay ensures skeleton is briefly visible for smooth transition
        try? await Task.sleep(for: .milliseconds(300))
        isInitialLoading = false
    }

    // MARK: - Refresh (Pull-to-Refresh)

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true

        // Check connectivity
        let isConnected = await api.checkConnectivity()

        if !isConnected {
            isOffline = true
            isRefreshing = false
            return
        }

        isOffline = false

        // Fetch new jokes
        let newJokes = await api.fetchMoreJokes(category: selectedCategory, count: batchSize)

        guard !Task.isCancelled else {
            isRefreshing = false
            return
        }

        if !newJokes.isEmpty {
            // Cache them
            let grouped = Dictionary(grouping: newJokes, by: { $0.category })
            for (category, categoryJokes) in grouped {
                storage.saveCachedJokes(categoryJokes, for: category)
            }

            // Add to beginning of list
            var updatedJokes = jokes
            for joke in newJokes.reversed() {
                if !updatedJokes.contains(where: { $0.setup == joke.setup }) {
                    updatedJokes.insert(joke, at: 0)
                }
            }
            jokes = updatedJokes
        }

        isRefreshing = false
    }

    // MARK: - Infinite Scroll (Load More)

    /// Called when user scrolls near the bottom of the list
    func loadMoreIfNeeded(currentItem: Joke) {
        // Check if we're near the end of the list
        let thresholdIndex = filteredJokes.index(filteredJokes.endIndex, offsetBy: -3, limitedBy: filteredJokes.startIndex) ?? filteredJokes.startIndex

        guard let currentIndex = filteredJokes.firstIndex(where: { $0.id == currentItem.id }),
              currentIndex >= thresholdIndex else {
            return
        }

        loadMore()
    }

    /// Load more jokes (for infinite scroll)
    func loadMore() {
        guard !isLoadingMore && !isRefreshing && hasMoreJokes else { return }

        loadMoreTask?.cancel()
        loadMoreTask = Task {
            await performLoadMore()
        }
    }

    private func performLoadMore() async {
        isLoadingMore = true

        // Check connectivity
        let isConnected = await api.checkConnectivity()

        if !isConnected {
            isOffline = true
            isLoadingMore = false
            return
        }

        isOffline = false

        // Fetch more jokes for current category (or all if no filter)
        let newJokes = await api.fetchMoreJokes(category: selectedCategory, count: batchSize)

        guard !Task.isCancelled else {
            isLoadingMore = false
            return
        }

        if newJokes.isEmpty {
            // No more jokes available from API
            // (In practice, these APIs always return something, but handle edge case)
            hasMoreJokes = true // Keep trying - APIs are random so there's always more
        } else {
            // Cache them
            let grouped = Dictionary(grouping: newJokes, by: { $0.category })
            for (category, categoryJokes) in grouped {
                storage.saveCachedJokes(categoryJokes, for: category)
            }

            // Add to end of list, avoiding duplicates
            var updatedJokes = jokes
            for joke in newJokes {
                if !updatedJokes.contains(where: { $0.setup == joke.setup }) {
                    updatedJokes.append(joke)
                }
            }
            jokes = updatedJokes
        }

        isLoadingMore = false
    }

    // MARK: - Ratings

    func rateJoke(_ joke: Joke, rating: Int) {
        HapticManager.shared.selection()

        if rating == 0 {
            storage.removeRating(for: joke.id)
            if let index = jokes.firstIndex(where: { $0.id == joke.id }) {
                jokes[index].userRating = nil
            }
        } else {
            let clampedRating = min(max(rating, 1), 4)
            storage.saveRating(for: joke.id, rating: clampedRating)
            if let index = jokes.firstIndex(where: { $0.id == joke.id }) {
                jokes[index].userRating = clampedRating
            }
        }
    }

    // MARK: - Sharing

    func shareJoke(_ joke: Joke) {
        HapticManager.shared.success()

        let text = "\(joke.setup)\n\n\(joke.punchline)\n\n— Mr. Funny Jokes"

        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        topVC.present(activityVC, animated: true)
    }

    func copyJoke(_ joke: Joke) {
        HapticManager.shared.success()

        let text = "\(joke.setup)\n\n\(joke.punchline)"
        UIPasteboard.general.string = text

        copiedJokeId = joke.id

        copyTask?.cancel()
        copyTask = Task { [weak self, jokeId = joke.id] in
            do {
                try await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                if self?.copiedJokeId == jokeId {
                    self?.copiedJokeId = nil
                }
            } catch {
                // Task was cancelled
            }
        }
    }

    // MARK: - Category Selection

    func selectCategory(_ category: JokeCategory?) {
        HapticManager.shared.lightTap()
        selectedCategory = category
        hasMoreJokes = true // Reset when changing categories
    }
}
