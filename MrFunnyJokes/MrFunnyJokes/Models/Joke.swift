import Foundation
import CryptoKit

struct Joke: Identifiable, Codable, Equatable {
    let id: UUID
    let category: JokeCategory
    let setup: String
    let punchline: String
    var userRating: Int?
    var isSaved: Bool = false

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
    /// When the joke was added to the catalog. Nil for jokes cached by older versions.
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, category, setup, punchline, userRating, isSaved
        case firestoreId, character, tags, sfw, source
        case ratingCount, ratingAvg, likes, dislikes, popularityScore, createdAt
    }

    init(
        id: UUID = UUID(),
        category: JokeCategory,
        setup: String,
        punchline: String,
        userRating: Int? = nil,
        isSaved: Bool = false,
        firestoreId: String? = nil,
        character: String? = nil,
        tags: [String]? = nil,
        sfw: Bool = true,
        source: String? = nil,
        ratingCount: Int = 0,
        ratingAvg: Double = 0.0,
        likes: Int = 0,
        dislikes: Int = 0,
        popularityScore: Double = 0.0,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.setup = setup
        self.punchline = punchline
        self.userRating = userRating
        self.isSaved = isSaved
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
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        category = try container.decode(JokeCategory.self, forKey: .category)
        setup = try container.decode(String.self, forKey: .setup)
        punchline = try container.decode(String.self, forKey: .punchline)
        userRating = try container.decodeIfPresent(Int.self, forKey: .userRating)
        isSaved = try container.decodeIfPresent(Bool.self, forKey: .isSaved) ?? false

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
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    var ratingEmoji: String? {
        guard let rating = userRating else { return nil }
        switch rating {
        case 1: return "🫠"
        case 5: return "😂"
        default: return nil
        }
    }

    static let ratingEmojis = ["🫠", "😂"]

    /// The same `id` for a Firestore joke every time it is decoded, so a joke keeps its
    /// place in lists, its selection and its scroll anchor when the catalog is re-fetched.
    static func stableID(forFirestoreId firestoreId: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(firestoreId.utf8)).prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    // MARK: - Display Text

    /// What cards show: the setup only, never the punchline
    var cardText: String {
        JokeTextParser.teaser(setup: setup, punchline: punchline, isKnockKnock: category == .knockKnock)
    }

    /// The setup, one line per part for knock-knock jokes
    var setupLines: [String] {
        category == .knockKnock ? JokeTextParser.knockKnockLines(setup) : [setup]
    }

    /// The punchline, one line per part for knock-knock jokes. Empty when there is none.
    var punchlineLines: [String] {
        let lines = category == .knockKnock ? JokeTextParser.knockKnockLines(punchline) : [punchline]
        return lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Formats the joke text for sharing and copying
    func formattedTextForSharing(characterName: String) -> String {
        let text = JokeTextParser.fullText(setup: setup, punchline: punchline, isKnockKnock: category == .knockKnock)
        return "\(text)\n\n— \(characterName)"
    }
}
