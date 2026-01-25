import Foundation

/// Shared data model for jokes cached for Siri access
/// This is a lightweight version of the Joke model used for Siri integration
struct SharedJoke: Codable, Identifiable {
    let id: String
    let setup: String
    let punchline: String
    let character: String?  // Character ID (e.g., "mr_funny")
    let type: String?       // Joke type (e.g., "knock_knock", "dad_joke")

    /// Full joke text combining setup and punchline
    var text: String { "\(setup) \(punchline)" }

    init(id: String, setup: String, punchline: String, character: String? = nil, type: String? = nil) {
        self.id = id
        self.setup = setup
        self.punchline = punchline
        self.character = character
        self.type = type
    }
}
