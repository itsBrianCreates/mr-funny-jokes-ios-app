import WidgetKit
import SwiftUI

@main
struct JokeOfTheDayWidgetBundle: WidgetBundle {
    var body: some Widget {
        JokeOfTheDayWidget()
    }
}

struct JokeOfTheDayWidget: Widget {
    let kind: String = "JokeOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JokeOfTheDayProvider()) { entry in
            JokeOfTheDayWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    // Use system background - white in light mode, dark in dark mode
                    Color(UIColor.systemBackground)
                }
        }
        .configurationDisplayName("Joke of the Day")
        .description("Start your day with a smile! Get a fresh joke every day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
