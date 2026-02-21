import SwiftUI

struct MeView: View {
    @ObservedObject var viewModel: JokeViewModel
    @State private var selectedJokeId: UUID?

    private var selectedJoke: Joke? {
        guard let id = selectedJokeId else { return nil }
        return viewModel.jokes.first { $0.id == id }
    }

    /// The character associated with a joke, if any
    private func jokeCharacter(for joke: Joke) -> JokeCharacter? {
        guard let characterName = joke.character else { return nil }
        return JokeCharacter.find(byName: characterName)
    }

    var body: some View {
        if viewModel.savedJokes.isEmpty {
            emptyState
        } else {
            savedJokesList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.slash")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text("No Saved Jokes Yet")
                .font(.title2.weight(.semibold))

            Text("Tap Save on any joke to start your collection!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Saved Jokes List

    private var savedJokesList: some View {
        List {
            ForEach(viewModel.savedJokes) { joke in
                jokeCard(for: joke)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.unsaveJoke(joke)
                        } label: {
                            Label("Unsave", systemImage: "person.badge.minus")
                        }
                        .tint(.red)
                    }
            }
        }
        .listStyle(.plain)
        .sheet(isPresented: Binding(
            get: { selectedJokeId != nil },
            set: { if !$0 { selectedJokeId = nil } }
        )) {
            if let joke = selectedJoke {
                JokeDetailSheet(
                    joke: joke,
                    isCopied: viewModel.copiedJokeId == joke.id,
                    onDismiss: { selectedJokeId = nil },
                    onShare: { viewModel.shareJoke(joke) },
                    onCopy: { viewModel.copyJoke(joke) },
                    onRate: { rating in viewModel.rateJoke(joke, rating: rating) },
                    onSave: { viewModel.saveJoke(joke) }
                )
            }
        }
    }

    // MARK: - Joke Card

    private func jokeCard(for joke: Joke) -> some View {
        Button {
            HapticManager.shared.mediumImpact()
            selectedJokeId = joke.id
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(joke.setup)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    if let character = jokeCharacter(for: joke) {
                        CharacterIndicatorView(character: character)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: joke.category.icon)
                        Text(joke.category.rawValue)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        MeView(viewModel: JokeViewModel())
            .navigationTitle("My Jokes")
    }
}
