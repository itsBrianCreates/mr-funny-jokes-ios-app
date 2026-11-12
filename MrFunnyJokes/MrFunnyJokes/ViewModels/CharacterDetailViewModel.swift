import SwiftUI

/// Notification posted when a joke rating changes in any ViewModel
/// Used to sync ratings across CharacterDetailViewModel and JokeViewModel
extension Notification.Name {
    static let jokeRatingDidChange = Notification.Name("jokeRatingDidChange")
    static let jokeSaveDidChange = Notification.Name("jokeSaveDidChange")
}

/// ViewModel for managing character detail view state and data
@MainActor
final class CharacterDetailViewModel: ObservableObject {
    @Published var jokes: [Joke] = []
    @Published var isLoading = false
    @Published var selectedJokeType: JokeCategory? = nil
    @Published var copiedJokeId: UUID?

    let character: JokeCharacter

    private let firestoreService = FirestoreService.shared
    private let catalog = JokeCatalogService.shared
    private let storage = LocalStorageService.shared
    private var copyTask: Task<Void, Never>?

    // MARK: - Fresh Feed

    /// Marks a joke as seen (its card was on screen). Takes effect the next time a feed is built.
    func markJokeImpression(_ joke: Joke) {
        storage.markImpression(firestoreId: joke.firestoreId)
    }

    /// Marks a joke as opened (punchline revealed), same as opening it from the home feed
    func markJokeViewed(_ joke: Joke) {
        storage.markViewed(firestoreId: joke.firestoreId)
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

    /// Loads every joke this character tells, the ones this person hasn't seen first.
    /// Seen-tracking is shared with the home feed, so a joke scrolled past there counts here too.
    func loadJokes() async {
        // Once per visit: the order must not change when a sheet closes and the page reappears
        guard !isLoading, jokes.isEmpty else { return }
        isLoading = true

        var catalogJokes = await catalog.loadFromDisk()
        if catalogJokes.isEmpty {
            // The home feed normally has the catalog downloaded long before a character page opens
            do {
                try await catalog.sync()
                catalogJokes = catalog.jokes
            } catch {
                print("Error loading jokes for \(character.name): \(error)")
            }
        }

        // Apply user ratings and save state
        let characterJokes = catalogJokes
            .filter { $0.character == character.id }
            .map { joke -> Joke in
                var mutableJoke = joke
                mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
                mutableJoke.isSaved = storage.isJokeSaved(firestoreId: joke.firestoreId ?? joke.id.uuidString)
                return mutableJoke
            }

        jokes = JokeFeedOrdering.freshFirst(
            characterJokes,
            seenOrder: storage.getImpressionOrder(),
            ratedIds: storage.getRatedJokeIds(),
            viewedIds: storage.getViewedIdsFast()
        )

        isLoading = false
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
            let ratingName = clampedRating == 5 ? "hilarious" : "horrible"
            let analyticsJokeId = joke.firestoreId ?? joke.id.uuidString
            let analyticsCharacter = joke.character ?? "unknown"
            Task.detached { AnalyticsService.shared.logJokeRated(jokeId: analyticsJokeId, character: analyticsCharacter, rating: ratingName) }

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

    // MARK: - Saving

    /// Toggle save state for a joke
    func saveJoke(_ joke: Joke) {
        HapticManager.shared.lightTap()

        let key = joke.firestoreId ?? joke.id.uuidString
        let currentlySaved = storage.isJokeSaved(firestoreId: key)

        // Toggle save state in storage
        if currentlySaved {
            storage.unsaveJoke(firestoreId: key)
        } else {
            storage.saveJoke(firestoreId: key)
        }

        // Update local state
        if let index = jokes.firstIndex(where: { $0.id == joke.id }) {
            jokes[index].isSaved = !currentlySaved
        }

        // Notify other ViewModels about the save change
        let updatedJoke: Joke
        if let index = jokes.firstIndex(where: { $0.id == joke.id }) {
            updatedJoke = jokes[index]
        } else {
            var mutableJoke = joke
            mutableJoke.isSaved = !currentlySaved
            updatedJoke = mutableJoke
        }

        let jokeData = try? JSONEncoder().encode(updatedJoke)
        NotificationCenter.default.post(
            name: .jokeSaveDidChange,
            object: nil,
            userInfo: [
                "jokeId": joke.id,
                "firestoreId": key,
                "isSaved": !currentlySaved,
                "jokeData": jokeData as Any
            ]
        )
    }

    // MARK: - Sharing

    func shareJoke(_ joke: Joke) {
        HapticManager.shared.success()
        let jokeId = joke.firestoreId ?? joke.id.uuidString
        Task.detached { AnalyticsService.shared.logJokeShared(jokeId: jokeId, method: "share") }

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
        let jokeId = joke.firestoreId ?? joke.id.uuidString
        Task.detached { AnalyticsService.shared.logJokeShared(jokeId: jokeId, method: "copy") }

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
