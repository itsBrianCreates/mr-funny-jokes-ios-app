import SwiftUI
import WidgetKit

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
    private let sharedStorage = SharedStorageService.shared
    private let firestoreService = FirestoreService.shared
    private var copyTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?

    /// Number of jokes to fetch per batch
    private let batchSize = 10
    /// Number of jokes to fetch per category on initial load
    private let initialLoadPerCategory = 8

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

    /// The cached joke of the day ID - persisted across app/widget
    @Published private(set) var jokeOfTheDayId: String?

    /// Cached joke data from shared storage (used as fallback if joke not in array)
    private var cachedJokeOfTheDayData: SharedJokeOfTheDay?

    /// Joke of the Day - sourced from shared storage to ensure consistency with widget
    var jokeOfTheDay: Joke? {
        guard let id = jokeOfTheDayId else { return nil }

        // First, try to find the joke in our array
        if let joke = jokes.first(where: { $0.id.uuidString == id }) {
            return joke
        }

        // Fallback: reconstruct from shared storage data
        // This handles the case where the saved joke ID doesn't match any joke in our array
        // (e.g., if the joke was saved with a different UUID)
        if let sharedJoke = cachedJokeOfTheDayData {
            let category = JokeCategory(rawValue: sharedJoke.category ?? "") ?? .dadJoke
            return Joke(
                id: UUID(uuidString: sharedJoke.id) ?? UUID(),
                category: category,
                setup: sharedJoke.setup,
                punchline: sharedJoke.punchline
            )
        }

        return nil
    }

    /// Compute a new joke of the day deterministically based on the current date
    /// This should only be called when we need a NEW joke (new day or first run)
    private func computeNewJokeOfTheDay() -> Joke? {
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

    /// Load jokes from local cache (Firebase jokes only - no hardcoded fallback)
    private func loadLocalJokes() {
        let cached = storage.loadAllCachedJokes()
        jokes = cached.shuffled()

        // Initialize joke of the day - check shared storage first for persistence
        initializeJokeOfTheDay()
    }

    /// Initialize joke of the day from shared storage or compute new one
    /// This ensures the same joke persists for 24 hours across app and widget
    private func initializeJokeOfTheDay() {
        // First, check if we have a valid joke of the day saved from today
        if !sharedStorage.needsUpdate(), let savedJoke = sharedStorage.loadJokeOfTheDay() {
            // Use the saved joke ID - this ensures consistency with widget
            jokeOfTheDayId = savedJoke.id
            // Cache the full joke data for fallback reconstruction
            cachedJokeOfTheDayData = savedJoke
            return
        }

        // No saved joke for today - compute a new one
        guard let newJoke = computeNewJokeOfTheDay() else { return }

        // Save and sync to widget
        jokeOfTheDayId = newJoke.id.uuidString
        saveJokeOfTheDayToWidget(newJoke)

        // Also cache the data locally for fallback
        cachedJokeOfTheDayData = SharedJokeOfTheDay(
            id: newJoke.id.uuidString,
            setup: newJoke.setup,
            punchline: newJoke.punchline,
            category: newJoke.category.rawValue
        )
    }

    /// Save a specific joke as the joke of the day to shared storage
    private func saveJokeOfTheDayToWidget(_ joke: Joke) {
        let sharedJoke = SharedJokeOfTheDay(
            id: joke.id.uuidString,
            setup: joke.setup,
            punchline: joke.punchline,
            category: joke.category.rawValue
        )

        sharedStorage.saveJokeOfTheDay(sharedJoke)
        WidgetCenter.shared.reloadTimelines(ofKind: "JokeOfTheDayWidget")
    }

    /// Fetch initial content from Firestore
    private func fetchInitialAPIContent() async {
        do {
            // Fetch jokes from Firestore
            let newJokes = try await firestoreService.fetchInitialJokes(limit: 24)

            guard !Task.isCancelled else { return }

            isOffline = false

            if !newJokes.isEmpty {
                // Cache the new jokes by category
                let grouped = Dictionary(grouping: newJokes, by: { $0.category })
                for (category, categoryJokes) in grouped {
                    storage.saveCachedJokes(categoryJokes, for: category)
                }

                // Apply user ratings from local storage
                let jokesWithRatings = newJokes.map { joke -> Joke in
                    var mutableJoke = joke
                    mutableJoke.userRating = storage.getRating(for: joke.id)
                    return mutableJoke
                }

                // Replace local/hardcoded jokes with Firebase jokes
                // Firebase is now the primary data source
                jokes = jokesWithRatings.shuffled()

                // Re-initialize joke of the day with the new Firebase jokes
                initializeJokeOfTheDay()
            }
        } catch {
            // Network error - mark as offline and use cached content
            print("Firestore fetch error: \(error)")
            isOffline = true
            // Ensure cached jokes are loaded if jokes array is empty
            if jokes.isEmpty {
                loadLocalJokes()
            }
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

        do {
            // Reset pagination to get fresh data
            firestoreService.resetPagination()
            hasMoreJokes = true

            // Fetch new jokes from Firestore
            let newJokes: [Joke]
            if let category = selectedCategory {
                newJokes = try await firestoreService.fetchJokes(category: category, limit: batchSize)
            } else {
                newJokes = try await firestoreService.fetchInitialJokes(limit: batchSize)
            }

            guard !Task.isCancelled else {
                isRefreshing = false
                return
            }

            isOffline = false

            if !newJokes.isEmpty {
                // Cache them
                let grouped = Dictionary(grouping: newJokes, by: { $0.category })
                for (category, categoryJokes) in grouped {
                    storage.saveCachedJokes(categoryJokes, for: category)
                }

                // Apply user ratings
                let jokesWithRatings = newJokes.map { joke -> Joke in
                    var mutableJoke = joke
                    mutableJoke.userRating = storage.getRating(for: joke.id)
                    return mutableJoke
                }

                // Replace with fresh Firebase jokes
                jokes = jokesWithRatings.shuffled()

                // Re-initialize joke of the day with refreshed jokes
                initializeJokeOfTheDay()
            }
        } catch {
            print("Firestore refresh error: \(error)")
            isOffline = true
            // Reload cached jokes as fallback when offline
            loadLocalJokes()
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
        let startTime = Date()

        do {
            // Fetch more jokes from Firestore
            let newJokes: [Joke]
            if let category = selectedCategory {
                newJokes = try await firestoreService.fetchMoreJokes(category: category, limit: batchSize)
            } else {
                newJokes = try await firestoreService.fetchMoreJokes(limit: batchSize)
            }

            guard !Task.isCancelled else {
                isLoadingMore = false
                return
            }

            isOffline = false

            if newJokes.isEmpty {
                // No more jokes available
                hasMoreJokes = false
            } else {
                // Cache them
                let grouped = Dictionary(grouping: newJokes, by: { $0.category })
                for (category, categoryJokes) in grouped {
                    storage.saveCachedJokes(categoryJokes, for: category)
                }

                // Apply user ratings
                let jokesWithRatings = newJokes.map { joke -> Joke in
                    var mutableJoke = joke
                    mutableJoke.userRating = storage.getRating(for: joke.id)
                    return mutableJoke
                }

                // Add to end of list, avoiding duplicates
                var updatedJokes = jokes
                for joke in jokesWithRatings {
                    if !updatedJokes.contains(where: { $0.setup == joke.setup && $0.punchline == joke.punchline }) {
                        updatedJokes.append(joke)
                    }
                }
                jokes = updatedJokes
            }
        } catch {
            print("Firestore load more error: \(error)")
            isOffline = true
        }

        // Ensure skeleton is visible for at least a short time
        await ensureMinimumLoadingTime(startTime: startTime)
        isLoadingMore = false
    }

    /// Ensures the loading indicator is shown for at least 400ms for better UX
    private func ensureMinimumLoadingTime(startTime: Date) async {
        let minimumLoadingDuration: TimeInterval = 0.4
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < minimumLoadingDuration {
            let remaining = minimumLoadingDuration - elapsed
            try? await Task.sleep(for: .milliseconds(Int(remaining * 1000)))
        }
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

            // Sync rating to Firestore if we have a Firestore ID
            if let firestoreId = joke.firestoreId {
                Task {
                    do {
                        try await firestoreService.updateJokeRating(jokeId: firestoreId, rating: clampedRating)
                    } catch {
                        print("Failed to sync rating to Firestore: \(error)")
                    }
                }
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
        firestoreService.resetPagination() // Reset Firestore pagination
    }

}
