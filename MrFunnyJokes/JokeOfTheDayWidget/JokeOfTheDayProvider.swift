import WidgetKit
import SwiftUI

struct JokeOfTheDayEntry: TimelineEntry {
    let date: Date
    let joke: SharedJokeOfTheDay
}

struct JokeOfTheDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> JokeOfTheDayEntry {
        JokeOfTheDayEntry(date: Date(), joke: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (JokeOfTheDayEntry) -> Void) {
        let joke = SharedStorageService.shared.loadJokeOfTheDay() ?? .placeholder
        let entry = JokeOfTheDayEntry(date: Date(), joke: joke)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JokeOfTheDayEntry>) -> Void) {
        let joke = SharedStorageService.shared.loadJokeOfTheDay() ?? .placeholder
        let currentDate = Date()

        // Create entry for current joke
        let entry = JokeOfTheDayEntry(date: currentDate, joke: joke)

        // Calculate next midnight for refresh
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)

        // Refresh once daily at midnight
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}
