import SwiftUI

/// ViewModel for managing character detail view state and data
@MainActor
final class CharacterDetailViewModel: ObservableObject {
    @Published var jokes: [Joke] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreJokes = true
    @Published var selectedJokeType: JokeCategory? = nil
    @Published var copiedJokeId: UUID?

    let character: Character

    private let firestoreService = FirestoreService.shared
    private let storage = LocalStorageService.shared
    private var copyTask: Task<Void, Never>?
    private var lastDocument: String?

    /// Batch size for loading jokes
    private let batchSize = 15

    /// Filtered jokes based on selected joke type
    var filteredJokes: [Joke] {
        guard let category = selectedJokeType else {
            return jokes
        }
        return jokes.filter { $0.category == category }
    }

    /// Available joke types for this character (based on jokes loaded)
    var availableJokeTypes: [JokeCategory] {
        let types = Set(jokes.map { $0.category })
        return JokeCategory.allCases.filter { types.contains($0) }
    }

    init(character: Character) {
        self.character = character
    }

    // MARK: - Load Jokes

    /// Loads initial jokes for this character
    func loadJokes() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let newJokes = try await firestoreService.fetchJokes(
                byCharacter: character.name,
                limit: batchSize
            )

            // Apply user ratings
            let jokesWithRatings = newJokes.map { joke -> Joke in
                var mutableJoke = joke
                mutableJoke.userRating = storage.getRating(for: joke.id)
                return mutableJoke
            }

            jokes = jokesWithRatings
            hasMoreJokes = newJokes.count >= batchSize
        } catch {
            print("Error loading jokes for \(character.name): \(error)")
        }

        isLoading = false
    }

    /// Loads more jokes (for infinite scroll)
    func loadMoreJokes() async {
        guard !isLoadingMore && hasMoreJokes else { return }
        isLoadingMore = true

        do {
            // Fetch more jokes - we'll use the current count as offset indicator
            let existingIds = Set(jokes.compactMap { $0.firestoreId })
            let newJokes = try await firestoreService.fetchJokes(
                byCharacter: character.name,
                limit: batchSize * 2 // Fetch more to find new ones
            )

            // Filter out duplicates
            let uniqueNewJokes = newJokes.filter { joke in
                guard let id = joke.firestoreId else { return true }
                return !existingIds.contains(id)
            }.prefix(batchSize)

            if uniqueNewJokes.isEmpty {
                hasMoreJokes = false
            } else {
                // Apply user ratings
                let jokesWithRatings = uniqueNewJokes.map { joke -> Joke in
                    var mutableJoke = joke
                    mutableJoke.userRating = storage.getRating(for: joke.id)
                    return mutableJoke
                }

                jokes.append(contentsOf: jokesWithRatings)
            }
        } catch {
            print("Error loading more jokes for \(character.name): \(error)")
        }

        isLoadingMore = false
    }

    /// Checks if more jokes should be loaded based on current scroll position
    func loadMoreIfNeeded(currentItem: Joke) {
        let thresholdIndex = filteredJokes.index(
            filteredJokes.endIndex,
            offsetBy: -3,
            limitedBy: filteredJokes.startIndex
        ) ?? filteredJokes.startIndex

        guard let currentIndex = filteredJokes.firstIndex(where: { $0.id == currentItem.id }),
              currentIndex >= thresholdIndex else {
            return
        }

        Task {
            await loadMoreJokes()
        }
    }

    // MARK: - Joke Type Filter

    /// Selects a joke type filter
    func selectJokeType(_ category: JokeCategory?) {
        HapticManager.shared.lightTap()
        selectedJokeType = category
    }

    // MARK: - Ratings

    func rateJoke(_ joke: Joke, rating: Int) {
        HapticManager.shared.selection()

        if rating == 0 {
            storage.removeRating(for: joke.id)
            if let index = jokes.firstIndex(where: { $0.id == joke.id }) {
                jokes[index].userRating = nil
            }
        } else {
            let clampedRating = min(max(rating, 1), 4)
            storage.saveRating(for: joke.id, rating: clampedRating)
            if let index = jokes.firstIndex(where: { $0.id == joke.id }) {
                jokes[index].userRating = clampedRating
            }

            // Sync rating to Firestore if we have a Firestore ID
            if let firestoreId = joke.firestoreId {
                Task {
                    do {
                        try await firestoreService.updateJokeRating(jokeId: firestoreId, rating: clampedRating)
                    } catch {
                        print("Failed to sync rating to Firestore: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Sharing

    func shareJoke(_ joke: Joke) {
        HapticManager.shared.success()

        let text = "\(joke.setup)\n\n\(joke.punchline)\n\n— \(character.name)"

        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        topVC.present(activityVC, animated: true)
    }

    func copyJoke(_ joke: Joke) {
        HapticManager.shared.success()

        let text = "\(joke.setup)\n\n\(joke.punchline)"
        UIPasteboard.general.string = text

        copiedJokeId = joke.id

        copyTask?.cancel()
        copyTask = Task { [weak self, jokeId = joke.id] in
            do {
                try await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                if self?.copiedJokeId == jokeId {
                    self?.copiedJokeId = nil
                }
            } catch {
                // Task was cancelled
            }
        }
    }
}
