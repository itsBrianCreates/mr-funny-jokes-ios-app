import SwiftUI

struct JokeCardView: View {
    let joke: Joke
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void
    let onSave: () -> Void
    let onView: () -> Void
    /// Laugh and Horrible counts; the joke's own when not given
    var counts: JokeCounts? = nil
    /// Called with the new Laugh state; falls back to `onRate`
    var onLaugh: ((Bool) -> Void)? = nil
    /// When set, a tap hands the joke to the caller instead of opening this card's own sheet
    var onSelect: (() -> Void)? = nil
    /// Highlights the card while its joke is shown in a detail pane
    var isSelected = false

    @State private var showingSheet = false

    /// The character associated with this joke, if any
    private var jokeCharacter: JokeCharacter? {
        guard let characterName = joke.character else { return nil }
        return JokeCharacter.find(byName: characterName)
    }

    private func open() {
        HapticManager.shared.mediumImpact()
        if let onSelect {
            onSelect()
        } else {
            showingSheet = true
        }
        onView()
    }

    var body: some View {
        JokeCardLayout(
            joke: joke,
            counts: counts ?? JokeCounts(laughs: joke.likes, shares: joke.shares, horribles: joke.dislikes),
            background: AnyShapeStyle(.cardBackground),
            selectionColor: isSelected ? .accessibleYellow : nil,
            onOpen: open,
            onLaugh: onLaugh ?? { isOn in onRate(isOn ? 5 : 0) },
            onHorrible: { onRate(joke.userRating == 1 ? 0 : 1) }
        ) {
            if let character = jokeCharacter {
                CharacterIndicatorView(character: character)
            }
        }
        .jokeCardMenu(joke: joke, onCopy: onCopy, onSave: onSave)
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

// MARK: - Card Layout

/// A feed card: the setup, then one row with who tells it (or the joke type on a
/// character's page) on the left and the Laugh and Horrible counts on the right.
/// The text and the left of the row open the joke; the two faces vote in place.
struct JokeCardLayout<Byline: View>: View {
    let joke: Joke
    let counts: JokeCounts
    let background: AnyShapeStyle
    /// Outline while the joke is shown in a detail pane
    var selectionColor: Color? = nil
    let onOpen: () -> Void
    let onLaugh: (Bool) -> Void
    /// Toggles the Horrible rating
    let onHorrible: () -> Void
    @ViewBuilder let byline: Byline

    private let shape = RoundedRectangle(cornerRadius: 16)

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) {
                // Setup only; the punchline waits for the tap
                Text(joke.cardText)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Never give up lines to the flexible row below
                    .fixedSize(horizontal: false, vertical: true)
                    .padding([.horizontal, .top], 16)
                    .padding(.bottom, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(joke.hasPunchline ? "Opens the joke to show the punchline" : "Opens the joke")

            HStack(spacing: 0) {
                Button(action: onOpen) {
                    byline
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the joke")

                InlineVoteCounts(
                    joke: joke,
                    counts: counts,
                    onLaugh: onLaugh,
                    onHorrible: onHorrible
                )
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .padding(.bottom, 4)
            // Sits at the bottom when a grid row stretches the card. A flexible frame
            // rather than a Spacer, which would add a gap above this row.
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(background, in: shape)
        .overlay {
            if let selectionColor {
                shape.strokeBorder(selectionColor, lineWidth: 2)
            }
        }
        .contentShape(.contextMenuPreview, shape)
    }
}

// MARK: - Character Indicator View

/// A small circular indicator showing the character who tells this joke
struct CharacterIndicatorView: View {
    let character: JokeCharacter

    /// The same size as the faces at the other end of the card's row
    private let size = JokeCardMetrics.rowIconSize

    var body: some View {
        HStack(spacing: 6) {
            // Small circular character image
            Image(character.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())

            // Character name
            Text(character.name)
                .font(JokeCardMetrics.rowFont.weight(.medium))
                .foregroundStyle(character.color)
                .lineLimit(1)
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
                onSave: {},
                onView: {}
            )

            JokeCardView(
                joke: Joke(
                    category: .knockKnock,
                    setup: "Knock, knock.\nWho's there?\nNobel.",
                    punchline: "Nobel who?\nNo bell… that's why I knocked.",
                    userRating: 1,
                    character: "Mr. Potty"
                ),
                isCopied: true,
                onShare: {},
                onCopy: {},
                onRate: { _ in },
                onSave: {},
                onView: {}
            )

            JokeCardView(
                joke: Joke(
                    category: .pickupLine,
                    setup: "Do you believe in love at first sight,",
                    punchline: "or should I walk by again?",
                    userRating: 5,
                    character: "Mr. Love"
                ),
                isCopied: false,
                onShare: {},
                onCopy: {},
                onRate: { _ in },
                onSave: {},
                onView: {}
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
                onSave: {},
                onView: {}
            )
        }
        .padding()
    }
}
