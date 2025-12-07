import Foundation
import FirebaseFirestore

// MARK: - Firestore Joke Model

/// Represents a joke document from the Firestore "jokes" collection
struct FirestoreJoke: Codable, Identifiable {
    @DocumentID var id: String?
    let text: String
    let type: String
    let character: String?
    let tags: [String]?
    let sfw: Bool?
    let source: String?
    let createdAt: Date?
    let ratingCount: Int?
    let ratingSum: Int?
    let ratingAvg: Double?
    let likes: Int?
    let dislikes: Int?
    let popularityScore: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case type
        case character
        case tags
        case sfw
        case source
        case createdAt = "created_at"
        case ratingCount = "rating_count"
        case ratingSum = "rating_sum"
        case ratingAvg = "rating_avg"
        case likes
        case dislikes
        case popularityScore = "popularity_score"
    }

    /// Converts Firestore joke to the app's Joke model
    func toJoke() -> Joke {
        let category = JokeCategory.fromFirestoreType(type)

        // Parse the text - some jokes may have setup/punchline format
        let (setup, punchline) = parseJokeText(text, category: category)

        return Joke(
            id: UUID(uuidString: id ?? "") ?? UUID(),
            category: category,
            setup: setup,
            punchline: punchline,
            firestoreId: id,
            character: character,
            tags: tags,
            sfw: sfw ?? true,
            source: source,
            ratingCount: ratingCount ?? 0,
            ratingAvg: ratingAvg ?? 0.0,
            likes: likes ?? 0,
            dislikes: dislikes ?? 0,
            popularityScore: popularityScore ?? 0.0
        )
    }

    /// Parse joke text into setup and punchline
    private func parseJokeText(_ text: String, category: JokeCategory) -> (setup: String, punchline: String) {
        // Special handling for knock-knock jokes
        if category == .knockKnock {
            return parseKnockKnockJoke(text)
        }

        // Try to split on common delimiters
        let delimiters = ["\n\n", "\n", " - ", "? ", "! "]

        for delimiter in delimiters {
            let parts = text.components(separatedBy: delimiter)
            if parts.count >= 2 {
                let setup = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let punchline = parts.dropFirst().joined(separator: delimiter).trimmingCharacters(in: .whitespacesAndNewlines)
                if !setup.isEmpty && !punchline.isEmpty {
                    // For question delimiter, add it back
                    if delimiter == "? " {
                        return (setup + "?", punchline)
                    }
                    if delimiter == "! " {
                        return (setup + "!", punchline)
                    }
                    return (setup, punchline)
                }
            }
        }

        // If no delimiter found, use the whole text as setup with empty punchline
        return (text, "")
    }

    /// Parse knock-knock joke into setup and punchline
    /// Input: "Knock, knock. Who's there? Nobel. Nobel who? Nobel … that's why I knocked."
    /// Output: setup = "Knock, knock. Who's there? Nobel." punchline = "Nobel who? Nobel … that's why I knocked."
    private func parseKnockKnockJoke(_ text: String) -> (setup: String, punchline: String) {
        // Find the "[Name] who?" pattern to split setup and punchline
        // This matches a word followed by " who?" (case insensitive)
        if let whoRange = text.range(of: #"\b\w+\s+who\?"#, options: [.regularExpression, .caseInsensitive]) {
            let setup = String(text[..<whoRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let punchline = String(text[whoRange.lowerBound...]).trimmingCharacters(in: .whitespaces)

            return (setup, punchline)
        }

        // Fallback: use the whole text as setup
        return (text, "")
    }
}

// MARK: - Firestore Character Model

/// Represents a character document from the Firestore "characters" collection
struct FirestoreCharacter: Codable, Identifiable {
    @DocumentID var id: String?
    let name: String
    let personality: String?
    let jokeTypes: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case personality
        case jokeTypes = "joke_types"
    }
}

// MARK: - JokeCategory Extension for Firestore

extension JokeCategory {
    /// Maps Firestore type string to JokeCategory
    static func fromFirestoreType(_ type: String) -> JokeCategory {
        let normalizedType = type.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalizedType {
        case "dad", "dad joke", "dad_joke", "dadjoke", "dad jokes":
            return .dadJoke
        case "knock", "knock-knock", "knock_knock", "knockknock", "knock-knock jokes":
            return .knockKnock
        case "pickup", "pickup line", "pickup_line", "pickupline", "pick up line", "pick up lines":
            return .pickupLine
        default:
            // Default to dad joke for unknown types
            return .dadJoke
        }
    }

    /// Returns the Firestore type string for this category
    /// Must match the type values stored in the database (e.g., from add-jokes.js)
    var firestoreType: String {
        switch self {
        case .dadJoke:
            return "dad_joke"
        case .knockKnock:
            return "knock_knock"
        case .pickupLine:
            return "pickup_line"
        }
    }
}
