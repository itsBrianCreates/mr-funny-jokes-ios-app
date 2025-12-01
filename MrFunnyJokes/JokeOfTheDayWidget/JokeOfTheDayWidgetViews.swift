import SwiftUI
import WidgetKit

struct JokeOfTheDayWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: JokeOfTheDayProvider.Entry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(joke: entry.joke)
        case .systemMedium:
            MediumWidgetView(joke: entry.joke)
        case .systemLarge:
            LargeWidgetView(joke: entry.joke)
        default:
            SmallWidgetView(joke: entry.joke)
        }
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let joke: SharedJokeOfTheDay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 4) {
                Text("😄")
                    .font(.caption)
                Text("Joke of the Day")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Truncated setup text (teaser)
            Text(joke.setup)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(4)
                .multilineTextAlignment(.leading)

            Spacer()

            // Tap hint
            Text("Tap to reveal")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "mrfunnyjokes://home"))
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let joke: SharedJokeOfTheDay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 4) {
                Text("😄")
                    .font(.subheadline)
                Text("Joke of the Day")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            // Full joke
            VStack(alignment: .leading, spacing: 6) {
                Text(joke.setup)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(joke.punchline)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.widgetAccent)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "mrfunnyjokes://home"))
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let joke: SharedJokeOfTheDay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Text("😄")
                    .font(.title3)
                Text("Joke of the Day")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            // Full joke with larger typography
            VStack(alignment: .leading, spacing: 16) {
                Text(joke.setup)
                    .font(.title3)
                    .fontWeight(.medium)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)

                Text(joke.punchline)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.widgetAccent)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            // Category label
            if let category = joke.category {
                HStack {
                    Spacer()
                    Text(category)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "mrfunnyjokes://home"))
    }
}

// MARK: - Widget Accent Color

extension Color {
    /// Brand yellow accent for the widget
    static let widgetAccent = Color(red: 0.85, green: 0.65, blue: 0.0)
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    JokeOfTheDayWidget()
} timeline: {
    JokeOfTheDayEntry(date: .now, joke: .placeholder)
    JokeOfTheDayEntry(
        date: .now,
        joke: SharedJokeOfTheDay(
            id: "1",
            setup: "What do you call a fake noodle?",
            punchline: "An impasta!",
            category: "Dad Jokes"
        )
    )
}

#Preview("Medium", as: .systemMedium) {
    JokeOfTheDayWidget()
} timeline: {
    JokeOfTheDayEntry(date: .now, joke: .placeholder)
    JokeOfTheDayEntry(
        date: .now,
        joke: SharedJokeOfTheDay(
            id: "1",
            setup: "Why did the scarecrow win an award?",
            punchline: "Because he was outstanding in his field!",
            category: "Dad Jokes"
        )
    )
}

#Preview("Large", as: .systemLarge) {
    JokeOfTheDayWidget()
} timeline: {
    JokeOfTheDayEntry(date: .now, joke: .placeholder)
    JokeOfTheDayEntry(
        date: .now,
        joke: SharedJokeOfTheDay(
            id: "1",
            setup: "I told my wife she was drawing her eyebrows too high.",
            punchline: "She looked surprised.",
            category: "Dad Jokes"
        )
    )
}
