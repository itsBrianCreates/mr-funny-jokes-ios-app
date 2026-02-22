import SwiftUI
import WidgetKit
import Combine

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

    /// Network monitor for detecting actual connectivity status
    private let networkMonitor = NetworkMonitor.shared

    /// Indicates if we're currently offline based on actual network connectivity
    @Published private(set) var isOffline = false

    /// Indicates if we've reached the end and no more jokes are available
    @Published var hasMoreJokes = true

    /// Tracks if background catalog loading is complete
    @Published private(set) var isBackgroundLoadingComplete = false

    /// Background loading task reference for cancellation
    private var backgroundLoadTask: Task<Void, Never>?

    /// Tracks if background load has been triggered (only once per session)
    private var hasTriggeredBackgroundLoad = false

    /// Batch size for background loading (larger than scroll loading for efficiency)
    private let backgroundBatchSize = 50

    private let storage = LocalStorageService.shared
    private let sharedStorage = SharedStorageService.shared
    private let firestoreService = FirestoreService.shared
    private var copyTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// Number of jokes to fetch per batch
    private let batchSize = 10
    /// Number of jokes to fetch per category on initial load
    private let initialLoadPerCategory = 8

    var filteredJokes: [Joke] {
        // Step 1: Apply category filter if selected
        let categoryFiltered: [Joke]
        if let category = selectedCategory {
            categoryFiltered = jokes.filter { $0.category == category }
        } else {
            categoryFiltered = jokes
        }

        // Step 2: Separate into unrated and rated groups
        // Unrated jokes appear first, rated jokes appear at the bottom
        let unrated = categoryFiltered.filter { $0.userRating == nil }
        let rated = categoryFiltered.filter { $0.userRating != nil }

        // Step 3: Sort each group by popularity score (descending)
        let sortedUnrated = unrated.sorted { $0.popularityScore > $1.popularityScore }
        let sortedRated = rated.sorted { $0.popularityScore > $1.popularityScore }

        // Step 4: Combine with unrated first, rated at bottom
        let combined = sortedUnrated + sortedRated

        // MARK: - Seasonal Content Ranking
        // Step 5: Apply seasonal demotion for Christmas jokes outside Nov 1 - Dec 31
        if !SeasonalHelper.isChristmasSeason() {
            let nonChristmas = combined.filter { !$0.isChristmasJoke }
            let christmas = combined.filter { $0.isChristmasJoke }
            return nonChristmas + christmas
        } else {
            return combined
        }
    }

    // Jokes that have been saved by the user (sorted by most recently saved)
    var savedJokes: [Joke] {
        let saved = jokes.filter { $0.isSaved }
        return saved.sorted { joke1, joke2 in
            let t1 = storage.getSavedTimestamp(for: joke1.firestoreId ?? joke1.id.uuidString) ?? 0
            let t2 = storage.getSavedTimestamp(for: joke2.firestoreId ?? joke2.id.uuidString) ?? 0
            return t1 > t2  // Most recently saved first
        }
    }

    /// Sort jokes by rating timestamp (most recently rated first)
    private func sortByRatingTimestamp(_ jokes: [Joke]) -> [Joke] {
        jokes.sorted { joke1, joke2 in
            let timestamp1 = storage.getRatingTimestamp(for: joke1.id, firestoreId: joke1.firestoreId) ?? 0
            let timestamp2 = storage.getRatingTimestamp(for: joke2.id, firestoreId: joke2.firestoreId) ?? 0
            return timestamp1 > timestamp2  // Most recent first
        }
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
            let jokeId = UUID(uuidString: sharedJoke.id) ?? UUID()
            var joke = Joke(
                id: jokeId,
                category: category,
                setup: sharedJoke.setup,
                punchline: sharedJoke.punchline,
                firestoreId: sharedJoke.firestoreId,
                character: sharedJoke.character
            )
            // Apply any saved user rating and save state from local storage
            joke.userRating = storage.getRating(for: jokeId, firestoreId: sharedJoke.firestoreId)
            joke.isSaved = storage.isJokeSaved(firestoreId: sharedJoke.firestoreId ?? jokeId.uuidString)
            return joke
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
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                withAnimation(.easeInOut(duration: 0.3)) {
                    self?.isOffline = !isConnected
                }
            }
            .store(in: &cancellables)

        // Listen for rating changes from other ViewModels (e.g., CharacterDetailViewModel)
        // This ensures the Me tab updates when ratings are made in character views
        NotificationCenter.default.publisher(for: .jokeRatingDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleRatingNotification(notification)
            }
            .store(in: &cancellables)

        // Listen for save changes from other ViewModels (e.g., CharacterDetailViewModel)
        // This ensures the Me tab updates when saves are made in character views
        NotificationCenter.default.publisher(for: .jokeSaveDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleSaveNotification(notification)
            }
            .store(in: &cancellables)

        // Set initial offline state
        isOffline = networkMonitor.isOffline

        // Load joke of the day from storage immediately (lightweight)
        loadJokeOfTheDayFromStorage()

        // Start async content loading - doesn't block the main thread
        initialLoadTask = Task {
            await loadInitialContentAsync()
        }
    }

    /// Handle rating change notifications from other ViewModels
    private func handleRatingNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rating = userInfo["rating"] as? Int else { return }

        let firestoreId = userInfo["firestoreId"] as? String
        let jokeId = userInfo["jokeId"] as? UUID
        let jokeData = userInfo["jokeData"] as? Data

        // Find and update the joke in our array
        let jokeIndex = jokes.firstIndex(where: {
            if let fid = firestoreId, let otherFid = $0.firestoreId {
                return fid == otherFid
            }
            if let jid = jokeId {
                return $0.id == jid
            }
            return false
        })

        if let index = jokeIndex {
            // Joke exists in array - update its rating
            if rating == 0 {
                jokes[index].userRating = nil
            } else {
                jokes[index].userRating = rating
            }
        } else if rating != 0, let data = jokeData {
            // Joke not in array and rating is being set (not cleared)
            // Decode the joke from notification data and add it to the array
            // This ensures jokes rated in character views appear in the Me tab
            if var joke = try? JSONDecoder().decode(Joke.self, from: data) {
                joke.userRating = rating
                jokes.append(joke)
            }
        }

        // Invalidate sort cache since ratings changed
        invalidateSortCache()
    }

    // MARK: - Feed Algorithm (Freshness Sorting)

    /// Cached impression and rated IDs to avoid repeated lookups during sorting
    private var cachedImpressionIds: Set<String>?
    private var cachedRatedIds: Set<String>?

    /// Invalidates the cached impression/rated IDs (call when new impressions or ratings are added)
    private func invalidateSortCache() {
        cachedImpressionIds = nil
        cachedRatedIds = nil
    }

    /// Sorts jokes for a fresh feed experience
    /// Prioritizes: Unseen jokes > Seen but unrated > Already rated
    /// Shuffles within each tier to maintain category variety
    private func sortJokesForFreshFeed(_ jokes: [Joke]) -> [Joke] {
        // Use cached IDs if available, otherwise fetch and cache
        let impressionIds: Set<String>
        let ratedIds: Set<String>

        if let cached = cachedImpressionIds {
            impressionIds = cached
        } else {
            impressionIds = storage.getImpressionIdsFast()
            cachedImpressionIds = impressionIds
        }

        if let cached = cachedRatedIds {
            ratedIds = cached
        } else {
            ratedIds = storage.getRatedJokeIdsFast()
            cachedRatedIds = ratedIds
        }

        var unseenJokes: [Joke] = []
        var seenUnratedJokes: [Joke] = []
        var ratedJokes: [Joke] = []

        for joke in jokes {
            let key = joke.firestoreId ?? joke.id.uuidString
            let hasImpression = impressionIds.contains(key)
            let hasRating = ratedIds.contains(key)

            if !hasImpression {
                unseenJokes.append(joke)
            } else if !hasRating {
                seenUnratedJokes.append(joke)
            } else {
                ratedJokes.append(joke)
            }
        }

        // Shuffle within each tier to maintain category variety
        return unseenJokes.shuffled() + seenUnratedJokes.shuffled() + ratedJokes.shuffled()
    }

    /// Marks a joke as seen/impressed for feed freshness tracking
    func markJokeImpression(_ joke: Joke) {
        storage.markImpression(firestoreId: joke.firestoreId)
        // Invalidate cache since impressions changed
        invalidateSortCache()
    }

    // MARK: - Initial Load

    /// Load content on app start asynchronously - cache first, then API
    /// This is fully async to avoid blocking the main thread during startup
    private func loadInitialContentAsync() async {
        // PHASE 0: Run one-time migrations (gated by UserDefaults flags)
        // Must run before memory cache preload so cache loads already-migrated data
        storage.migrateRatingsToBinaryIfNeeded()
        storage.migrateRatedToSavedIfNeeded()

        // PHASE 1: Preload memory cache for fast sorting (critical for performance)
        await storage.preloadMemoryCacheAsync()

        // PHASE 2: Load cached jokes asynchronously (off main thread)
        let cached = await storage.loadAllCachedJokesAsync()

        if !cached.isEmpty {
            // Ensure ratings and save state are applied from authoritative source (defensive - cache should have them,
            // but re-apply for consistency with all other load paths: fetchInitialAPIContent,
            // fetchInitialAPIContentBackground, refresh, performLoadMore)
            let cachedWithRatings = cached.map { joke -> Joke in
                var mutableJoke = joke
                mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                mutableJoke.isSaved = storage.isJokeSaved(firestoreId: joke.firestoreId ?? joke.id.uuidString)
                return mutableJoke
            }

            // Load cached content into feed (renders behind splash)
            jokes = sortJokesForFreshFeed(cachedWithRatings)

            // PHASE 3: Fetch fresh content from Firebase before dismissing splash
            // Splash stays visible until fetch completes, so the main thread is free
            // when the user can first interact. Max splash timer (5s) prevents infinite wait.
            await fetchInitialAPIContentBackground()
        } else {
            // No cache (first launch) - must wait for Firebase fetch
            await fetchInitialAPIContent()
        }
    }

    /// Legacy sync method - kept for refresh scenarios where we're already on main thread
    private func loadLocalJokes() {
        let cached = storage.loadAllCachedJokes()
        jokes = sortJokesForFreshFeed(cached)

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

        // Update the daily notification with the new joke content
        NotificationManager.shared.scheduleJokeOfTheDayNotification()
    }

    /// Fetch initial content from Firestore (blocking - waits before completing initial load)
    /// Used when there's no cached content available
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

                // Cache jokes for Siri access (offline support)
                let sharedJokesForSiri = newJokes.map { joke in
                    SharedJoke(
                        id: joke.firestoreId ?? joke.id.uuidString,
                        setup: joke.setup,
                        punchline: joke.punchline,
                        character: joke.character,
                        type: joke.category.rawValue
                    )
                }
                sharedStorage.saveCachedJokesForSiri(sharedJokesForSiri)

                // Populate widget fallback cache for offline graceful degradation
                populateFallbackCache(from: newJokes)

                // Apply user ratings and save state from local storage
                let jokesWithRatings = newJokes.map { joke -> Joke in
                    var mutableJoke = joke
                    mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                    mutableJoke.isSaved = storage.isJokeSaved(firestoreId: joke.firestoreId ?? joke.id.uuidString)
                    return mutableJoke
                }

                // Replace local/hardcoded jokes with Firebase jokes
                // Firebase is now the primary data source (sorted for freshness)
                jokes = sortJokesForFreshFeed(jokesWithRatings)

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

    /// Fetch initial content from Firestore in background (non-blocking)
    /// Used after cache is already loaded - updates UI but doesn't block splash transition
    private func fetchInitialAPIContentBackground() async {
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

                // Cache jokes for Siri access (offline support)
                let sharedJokesForSiri = newJokes.map { joke in
                    SharedJoke(
                        id: joke.firestoreId ?? joke.id.uuidString,
                        setup: joke.setup,
                        punchline: joke.punchline,
                        character: joke.character,
                        type: joke.category.rawValue
                    )
                }
                sharedStorage.saveCachedJokesForSiri(sharedJokesForSiri)

                // Populate widget fallback cache for offline graceful degradation
                populateFallbackCache(from: newJokes)

                // Apply user ratings and save state from local storage
                let jokesWithRatings = newJokes.map { joke -> Joke in
                    var mutableJoke = joke
                    mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                    mutableJoke.isSaved = storage.isJokeSaved(firestoreId: joke.firestoreId ?? joke.id.uuidString)
                    return mutableJoke
                }

                // Replace with Firebase jokes (sorted for freshness)
                // This smoothly updates the UI if user is already viewing the feed
                jokes = sortJokesForFreshFeed(jokesWithRatings)

                // Re-initialize joke of the day - fetches from Firebase if needed
                await initializeJokeOfTheDayAsync()
            }
        } catch {
            // Network error - cached content is already loaded, so just log
            print("Background Firestore fetch error: \(error)")
        }

        // If initial loading wasn't completed (no cache was available),
        // complete it now that Firebase fetch is done
        if isInitialLoading {
            await completeInitialLoading()
        }
    }

    private func completeInitialLoading() async {
        // No artificial delay - let the UI become interactive as soon as data is ready
        isInitialLoading = false
    }

    // MARK: - Refresh (Category Change)

    /// Refreshes the joke feed when category changes
    func refresh() async {
        guard !isRefreshing else { return }

        // Cancel background loading and reset state
        backgroundLoadTask?.cancel()
        hasTriggeredBackgroundLoad = false
        isBackgroundLoadingComplete = false
        isRefreshing = true

        do {
            // Reset pagination to get fresh data
            firestoreService.resetPagination()
            hasMoreJokes = true

            // Note: We don't clear cache here - it's replaced after successful fetch
            // This preserves fallback data if the network request fails

            // Fetch new jokes from Firestore
            let newJokes: [Joke]
            if let category = selectedCategory {
                newJokes = try await firestoreService.fetchJokes(category: category, limit: batchSize)
            } else {
                newJokes = try await firestoreService.fetchInitialJokesAllCategories(countPerCategory: initialLoadPerCategory)
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

                // Update Siri cache with fresh jokes
                let sharedJokesForSiri = newJokes.map { joke in
                    SharedJoke(
                        id: joke.firestoreId ?? joke.id.uuidString,
                        setup: joke.setup,
                        punchline: joke.punchline,
                        character: joke.character,
                        type: joke.category.rawValue
                    )
                }
                sharedStorage.saveCachedJokesForSiri(sharedJokesForSiri)

                // Populate widget fallback cache for offline graceful degradation
                populateFallbackCache(from: newJokes)

                // Apply user ratings and save state
                let jokesWithRatings = newJokes.map { joke -> Joke in
                    var mutableJoke = joke
                    mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                    mutableJoke.isSaved = storage.isJokeSaved(firestoreId: joke.firestoreId ?? joke.id.uuidString)
                    return mutableJoke
                }

                // Replace with fresh Firebase jokes (sorted for freshness)
                jokes = sortJokesForFreshFeed(jokesWithRatings)

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
        // Trigger background catalog loading on first scroll
        triggerBackgroundLoadIfNeeded()

        // Check if we're near the end of the list
        let thresholdIndex = filteredJokes.index(filteredJokes.endIndex, offsetBy: -3, limitedBy: filteredJokes.startIndex) ?? filteredJokes.startIndex

        guard let currentIndex = filteredJokes.firstIndex(where: { $0.id == currentItem.id }),
              currentIndex >= thresholdIndex else {
            return
        }

        loadMore()
    }

    // MARK: - Background Catalog Loading

    /// Triggers background catalog loading if not already started
    /// Called on first scroll, not app launch (per CONTEXT.md)
    func triggerBackgroundLoadIfNeeded() {
        guard !hasTriggeredBackgroundLoad && !isBackgroundLoadingComplete else { return }
        hasTriggeredBackgroundLoad = true

        backgroundLoadTask = Task { [weak self] in
            await self?.loadFullCatalogInBackground()
        }
    }

    /// Loads the full joke catalog silently in background
    /// Designed for 500-2000 jokes per CONTEXT.md
    private func loadFullCatalogInBackground() async {
        // Load in batches to avoid memory spikes
        while hasMoreJokes && !Task.isCancelled {
            do {
                let newJokes: [Joke]
                if let category = selectedCategory {
                    newJokes = try await firestoreService.fetchMoreJokes(category: category, limit: backgroundBatchSize)
                } else {
                    newJokes = try await firestoreService.fetchMoreJokes(limit: backgroundBatchSize)
                }

                guard !Task.isCancelled else { return }

                if newJokes.isEmpty {
                    break
                }

                // Apply user ratings and save state
                let jokesWithRatings = newJokes.map { joke -> Joke in
                    var mutableJoke = joke
                    mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                    mutableJoke.isSaved = storage.isJokeSaved(firestoreId: joke.firestoreId ?? joke.id.uuidString)
                    return mutableJoke
                }

                // Merge with existing jokes, avoiding duplicates
                var updatedJokes = jokes
                for joke in jokesWithRatings {
                    if !updatedJokes.contains(where: { $0.setup == joke.setup && $0.punchline == joke.punchline }) {
                        updatedJokes.append(joke)
                    }
                }
                jokes = updatedJokes

                // Small delay between batches to avoid overwhelming
                try? await Task.sleep(for: .milliseconds(100))
            } catch {
                // Silent failure per CONTEXT.md - just stop loading
                break
            }
        }

        isBackgroundLoadingComplete = true
    }

    /// Load more jokes (for infinite scroll)
    func loadMore() {
        guard !isLoadingMore && !isRefreshing && hasMoreJokes else { return }

        loadMoreTask?.cancel()
        loadMoreTask = Task {
            await performLoadMore()
        }
    }

    /// Tracks consecutive empty fetches to detect end of data
    private var consecutiveEmptyFetches = 0
    private let maxEmptyFetches = 3

    private func performLoadMore() async {
        withAnimation(.easeInOut(duration: 0.3)) { self.isLoadingMore = true }
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
                // Track consecutive empty fetches
                // For category filtering, we may need multiple fetches to find matching jokes
                consecutiveEmptyFetches += 1
                if consecutiveEmptyFetches >= maxEmptyFetches {
                    // After 3 consecutive empty fetches, assume no more jokes
                    hasMoreJokes = false
                }
            } else {
                // Reset empty fetch counter on successful fetch
                consecutiveEmptyFetches = 0

                // Cache them
                let grouped = Dictionary(grouping: newJokes, by: { $0.category })
                for (category, categoryJokes) in grouped {
                    storage.saveCachedJokes(categoryJokes, for: category)
                }

                // Apply user ratings and save state
                let jokesWithRatings = newJokes.map { joke -> Joke in
                    var mutableJoke = joke
                    mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                    mutableJoke.isSaved = storage.isJokeSaved(firestoreId: joke.firestoreId ?? joke.id.uuidString)
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
        withAnimation(.easeInOut(duration: 0.3)) { self.isLoadingMore = false }
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

        // Invalidate sort cache since ratings are changing
        invalidateSortCache()

        // Find joke index using firestoreId (stable) or fallback to UUID
        // This handles cases where jokes array was refreshed and UUIDs changed
        let jokeIndex = jokes.firstIndex(where: {
            if let firestoreId = joke.firestoreId, let otherFirestoreId = $0.firestoreId {
                return firestoreId == otherFirestoreId
            }
            return $0.id == joke.id
        })

        if rating == 0 {
            storage.removeRating(for: joke.id, firestoreId: joke.firestoreId)
            if let index = jokeIndex {
                jokes[index].userRating = nil
            }
        } else {
            let clampedRating = min(max(rating, 1), 5)
            let ratingName = clampedRating == 5 ? "hilarious" : "horrible"
            let analyticsJokeId = joke.firestoreId ?? joke.id.uuidString
            let analyticsCharacter = joke.character ?? "unknown"
            Task.detached { AnalyticsService.shared.logJokeRated(jokeId: analyticsJokeId, character: analyticsCharacter, rating: ratingName) }
            storage.saveRating(for: joke.id, firestoreId: joke.firestoreId, rating: clampedRating)
            if let index = jokeIndex {
                jokes[index].userRating = clampedRating
            } else {
                // Joke not in array (e.g., Joke of the Day from cache)
                // Add it to the array so it appears in the Me tab and triggers UI update
                var mutableJoke = joke
                mutableJoke.userRating = clampedRating
                jokes.append(mutableJoke)
            }

            // Sync rating to Firestore if we have a Firestore ID
            if let firestoreId = joke.firestoreId {
                Task {
                    do {
                        try await firestoreService.updateJokeRating(jokeId: firestoreId, rating: clampedRating)

                        // Log rating event for weekly rankings (only for hilarious=5 or horrible=1)
                        if clampedRating == 1 || clampedRating == 5 {
                            let deviceId = storage.getDeviceId()
                            try await firestoreService.logRatingEvent(
                                jokeId: firestoreId,
                                rating: clampedRating,
                                deviceId: deviceId
                            )
                        }
                    } catch {
                        print("Failed to sync rating to Firestore: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Saving

    /// Toggle save state for a joke
    func saveJoke(_ joke: Joke) {
        HapticManager.shared.lightTap()

        let key = joke.firestoreId ?? joke.id.uuidString
        let currentlySaved = storage.isJokeSaved(firestoreId: key)

        // Toggle save state in storage
        if currentlySaved {
            storage.unsaveJoke(firestoreId: key)
        } else {
            storage.saveJoke(firestoreId: key)
        }

        // Update local state with animation
        let jokeIndex = jokes.firstIndex(where: {
            if let firestoreId = joke.firestoreId, let otherFirestoreId = $0.firestoreId {
                return firestoreId == otherFirestoreId
            }
            return $0.id == joke.id
        })

        if let index = jokeIndex {
            withAnimation { jokes[index].isSaved = !currentlySaved }
        } else {
            // Joke not in array - add it
            var mutableJoke = joke
            mutableJoke.isSaved = !currentlySaved
            withAnimation { jokes.append(mutableJoke) }
        }

        // Post notification to sync with other ViewModels
        let updatedJoke: Joke
        if let index = jokeIndex {
            updatedJoke = jokes[index]
        } else {
            var mutableJoke = joke
            mutableJoke.isSaved = !currentlySaved
            updatedJoke = mutableJoke
        }

        let jokeData = try? JSONEncoder().encode(updatedJoke)
        NotificationCenter.default.post(
            name: .jokeSaveDidChange,
            object: nil,
            userInfo: [
                "jokeId": joke.id,
                "firestoreId": key,
                "isSaved": !currentlySaved,
                "jokeData": jokeData as Any
            ]
        )
    }

    /// Unsave a joke (dedicated method for swipe-to-delete in MeView)
    func unsaveJoke(_ joke: Joke) {
        let key = joke.firestoreId ?? joke.id.uuidString

        // Only unsave if currently saved
        guard storage.isJokeSaved(firestoreId: key) else { return }

        storage.unsaveJoke(firestoreId: key)

        // Update local state with animation
        let jokeIndex = jokes.firstIndex(where: {
            if let firestoreId = joke.firestoreId, let otherFirestoreId = $0.firestoreId {
                return firestoreId == otherFirestoreId
            }
            return $0.id == joke.id
        })

        if let index = jokeIndex {
            withAnimation { jokes[index].isSaved = false }
        }

        // Post notification to sync with other ViewModels
        let jokeData = try? JSONEncoder().encode(joke)
        NotificationCenter.default.post(
            name: .jokeSaveDidChange,
            object: nil,
            userInfo: [
                "jokeId": joke.id,
                "firestoreId": key,
                "isSaved": false,
                "jokeData": jokeData as Any
            ]
        )
    }

    /// Handle save change notifications from other ViewModels
    private func handleSaveNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isSaved = userInfo["isSaved"] as? Bool else { return }

        let firestoreId = userInfo["firestoreId"] as? String
        let jokeId = userInfo["jokeId"] as? UUID
        let jokeData = userInfo["jokeData"] as? Data

        // Find and update the joke in our array
        let jokeIndex = jokes.firstIndex(where: {
            if let fid = firestoreId, let otherFid = $0.firestoreId {
                return fid == otherFid
            }
            if let jid = jokeId {
                return $0.id == jid
            }
            return false
        })

        if let index = jokeIndex {
            // Joke exists in array - update its save state
            withAnimation { jokes[index].isSaved = isSaved }
        } else if isSaved, let data = jokeData {
            // Joke not in array and is being saved
            // Decode the joke from notification data and add it to the array
            if var joke = try? JSONDecoder().decode(Joke.self, from: data) {
                joke.isSaved = isSaved
                withAnimation { jokes.append(joke) }
            }
        }
    }

    // MARK: - Sharing

    func shareJoke(_ joke: Joke) {
        HapticManager.shared.success()
        let jokeId = joke.firestoreId ?? joke.id.uuidString
        Task.detached { AnalyticsService.shared.logJokeShared(jokeId: jokeId, method: "share") }

        // Get character name from joke's character field, fallback to generic app name
        let characterName: String
        if let characterId = joke.character,
           let character = JokeCharacter.find(byId: characterId) {
            characterName = character.name
        } else {
            characterName = "Mr. Funny Jokes"
        }

        let text = joke.formattedTextForSharing(characterName: characterName)

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
        let jokeId = joke.firestoreId ?? joke.id.uuidString
        Task.detached { AnalyticsService.shared.logJokeShared(jokeId: jokeId, method: "copy") }

        // Get character name from joke's character field, fallback to generic app name
        let characterName: String
        if let characterId = joke.character,
           let character = JokeCharacter.find(byId: characterId) {
            characterName = character.name
        } else {
            characterName = "Mr. Funny Jokes"
        }

        let text = joke.formattedTextForSharing(characterName: characterName)
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
        consecutiveEmptyFetches = 0 // Reset empty fetch counter
        firestoreService.resetPagination() // Reset Firestore pagination

        // Fetch jokes for the selected category
        Task {
            await refresh()
        }
    }

    // MARK: - Widget Fallback Cache

    /// Populate widget fallback cache with jokes for offline graceful degradation
    /// Called after jokes are fetched from Firestore to ensure widgets have backup content
    private func populateFallbackCache(from jokes: [Joke]) {
        // Convert to SharedJokeOfTheDay format, taking up to 20 jokes
        let fallbackJokes = jokes.prefix(20).map { joke in
            SharedJokeOfTheDay(
                id: joke.id.uuidString,
                setup: joke.setup,
                punchline: joke.punchline,
                category: joke.category.rawValue,
                firestoreId: joke.firestoreId,
                character: joke.character,
                lastUpdated: Date()
            )
        }

        sharedStorage.saveFallbackJokes(Array(fallbackJokes))
    }

}
