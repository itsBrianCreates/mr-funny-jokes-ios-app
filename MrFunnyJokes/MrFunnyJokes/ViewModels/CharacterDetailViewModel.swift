import SwiftUI
import Combine

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
        // Holiday jokes outside their season (see `Joke.isOutOfSeason`) go to the bottom
        let now = Date()
        let inSeason = categoryFiltered.filter { !$0.isOutOfSeason(on: now) }
        let outOfSeason = categoryFiltered.filter { $0.isOutOfSeason(on: now) }
        return inSeason + outOfSeason
    }

    /// Available joke types for this character (based on character's allowed categories)
    var availableJokeTypes: [JokeCategory] {
        // Only return categories that this character is allowed to tell
        return character.allowedCategories
    }

    private var cancellables = Set<AnyCancellable>()

    init(character: JokeCharacter) {
        self.character = character

        // A finished share bumps the joke's share count on screen
        NotificationCenter.default.publisher(for: .jokeShareDidComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, let id = notification.userInfo?["firestoreId"] as? String,
                      let joke = self.jokes.first(where: { $0.firestoreId == id }) else { return }
                var counts = self.counts(for: joke)
                counts.shares += 1
                self.liveCounts[id] = counts
            }
            .store(in: &cancellables)
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
        if catalogJokes.isEmpty {
            // First launch with no connection: the starter jokes beat an empty page
            catalogJokes = catalog.starterJokes()
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

    // MARK: - Counts

    /// Laugh and share counts changed on this page, by Firestore ID
    @Published private(set) var liveCounts: [String: JokeCounts] = [:]

    func counts(for joke: Joke) -> JokeCounts {
        if let id = joke.firestoreId, let live = liveCounts[id] { return live }
        return JokeCounts(laughs: joke.likes, shares: joke.shares, horribles: joke.dislikes)
    }

    /// Laugh is the Hilarious rating; turning it off clears the rating.
    func laugh(_ joke: Joke, isOn: Bool) {
        if isOn {
            let jokeId = joke.firestoreId ?? joke.id.uuidString
            let characterId = joke.character ?? "unknown"
            Task.detached { AnalyticsService.shared.logJokeLaughed(jokeId: jokeId, character: characterId, surface: "feed_card") }
        }
        rateJoke(joke, rating: isOn ? 5 : 0)
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

        // A rating that adds or removes a laugh moves the joke's laugh count
        let likesDelta = JokeEngagement.likesDelta(
            previousRating: jokeIndex.map { jokes[$0].userRating } ?? joke.userRating,
            newRating: rating == 0 ? nil : min(max(rating, 1), 5)
        )
        let dislikesDelta = JokeEngagement.dislikesDelta(
            previousRating: jokeIndex.map { jokes[$0].userRating } ?? joke.userRating,
            newRating: rating == 0 ? nil : min(max(rating, 1), 5)
        )
        if likesDelta != 0 || dislikesDelta != 0, let firestoreId = joke.firestoreId {
            var counts = counts(for: joke)
            counts.laughs = max(counts.laughs + likesDelta, 0)
            counts.horribles = max(counts.horribles + dislikesDelta, 0)
            liveCounts[firestoreId] = counts
            Task {
                try? await firestoreService.adjustJokeLikes(jokeId: firestoreId, by: likesDelta)
                try? await firestoreService.adjustJokeDislikes(jokeId: firestoreId, by: dislikesDelta)
            }
        }

        if rating == 0 {
            storage.removeRating(for: joke.id, firestoreId: joke.firestoreId)
            if let index = jokeIndex {
                jokes[index].userRating = nil
            }
        } else {
            let clampedRating = min(max(rating, 1), 5)
            storage.saveRating(for: joke.id, firestoreId: joke.firestoreId, rating: clampedRating)
            let previousRating = jokeIndex.map { jokes[$0].userRating } ?? joke.userRating
            if let index = jokeIndex {
                jokes[index].userRating = clampedRating
            }

            // A joke newly rated Hilarious counts toward asking for an App Store rating
            if ReviewPromptService.isPositive(clampedRating), !ReviewPromptService.isPositive(previousRating) {
                ReviewPromptService.shared.recordPositiveRating()
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

    /// Shares the joke's card image and its link (mrfunnyjokes.app/j/<id>)
    func shareJoke(_ joke: Joke, from surface: JokeShareService.Surface = .jokeSheet) {
        let jokeId = joke.firestoreId ?? joke.id.uuidString
        Task.detached { AnalyticsService.shared.logJokeShared(jokeId: jokeId, method: "share") }
        JokeShareService.shared.share(joke, from: surface)
    }

    func copyJoke(_ joke: Joke) {
        HapticManager.shared.success()
        let jokeId = joke.firestoreId ?? joke.id.uuidString
        Task.detached { AnalyticsService.shared.logJokeShared(jokeId: jokeId, method: "copy") }

        let text = joke.formattedTextForSharing(characterName: character.name)
        UIPasteboard.general.string = text
        JokeShareService.shared.countShare(of: joke)

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
