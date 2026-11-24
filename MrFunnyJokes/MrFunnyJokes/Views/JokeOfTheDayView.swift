import SwiftUI

/// The Joke of the Day on Home: who's telling it, the setup, and a row to laugh,
/// share or do more. Tapping the joke opens it full screen for the punchline.
struct JokeOfTheDayView: View {
    let joke: Joke
    /// Laugh and share counts, always shown, zero included
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

    static let cornerRadius: CGFloat = 20

    /// The character associated with this joke, if any
    private var jokeCharacter: JokeCharacter? { joke.teller }

    /// "Tuesday, Nov 24"
    private var todayString: String {
        Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// The teller, then the date
    private var byline: String {
        [jokeCharacter?.name, todayString].compactMap { $0 }.joined(separator: " · ")
    }

    /// Background color - uses character's themed background if available
    private var cardBackground: Color {
        jokeCharacter?.backgroundColor ?? Color(
            light: Color(red: 1.0, green: 0.98, blue: 0.94),  // Warm cream
            dark: Color(red: 0.18, green: 0.16, blue: 0.10)   // Warm dark
        )
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
            .accessibilityHint(joke.hasPunchline ? "Opens the joke to show the punchline" : "Opens the joke")

            actionRow
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .background(cardBackground, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if let character = jokeCharacter {
                    Image(character.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Joke of the Day")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(byline)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)

                Spacer(minLength: 0)
            }

            // Setup only; the punchline waits for the tap
            Text(joke.cardText)
                .font(.title2.weight(.semibold))
                .lineSpacing(3)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Laugh, Share, More

    private var actionRow: some View {
        HStack(spacing: 0) {
            LaughButton(
                isOn: joke.userRating == 5,
                label: JokeEngagement.compact(counts.laughs),
                onToggle: onLaugh
            )

            Button(action: onShare) {
                StackedActionLabel(
                    systemImage: "square.and.arrow.up",
                    label: JokeEngagement.compact(counts.shares)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")
            .accessibilityValue("\(counts.shares) shares")

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
