import Foundation

/// Shared data model for the Joke of the Day widget
/// This is a lightweight version of the Joke model used for widget communication
struct SharedJokeOfTheDay: Codable {
    let id: String
    let setup: String
    let punchline: String
    let category: String?
    let lastUpdated: Date

    init(id: String, setup: String, punchline: String, category: String? = nil, lastUpdated: Date = Date()) {
        self.id = id
        self.setup = setup
        self.punchline = punchline
        self.category = category
        self.lastUpdated = lastUpdated
    }

    /// Default placeholder joke for when no data is available
    static let placeholder = SharedJokeOfTheDay(
        id: "placeholder",
        setup: "Why don't scientists trust atoms?",
        punchline: "Because they make up everything!",
        category: "Dad Jokes",
        lastUpdated: Date()
    )
}
