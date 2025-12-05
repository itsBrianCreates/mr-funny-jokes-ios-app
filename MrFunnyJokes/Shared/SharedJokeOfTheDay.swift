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

    /// Default placeholder for when no data is available yet
    static let placeholder = SharedJokeOfTheDay(
        id: "placeholder",
        setup: "Loading jokes...",
        punchline: "Open the app to get today's joke!",
        category: nil,
        lastUpdated: Date()
    )
}
