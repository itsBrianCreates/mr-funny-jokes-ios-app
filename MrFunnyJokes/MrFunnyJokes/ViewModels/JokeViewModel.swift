import SwiftUI
import WidgetKit
import Combine

@MainActor
final class JokeViewModel: ObservableObject {
    @Published var jokes: [Joke] = []
    @Published var selectedCategory: JokeCategory? = nil
    @Published var selectedMeCategory: JokeCategory? = nil
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var copiedJokeId: UUID?

    /// Tracks initial app launch loading state for skeleton display
    @Published var isInitialLoading = true

    /// Tracks if more jokes are being loaded (for infinite scroll)
    @Published var isLoadingMore = false

    /// Network monitor for detecting actual connectivity status
    private let networkMonitor = NetworkMonitor.shared

    /// Indicates if we're currently offline based on actual network connectivity
    @Published private(set) var isOffline = false

    /// Indicates if we've reached the end and no more jokes are available
    @Published var hasMoreJokes = true

    private let storage = LocalStorageService.shared
    private let sharedStorage = SharedStorageService.shared
    private let firestoreService = FirestoreService.shared
    private var copyTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?
    private var networkCancellable: AnyCancellable?

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

    // MARK: - Filtered Rated Jokes (for Me tab)

    /// Rated jokes filtered by the selected Me tab category
    var filteredRatedJokes: [Joke] {
        guard let category = selectedMeCategory else {
            return ratedJokes
        }
        return ratedJokes.filter { $0.category == category }
    }

    /// Hilarious jokes filtered by the selected Me tab category
    var filteredHilariousJokes: [Joke] {
        guard let category = selectedMeCategory else {
            return hilariousJokes
        }
        return hilariousJokes.filter { $0.category == category }
    }

    /// Funny jokes filtered by the selected Me tab category
    var filteredFunnyJokes: [Joke] {
        guard let category = selectedMeCategory else {
            return funnyJokes
        }
        return funnyJokes.filter { $0.category == category }
    }

    /// Meh jokes filtered by the selected Me tab category
    var filteredMehJokes: [Joke] {
        guard let category = selectedMeCategory else {
            return mehJokes
        }
        return mehJokes.filter { $0.category == category }
    }

    /// Groan jokes filtered by the selected Me tab category
    var filteredGroanJokes: [Joke] {
        guard let category = selectedMeCategory else {
            return groanJokes
        }
        return groanJokes.filter { $0.category == category }
    }

    /// The cached joke of the day firestoreId - used to match Firebase jokes
    /// This is persisted across app/widget via SharedStorageService
    @Published private(set) var jokeOfTheDayId: String?

    /// Cached joke data from shared storage (used as fallback if joke not in array)
    private var cachedJokeOfTheDayData: SharedJokeOfTheDay?

    /// Joke of the Day - sourced from shared storage to ensure consistency with widget
    /// Uses firestoreId for lookup to properly match Firebase jokes
    var jokeOfTheDay: Joke? {
        guard let id = jokeOfTheDayId else { return nil }

        // First, try to find the joke in our array by firestoreId
        if let joke = jokes.first(where: { $0.firestoreId == id }) {
            return joke
        }

        // Fallback: reconstruct from shared storage data
        // This handles the case where the saved joke isn't in our jokes array yet
        if let sharedJoke = cachedJokeOfTheDayData {
            let category = JokeCategory(rawValue: sharedJoke.category ?? "") ?? .dadJoke
            return Joke(
                id: UUID(uuidString: sharedJoke.id) ?? UUID(),
                category: category,
                setup: sharedJoke.setup,
                punchline: sharedJoke.punchline,
                firestoreId: sharedJoke.firestoreId,
                character: sharedJoke.character
            )
        }

        return nil
    }

    /// Fetch the joke of the day from Firebase
    /// First tries to get the designated joke for today from daily_jokes collection,
    /// falls back to a random joke if no designated joke exists
    private func fetchJokeOfTheDayFromFirebase() async -> Joke? {
        do {
            // First, try to fetch the designated joke of the day for today
            if let designatedJoke = try await firestoreService.fetchJokeOfTheDay() {
                return designatedJoke
            }

            // Fallback to a random joke if no designated joke for today
            return try await firestoreService.fetchRandomJoke()
        } catch {
            print("Failed to fetch joke of the day from Firebase: \(error)")
            // Fallback to local jokes if Firebase fetch fails
            guard !jokes.isEmpty else { return nil }
            return jokes.randomElement()
        }
    }

    init() {
        // Subscribe to network connectivity changes
        networkCancellable = networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
            }

        // Set initial offline state
        isOffline = networkMonitor.isOffline

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

    /// Initialize joke of the day from shared storage only (sync)
    /// Use this for initial load from cache
    private func loadJokeOfTheDayFromStorage() {
        if let savedJoke = sharedStorage.loadJokeOfTheDay() {
            // Use firestoreId for lookup if available, otherwise fall back to id
            jokeOfTheDayId = savedJoke.firestoreId ?? savedJoke.id
            cachedJokeOfTheDayData = savedJoke
        }
    }

    /// Initialize joke of the day - checks storage first, fetches from Firebase if needed
    /// This ensures the same joke persists for 24 hours across app and widget
    private func initializeJokeOfTheDay() {
        // First, check if we have a valid joke of the day saved from today
        if !sharedStorage.needsUpdate(), let savedJoke = sharedStorage.loadJokeOfTheDay() {
            // Use firestoreId for lookup - this properly matches Firebase jokes
            jokeOfTheDayId = savedJoke.firestoreId ?? savedJoke.id
            // Cache the full joke data for fallback reconstruction
            cachedJokeOfTheDayData = savedJoke
            return
        }

        // No saved joke for today - fetch from Firebase in background
        Task {
            await fetchAndSaveJokeOfTheDay()
        }
    }

    /// Async version: Initialize joke of the day - checks storage first, fetches from Firebase if needed
    /// Call this from async contexts to avoid spawning unnecessary Tasks
    private func initializeJokeOfTheDayAsync() async {
        // First, check if we have a valid joke of the day saved from today
        if !sharedStorage.needsUpdate(), let savedJoke = sharedStorage.loadJokeOfTheDay() {
            // Use firestoreId for lookup - this properly matches Firebase jokes
            jokeOfTheDayId = savedJoke.firestoreId ?? savedJoke.id
            // Cache the full joke data for fallback reconstruction
            cachedJokeOfTheDayData = savedJoke
            return
        }

        // No saved joke for today - fetch from Firebase
        await fetchAndSaveJokeOfTheDay()
    }

    /// Fetch a new joke of the day from Firebase and save it
    private func fetchAndSaveJokeOfTheDay() async {
        guard let newJoke = await fetchJokeOfTheDayFromFirebase() else { return }

        // Use firestoreId for storage - this is the actual Firebase document ID
        let jokeIdentifier = newJoke.firestoreId ?? newJoke.id.uuidString

        // Save and sync to widget
        jokeOfTheDayId = jokeIdentifier
        saveJokeOfTheDayToWidget(newJoke)

        // Also cache the data locally for fallback
        cachedJokeOfTheDayData = SharedJokeOfTheDay(
            id: newJoke.id.uuidString,
            setup: newJoke.setup,
            punchline: newJoke.punchline,
            category: newJoke.category.rawValue,
            firestoreId: newJoke.firestoreId,
            character: newJoke.character
        )
    }

    /// Save a specific joke as the joke of the day to shared storage
    private func saveJokeOfTheDayToWidget(_ joke: Joke) {
        let sharedJoke = SharedJokeOfTheDay(
            id: joke.id.uuidString,
            setup: joke.setup,
            punchline: joke.punchline,
            category: joke.category.rawValue,
            firestoreId: joke.firestoreId,
            character: joke.character
        )

        sharedStorage.saveJokeOfTheDay(sharedJoke)
        WidgetCenter.shared.reloadTimelines(ofKind: "JokeOfTheDayWidget")
    }

    /// Fetch initial content from Firestore
    private func fetchInitialAPIContent() async {
        do {
            // Fetch jokes from Firestore using concurrent category loading for faster results
            let newJokes = try await firestoreService.fetchInitialJokesAllCategories(countPerCategory: initialLoadPerCategory)

            guard !Task.isCancelled else { return }

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

                // Re-initialize joke of the day - fetches from Firebase if needed
                await initializeJokeOfTheDayAsync()
            }
        } catch {
            // Network error - use cached content as fallback
            print("Firestore fetch error: \(error)")
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

    /// Refreshes the joke feed
    /// - Parameter forceServerFetch: When true, bypasses Firestore cache and fetches from server.
    ///   Use true for pull-to-refresh, false for category changes (allows graceful cache fallback).
    func refresh(forceServerFetch: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true

        do {
            // Reset pagination to get fresh data
            firestoreService.resetPagination()
            hasMoreJokes = true

            // Note: We don't clear cache here - it's replaced after successful fetch
            // This preserves fallback data if the network request fails

            // Fetch new jokes from Firestore
            // Only force server fetch for explicit pull-to-refresh, not for category changes
            let newJokes: [Joke]
            if let category = selectedCategory {
                newJokes = try await firestoreService.fetchJokes(category: category, limit: batchSize, forceRefresh: forceServerFetch)
            } else {
                newJokes = try await firestoreService.fetchInitialJokesAllCategories(countPerCategory: initialLoadPerCategory, forceRefresh: forceServerFetch)
            }

            guard !Task.isCancelled else {
                isRefreshing = false
                return
            }

            if !newJokes.isEmpty {
                // Replace cache with fresh jokes (not append)
                let grouped = Dictionary(grouping: newJokes, by: { $0.category })
                for (category, categoryJokes) in grouped {
                    storage.replaceCachedJokes(categoryJokes, for: category)
                }

                // Apply user ratings
                let jokesWithRatings = newJokes.map { joke -> Joke in
                    var mutableJoke = joke
                    mutableJoke.userRating = storage.getRating(for: joke.id)
                    return mutableJoke
                }

                // Replace with fresh Firebase jokes
                jokes = jokesWithRatings.shuffled()

                // Re-initialize joke of the day - fetches from Firebase if needed
                await initializeJokeOfTheDayAsync()
            }
        } catch {
            print("Firestore refresh error: \(error)")
            // Reload cached jokes as fallback on error
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
            // Network error during load more - no action needed, user can retry
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

        // Fetch jokes for the selected category
        Task {
            await refresh()
        }
    }

    // MARK: - Me Tab Category Selection

    func selectMeCategory(_ category: JokeCategory?) {
        HapticManager.shared.lightTap()
        selectedMeCategory = category
    }

}
