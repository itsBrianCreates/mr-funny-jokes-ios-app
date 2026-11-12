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

    /// Network monitor for detecting actual connectivity status
    private let networkMonitor = NetworkMonitor.shared

    /// Indicates if we're currently offline based on actual network connectivity
    @Published private(set) var isOffline = false

    /// Goes up each time the feed is put in a new order (launch, pull-to-refresh, coming
    /// back after a while), so the feed view can return to the top
    @Published private(set) var feedGeneration = 0

    private let storage = LocalStorageService.shared
    private let sharedStorage = SharedStorageService.shared
    private let firestoreService = FirestoreService.shared
    private let catalog = JokeCatalogService.shared
    private var copyTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// When the view model was created; the splash gives up waiting 5s after this
    private let launchedAt = Date()

    /// When the app last went to the background
    private var lastBackgroundedAt: Date?

    /// Coming back after this long counts as a new visit and gets a fresh feed
    private let freshFeedInterval: TimeInterval = 30 * 60

    /// The feed. `jokes` is already in fresh-first order (see `showFreshFeed`), and that
    /// order holds until the next fresh feed so nothing moves while the person scrolls.
    var filteredJokes: [Joke] {
        // Step 1: Apply category filter if selected
        let categoryFiltered: [Joke]
        if let category = selectedCategory {
            categoryFiltered = jokes.filter { $0.category == category }
        } else {
            categoryFiltered = jokes
        }

        // MARK: - Seasonal Content Ranking
        // Step 2: Apply seasonal demotion for Christmas jokes outside Nov 1 - Dec 31
        if !SeasonalHelper.isChristmasSeason() {
            let nonChristmas = categoryFiltered.filter { !$0.isChristmasJoke }
            let christmas = categoryFiltered.filter { $0.isChristmasJoke }
            return nonChristmas + christmas
        } else {
            return categoryFiltered
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
            // Same off-season exclusion as FirestoreService.fetchRandomJoke()
            if !SeasonalHelper.isChristmasSeason() {
                let nonChristmas = jokes.filter { !$0.isChristmasJoke }
                if !nonChristmas.isEmpty {
                    return nonChristmas.randomElement()
                }
            }
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

        // A feed left in the background goes stale: coming back later should feel like a new visit
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.lastBackgroundedAt = Date()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showFreshFeedIfBackFromLongBreak()
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
    }

    // MARK: - Fresh Feed

    /// Marks a joke as seen (its card was on screen). Takes effect in the next fresh feed.
    func markJokeImpression(_ joke: Joke) {
        storage.markImpression(firestoreId: joke.firestoreId)
    }

    /// Marks a joke as opened (punchline revealed). Takes effect in the next fresh feed,
    /// where it drops below everything not yet opened.
    func markJokeViewed(_ joke: Joke) {
        storage.markViewed(firestoreId: joke.firestoreId)
    }

    /// Puts the feed in a new order: jokes this person hasn't seen first.
    /// Only call when the person isn't mid-scroll (launch, pull-to-refresh, back after a while).
    private func showFreshFeed(from catalogJokes: [Joke]) {
        storage.beginImpressionSession()

        let ordered = JokeFeedOrdering.freshFirst(
            applyingUserState(to: catalogJokes),
            seenOrder: storage.getImpressionOrder(),
            ratedIds: storage.getRatedJokeIdsFast(),
            viewedIds: storage.getViewedIdsFast()
        )

        jokes = ordered
        feedGeneration += 1
        updateSharedCaches(from: ordered)
    }

    /// Takes in catalog changes without moving anything the person may be looking at:
    /// edited jokes update in place, new ones wait at the end for the next fresh feed.
    private func mergeCatalogKeepingOrder(_ catalogJokes: [Joke]) {
        var freshById: [String: Joke] = [:]
        for joke in applyingUserState(to: catalogJokes) {
            if let id = joke.firestoreId { freshById[id] = joke }
        }

        var merged: [Joke] = []
        var shownIds = Set<String>()
        for joke in jokes {
            guard let id = joke.firestoreId else {
                merged.append(joke)
                continue
            }
            // A joke no longer in the catalog was deleted
            if let fresh = freshById[id], shownIds.insert(id).inserted {
                merged.append(fresh)
            }
        }
        for joke in catalogJokes {
            if let id = joke.firestoreId, !shownIds.contains(id), let fresh = freshById[id] {
                merged.append(fresh)
            }
        }
        jokes = merged
    }

    /// Ratings and saves live in local storage, not in the catalog
    private func applyingUserState(to jokes: [Joke]) -> [Joke] {
        jokes.map { joke in
            var mutableJoke = joke
            mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
            mutableJoke.isSaved = storage.isJokeSaved(firestoreId: joke.firestoreId ?? joke.id.uuidString)
            return mutableJoke
        }
    }

    /// Brings the on-device catalog up to date.
    /// - Returns: The catalog when it changed; nil when nothing changed or Firestore couldn't be reached
    private func syncCatalog() async -> [Joke]? {
        guard !networkMonitor.isOffline else { return nil }
        do {
            return try await catalog.sync() ? catalog.jokes : nil
        } catch {
            print("Catalog sync error: \(error)")
            return nil
        }
    }

    private func showFreshFeedIfBackFromLongBreak() {
        guard let lastBackgroundedAt,
              Date().timeIntervalSince(lastBackgroundedAt) >= freshFeedInterval,
              !isInitialLoading else { return }
        self.lastBackgroundedAt = nil

        Task {
            await refresh()
        }
    }

    // MARK: - Initial Load

    /// Load content on app start: the catalog saved on the device first, then what changed since.
    /// This is fully async to avoid blocking the main thread during startup
    private func loadInitialContentAsync() async {
        // PHASE 0: Run one-time migrations (gated by UserDefaults flags)
        // Must run before memory cache preload so cache loads already-migrated data
        storage.migrateRatingsToBinaryIfNeeded()
        storage.migrateRatedToSavedIfNeeded()

        // PHASE 1: Preload memory cache for fast sorting (critical for performance)
        await storage.preloadMemoryCacheAsync()

        // PHASE 2: Show the catalog saved on the device (renders behind splash)
        let saved = await catalog.loadFromDisk()

        if !saved.isEmpty {
            showFreshFeed(from: saved)

            // PHASE 3: Pick up jokes added or edited since the last sync. Normally done
            // long before the splash lifts, so new jokes lead the feed on this launch.
            if let updated = await syncCatalog() {
                let splashMayBeGone = Date().timeIntervalSince(launchedAt) > 4
                if splashMayBeGone {
                    mergeCatalogKeepingOrder(updated)
                } else {
                    showFreshFeed(from: updated)
                }
            }
        } else if let downloaded = await syncCatalog() {
            // First launch, or first launch after updating from a version without a catalog
            showFreshFeed(from: downloaded)
            // The small per-category cache older versions kept is no longer needed
            storage.clearCache()
        } else {
            // No catalog and no network: fall back to whatever an older version cached
            let legacy = await storage.loadAllCachedJokesAsync()
            if !legacy.isEmpty {
                showFreshFeed(from: legacy)
            }
        }

        await initializeJokeOfTheDayAsync()
        isInitialLoading = false
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

    // MARK: - Refresh

    /// Pull-to-refresh, and coming back after a long break: pick up new jokes, then put
    /// the feed in a new fresh-first order. Jokes seen since the last order drop down.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true

        _ = await syncCatalog()

        let source = catalog.jokes.isEmpty ? jokes : catalog.jokes
        if !source.isEmpty {
            showFreshFeed(from: source)
        }

        // Fetches a new joke of the day if the saved one is from another day
        await initializeJokeOfTheDayAsync()

        isRefreshing = false
    }

    // MARK: - Ratings

    func rateJoke(_ joke: Joke, rating: Int) {
        HapticManager.shared.selection()

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

    /// Filters the feed. The whole catalog is already in memory, so nothing is fetched.
    func selectCategory(_ category: JokeCategory?) {
        HapticManager.shared.lightTap()
        selectedCategory = category
    }

    // MARK: - Siri and Widget Caches

    /// Hands Siri and the widget a batch from the top of the feed, so they also lead
    /// with jokes this person hasn't seen. Both read these when they can't reach Firestore.
    private func updateSharedCaches(from jokes: [Joke]) {
        let sharedJokesForSiri = jokes.prefix(100).map { joke in
            SharedJoke(
                id: joke.firestoreId ?? joke.id.uuidString,
                setup: joke.setup,
                punchline: joke.punchline,
                character: joke.character,
                type: joke.category.rawValue
            )
        }
        sharedStorage.saveCachedJokesForSiri(Array(sharedJokesForSiri))

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
