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

    /// Formats the joke text for sharing, with special handling for knock-knock jokes
    /// to display each part on its own line.
    func formattedTextForSharing(characterName: String) -> String {
        if category == .knockKnock {
            return formatKnockKnockForSharing(characterName: characterName)
        } else {
            return "\(setup)\n\n\(punchline)\n\n— \(characterName)"
        }
    }

    private func formatKnockKnockForSharing(characterName: String) -> String {
        var lines: [String] = []

        // Format setup: "Knock, knock. Who's there? Nobel." -> ["Knock, knock.", "Who's there?", "Nobel."]
        if let range = setup.range(of: "Who's there?", options: .caseInsensitive) {
            // Part before "Who's there?" (e.g., "Knock, knock.")
            let knockPart = String(setup[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !knockPart.isEmpty {
                lines.append(knockPart)
            }

            // "Who's there?"
            lines.append("Who's there?")

            // The answer (e.g., "Nobel.")
            let answer = String(setup[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !answer.isEmpty {
                var formattedAnswer = answer.prefix(1).uppercased() + answer.dropFirst()
                if !formattedAnswer.hasSuffix(".") && !formattedAnswer.hasSuffix("!") && !formattedAnswer.hasSuffix("?") {
                    formattedAnswer += "."
                }
                lines.append(formattedAnswer)
            }
        } else {
            lines.append(setup)
        }

        // Format punchline: "Nobel who? Nobel … that's why I knocked." -> ["Nobel who?", "Nobel … that's why I knocked."]
        if let whoRange = punchline.range(of: " who?", options: .caseInsensitive) {
            let questionPart = String(punchline[...whoRange.upperBound]).trimmingCharacters(in: .whitespaces)
            let answerPart = String(punchline[whoRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            lines.append(questionPart)
            if !answerPart.isEmpty {
                lines.append(answerPart)
            }
        } else {
            lines.append(punchline)
        }

        lines.append("")
        lines.append("— \(characterName)")

        return lines.joined(separator: "\n")
    }
}
