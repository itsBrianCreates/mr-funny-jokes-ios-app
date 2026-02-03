import Foundation

final class LocalStorageService: @unchecked Sendable {
    static let shared = LocalStorageService()

    private let userDefaults: UserDefaults
    private let ratingsKey = "jokeRatings"
    private let ratingTimestampsKey = "jokeRatingTimestamps"
    private let impressionsKey = "jokeImpressions"
    private let cachedJokesKeyPrefix = "cachedJokes_"
    private let deviceIdKey = "anonymousDeviceId"
    private let queue = DispatchQueue(label: "com.mrfunnyjokes.storage", qos: .userInitiated)

    /// Maximum number of jokes to cache per category
    private let maxCachePerCategory = 50

    /// Maximum number of impressions to track (FIFO when exceeded)
    private let maxImpressions = 500

    // MARK: - In-Memory Cache (for fast access during startup)

    /// In-memory cache of impression IDs - loaded once, updated on writes
    private var cachedImpressionIds: Set<String>?

    /// In-memory cache of rated joke IDs - loaded once, updated on writes
    private var cachedRatedIds: Set<String>?

    /// Flag indicating if in-memory caches are loaded
    private var memoryCacheLoaded = false

    private init() {
        self.userDefaults = UserDefaults.standard
    }

    // MARK: - Memory Cache Preloading

    /// Preload impression and rating data into memory for fast access
    /// Call this early during app startup to eliminate disk reads during sorting
    func preloadMemoryCache() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if !self.memoryCacheLoaded {
                self.cachedImpressionIds = Set(self.loadImpressionsSync())
                self.cachedRatedIds = Set(self.loadRatingsSync().keys)
                self.memoryCacheLoaded = true
            }
        }
    }

    /// Async version: Preload and return when ready
    func preloadMemoryCacheAsync() async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                if !self.memoryCacheLoaded {
                    self.cachedImpressionIds = Set(self.loadImpressionsSync())
                    self.cachedRatedIds = Set(self.loadRatingsSync().keys)
                    self.memoryCacheLoaded = true
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Anonymous Device ID

    /// Get or create an anonymous device ID for rating event tracking
    /// This ID is used to deduplicate ratings per device per week
    /// It is NOT linked to any personal information
    func getDeviceId() -> String {
        if let existingId = userDefaults.string(forKey: deviceIdKey) {
            return existingId
        }

        let newId = UUID().uuidString
        userDefaults.set(newId, forKey: deviceIdKey)
        return newId
    }

    // MARK: - Hardcoded Jokes (Removed - Firebase only)

    /// Hardcoded jokes have been removed - app now uses Firebase as the only data source
    func loadHardcodedJokes() -> [Joke] {
        return []
    }

    /// Load fallback jokes for a specific category (disabled - Firebase only)
    func loadFallbackJokes(for category: JokeCategory) -> [Joke] {
        return []
    }

    // MARK: - Ratings

    /// Save rating using firestoreId as the key for cross-view consistency
    /// Falls back to UUID string if firestoreId is not available
    func saveRating(for jokeId: UUID, firestoreId: String?, rating: Int) {
        let key = firestoreId ?? jokeId.uuidString
        queue.sync {
            var ratings = self.loadRatingsSync()
            ratings[key] = rating
            self.saveRatingsSync(ratings)

            // Save timestamp for sorting (most recently rated first)
            var timestamps = self.loadRatingTimestampsSync()
            timestamps[key] = Date().timeIntervalSince1970
            self.saveRatingTimestampsSync(timestamps)

            // Update in-memory cache
            cachedRatedIds?.insert(key)
        }
    }

    /// Remove rating using firestoreId as the key
    func removeRating(for jokeId: UUID, firestoreId: String?) {
        let key = firestoreId ?? jokeId.uuidString
        queue.sync {
            var ratings = self.loadRatingsSync()
            ratings.removeValue(forKey: key)
            self.saveRatingsSync(ratings)

            // Remove timestamp as well
            var timestamps = self.loadRatingTimestampsSync()
            timestamps.removeValue(forKey: key)
            self.saveRatingTimestampsSync(timestamps)

            // Update in-memory cache
            cachedRatedIds?.remove(key)
        }
    }

    /// Get rating using firestoreId as the key for cross-view consistency
    func getRating(for jokeId: UUID, firestoreId: String?) -> Int? {
        let key = firestoreId ?? jokeId.uuidString
        return queue.sync {
            let ratings = self.loadRatingsSync()
            return ratings[key]
        }
    }

    // MARK: - Legacy Rating Methods (deprecated)

    @available(*, deprecated, message: "Use saveRating(for:firestoreId:rating:) instead")
    func saveRating(for jokeId: UUID, rating: Int) {
        queue.sync {
            var ratings = self.loadRatingsSync()
            ratings[jokeId.uuidString] = rating
            self.saveRatingsSync(ratings)
        }
    }

    @available(*, deprecated, message: "Use removeRating(for:firestoreId:) instead")
    func removeRating(for jokeId: UUID) {
        queue.sync {
            var ratings = self.loadRatingsSync()
            ratings.removeValue(forKey: jokeId.uuidString)
            self.saveRatingsSync(ratings)
        }
    }

    @available(*, deprecated, message: "Use getRating(for:firestoreId:) instead")
    func getRating(for jokeId: UUID) -> Int? {
        queue.sync {
            let ratings = self.loadRatingsSync()
            return ratings[jokeId.uuidString]
        }
    }

    private func loadRatingsSync() -> [String: Int] {
        return userDefaults.dictionary(forKey: ratingsKey) as? [String: Int] ?? [:]
    }

    private func saveRatingsSync(_ ratings: [String: Int]) {
        userDefaults.set(ratings, forKey: ratingsKey)
    }

    // MARK: - Rating Timestamps (for sorting by most recent)

    /// Get the timestamp when a joke was rated (for sorting)
    func getRatingTimestamp(for jokeId: UUID, firestoreId: String?) -> TimeInterval? {
        let key = firestoreId ?? jokeId.uuidString
        return queue.sync {
            let timestamps = self.loadRatingTimestampsSync()
            return timestamps[key]
        }
    }

    private func loadRatingTimestampsSync() -> [String: TimeInterval] {
        return userDefaults.dictionary(forKey: ratingTimestampsKey) as? [String: TimeInterval] ?? [:]
    }

    private func saveRatingTimestampsSync(_ timestamps: [String: TimeInterval]) {
        userDefaults.set(timestamps, forKey: ratingTimestampsKey)
    }

    private func loadRatings() -> [String: Int] {
        queue.sync {
            loadRatingsSync()
        }
    }

    private func applyStoredRatings(to jokes: [Joke]) -> [Joke] {
        let ratings = loadRatings()
        return jokes.map { joke in
            var updatedJoke = joke
            // Try firestoreId first (preferred), then fall back to UUID
            let key = joke.firestoreId ?? joke.id.uuidString
            if let rating = ratings[key] {
                updatedJoke.userRating = rating
            }
            return updatedJoke
        }
    }

    // MARK: - Impressions (Feed Freshness Tracking)

    /// Mark a joke as seen/impressed using firestoreId
    /// Used to prioritize unseen jokes in the feed
    func markImpression(firestoreId: String?) {
        guard let firestoreId = firestoreId else { return }
        queue.sync {
            var impressions = loadImpressionsSync()

            // Already tracked
            if impressions.contains(firestoreId) { return }

            // Add new impression
            impressions.append(firestoreId)

            // FIFO: Remove oldest if over limit
            if impressions.count > maxImpressions {
                impressions.removeFirst(impressions.count - maxImpressions)
            }

            saveImpressionsSync(impressions)

            // Update in-memory cache
            cachedImpressionIds?.insert(firestoreId)
        }
    }

    /// Check if a joke has been seen/impressed
    func hasImpression(firestoreId: String?) -> Bool {
        guard let firestoreId = firestoreId else { return false }
        return queue.sync {
            let impressions = loadImpressionsSync()
            return impressions.contains(firestoreId)
        }
    }

    /// Get all impression IDs (for batch checking)
    /// Uses in-memory cache if available for fast access
    func getImpressionIds() -> Set<String> {
        return queue.sync {
            if let cached = cachedImpressionIds {
                return cached
            }
            let ids = Set(loadImpressionsSync())
            cachedImpressionIds = ids
            return ids
        }
    }

    /// Get all rated joke IDs (for batch checking)
    /// Uses in-memory cache if available for fast access
    func getRatedJokeIds() -> Set<String> {
        return queue.sync {
            if let cached = cachedRatedIds {
                return cached
            }
            let ids = Set(loadRatingsSync().keys)
            cachedRatedIds = ids
            return ids
        }
    }

    /// Fast, non-blocking access to impression IDs from memory cache
    /// Returns empty set if cache not yet loaded - use preloadMemoryCacheAsync() first
    func getImpressionIdsFast() -> Set<String> {
        return cachedImpressionIds ?? []
    }

    /// Fast, non-blocking access to rated joke IDs from memory cache
    /// Returns empty set if cache not yet loaded - use preloadMemoryCacheAsync() first
    func getRatedJokeIdsFast() -> Set<String> {
        return cachedRatedIds ?? []
    }

    /// Clear all impressions (used on pull-to-refresh for a fresh feed)
    func clearImpressions() {
        queue.sync {
            userDefaults.removeObject(forKey: impressionsKey)
            cachedImpressionIds = []
        }
    }

    private func loadImpressionsSync() -> [String] {
        return userDefaults.stringArray(forKey: impressionsKey) ?? []
    }

    private func saveImpressionsSync(_ impressions: [String]) {
        userDefaults.set(impressions, forKey: impressionsKey)
    }

    // MARK: - Per-Category Cached Jokes

    private func cacheKey(for category: JokeCategory) -> String {
        return cachedJokesKeyPrefix + category.rawValue.replacingOccurrences(of: " ", with: "_")
    }

    /// Save jokes to cache for a specific category (keeps last 20)
    func saveCachedJokes(_ jokes: [Joke], for category: JokeCategory) {
        queue.sync {
            let key = cacheKey(for: category)

            // Load existing cached jokes
            var existingJokes: [Joke] = []
            if let data = userDefaults.data(forKey: key) {
                existingJokes = (try? JSONDecoder().decode([Joke].self, from: data)) ?? []
            }

            // Add new jokes, avoiding duplicates
            for joke in jokes where joke.category == category {
                if !existingJokes.contains(where: { $0.setup == joke.setup && $0.punchline == joke.punchline }) {
                    existingJokes.insert(joke, at: 0) // Insert at beginning (newest first)
                }
            }

            // Keep only the most recent maxCachePerCategory jokes
            if existingJokes.count > maxCachePerCategory {
                existingJokes = Array(existingJokes.prefix(maxCachePerCategory))
            }

            // Save
            if let data = try? JSONEncoder().encode(existingJokes) {
                userDefaults.set(data, forKey: key)
            }
        }
    }

    /// Load cached jokes for a specific category
    func loadCachedJokes(for category: JokeCategory) -> [Joke] {
        let data: Data? = queue.sync {
            userDefaults.data(forKey: cacheKey(for: category))
        }

        guard let data = data else { return [] }

        do {
            let jokes = try JSONDecoder().decode([Joke].self, from: data)
            return applyStoredRatings(to: jokes)
        } catch {
            return []
        }
    }

    /// Load all cached jokes across all categories
    func loadAllCachedJokes() -> [Joke] {
        var allJokes: [Joke] = []
        for category in JokeCategory.allCases {
            allJokes.append(contentsOf: loadCachedJokes(for: category))
        }
        return allJokes
    }

    // MARK: - Async Cache Loading (Non-blocking)

    /// Load cached jokes for a specific category asynchronously (non-blocking)
    func loadCachedJokesAsync(for category: JokeCategory) async -> [Joke] {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                guard let data = self.userDefaults.data(forKey: self.cacheKey(for: category)) else {
                    continuation.resume(returning: [])
                    return
                }

                do {
                    let jokes = try JSONDecoder().decode([Joke].self, from: data)
                    let ratingsDict = self.userDefaults.dictionary(forKey: self.ratingsKey) as? [String: Int] ?? [:]

                    // Apply ratings inline to avoid additional sync calls
                    let jokesWithRatings = jokes.map { joke in
                        var updatedJoke = joke
                        let key = joke.firestoreId ?? joke.id.uuidString
                        if let rating = ratingsDict[key] {
                            updatedJoke.userRating = rating
                        }
                        return updatedJoke
                    }

                    continuation.resume(returning: jokesWithRatings)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Load all cached jokes across all categories asynchronously (non-blocking)
    /// Uses concurrent loading for better performance
    func loadAllCachedJokesAsync() async -> [Joke] {
        await withTaskGroup(of: [Joke].self) { group in
            for category in JokeCategory.allCases {
                group.addTask {
                    await self.loadCachedJokesAsync(for: category)
                }
            }

            var allJokes: [Joke] = []
            for await jokes in group {
                allJokes.append(contentsOf: jokes)
            }
            return allJokes
        }
    }

    /// Append a single joke to the appropriate category cache
    func appendCachedJoke(_ joke: Joke) {
        saveCachedJokes([joke], for: joke.category)
    }

    /// Check if we have any cached content
    func hasCachedContent() -> Bool {
        for category in JokeCategory.allCases {
            if !loadCachedJokes(for: category).isEmpty {
                return true
            }
        }
        return false
    }

    /// Get the count of cached jokes per category
    func cachedJokesCount() -> [JokeCategory: Int] {
        var counts: [JokeCategory: Int] = [:]
        for category in JokeCategory.allCases {
            counts[category] = loadCachedJokes(for: category).count
        }
        return counts
    }

    // MARK: - Legacy Support (deprecated, use category-specific methods)

    @available(*, deprecated, message: "Use loadAllCachedJokes() instead")
    func loadCachedJokes() -> [Joke] {
        return loadAllCachedJokes()
    }

    @available(*, deprecated, message: "Use saveCachedJokes(_:for:) instead")
    func saveCachedJokes(_ jokes: [Joke]) {
        // Group by category and save
        let grouped = Dictionary(grouping: jokes, by: { $0.category })
        for (category, categoryJokes) in grouped {
            saveCachedJokes(categoryJokes, for: category)
        }
    }

    // MARK: - Clear Cache

    func clearCache() {
        queue.sync {
            for category in JokeCategory.allCases {
                userDefaults.removeObject(forKey: cacheKey(for: category))
            }
        }
    }

    /// Clear cache for a specific category
    func clearCache(for category: JokeCategory) {
        queue.sync {
            userDefaults.removeObject(forKey: cacheKey(for: category))
        }
    }

    /// Replace all cached jokes for a category (clears old cache first)
    func replaceCachedJokes(_ jokes: [Joke], for category: JokeCategory) {
        queue.sync {
            let key = cacheKey(for: category)
            let categoryJokes = jokes.filter { $0.category == category }

            // Keep only the most recent maxCachePerCategory jokes
            let jokesToCache = Array(categoryJokes.prefix(maxCachePerCategory))

            // Save (replaces existing cache entirely)
            if let data = try? JSONEncoder().encode(jokesToCache) {
                userDefaults.set(data, forKey: key)
            }
        }
    }

}
