import SwiftUI

/// Notification posted when a joke rating changes in any ViewModel
/// Used to sync ratings across CharacterDetailViewModel and JokeViewModel
extension Notification.Name {
    static let jokeRatingDidChange = Notification.Name("jokeRatingDidChange")
}

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

    /// Number of jokes to fetch from Firestore per batch
    private let fetchBatchSize = 50

    // MARK: - Feed Algorithm (Freshness Sorting)

    /// Sorts jokes for a fresh feed experience
    /// Prioritizes: Unseen jokes > Seen but unrated > Already rated
    /// Shuffles within each tier to maintain category variety
    private func sortJokesForFreshFeed(_ jokes: [Joke]) -> [Joke] {
        let impressionIds = storage.getImpressionIds()
        let ratedIds = storage.getRatedJokeIds()

        var unseenJokes: [Joke] = []
        var seenUnratedJokes: [Joke] = []
        var ratedJokes: [Joke] = []

        for joke in jokes {
            let key = joke.firestoreId ?? joke.id.uuidString
            let hasImpression = impressionIds.contains(key)
            let hasRating = ratedIds.contains(key)

            if !hasImpression {
                unseenJokes.append(joke)
            } else if !hasRating {
                seenUnratedJokes.append(joke)
            } else {
                ratedJokes.append(joke)
            }
        }

        // Shuffle within each tier to maintain category variety
        return unseenJokes.shuffled() + seenUnratedJokes.shuffled() + ratedJokes.shuffled()
    }

    /// Marks a joke as seen/impressed for feed freshness tracking
    func markJokeImpression(_ joke: Joke) {
        storage.markImpression(firestoreId: joke.firestoreId)
    }

    /// Filtered jokes based on selected joke type
    var filteredJokes: [Joke] {
        let categoryFiltered: [Joke]
        if let category = selectedJokeType {
            categoryFiltered = jokes.filter { $0.category == category }
        } else {
            categoryFiltered = jokes
        }

        // MARK: - Seasonal Content Ranking
        // Apply seasonal demotion for Christmas jokes outside Nov 1 - Dec 31
        if !SeasonalHelper.isChristmasSeason() {
            let nonChristmas = categoryFiltered.filter { !$0.isChristmasJoke }
            let christmas = categoryFiltered.filter { $0.isChristmasJoke }
            return nonChristmas + christmas
        } else {
            return categoryFiltered
        }
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
            // Fetch initial batch of jokes for this character from Firestore
            // Uses server-side pagination with composite index (character, popularity_score)
            let characterJokes = try await firestoreService.fetchInitialJokesForCharacter(
                characterId: character.id,
                limit: fetchBatchSize
            )

            // Apply user ratings
            let jokesWithRatings = characterJokes.map { joke -> Joke in
                var mutableJoke = joke
                mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                return mutableJoke
            }

            // Sort for fresh feed experience (unseen > seen-unrated > rated)
            jokes = sortJokesForFreshFeed(jokesWithRatings)

            // hasMoreJokes is true if we got a full batch (might be more in database)
            hasMoreJokes = characterJokes.count == fetchBatchSize
        } catch {
            print("Error loading jokes for \(character.name): \(error)")
        }

        isLoading = false
    }

    /// Loads more jokes (for infinite scroll)
    func loadMoreJokes() async {
        guard !isLoadingMore && hasMoreJokes else { return }
        withAnimation(.easeInOut(duration: 0.3)) { self.isLoadingMore = true }
        let startTime = Date()

        do {
            let existingIds = Set(jokes.compactMap { $0.firestoreId })

            // Use character-specific pagination
            // The Firestore query already filters by character field
            let (characterJokes, hasMore) = try await firestoreService.fetchMoreJokesForCharacter(
                characterId: character.id,
                limit: fetchBatchSize
            )

            // If we got no results from Firestore, we've exhausted the database
            if characterJokes.isEmpty {
                hasMoreJokes = false
            } else {
                // Filter out duplicates
                let uniqueNewJokes = characterJokes.filter { joke in
                    guard let id = joke.firestoreId else { return true }
                    return !existingIds.contains(id)
                }

                if !uniqueNewJokes.isEmpty {
                    // Apply user ratings
                    let jokesWithRatings = uniqueNewJokes.map { joke -> Joke in
                        var mutableJoke = joke
                        mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                        return mutableJoke
                    }

                    jokes.append(contentsOf: jokesWithRatings)
                }

                hasMoreJokes = hasMore
            }
        } catch {
            print("Error loading more jokes for \(character.name): \(error)")
        }

        // Ensure minimum loading time for smooth UX
        await ensureMinimumLoadingTime(startTime: startTime)
        withAnimation(.easeInOut(duration: 0.3)) { self.isLoadingMore = false }
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

        // Find joke index using firestoreId (stable) or fallback to UUID
        // This handles cases where jokes array was refreshed and UUIDs changed
        let jokeIndex = jokes.firstIndex(where: {
            if let firestoreId = joke.firestoreId, let otherFirestoreId = $0.firestoreId {
                return firestoreId == otherFirestoreId
            }
            return $0.id == joke.id
        })

        if rating == 0 {
            storage.removeRating(for: joke.id, firestoreId: joke.firestoreId)
            if let index = jokeIndex {
                jokes[index].userRating = nil
            }
        } else {
            let clampedRating = min(max(rating, 1), 5)
            storage.saveRating(for: joke.id, firestoreId: joke.firestoreId, rating: clampedRating)
            if let index = jokeIndex {
                jokes[index].userRating = clampedRating
            }

            // Sync rating to Firestore if we have a Firestore ID
            if let firestoreId = joke.firestoreId {
                Task {
                    do {
                        try await firestoreService.updateJokeRating(jokeId: firestoreId, rating: clampedRating)

                        // Log rating event for weekly rankings (only for hilarious=5 or horrible=1)
                        if clampedRating == 1 || clampedRating == 5 {
                            let deviceId = storage.getDeviceId()
                            try await firestoreService.logRatingEvent(
                                jokeId: firestoreId,
                                rating: clampedRating,
                                deviceId: deviceId
                            )
                        }
                    } catch {
                        print("Failed to sync rating to Firestore: \(error)")
                    }
                }
            }
        }

        // Notify other ViewModels (especially JokeViewModel) about the rating change
        // This ensures the Me tab updates when ratings are made in character views
        // Include the full joke data so JokeViewModel can add it if not already present
        var jokeForNotification = joke
        let effectiveRating = rating == 0 ? nil : min(max(rating, 1), 5)
        jokeForNotification.userRating = effectiveRating
        let jokeData = try? JSONEncoder().encode(jokeForNotification)

        NotificationCenter.default.post(
            name: .jokeRatingDidChange,
            object: nil,
            userInfo: [
                "firestoreId": joke.firestoreId as Any,
                "jokeId": joke.id,
                "rating": rating,
                "jokeData": jokeData as Any
            ]
        )
    }

    // MARK: - Sharing

    func shareJoke(_ joke: Joke) {
        HapticManager.shared.success()

        let text = joke.formattedTextForSharing(characterName: character.name)

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

        let text = joke.formattedTextForSharing(characterName: character.name)
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
