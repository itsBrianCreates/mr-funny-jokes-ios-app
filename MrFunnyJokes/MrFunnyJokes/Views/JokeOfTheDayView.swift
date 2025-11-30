import SwiftUI

struct JokeOfTheDayView: View {
    let joke: Joke
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void

    @State private var showingSheet = false
    @State private var isAppearing = false
    @State private var sparklePhase: CGFloat = 0

    var body: some View {
        Button {
            HapticManager.shared.mediumImpact()
            showingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                // Header with badge and rating
                HStack {
                    // "Joke of the Day" badge with sparkle
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .symbolEffect(.pulse, options: .repeating)
                            .foregroundColor(Color.brandYellow)
                        Text("Joke of the Day")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    .foregroundColor(Color.accessibleYellow)

                    Spacer()

                    // Rating if present
                    if let rating = joke.userRating {
                        CompactGroanOMeterView(rating: rating)
                    }
                }

                // Setup text - larger for hero card
                Text(joke.setup)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(4)

                // Tap hint
                HStack {
                    Text("Tap to reveal punchline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Category badge
                    HStack(spacing: 4) {
                        Image(systemName: joke.category.icon)
                        Text(joke.category.rawValue)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.brandYellowLight)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.brandYellow, Color.brandYellow.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
            }
            .shadow(color: Color.brandYellow.opacity(0.2), radius: 8, x: 0, y: 4)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(isAppearing ? 1 : 0.9)
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
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
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            JokeOfTheDayView(
                joke: Joke(
                    category: .dadJoke,
                    setup: "Why don't scientists trust atoms?",
                    punchline: "Because they make up everything!"
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
                    userRating: 4
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
