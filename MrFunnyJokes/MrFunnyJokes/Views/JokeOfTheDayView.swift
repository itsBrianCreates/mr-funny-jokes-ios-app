import SwiftUI

struct JokeOfTheDayView: View {
    let joke: Joke
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void

    @State private var showingSheet = false
    @State private var isAppearing = false

    /// The character associated with this joke, if any
    private var jokeCharacter: JokeCharacter? {
        guard let characterName = joke.character else { return nil }
        return JokeCharacter.find(byName: characterName)
    }

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

    var body: some View {
        Button {
            HapticManager.shared.mediumImpact()
            showingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Badge inside the card
                Text("JOKE OF THE DAY")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 6))

                // Main joke text
                Text(joke.setup)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Bottom section with character info
                HStack(spacing: 12) {
                    // Character avatar (larger)
                    if let character = jokeCharacter {
                        Image(character.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(accentColor, lineWidth: 2)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(character.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(todayString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Fallback if no character
                        VStack(alignment: .leading, spacing: 2) {
                            Text(joke.category.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(todayString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Rating indicator or "Tap to rate"
                    if let rating = joke.userRating {
                        CompactGroanOMeterView(rating: rating)
                    } else {
                        Text("Tap to rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(accentColor, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isAppearing ? 1 : 0.95)
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
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

    /// Subtle background color that works in both light and dark mode
    private var cardBackground: Color {
        Color(
            light: Color(red: 1.0, green: 0.98, blue: 0.94),  // Warm cream/off-white
            dark: Color(red: 0.15, green: 0.14, blue: 0.12)   // Warm dark gray
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            JokeOfTheDayView(
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

            JokeOfTheDayView(
                joke: Joke(
                    category: .knockKnock,
                    setup: "Knock knock. Who's there? Lettuce.",
                    punchline: "Lettuce who? Lettuce in, it's cold out here!",
                    userRating: 4,
                    character: "Mr. Potty"
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
