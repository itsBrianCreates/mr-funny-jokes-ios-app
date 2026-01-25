import SwiftUI
import Combine

@MainActor
final class MonthlyRankingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var hilariousJokes: [RankedJoke] = []
    @Published var horribleJokes: [RankedJoke] = []
    @Published var isLoading = true
    @Published var hasData = false
    @Published var totalHilariousRatings = 0
    @Published var totalHorribleRatings = 0
    @Published var monthDateRange: String = ""

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
            // Fetch monthly rankings from Firestore (backend collection name unchanged)
            guard let rankings = try await firestoreService.fetchWeeklyRankings() else {
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

            // Format date range
            monthDateRange = formatDateRange(start: rankings.weekStart, end: rankings.weekEnd)

            hasData = !hilariousJokes.isEmpty || !horribleJokes.isEmpty

        } catch {
            print("Failed to load monthly rankings: \(error)")
            hasData = false
        }

        isLoading = false
    }

    /// Format the month date range for display (e.g., "Dec 1 - 31")
    private func formatDateRange(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"

        let startMonthStr = monthFormatter.string(from: start)
        let startDayStr = dayFormatter.string(from: start)
        let endDayStr = dayFormatter.string(from: end)

        if startMonth == endMonth {
            // Same month: "Dec 1 - 31"
            return "\(startMonthStr) \(startDayStr) - \(endDayStr)"
        } else {
            // Different months: "Dec 30 - Jan 5"
            let endMonthStr = monthFormatter.string(from: end)
            return "\(startMonthStr) \(startDayStr) - \(endMonthStr) \(endDayStr)"
        }
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
