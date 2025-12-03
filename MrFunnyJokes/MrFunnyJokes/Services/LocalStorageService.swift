import Foundation

final class LocalStorageService: @unchecked Sendable {
    static let shared = LocalStorageService()

    private let userDefaults: UserDefaults
    private let ratingsKey = "jokeRatings"
    private let cachedJokesKeyPrefix = "cachedJokes_"
    private let queue = DispatchQueue(label: "com.mrfunnyjokes.storage", qos: .userInitiated)

    /// Maximum number of jokes to cache per category
    private let maxCachePerCategory = 50

    private init() {
        self.userDefaults = UserDefaults.standard
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

    func saveRating(for jokeId: UUID, rating: Int) {
        queue.sync {
            var ratings = self.loadRatingsSync()
            ratings[jokeId.uuidString] = rating
            self.saveRatingsSync(ratings)
        }
    }

    func removeRating(for jokeId: UUID) {
        queue.sync {
            var ratings = self.loadRatingsSync()
            ratings.removeValue(forKey: jokeId.uuidString)
            self.saveRatingsSync(ratings)
        }
    }

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

    private func loadRatings() -> [String: Int] {
        queue.sync {
            loadRatingsSync()
        }
    }

    private func applyStoredRatings(to jokes: [Joke]) -> [Joke] {
        let ratings = loadRatings()
        return jokes.map { joke in
            var updatedJoke = joke
            if let rating = ratings[joke.id.uuidString] {
                updatedJoke.userRating = rating
            }
            return updatedJoke
        }
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
}
