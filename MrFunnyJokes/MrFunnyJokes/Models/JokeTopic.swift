import SwiftUI

/// A subject people browse jokes by ("Sports", "Christmas"), built from one or more
/// Firestore tags.
///
/// Topics are a short, curated list on purpose: the catalog carries dozens of tags, and
/// showing them all would bury the handful people look for. A topic only appears once it
/// has enough jokes to be worth opening (`minimumJokes`), so thin ones like Halloween
/// show up by themselves when the catalog fills them in.
struct JokeTopic: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    /// A joke with any of these tags belongs to the topic
    let tags: Set<String>
    let color: Color
    /// Seasonal topics lead the browse grid and get a shortcut on Home while this is true
    var isInSeason: (Date) -> Bool = { _ in false }

    /// Topics with fewer jokes than this stay hidden
    static let minimumJokes = 15

    func contains(_ joke: Joke) -> Bool {
        guard let jokeTags = joke.tags else { return false }
        return jokeTags.contains { tags.contains($0) }
    }

    static func == (lhs: JokeTopic, rhs: JokeTopic) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - The Topic List

extension JokeTopic {
    /// Every topic the app knows. "wordplay" is deliberately absent: most jokes carry it,
    /// so it narrows nothing. Bathroom humor is Mr. Potty's page.
    static let all: [JokeTopic] = [
        JokeTopic(id: "thanksgiving", name: "Thanksgiving", emoji: "🦃", tags: ["thanksgiving"], color: .orange,
                  isInSeason: { SeasonalHelper.isThanksgivingSeason(date: $0) }),
        JokeTopic(id: "christmas", name: "Christmas", emoji: "🎄", tags: ["christmas"], color: .red,
                  isInSeason: { SeasonalHelper.isChristmasFeatureSeason(date: $0) }),
        JokeTopic(id: "halloween", name: "Halloween", emoji: "🎃", tags: ["halloween"], color: .orange,
                  isInSeason: { SeasonalHelper.isHalloweenSeason(date: $0) }),
        JokeTopic(id: "food", name: "Food", emoji: "🍕", tags: ["food"], color: .orange),
        JokeTopic(id: "animals", name: "Animals", emoji: "🐶", tags: ["animals"], color: .brown),
        JokeTopic(id: "science_tech", name: "Science & Tech", emoji: "🔬", tags: ["science", "technology", "tech"], color: .blue),
        JokeTopic(id: "family", name: "Family", emoji: "👨‍👩‍👧", tags: ["family"], color: .teal),
        JokeTopic(id: "health", name: "Health", emoji: "🩺", tags: ["health"], color: .mint),
        JokeTopic(id: "work", name: "Work", emoji: "💼", tags: ["work"], color: .indigo),
        JokeTopic(id: "romance", name: "Romance", emoji: "💘", tags: ["romantic", "romance", "relationships", "sweet"], color: .pink),
        JokeTopic(id: "travel", name: "Travel", emoji: "✈️", tags: ["travel"], color: .cyan),
        JokeTopic(id: "school", name: "School", emoji: "🎒", tags: ["school"], color: .yellow),
        JokeTopic(id: "sports", name: "Sports", emoji: "⚽️", tags: ["sports"], color: .green),
        JokeTopic(id: "weather_nature", name: "Nature", emoji: "🌦️", tags: ["weather", "nature"], color: .cyan),
        JokeTopic(id: "music", name: "Music", emoji: "🎵", tags: ["music"], color: .purple),
        JokeTopic(id: "movies", name: "Movies", emoji: "🎬", tags: ["movies"], color: .gray),
    ]

    /// The topics worth showing for a catalog, with how many jokes each has:
    /// in-season topics first, then the biggest.
    static func browsable(in jokes: [Joke], on date: Date = Date()) -> [(topic: JokeTopic, count: Int)] {
        var counts: [String: Int] = [:]
        for joke in jokes {
            for topic in all where topic.contains(joke) {
                counts[topic.id, default: 0] += 1
            }
        }

        return all
            .compactMap { topic -> (topic: JokeTopic, count: Int)? in
                guard let count = counts[topic.id], count >= minimumJokes else { return nil }
                return (topic, count)
            }
            .sorted { first, second in
                let firstInSeason = first.topic.isInSeason(date)
                let secondInSeason = second.topic.isInSeason(date)
                if firstInSeason != secondInSeason { return firstInSeason }
                return first.count > second.count
            }
    }

    /// The topic to feature on Home right now, if a seasonal one is in season and has enough jokes
    static func inSeason(in jokes: [Joke], on date: Date = Date()) -> (topic: JokeTopic, count: Int)? {
        browsable(in: jokes, on: date).first { $0.topic.isInSeason(date) }
    }
}
