import Foundation

final class LocalStorageService: @unchecked Sendable {
    static let shared = LocalStorageService()

    private let userDefaults: UserDefaults
    private let ratingsKey = "jokeRatings"
    private let cachedJokesKey = "cachedJokes"
    private let queue = DispatchQueue(label: "com.mrfunnyjokes.storage", qos: .userInitiated)

    private init() {
        self.userDefaults = UserDefaults.standard
    }

    // MARK: - Hardcoded Jokes

    func loadHardcodedJokes() -> [Joke] {
        guard let url = Bundle.main.url(forResource: "HardcodedJokes", withExtension: "json") else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let jokes = try JSONDecoder().decode([Joke].self, from: data)
            return applyStoredRatings(to: jokes)
        } catch {
            // Return empty array instead of crashing
            return []
        }
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

    // MARK: - Cached API Jokes

    func saveCachedJokes(_ jokes: [Joke]) {
        queue.sync {
            do {
                let data = try JSONEncoder().encode(jokes)
                self.userDefaults.set(data, forKey: self.cachedJokesKey)
            } catch {
                // Silently fail - not critical
            }
        }
    }

    func loadCachedJokes() -> [Joke] {
        let data: Data? = queue.sync {
            self.userDefaults.data(forKey: self.cachedJokesKey)
        }

        guard let data = data else {
            return []
        }

        do {
            let jokes = try JSONDecoder().decode([Joke].self, from: data)
            return applyStoredRatings(to: jokes)
        } catch {
            // Return empty array on decode failure
            return []
        }
    }

    func appendCachedJoke(_ joke: Joke) {
        queue.sync {
            // Load existing jokes
            var jokes: [Joke] = []
            if let data = self.userDefaults.data(forKey: self.cachedJokesKey) {
                jokes = (try? JSONDecoder().decode([Joke].self, from: data)) ?? []
            }

            // Avoid duplicates based on setup text
            guard !jokes.contains(where: { $0.setup == joke.setup }) else { return }

            jokes.append(joke)

            // Save updated list
            if let data = try? JSONEncoder().encode(jokes) {
                self.userDefaults.set(data, forKey: self.cachedJokesKey)
            }
        }
    }
}
