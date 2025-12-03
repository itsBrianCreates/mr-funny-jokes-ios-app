import SwiftUI

struct JokeCardView: View {
    let joke: Joke
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void

    @State private var showingSheet = false

    /// The character associated with this joke, if any
    private var character: Character? {
        guard let characterName = joke.character else { return nil }
        return Character.find(byName: characterName)
    }

    var body: some View {
        Button {
            HapticManager.shared.mediumImpact()
            showingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Setup text
                Text(joke.setup)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Character, category and rating row
                HStack(spacing: 8) {
                    // Character indicator (if available)
                    if let character = character {
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
                        CompactGroanOMeterView(rating: rating)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSheet) {
            JokeDetailSheet(
                joke: joke,
                isCopied: isCopied,
                onDismiss: { showingSheet = false },
                onShare: onShare,
                onCopy: onCopy,
                onRate: onRate
            )
        }
    }
}

// MARK: - Character Indicator View

/// A small circular indicator showing the character who tells this joke
struct CharacterIndicatorView: View {
    let character: Character

    /// Size of the indicator circle
    private let size: CGFloat = 20

    var body: some View {
        HStack(spacing: 4) {
            // Small circular icon
            ZStack {
                Circle()
                    .fill(character.color.opacity(0.2))
                    .frame(width: size, height: size)

                Image(systemName: character.sfSymbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(character.color)
            }

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
                onRate: { _ in }
            )

            JokeCardView(
                joke: Joke(
                    category: .knockKnock,
                    setup: "Knock knock. Who's there? Lettuce.",
                    punchline: "Lettuce who? Lettuce in, it's cold out here!",
                    userRating: 3,
                    character: "Mr. Potty"
                ),
                isCopied: true,
                onShare: {},
                onCopy: {},
                onRate: { _ in }
            )

            JokeCardView(
                joke: Joke(
                    category: .pickupLine,
                    setup: "Are you a magician?",
                    punchline: "Because whenever I look at you, everyone else disappears!",
                    userRating: 4,
                    character: "Mr. Love"
                ),
                isCopied: false,
                onShare: {},
                onCopy: {},
                onRate: { _ in }
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
                onRate: { _ in }
            )
        }
        .padding()
    }
}
