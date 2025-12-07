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
    private var loadMoreTask: Task<Void, Never>?

    /// Batch size for filtering character jokes from each fetch
    private let batchSize = 15
    /// Number of jokes to fetch from Firestore per batch (larger to ensure we find enough character matches)
    private let fetchBatchSize = 50
    /// Maximum consecutive empty batches before giving up
    private let maxEmptyBatches = 3

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
            // Use character-specific pagination to avoid conflicts with home tab
            let allJokes = try await firestoreService.fetchInitialJokesForCharacter(
                characterId: character.id,
                limit: fetchBatchSize
            )

            // Filter jokes for this character using flexible matching
            let characterJokes = allJokes.filter { joke in
                matchesCharacter(joke: joke, character: character)
            }

            // Apply user ratings
            let jokesWithRatings = characterJokes.map { joke -> Joke in
                var mutableJoke = joke
                mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                return mutableJoke
            }

            jokes = jokesWithRatings

            // If we got a full batch from Firestore, there might be more
            hasMoreJokes = allJokes.count >= fetchBatchSize
        } catch {
            print("Error loading jokes for \(character.name): \(error)")
        }

        isLoading = false
    }

    /// Checks if a joke belongs to the specified character
    /// Uses flexible matching to handle various character field formats,
    /// with a fallback to category-based assignment ONLY when character field is not set
    private func matchesCharacter(joke: Joke, character: JokeCharacter) -> Bool {
        // First, try to match by the character field if it's set
        if let jokeCharacter = joke.character?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           !jokeCharacter.isEmpty {
            let characterId = character.id.lowercased()
            let characterName = character.name.lowercased()
            let characterNameNoPeriod = characterName.replacingOccurrences(of: ".", with: "")
            let characterIdWithSpaces = characterId.replacingOccurrences(of: "_", with: " ")

            // Match against various possible formats
            // If the joke has a character field set, we return the result directly
            // and do NOT fall back to category matching (which would cause cross-character leakage)
            return jokeCharacter == characterId ||                          // "mr_funny"
                   jokeCharacter == characterName ||                        // "mr. funny"
                   jokeCharacter == characterNameNoPeriod ||                // "mr funny"
                   jokeCharacter == characterIdWithSpaces ||                // "mr funny"
                   jokeCharacter.replacingOccurrences(of: " ", with: "_") == characterId ||
                   jokeCharacter.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "_") == characterId
        }

        // Fallback: assign jokes to characters based on category
        // This ONLY applies when the character field is nil or empty
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
        let startTime = Date()

        do {
            let existingIds = Set(jokes.compactMap { $0.firestoreId })
            var emptyBatchCount = 0
            var foundNewJokes = false

            // Keep fetching batches until we find character jokes or exhaust the database
            while emptyBatchCount < maxEmptyBatches && !foundNewJokes {
                // Use character-specific pagination
                let (allJokes, hasMore) = try await firestoreService.fetchMoreJokesForCharacter(
                    characterId: character.id,
                    limit: fetchBatchSize
                )

                // If we got no results from Firestore, we've exhausted the database
                if allJokes.isEmpty {
                    hasMoreJokes = false
                    break
                }

                // Filter jokes for this character using flexible matching
                let characterJokes = allJokes.filter { joke in
                    matchesCharacter(joke: joke, character: character)
                }

                // Filter out duplicates
                let uniqueNewJokes = characterJokes.filter { joke in
                    guard let id = joke.firestoreId else { return true }
                    return !existingIds.contains(id)
                }

                if uniqueNewJokes.isEmpty {
                    // No matching jokes in this batch, but there might be more in the database
                    emptyBatchCount += 1
                    if !hasMore {
                        // Database is exhausted
                        hasMoreJokes = false
                        break
                    }
                    // Continue to next batch
                } else {
                    // Found new jokes for this character
                    foundNewJokes = true

                    // Apply user ratings
                    let jokesWithRatings = uniqueNewJokes.map { joke -> Joke in
                        var mutableJoke = joke
                        mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                        return mutableJoke
                    }

                    jokes.append(contentsOf: jokesWithRatings)
                    hasMoreJokes = hasMore
                }
            }

            // If we hit max empty batches, assume no more character jokes
            if emptyBatchCount >= maxEmptyBatches {
                hasMoreJokes = false
            }
        } catch {
            print("Error loading more jokes for \(character.name): \(error)")
        }

        // Ensure minimum loading time for smooth UX
        await ensureMinimumLoadingTime(startTime: startTime)
        isLoadingMore = false
    }

    /// Ensures the loading indicator is shown for at least 400ms for better UX
    private func ensureMinimumLoadingTime(startTime: Date) async {
        let minimumLoadingDuration: TimeInterval = 0.4
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < minimumLoadingDuration {
            let remaining = minimumLoadingDuration - elapsed
            try? await Task.sleep(for: .milliseconds(Int(remaining * 1000)))
        }
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

        loadMore()
    }

    /// Triggers loading more jokes with task management
    func loadMore() {
        guard !isLoadingMore && hasMoreJokes else { return }

        loadMoreTask?.cancel()
        loadMoreTask = Task {
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
            storage.removeRating(for: joke.id, firestoreId: joke.firestoreId)
            if let index = jokes.firstIndex(where: { $0.id == joke.id }) {
                jokes[index].userRating = nil
            }
        } else {
            let clampedRating = min(max(rating, 1), 5)
            storage.saveRating(for: joke.id, firestoreId: joke.firestoreId, rating: clampedRating)
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
