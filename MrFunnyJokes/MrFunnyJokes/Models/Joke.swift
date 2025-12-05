import Foundation

struct Joke: Identifiable, Codable, Equatable {
    let id: UUID
    let category: JokeCategory
    let setup: String
    let punchline: String
    var userRating: Int?

    // Firestore-specific fields
    var firestoreId: String?
    var character: String?
    var tags: [String]?
    var sfw: Bool
    var source: String?
    var ratingCount: Int
    var ratingAvg: Double
    var likes: Int
    var dislikes: Int
    var popularityScore: Double

    enum CodingKeys: String, CodingKey {
        case id, category, setup, punchline, userRating
        case firestoreId, character, tags, sfw, source
        case ratingCount, ratingAvg, likes, dislikes, popularityScore
    }

    init(
        id: UUID = UUID(),
        category: JokeCategory,
        setup: String,
        punchline: String,
        userRating: Int? = nil,
        firestoreId: String? = nil,
        character: String? = nil,
        tags: [String]? = nil,
        sfw: Bool = true,
        source: String? = nil,
        ratingCount: Int = 0,
        ratingAvg: Double = 0.0,
        likes: Int = 0,
        dislikes: Int = 0,
        popularityScore: Double = 0.0
    ) {
        self.id = id
        self.category = category
        self.setup = setup
        self.punchline = punchline
        self.userRating = userRating
        self.firestoreId = firestoreId
        self.character = character
        self.tags = tags
        self.sfw = sfw
        self.source = source
        self.ratingCount = ratingCount
        self.ratingAvg = ratingAvg
        self.likes = likes
        self.dislikes = dislikes
        self.popularityScore = popularityScore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        category = try container.decode(JokeCategory.self, forKey: .category)
        setup = try container.decode(String.self, forKey: .setup)
        punchline = try container.decode(String.self, forKey: .punchline)
        userRating = try container.decodeIfPresent(Int.self, forKey: .userRating)

        // Firestore fields with defaults for backward compatibility
        firestoreId = try container.decodeIfPresent(String.self, forKey: .firestoreId)
        character = try container.decodeIfPresent(String.self, forKey: .character)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        sfw = try container.decodeIfPresent(Bool.self, forKey: .sfw) ?? true
        source = try container.decodeIfPresent(String.self, forKey: .source)
        ratingCount = try container.decodeIfPresent(Int.self, forKey: .ratingCount) ?? 0
        ratingAvg = try container.decodeIfPresent(Double.self, forKey: .ratingAvg) ?? 0.0
        likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
        dislikes = try container.decodeIfPresent(Int.self, forKey: .dislikes) ?? 0
        popularityScore = try container.decodeIfPresent(Double.self, forKey: .popularityScore) ?? 0.0
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
