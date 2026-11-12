import Foundation

/// Shared data model for the Joke of the Day widget
/// This is a lightweight version of the Joke model used for widget communication
struct SharedJokeOfTheDay: Codable {
    let id: String
    let setup: String
    let punchline: String
    let category: String?
    let firestoreId: String?
    let character: String?
    let lastUpdated: Date

    init(id: String, setup: String, punchline: String, category: String? = nil, firestoreId: String? = nil, character: String? = nil, lastUpdated: Date = Date()) {
        self.id = id
        self.setup = setup
        self.punchline = punchline
        self.category = category
        self.firestoreId = firestoreId
        self.character = character
        self.lastUpdated = lastUpdated
    }

    /// What widgets and notifications show: the setup only, never the punchline
    var cardText: String {
        // An entry saved by an older version can hold the whole joke in `setup`
        // with no punchline. Split it again so the widget doesn't give it away.
        var parts = (setup: setup, punchline: punchline)
        if punchline.isEmpty {
            parts = JokeTextParser.split(setup)
        }
        return JokeTextParser.teaser(
            setup: parts.setup,
            punchline: parts.punchline,
            isKnockKnock: JokeTextParser.isKnockKnock(parts.setup)
        )
    }

    /// `cardText` on one flowing line, for slots too short for a three-line knock-knock
    var compactCardText: String {
        cardText.replacingOccurrences(of: "\n", with: " ")
    }

    /// Default placeholder for when no data is available yet
    /// Shown when: JOTD is stale (>24h), network fetch fails, and fallback cache is empty
    static let placeholder = SharedJokeOfTheDay(
        id: "placeholder",
        setup: "Open Mr. Funny Jokes to get started!",
        punchline: "",
        category: nil,
        firestoreId: nil,
        character: nil,
        lastUpdated: Date()
    )
}
