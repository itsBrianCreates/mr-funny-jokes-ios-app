import SwiftUI

/// Every joke on one topic, the ones this person hasn't seen first
struct TopicDetailView: View {
    @ObservedObject var viewModel: JokeViewModel
    let topic: JokeTopic

    var body: some View {
        JokeCollectionPage(
            viewModel: viewModel,
            title: "\(topic.emoji) \(topic.name)",
            destination: .topic(topic),
            loadJokes: { viewModel.freshFirstJokes(in: topic) }
        )
    }
}

/// Every joke of one type (dad jokes, knock-knocks, pickup lines), unseen first
struct JokeTypeDetailView: View {
    @ObservedObject var viewModel: JokeViewModel
    let category: JokeCategory

    var body: some View {
        JokeCollectionPage(
            viewModel: viewModel,
            title: category.rawValue,
            destination: .jokeType(category),
            loadJokes: { viewModel.freshFirstJokes(ofType: category) }
        )
    }
}

// MARK: - Joke Collection Page

/// A pushed page listing a set of jokes, opened from the topic grid or a chip on a joke
private struct JokeCollectionPage: View {
    @ObservedObject var viewModel: JokeViewModel
    let title: String
    /// What this page is, so jokes opened here don't link back to it
    let destination: JokeDestination
    let loadJokes: () -> [Joke]

    /// Joke shown in the detail pane or sheet. An ID, so it always reads fresh data.
    @State private var selectedJokeId: UUID?

    /// The page's order, fixed when it opens so cards don't move while scrolling.
    /// IDs rather than jokes, so ratings and saves always read fresh view-model data.
    @State private var orderedJokeIds: [String]?

    private var jokes: [Joke] {
        guard let orderedJokeIds else { return [] }

        var jokesById: [String: Joke] = [:]
        for joke in viewModel.jokes {
            jokesById[joke.firestoreId ?? joke.id.uuidString] = joke
        }
        return orderedJokeIds.compactMap { jokesById[$0] }
    }

    var body: some View {
        JokeListDetailView(viewModel: viewModel, selectedJokeId: $selectedJokeId) { isSplit in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(jokes) { joke in
                        JokeCardView(
                            joke: joke,
                            isCopied: viewModel.copiedJokeId == joke.id,
                            onShare: { viewModel.shareJoke(joke) },
                            onCopy: { viewModel.copyJoke(joke) },
                            onRate: { rating in viewModel.rateJoke(joke, rating: rating) },
                            onSave: { viewModel.saveJoke(joke) },
                            onView: { viewModel.markJokeViewed(joke) },
                            onSelect: { selectedJokeId = joke.id },
                            isSelected: isSplit && selectedJokeId == joke.id
                        )
                        .onAppear {
                            viewModel.markJokeImpression(joke)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .environment(\.currentJokeDestination, destination)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Once per visit: closing a joke's sheet must not reshuffle the page
            guard orderedJokeIds == nil else { return }
            orderedJokeIds = loadJokes().map { $0.firestoreId ?? $0.id.uuidString }
        }
    }
}

#Preview {
    NavigationStack {
        TopicDetailView(viewModel: JokeViewModel(), topic: JokeTopic.all[3])
    }
}
