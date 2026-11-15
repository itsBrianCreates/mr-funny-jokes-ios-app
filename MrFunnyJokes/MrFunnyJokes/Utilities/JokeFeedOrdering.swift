import Foundation

/// Orders a feed so the jokes a person hasn't seen come first.
///
/// Shared by the home feed and the character pages. Call it once when a feed is
/// built (launch, pull-to-refresh, coming back after a while), never while the
/// person is scrolling: the order has to hold still under their thumb.
enum JokeFeedOrdering {
    /// Unseen jokes added to the catalog within this window lead the feed
    static let recentlyAddedWindow: TimeInterval = 30 * 24 * 60 * 60

    /// - Parameters:
    ///   - jokes: Jokes with `userRating` already applied
    ///   - seenOrder: IDs of jokes whose card has been on screen, least recently seen first
    ///   - ratedIds: IDs of jokes the person has rated
    ///   - viewedIds: IDs of jokes the person has opened (punchline revealed)
    /// - Returns: Newly added unseen jokes, then other unseen jokes, then jokes scrolled
    ///   past but never opened, then jokes already opened or rated. The first two groups
    ///   are shuffled; the last two run least recently seen first, so even a person who
    ///   has seen everything gets the jokes they saw longest ago.
    static func freshFirst(
        _ jokes: [Joke],
        seenOrder: [String],
        ratedIds: Set<String>,
        viewedIds: Set<String>,
        now: Date = Date()
    ) -> [Joke] {
        var seenRank: [String: Int] = [:]
        for (rank, id) in seenOrder.enumerated() {
            seenRank[id] = rank
        }

        var newlyAdded: [Joke] = []
        var unseen: [Joke] = []
        var scrolledPast: [(joke: Joke, rank: Int)] = []
        var finished: [(joke: Joke, rank: Int)] = []

        for joke in jokes {
            let key = joke.firestoreId ?? joke.id.uuidString
            let rank = seenRank[key]

            if joke.userRating != nil || ratedIds.contains(key) || viewedIds.contains(key) {
                finished.append((joke, rank ?? -1))
            } else if let rank {
                scrolledPast.append((joke, rank))
            } else if let createdAt = joke.createdAt, now.timeIntervalSince(createdAt) < recentlyAddedWindow {
                newlyAdded.append(joke)
            } else {
                unseen.append(joke)
            }
        }

        return newlyAdded.shuffled()
            + unseen.shuffled()
            + scrolledPast.sorted { $0.rank < $1.rank }.map(\.joke)
            + finished.sorted { $0.rank < $1.rank }.map(\.joke)
    }
}
