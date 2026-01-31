import WidgetKit
import SwiftUI

struct JokeOfTheDayEntry: TimelineEntry {
    let date: Date
    let joke: SharedJokeOfTheDay
}

struct JokeOfTheDayProvider: TimelineProvider {

    /// Eastern Time timezone for consistent refresh scheduling with Cloud Functions
    private static let easternTime = TimeZone(identifier: "America/New_York")!

    /// Staleness threshold: 24 hours in seconds
    private static let stalenessThreshold: TimeInterval = 86400

    func placeholder(in context: Context) -> JokeOfTheDayEntry {
        JokeOfTheDayEntry(date: Date(), joke: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (JokeOfTheDayEntry) -> Void) {
        let joke = SharedStorageService.shared.loadJokeOfTheDay() ?? .placeholder
        let entry = JokeOfTheDayEntry(date: Date(), joke: joke)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JokeOfTheDayEntry>) -> Void) {
        Task {
            let joke = await resolveJokeForDisplay()
            let entry = JokeOfTheDayEntry(date: Date(), joke: joke)

            // Schedule next refresh at midnight ET
            let nextRefresh = nextMidnightET()
            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    // MARK: - Private Helpers

    /// Resolve the joke to display using a cascade of sources:
    /// 1. Fresh data from main app (< 24 hours old)
    /// 2. Direct fetch from Firestore REST API
    /// 3. Random fallback joke from cache (graceful degradation per WIDGET-03)
    /// 4. Placeholder (fresh install, no cache)
    private func resolveJokeForDisplay() async -> SharedJokeOfTheDay {
        let sharedStorage = SharedStorageService.shared

        // Step 1: Check for fresh data from main app
        if let savedJoke = sharedStorage.loadJokeOfTheDay() {
            if !isStale(savedJoke.lastUpdated) {
                // Data is fresh (< 24 hours old), use it
                return savedJoke
            }
        }

        // Step 2: Data is stale or missing - try direct fetch from Firestore
        if let fetchedJoke = await WidgetDataFetcher.fetchJokeOfTheDay() {
            // Save to shared storage for future use
            sharedStorage.saveJokeOfTheDay(fetchedJoke)
            return fetchedJoke
        }

        // Step 3: Network failed - use cached fallback (graceful degradation per WIDGET-03)
        if let fallbackJoke = sharedStorage.getRandomFallbackJoke() {
            return fallbackJoke
        }

        // Step 4: No cache (fresh install) - return placeholder
        return .placeholder
    }

    /// Check if the given date is stale (older than 24 hours)
    private func isStale(_ date: Date) -> Bool {
        return Date().timeIntervalSince(date) > Self.stalenessThreshold
    }

    /// Calculate the next midnight in Eastern Time
    /// This ensures widgets refresh at midnight ET regardless of device timezone
    private func nextMidnightET() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.easternTime

        // Get tomorrow's date in ET
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!

        // Get start of day (midnight) for tomorrow in ET
        return calendar.startOfDay(for: tomorrow)
    }
}
