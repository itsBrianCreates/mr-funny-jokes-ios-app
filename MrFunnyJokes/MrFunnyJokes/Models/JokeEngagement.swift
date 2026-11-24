import Foundation

/// Laugh and share counts and how they read. Counts always show, zero included.
enum JokeEngagement {
    /// 0, 348, 1.2K, 15K, 2.4M
    static func compact(_ count: Int) -> String {
        switch count {
        case ..<1_000:
            return "\(max(count, 0))"
        case ..<1_000_000:
            return shortened(Double(count) / 1_000, suffix: "K")
        default:
            return shortened(Double(count) / 1_000_000, suffix: "M")
        }
    }

    private static func shortened(_ value: Double, suffix: String) -> String {
        // One decimal below 10 (1.2K), none above (15K). Rounded down, so 1,999 is 1.9K.
        if value < 10 {
            let tenths = (value * 10).rounded(.down) / 10
            let text = tenths == tenths.rounded() ? String(format: "%.0f", tenths) : String(format: "%.1f", tenths)
            return text + suffix
        }
        return String(format: "%.0f", value.rounded(.down)) + suffix
    }

    /// How a rating change moves the joke's `likes` count. Laugh is the Hilarious rating (5).
    static func likesDelta(previousRating: Int?, newRating: Int?) -> Int {
        let wasLaughing = previousRating == 5
        let isLaughing = newRating == 5
        if isLaughing && !wasLaughing { return 1 }
        if wasLaughing && !isLaughing { return -1 }
        return 0
    }
}

/// Live laugh and share counts for one joke
struct JokeCounts: Equatable {
    var laughs: Int
    var shares: Int
}
