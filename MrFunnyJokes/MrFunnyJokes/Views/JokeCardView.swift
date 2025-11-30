import SwiftUI

struct JokeCardView: View {
    let joke: Joke
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void

    @State private var showingSheet = false

    var body: some View {
        Button {
            HapticManager.shared.mediumImpact()
            showingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: joke.category.icon)
                        Text(joke.category.rawValue)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Spacer()

                    // Show rating emoji if rated, otherwise show expand hint
                    if let rating = joke.userRating {
                        CompactGroanOMeterView(rating: rating)
                    }
                }

                // Setup text
                Text(joke.setup)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            JokeCardView(
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

            JokeCardView(
                joke: Joke(
                    category: .knockKnock,
                    setup: "Knock knock. Who's there? Lettuce.",
                    punchline: "Lettuce who? Lettuce in, it's cold out here!",
                    userRating: 3
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
