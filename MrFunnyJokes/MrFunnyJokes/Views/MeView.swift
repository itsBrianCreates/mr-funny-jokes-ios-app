import SwiftUI

struct MeView: View {
    @ObservedObject var viewModel: JokeViewModel

    var body: some View {
        if viewModel.ratedJokes.isEmpty {
            emptyState
        } else {
            ratedJokesList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "star.slash")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text("No Rated Jokes Yet")
                .font(.title2.weight(.semibold))

            Text("Start rating jokes to save your favorites here!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Rated Jokes List

    private var ratedJokesList: some View {
        List {
            // Hilarious (4)
            if !viewModel.hilariousJokes.isEmpty {
                ratingSection(
                    title: "Hilarious",
                    emoji: "😂",
                    jokes: viewModel.hilariousJokes
                )
            }

            // Funny (3)
            if !viewModel.funnyJokes.isEmpty {
                ratingSection(
                    title: "Funny",
                    emoji: "😄",
                    jokes: viewModel.funnyJokes
                )
            }

            // Meh (2)
            if !viewModel.mehJokes.isEmpty {
                ratingSection(
                    title: "Meh",
                    emoji: "😐",
                    jokes: viewModel.mehJokes
                )
            }

            // Groan-worthy (1)
            if !viewModel.groanJokes.isEmpty {
                ratingSection(
                    title: "Groan-Worthy",
                    emoji: "😩",
                    jokes: viewModel.groanJokes
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Rating Section

    private func ratingSection(title: String, emoji: String, jokes: [Joke]) -> some View {
        Section {
            ForEach(jokes) { joke in
                JokeRowView(
                    joke: joke,
                    isCopied: viewModel.copiedJokeId == joke.id,
                    onShare: { viewModel.shareJoke(joke) },
                    onCopy: { viewModel.copyJoke(joke) },
                    onRate: { rating in viewModel.rateJoke(joke, rating: rating) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            viewModel.rateJoke(joke, rating: 0)
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        } header: {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(jokes.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .textCase(nil)
        }
    }
}

// MARK: - Joke Row View (for List)

struct JokeRowView: View {
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
            VStack(alignment: .leading, spacing: 6) {
                // Setup text
                Text(joke.setup)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                // Category
                HStack(spacing: 4) {
                    Image(systemName: joke.category.icon)
                    Text(joke.category.rawValue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
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
    NavigationStack {
        MeView(viewModel: JokeViewModel())
            .navigationTitle("My Jokes")
    }
}
