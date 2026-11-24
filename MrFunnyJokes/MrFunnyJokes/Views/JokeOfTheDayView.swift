import SwiftUI

/// The Joke of the Day on Home: the setup, who's telling it, and a row to laugh,
/// share or do more. Tapping the joke opens it full screen for the punchline.
struct JokeOfTheDayView: View {
    let joke: Joke
    /// Laugh and share counts. Shown only once they pass `JokeEngagement`'s thresholds.
    var counts = JokeCounts(laughs: 0, shares: 0)
    /// Opens the joke full screen
    let onOpen: () -> Void
    /// Called with the new Laugh state
    let onLaugh: (Bool) -> Void
    let onShare: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void
    /// The Horrible rating, under More
    let onNotFunny: () -> Void

    @State private var showingStylePicker = false
    @State private var isAppearing = false

    /// The character associated with this joke, if any
    private var jokeCharacter: JokeCharacter? { joke.teller }

    /// Today's date formatted
    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    /// Border/accent color - uses character color if available, otherwise brand yellow
    private var accentColor: Color {
        jokeCharacter?.color ?? .accessibleYellow
    }

    /// Background color - uses character's themed background if available
    private var cardBackground: Color {
        jokeCharacter?.backgroundColor ?? Color(
            light: Color(red: 1.0, green: 0.98, blue: 0.94),  // Warm cream
            dark: Color(red: 0.18, green: 0.16, blue: 0.10)   // Warm dark
        )
    }

    private var hint: String {
        joke.hasPunchline ? "Tap to see the punchline" : "Tap to open"
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                HapticManager.shared.mediumImpact()
                onOpen()
            } label: {
                jokeSection
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(hint)

            Divider()
                .padding(.horizontal, 16)

            actionRow
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor, lineWidth: 2)
        )
        .scaleEffect(isAppearing ? 1 : 0.95)
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
        .fullScreenCover(isPresented: $showingStylePicker) {
            ShareStylePickerView(joke: joke)
        }
    }

    // MARK: - Joke

    private var jokeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("JOKE OF THE DAY")
                    .font(.caption.weight(.heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 6))

                Spacer(minLength: 8)

                Text(todayString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Setup only; the punchline waits for the tap
            Text(joke.cardText)
                .font(.title2.weight(.heavy))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                if let character = jokeCharacter {
                    Image(character.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(accentColor, lineWidth: 2)
                        )
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(jokeCharacter?.name ?? joke.category.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    // MARK: - Laugh, Share, More

    private var actionRow: some View {
        HStack(spacing: 0) {
            LaughButton(
                isOn: joke.userRating == 5,
                label: JokeEngagement.laughLabel(counts.laughs),
                onToggle: onLaugh
            )

            Button(action: onShare) {
                StackedActionLabel(
                    systemImage: "square.and.arrow.up",
                    label: JokeEngagement.shareLabel(counts.shares)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")

            Menu {
                JokeMoreMenuItems(
                    joke: joke,
                    onCreateImage: { showingStylePicker = true },
                    onCopy: onCopy,
                    onSave: onSave,
                    onNotFunny: onNotFunny
                )
            } label: {
                StackedActionLabel(systemImage: "ellipsis", label: "More")
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview("All Characters") {
    ScrollView {
        VStack(spacing: 16) {
            // Mr. Funny - Yellow theme
            JokeOfTheDayView(
                joke: Joke(
                    category: .dadJoke,
                    setup: "Why don't scientists trust atoms?",
                    punchline: "Because they make up everything!",
                    character: "Mr. Funny"
                ),
                onOpen: {},
                onLaugh: { _ in },
                onShare: {},
                onCopy: {},
                onSave: {},
                onNotFunny: {}
            )

            // Mr. Bad - Red theme
            JokeOfTheDayView(
                joke: Joke(
                    category: .dadJoke,
                    setup: "I have a joke about trickle-down economics.",
                    punchline: "But 99% of you won't get it.",
                    character: "Mr. Bad"
                ),
                onOpen: {},
                onLaugh: { _ in },
                onShare: {},
                onCopy: {},
                onSave: {},
                onNotFunny: {}
            )

            // Mr. Sad - Blue theme
            JokeOfTheDayView(
                joke: Joke(
                    category: .dadJoke,
                    setup: "I told my wife she was drawing her eyebrows too high.",
                    punchline: "She looked surprised.",
                    character: "Mr. Sad"
                ),
                onOpen: {},
                onLaugh: { _ in },
                onShare: {},
                onCopy: {},
                onSave: {},
                onNotFunny: {}
            )

            // Mr. Potty - Brown theme
            JokeOfTheDayView(
                joke: Joke(
                    category: .dadJoke,
                    setup: "Why did the toilet paper roll down the hill?",
                    punchline: "To get to the bottom!",
                    character: "Mr. Potty"
                ),
                onOpen: {},
                onLaugh: { _ in },
                onShare: {},
                onCopy: {},
                onSave: {},
                onNotFunny: {}
            )

            // Mr. Love - Pink theme
            JokeOfTheDayView(
                joke: Joke(
                    category: .pickupLine,
                    setup: "Are you a magician?",
                    punchline: "Because whenever I look at you, everyone else disappears!",
                    character: "Mr. Love"
                ),
                onOpen: {},
                onLaugh: { _ in },
                onShare: {},
                onCopy: {},
                onSave: {},
                onNotFunny: {}
            )
        }
        .padding()
    }
}
