import Foundation

struct Joke: Identifiable, Codable, Equatable {
    let id: UUID
    let category: JokeCategory
    let setup: String
    let punchline: String
    var userRating: Int?

    init(id: UUID = UUID(), category: JokeCategory, setup: String, punchline: String, userRating: Int? = nil) {
        self.id = id
        self.category = category
        self.setup = setup
        self.punchline = punchline
        self.userRating = userRating
    }

    var ratingEmoji: String? {
        guard let rating = userRating else { return nil }
        switch rating {
        case 1: return "🫠"
        case 2: return "😩"
        case 3: return "😐"
        case 4: return "😄"
        case 5: return "😂"
        default: return nil
        }
    }

    static let ratingEmojis = ["🫠", "😩", "😐", "😄", "😂"]
}

// MARK: - API Response Models

struct DadJokeResponse: Codable {
    let id: String
    let joke: String
    let status: Int
}

struct OfficialJokeResponse: Codable {
    let id: Int
    let type: String
    let setup: String
    let punchline: String
}
