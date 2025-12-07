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
        VStack(alignment: .leading, spacing: 4) {
            // Header with character photo
            HStack(spacing: 4) {
                if let characterImageName = characterImageName(for: joke.character) {
                    Image(characterImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                }
                Text("Joke of the Day")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Truncated setup text (teaser)
            Text(joke.setup)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(5)
                .multilineTextAlignment(.leading)

            Spacer()

            // Tap hint
            Text("Tap to reveal")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "mrfunnyjokes://home"))
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let joke: SharedJokeOfTheDay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with character photo
            HStack(spacing: 6) {
                if let characterImageName = characterImageName(for: joke.character) {
                    Image(characterImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                }
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
            // Header with character photo
            HStack(spacing: 8) {
                if let characterImageName = characterImageName(for: joke.character) {
                    Image(characterImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                }
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

// MARK: - Character Image Helper

/// Maps character name or ID to the corresponding image asset name
func characterImageName(for character: String?) -> String? {
    guard let character = character else { return nil }

    let normalizedName = character.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    // Map character IDs and names to their image asset names
    switch normalizedName {
    case "mr_funny", "mr. funny", "mr funny", "mrfunny":
        return "MrFunny"
    case "mr_bad", "mr. bad", "mr bad", "mrbad":
        return "MrBad"
    case "mr_sad", "mr. sad", "mr sad", "mrsad":
        return "MrSad"
    case "mr_potty", "mr. potty", "mr potty", "mrpotty":
        return "MrPotty"
    case "mr_love", "mr. love", "mr love", "mrlove":
        return "MrLove"
    default:
        return nil
    }
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
            category: "Dad Jokes",
            character: "mr_funny"
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
            category: "Dad Jokes",
            character: "mr_funny"
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
            category: "Dad Jokes",
            character: "mr_funny"
        )
    )
}
