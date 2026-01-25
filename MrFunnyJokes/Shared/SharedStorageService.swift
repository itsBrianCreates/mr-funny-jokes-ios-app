import Foundation

/// Service for sharing data between the main app and widget extension via App Groups
final class SharedStorageService {
    static let shared = SharedStorageService()

    /// App Group identifier - must match the App Group configured in Xcode
    static let appGroupIdentifier = "group.com.bvanaski.mrfunnyjokes"

    private let jokeOfTheDayKey = "jokeOfTheDay"
    private let cachedJokesKey = "cachedJokesForSiri"
    private let recentlyToldKey = "recentlyToldJokeIds"
    private let maxRecentlyTold = 10

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: SharedStorageService.appGroupIdentifier)
    }

    private init() {}

    // MARK: - Joke of the Day

    /// Save the joke of the day for widget access
    func saveJokeOfTheDay(_ joke: SharedJokeOfTheDay) {
        guard let defaults = sharedDefaults else { return }

        do {
            let data = try JSONEncoder().encode(joke)
            defaults.set(data, forKey: jokeOfTheDayKey)
        } catch {
            print("Failed to encode joke of the day: \(error)")
        }
    }

    /// Load the joke of the day for widget display
    func loadJokeOfTheDay() -> SharedJokeOfTheDay? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: jokeOfTheDayKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(SharedJokeOfTheDay.self, from: data)
        } catch {
            print("Failed to decode joke of the day: \(error)")
            return nil
        }
    }

    /// Check if the stored joke needs to be updated (new day)
    func needsUpdate() -> Bool {
        guard let joke = loadJokeOfTheDay() else { return true }

        let calendar = Calendar.current
        let storedDay = calendar.ordinality(of: .day, in: .year, for: joke.lastUpdated) ?? 0
        let currentDay = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1

        return storedDay != currentDay
    }

    // MARK: - Siri Joke Cache

    /// Save jokes for Siri access (call from main app after fetch)
    func saveCachedJokesForSiri(_ jokes: [SharedJoke]) {
        guard let defaults = sharedDefaults else { return }

        do {
            let data = try JSONEncoder().encode(jokes)
            defaults.set(data, forKey: cachedJokesKey)
        } catch {
            print("Failed to encode jokes for Siri: \(error)")
        }
    }

    /// Get random joke avoiding recent repeats
    func getRandomCachedJoke() -> SharedJoke? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: cachedJokesKey),
              let jokes = try? JSONDecoder().decode([SharedJoke].self, from: data),
              !jokes.isEmpty else {
            return nil
        }

        let recentIds = defaults.stringArray(forKey: recentlyToldKey) ?? []

        // Try to find a joke not recently told
        let unseenJokes = jokes.filter { !recentIds.contains($0.id) }
        let selectedJoke = unseenJokes.randomElement() ?? jokes.randomElement()!

        // Track this joke as recently told (FIFO, max 10)
        var updatedRecent = recentIds
        updatedRecent.append(selectedJoke.id)
        if updatedRecent.count > maxRecentlyTold {
            updatedRecent.removeFirst()
        }
        defaults.set(updatedRecent, forKey: recentlyToldKey)

        return selectedJoke
    }

    /// Get the count of cached jokes for Siri
    func getCachedJokeCount() -> Int {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: cachedJokesKey),
              let jokes = try? JSONDecoder().decode([SharedJoke].self, from: data) else {
            return 0
        }
        return jokes.count
    }
}
