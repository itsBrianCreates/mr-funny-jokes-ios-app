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

    let character: JokeCharacter

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

    /// Available joke types for this character (based on character's allowed categories)
    var availableJokeTypes: [JokeCategory] {
        // Only return categories that this character is allowed to tell
        return character.allowedCategories
    }

    init(character: JokeCharacter) {
        self.character = character
    }

    // MARK: - Load Jokes

    /// Loads initial jokes for this character
    func loadJokes() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            // Fetch all jokes and filter client-side for this character
            // This is more reliable than querying by character field since:
            // 1. The character field may use different formats (id vs name)
            // 2. The compound query requires a Firestore index
            let allJokes = try await firestoreService.fetchInitialJokes(limit: 100)

            // Filter jokes for this character using flexible matching
            let characterJokes = allJokes.filter { joke in
                matchesCharacter(joke: joke, character: character)
            }

            // Apply user ratings
            let jokesWithRatings = characterJokes.map { joke -> Joke in
                var mutableJoke = joke
                mutableJoke.userRating = storage.getRating(for: joke.id)
                return mutableJoke
            }

            jokes = jokesWithRatings
            hasMoreJokes = characterJokes.count >= batchSize
        } catch {
            print("Error loading jokes for \(character.name): \(error)")
        }

        isLoading = false
    }

    /// Checks if a joke belongs to the specified character
    /// Uses flexible matching to handle various character field formats,
    /// with a fallback to category-based assignment when character field is not set
    private func matchesCharacter(joke: Joke, character: JokeCharacter) -> Bool {
        // First, try to match by the character field if it's set
        if let jokeCharacter = joke.character?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           !jokeCharacter.isEmpty {
            let characterId = character.id.lowercased()
            let characterName = character.name.lowercased()
            let characterNameNoPeriod = characterName.replacingOccurrences(of: ".", with: "")
            let characterIdWithSpaces = characterId.replacingOccurrences(of: "_", with: " ")

            // Match against various possible formats
            if jokeCharacter == characterId ||                          // "mr_funny"
               jokeCharacter == characterName ||                        // "mr. funny"
               jokeCharacter == characterNameNoPeriod ||                // "mr funny"
               jokeCharacter == characterIdWithSpaces ||                // "mr funny"
               jokeCharacter.replacingOccurrences(of: " ", with: "_") == characterId ||
               jokeCharacter.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "_") == characterId {
                return true
            }
        }

        // Fallback: assign jokes to characters based on category
        // This ensures jokes show up even if the character field isn't populated
        return matchesByCategory(joke: joke, character: character)
    }

    /// Maps joke categories to characters as a fallback when character field is not set
    /// Uses the character's allowedCategories to determine if a joke matches
    private func matchesByCategory(joke: Joke, character: JokeCharacter) -> Bool {
        // Check if the joke's category is in the character's allowed categories
        return character.allowedCategories.contains(joke.category)
    }

    /// Loads more jokes (for infinite scroll)
    func loadMoreJokes() async {
        guard !isLoadingMore && hasMoreJokes else { return }
        isLoadingMore = true

        do {
            // Fetch more jokes and filter client-side for this character
            let existingIds = Set(jokes.compactMap { $0.firestoreId })
            let allJokes = try await firestoreService.fetchMoreJokes(limit: 50)

            // Filter jokes for this character using flexible matching
            let characterJokes = allJokes.filter { joke in
                matchesCharacter(joke: joke, character: character)
            }

            // Filter out duplicates
            let uniqueNewJokes = characterJokes.filter { joke in
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
