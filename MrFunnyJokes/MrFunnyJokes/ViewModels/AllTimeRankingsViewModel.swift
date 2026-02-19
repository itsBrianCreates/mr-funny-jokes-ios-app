import SwiftUI
import Combine

@MainActor
final class AllTimeRankingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var hilariousJokes: [RankedJoke] = []
    @Published var horribleJokes: [RankedJoke] = []
    @Published var isLoading = true
    @Published var hasData = false
    @Published var totalHilariousRatings = 0
    @Published var totalHorribleRatings = 0

    // MARK: - Private Properties

    private let firestoreService = FirestoreService.shared
    private var loadTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        loadTask = Task {
            await loadRankings()
        }
    }

    deinit {
        loadTask?.cancel()
    }

    // MARK: - Public Methods

    /// Refresh the rankings data
    func refresh() async {
        await loadRankings()
    }

    // MARK: - Private Methods

    private func loadRankings() async {
        isLoading = true

        do {
            // Fetch all-time rankings from Firestore (backend collection name unchanged)
            guard let rankings = try await firestoreService.fetchAllTimeRankings() else {
                // No rankings data yet
                isLoading = false
                hasData = false
                return
            }

            // Get all joke IDs we need to fetch
            let hilariousIds = rankings.hilarious.map { $0.jokeId }
            let horribleIds = rankings.horrible.map { $0.jokeId }
            let allIds = Array(Set(hilariousIds + horribleIds))

            // Fetch all jokes in parallel
            let jokesDict = try await firestoreService.fetchJokes(byIds: allIds)

            // Build hilarious ranked jokes (sorted by rank, which is 1-10)
            hilariousJokes = rankings.hilarious.compactMap { entry in
                guard let joke = jokesDict[entry.jokeId] else { return nil }
                return RankedJoke(rank: entry.rank, count: entry.count, joke: joke)
            }.sorted { $0.rank < $1.rank }

            // Build horrible ranked jokes (sorted by rank, which is 1-10)
            horribleJokes = rankings.horrible.compactMap { entry in
                guard let joke = jokesDict[entry.jokeId] else { return nil }
                return RankedJoke(rank: entry.rank, count: entry.count, joke: joke)
            }.sorted { $0.rank < $1.rank }

            // Store totals
            totalHilariousRatings = rankings.totalHilariousRatings
            totalHorribleRatings = rankings.totalHorribleRatings

            hasData = !hilariousJokes.isEmpty || !horribleJokes.isEmpty

        } catch {
            print("Failed to load all-time rankings: \(error)")
            hasData = false
        }

        isLoading = false
    }

    /// Get jokes for a specific ranking type, reversed for countdown display (10 -> 1)
    func getJokesForCountdown(type: RankingType) -> [RankedJoke] {
        switch type {
        case .hilarious:
            return hilariousJokes.reversed()
        case .horrible:
            return horribleJokes.reversed()
        }
    }

    /// Get total ratings for a ranking type
    func getTotalRatings(for type: RankingType) -> Int {
        switch type {
        case .hilarious:
            return totalHilariousRatings
        case .horrible:
            return totalHorribleRatings
        }
    }

    /// Check if a ranking type has data
    func hasDataFor(type: RankingType) -> Bool {
        switch type {
        case .hilarious:
            return !hilariousJokes.isEmpty
        case .horrible:
            return !horribleJokes.isEmpty
        }
    }
}
