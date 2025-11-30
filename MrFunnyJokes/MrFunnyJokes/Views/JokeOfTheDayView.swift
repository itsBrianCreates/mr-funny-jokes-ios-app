import SwiftUI

struct JokeOfTheDayView: View {
    let joke: Joke
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void

    @State private var showingSheet = false
    @State private var isAppearing = false

    var body: some View {
        Button {
            HapticManager.shared.mediumImpact()
            showingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                // Header badge
                Text("Joke of the Day")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(.accessibleYellow)

                // Setup text - larger for hero card
                Text(joke.setup)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(4)

                // Category and rating row
                HStack {
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
            .padding(20)
            .background(.brandYellowLight, in: RoundedRectangle(cornerRadius: 20))
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
