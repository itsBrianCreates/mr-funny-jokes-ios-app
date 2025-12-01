import Foundation

/// Service for sharing data between the main app and widget extension via App Groups
final class SharedStorageService {
    static let shared = SharedStorageService()

    /// App Group identifier - must match the App Group configured in Xcode
    static let appGroupIdentifier = "group.com.bvanaski.mrfunnyjokes"

    private let jokeOfTheDayKey = "jokeOfTheDay"

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
}
