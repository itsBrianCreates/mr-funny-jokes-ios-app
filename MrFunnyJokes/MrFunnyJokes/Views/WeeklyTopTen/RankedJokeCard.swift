import SwiftUI

/// A joke card with rank badge and rating count for the Weekly Top 10
struct RankedJokeCard: View {
    let rankedJoke: RankedJoke
    let rankingType: RankingType
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void

    @State private var showingSheet = false

    /// The character associated with this joke, if any
    private var jokeCharacter: JokeCharacter? {
        guard let characterName = rankedJoke.joke.character else { return nil }
        return JokeCharacter.find(byName: characterName)
    }

    /// Formats the card preview text, with special handling for knock-knock jokes
    private var cardPreviewText: String {
        if rankedJoke.joke.category == .knockKnock {
            return formatKnockKnockPreview(rankedJoke.joke.setup)
        }
        return rankedJoke.joke.setup
    }

    /// Formats knock-knock setup for card preview with line break
    private func formatKnockKnockPreview(_ setup: String) -> String {
        if let range = setup.range(of: "Who's there?", options: .caseInsensitive) {
            let beforeAnswer = String(setup[...range.upperBound])
            let answer = String(setup[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !answer.isEmpty {
                return beforeAnswer + "\n" + answer
            }
        }
        return setup
    }

    /// Badge color based on rank
    private var badgeColor: Color {
        switch rankedJoke.rank {
        case 1:
            return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold for #1
        default:
            return Color.secondary.opacity(0.3) // Subtle gray for all others
        }
    }

    /// Badge text color for contrast
    private var badgeTextColor: Color {
        switch rankedJoke.rank {
        case 1:
            return .black
        default:
            return .primary
        }
    }

    var body: some View {
        Button {
            HapticManager.shared.mediumImpact()
            showingSheet = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Rank badge
                RankBadge(rank: rankedJoke.rank, color: badgeColor, textColor: badgeTextColor)

                // Joke content
                VStack(alignment: .leading, spacing: 10) {
                    // Setup text
                    Text(cardPreviewText)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3)

                    // Metadata row
                    HStack(spacing: 8) {
                        // Character indicator (if available)
                        if let character = jokeCharacter {
                            CharacterIndicatorView(character: character)
                        }

                        Spacer()

                        // Rating count with emoji
                        HStack(spacing: 4) {
                            Text(rankingType.emoji)
                                .font(.caption)
                            Text("\(rankedJoke.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
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
                joke: rankedJoke.joke,
                isCopied: isCopied,
                onDismiss: { showingSheet = false },
                onShare: onShare,
                onCopy: onCopy,
                onRate: onRate
            )
        }
    }
}

// MARK: - Rank Badge

struct RankBadge: View {
    let rank: Int
    let color: Color
    let textColor: Color

    /// Size of the badge
    private let size: CGFloat = 36

    /// Special icon for #1
    private var isChampion: Bool {
        rank == 1
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(color)
                .frame(width: size, height: size)

            if isChampion {
                // Trophy for #1
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(textColor)
            } else {
                // Rank number
                Text("#\(rank)")
                    .font(.system(size: rank < 10 ? 14 : 12, weight: .bold))
                    .foregroundStyle(textColor)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // #1 - Gold with crown
            RankedJokeCard(
                rankedJoke: RankedJoke(
                    rank: 1,
                    count: 347,
                    joke: Joke(
                        category: .dadJoke,
                        setup: "Why don't scientists trust atoms?",
                        punchline: "Because they make up everything!",
                        character: "mr_funny"
                    )
                ),
                rankingType: .hilarious,
                isCopied: false,
                onShare: {},
                onCopy: {},
                onRate: { _ in }
            )

            // #2 - Silver
            RankedJokeCard(
                rankedJoke: RankedJoke(
                    rank: 2,
                    count: 298,
                    joke: Joke(
                        category: .dadJoke,
                        setup: "I told my wife she was drawing her eyebrows too high.",
                        punchline: "She looked surprised.",
                        character: "mr_funny"
                    )
                ),
                rankingType: .hilarious,
                isCopied: false,
                onShare: {},
                onCopy: {},
                onRate: { _ in }
            )

            // #3 - Bronze
            RankedJokeCard(
                rankedJoke: RankedJoke(
                    rank: 3,
                    count: 245,
                    joke: Joke(
                        category: .knockKnock,
                        setup: "Knock, knock. Who's there? Nobel.",
                        punchline: "Nobel who? Nobel, that's why I knocked!",
                        character: "mr_funny"
                    )
                ),
                rankingType: .hilarious,
                isCopied: false,
                onShare: {},
                onCopy: {},
                onRate: { _ in }
            )

            // #10 - Regular
            RankedJokeCard(
                rankedJoke: RankedJoke(
                    rank: 10,
                    count: 89,
                    joke: Joke(
                        category: .dadJoke,
                        setup: "What do you call a fake noodle?",
                        punchline: "An impasta!",
                        character: "mr_potty"
                    )
                ),
                rankingType: .horrible,
                isCopied: false,
                onShare: {},
                onCopy: {},
                onRate: { _ in }
            )
        }
        .padding()
    }
}
