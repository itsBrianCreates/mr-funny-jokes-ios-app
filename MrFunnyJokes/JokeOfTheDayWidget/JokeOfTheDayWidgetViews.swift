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

    private var accentColor: Color {
        characterAccentColor(for: joke.character)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Badge with character accent color
            Text("JOKE OF THE DAY")
                .font(.system(size: 8, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(accentColor, in: RoundedRectangle(cornerRadius: 4))

            Spacer()

            // Joke setup only (no punchline to encourage tap)
            Text(joke.setup)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(4)
                .multilineTextAlignment(.leading)

            Spacer()

            // Character avatar with name
            HStack(spacing: 4) {
                if let imageName = characterImageName(for: joke.character) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(accentColor, lineWidth: 1)
                        )
                }
                if let name = characterDisplayName(for: joke.character) {
                    Text(name)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(accentColor)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "mrfunnyjokes://home"))
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let joke: SharedJokeOfTheDay

    private var accentColor: Color {
        characterAccentColor(for: joke.character)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Badge with character accent color
            Text("JOKE OF THE DAY")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentColor, in: RoundedRectangle(cornerRadius: 4))

            Spacer()

            // Joke setup only (no punchline to encourage tap)
            Text(joke.setup)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Spacer()

            // Character avatar with name
            HStack(spacing: 6) {
                if let imageName = characterImageName(for: joke.character) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(accentColor, lineWidth: 1.5)
                        )
                }
                if let name = characterDisplayName(for: joke.character) {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(accentColor)
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "mrfunnyjokes://home"))
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let joke: SharedJokeOfTheDay

    private var accentColor: Color {
        characterAccentColor(for: joke.character)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Badge with character accent color
            Text("JOKE OF THE DAY")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accentColor, in: RoundedRectangle(cornerRadius: 5))

            Spacer()

            // Joke setup only (no punchline to encourage tap)
            Text(joke.setup)
                .font(.title3)
                .fontWeight(.medium)
                .lineLimit(6)
                .multilineTextAlignment(.leading)

            Spacer()

            // Character avatar with name and category
            HStack(spacing: 10) {
                if let imageName = characterImageName(for: joke.character) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(accentColor, lineWidth: 2)
                        )
                }
                if let name = characterDisplayName(for: joke.character) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(accentColor)
                }

                Spacer()

                // Category label
                if let category = joke.category {
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

// MARK: - Character Colors

/// Returns the accent color for a character (border, badge, punchline)
func characterAccentColor(for character: String?) -> Color {
    guard let character = character else { return .widgetYellow }

    let normalizedName = character.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    switch normalizedName {
    case "mr_funny", "mr. funny", "mr funny", "mrfunny":
        return .widgetYellow
    case "mr_bad", "mr. bad", "mr bad", "mrbad":
        return .red
    case "mr_sad", "mr. sad", "mr sad", "mrsad":
        return .blue
    case "mr_potty", "mr. potty", "mr potty", "mrpotty":
        return .widgetBrown
    case "mr_love", "mr. love", "mr love", "mrlove":
        return .pink
    default:
        return .widgetYellow
    }
}

/// Returns the background color for a character's themed card
func characterBackgroundColor(for character: String?) -> Color {
    guard let character = character else { return .widgetYellowBackground }

    let normalizedName = character.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    switch normalizedName {
    case "mr_funny", "mr. funny", "mr funny", "mrfunny":
        return .widgetYellowBackground
    case "mr_bad", "mr. bad", "mr bad", "mrbad":
        return .widgetRedBackground
    case "mr_sad", "mr. sad", "mr sad", "mrsad":
        return .widgetBlueBackground
    case "mr_potty", "mr. potty", "mr potty", "mrpotty":
        return .widgetBrownBackground
    case "mr_love", "mr. love", "mr love", "mrlove":
        return .widgetPinkBackground
    default:
        return .widgetYellowBackground
    }
}

extension Color {
    /// Brand yellow accent for the widget
    static let widgetYellow = Color(red: 0.85, green: 0.65, blue: 0.0)

    /// Mr. Potty brown accent
    static let widgetBrown = Color(red: 0.55, green: 0.35, blue: 0.17)

    // MARK: - Character Background Colors

    /// Mr. Funny - warm cream/yellow tint
    static let widgetYellowBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.16, blue: 0.10, alpha: 1)
                : UIColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1)
        }
    )

    /// Mr. Bad - soft red tint
    static let widgetRedBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.12, blue: 0.12, alpha: 1)
                : UIColor(red: 1.0, green: 0.95, blue: 0.95, alpha: 1)
        }
    )

    /// Mr. Sad - soft blue tint
    static let widgetBlueBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1)
                : UIColor(red: 0.94, green: 0.96, blue: 1.0, alpha: 1)
        }
    )

    /// Mr. Potty - soft tan/beige
    static let widgetBrownBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.16, green: 0.14, blue: 0.10, alpha: 1)
                : UIColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 1)
        }
    )

    /// Mr. Love - soft pink tint
    static let widgetPinkBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.12, blue: 0.14, alpha: 1)
                : UIColor(red: 1.0, green: 0.95, blue: 0.97, alpha: 1)
        }
    )

    /// Legacy alias for backward compatibility
    static let widgetAccent = widgetYellow
}

// MARK: - Character Helpers

/// Maps character name or ID to the corresponding image asset name
func characterImageName(for character: String?) -> String? {
    guard let character = character else { return nil }

    let normalizedName = character.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

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

/// Returns the display name for a character
func characterDisplayName(for character: String?) -> String? {
    guard let character = character else { return nil }

    let normalizedName = character.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    switch normalizedName {
    case "mr_funny", "mr. funny", "mr funny", "mrfunny":
        return "Mr. Funny"
    case "mr_bad", "mr. bad", "mr bad", "mrbad":
        return "Mr. Bad"
    case "mr_sad", "mr. sad", "mr sad", "mrsad":
        return "Mr. Sad"
    case "mr_potty", "mr. potty", "mr potty", "mrpotty":
        return "Mr. Potty"
    case "mr_love", "mr. love", "mr love", "mrlove":
        return "Mr. Love"
    default:
        return nil
    }
}

// MARK: - Previews

#Preview("Small - Mr. Funny", as: .systemSmall) {
    JokeOfTheDayWidget()
} timeline: {
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

#Preview("Small - Mr. Bad", as: .systemSmall) {
    JokeOfTheDayWidget()
} timeline: {
    JokeOfTheDayEntry(
        date: .now,
        joke: SharedJokeOfTheDay(
            id: "2",
            setup: "I have a joke about trickle-down economics.",
            punchline: "But 99% of you won't get it.",
            category: "Dad Jokes",
            character: "mr_bad"
        )
    )
}

#Preview("Medium - Mr. Love", as: .systemMedium) {
    JokeOfTheDayWidget()
} timeline: {
    JokeOfTheDayEntry(
        date: .now,
        joke: SharedJokeOfTheDay(
            id: "3",
            setup: "Are you a magician?",
            punchline: "Because whenever I look at you, everyone else disappears!",
            category: "Pickup Lines",
            character: "mr_love"
        )
    )
}

#Preview("Medium - Mr. Sad", as: .systemMedium) {
    JokeOfTheDayWidget()
} timeline: {
    JokeOfTheDayEntry(
        date: .now,
        joke: SharedJokeOfTheDay(
            id: "4",
            setup: "Why did the scarecrow win an award?",
            punchline: "Because he was outstanding in his field!",
            category: "Dad Jokes",
            character: "mr_sad"
        )
    )
}

#Preview("Large - Mr. Potty", as: .systemLarge) {
    JokeOfTheDayWidget()
} timeline: {
    JokeOfTheDayEntry(
        date: .now,
        joke: SharedJokeOfTheDay(
            id: "5",
            setup: "Why did the toilet paper roll down the hill?",
            punchline: "To get to the bottom!",
            category: "Dad Jokes",
            character: "mr_potty"
        )
    )
}

#Preview("Large - Mr. Funny", as: .systemLarge) {
    JokeOfTheDayWidget()
} timeline: {
    JokeOfTheDayEntry(
        date: .now,
        joke: SharedJokeOfTheDay(
            id: "6",
            setup: "I told my wife she was drawing her eyebrows too high.",
            punchline: "She looked surprised.",
            category: "Dad Jokes",
            character: "mr_funny"
        )
    )
}
