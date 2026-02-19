import SwiftUI

struct MeView: View {
    @ObservedObject var viewModel: JokeViewModel
    @State private var selectedJokeId: UUID?
    @State private var selectedType: RankingType = .hilarious

    private var selectedJoke: Joke? {
        guard let id = selectedJokeId else { return nil }
        return viewModel.jokes.first { $0.id == id }
    }

    /// Jokes for the currently selected segment
    private var currentJokes: [Joke] {
        switch selectedType {
        case .hilarious:
            return viewModel.hilariousJokes
        case .horrible:
            return viewModel.horribleJokes
        }
    }

    /// Count of jokes for a given ranking type
    private func jokesCount(for type: RankingType) -> Int {
        switch type {
        case .hilarious:
            return viewModel.hilariousJokes.count
        case .horrible:
            return viewModel.horribleJokes.count
        }
    }

    /// The character associated with a joke, if any
    private func jokeCharacter(for joke: Joke) -> JokeCharacter? {
        guard let characterName = joke.character else { return nil }
        return JokeCharacter.find(byName: characterName)
    }

    var body: some View {
        if viewModel.ratedJokes.isEmpty {
            emptyState
        } else {
            segmentedContent
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

    // MARK: - Segmented Content

    private var segmentedContent: some View {
        List {
            // Segmented control with count badges
            Picker("Category", selection: $selectedType) {
                ForEach(RankingType.allCases) { type in
                    Text("\(type.emoji) \(type.rawValue) (\(jokesCount(for: type)))").tag(type)
                }
            }
            .pickerStyle(.segmented)
            .transaction { $0.animation = nil }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

            // Content for selected segment
            if currentJokes.isEmpty {
                EmptyStateView(type: selectedType)
                    .frame(minHeight: 300)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } else {
                ForEach(currentJokes) { joke in
                    jokeCard(for: joke)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.rateJoke(joke, rating: 0)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .tint(.red)
                        }
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
                    onRate: { rating in viewModel.rateJoke(joke, rating: rating) }
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
