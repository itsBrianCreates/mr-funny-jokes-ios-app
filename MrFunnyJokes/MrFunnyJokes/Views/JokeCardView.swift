import SwiftUI

struct JokeCardView: View {
    let joke: Joke
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void
    let onSave: () -> Void

    @State private var showingSheet = false

    /// The character associated with this joke, if any
    private var jokeCharacter: JokeCharacter? {
        guard let characterName = joke.character else { return nil }
        return JokeCharacter.find(byName: characterName)
    }

    /// Formats the card preview text, with special handling for knock-knock jokes
    private var cardPreviewText: String {
        if joke.category == .knockKnock {
            return formatKnockKnockPreview(joke.setup)
        }
        return joke.setup
    }

    /// Formats knock-knock setup for card preview with line break
    /// Input: "Knock, knock. Who's there? Nobel."
    /// Output: "Knock, knock. Who's there?\nNobel."
    private func formatKnockKnockPreview(_ setup: String) -> String {
        // Find "Who's there?" and add a line break after it
        if let range = setup.range(of: "Who's there?", options: .caseInsensitive) {
            let beforeAnswer = String(setup[...range.upperBound])
            let answer = String(setup[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !answer.isEmpty {
                return beforeAnswer + "\n" + answer
            }
        }
        return setup
    }

    var body: some View {
        Button {
            HapticManager.shared.mediumImpact()
            showingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Setup text (formatted for knock-knock jokes)
                Text(cardPreviewText)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Character, category and rating row
                HStack(spacing: 8) {
                    // Character indicator (if available)
                    if let character = jokeCharacter {
                        CharacterIndicatorView(character: character)
                    }

                    // Category
                    HStack(spacing: 4) {
                        Image(systemName: joke.category.icon)
                        Text(joke.category.rawValue)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    if let rating = joke.userRating {
                        CompactRatingView(rating: rating)
                    }
                }
            }
            .padding()
            .background(.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSheet) {
            JokeDetailSheet(
                joke: joke,
                isCopied: isCopied,
                onDismiss: { showingSheet = false },
                onShare: onShare,
                onCopy: onCopy,
                onRate: onRate,
                onSave: onSave
            )
        }
    }
}

// MARK: - Character Indicator View

/// A small circular indicator showing the character who tells this joke
struct CharacterIndicatorView: View {
    let character: JokeCharacter

    /// Size of the indicator circle
    private let size: CGFloat = 20

    var body: some View {
        HStack(spacing: 4) {
            // Small circular character image
            Image(character.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())

            // Character name
            Text(character.name)
                .font(.caption)
                .foregroundStyle(character.color)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            JokeCardView(
                joke: Joke(
                    category: .dadJoke,
                    setup: "Why don't scientists trust atoms?",
                    punchline: "Because they make up everything!",
                    character: "Mr. Funny"
                ),
                isCopied: false,
                onShare: {},
                onCopy: {},
                onRate: { _ in },
                onSave: {}
            )

            JokeCardView(
                joke: Joke(
                    category: .knockKnock,
                    setup: "Knock, knock. Who's there? Nobel.",
                    punchline: "Nobel who? Nobel … that's why I knocked.",
                    userRating: 1,
                    character: "Mr. Potty"
                ),
                isCopied: true,
                onShare: {},
                onCopy: {},
                onRate: { _ in },
                onSave: {}
            )

            JokeCardView(
                joke: Joke(
                    category: .pickupLine,
                    setup: "Are you a magician?",
                    punchline: "Because whenever I look at you, everyone else disappears!",
                    userRating: 5,
                    character: "Mr. Love"
                ),
                isCopied: false,
                onShare: {},
                onCopy: {},
                onRate: { _ in },
                onSave: {}
            )

            // Card without character
            JokeCardView(
                joke: Joke(
                    category: .dadJoke,
                    setup: "What do you call a fake noodle?",
                    punchline: "An impasta!"
                ),
                isCopied: false,
                onShare: {},
                onCopy: {},
                onRate: { _ in },
                onSave: {}
            )
        }
        .padding()
    }
}
