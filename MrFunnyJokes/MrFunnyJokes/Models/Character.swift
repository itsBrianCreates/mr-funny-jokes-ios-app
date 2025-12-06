import SwiftUI

/// Represents a character persona that categorizes jokes in the app
/// Named JokeCharacter to avoid conflict with Swift's built-in Character type
struct JokeCharacter: Identifiable, Hashable {
    let id: String
    let name: String
    let fullName: String
    let bio: String
    let imageName: String
    let color: Color
    /// The joke categories this character can tell
    let allowedCategories: [JokeCategory]

    /// Whether this character has multiple categories (and thus needs a filter)
    var hasMultipleCategories: Bool {
        allowedCategories.count > 1
    }

    /// All available characters in the app
    static let allCharacters: [JokeCharacter] = [
        .mrFunny,
        .mrBad,
        .mrSad,
        .mrPotty,
        .mrLove
    ]

    // MARK: - Character Definitions

    static let mrFunny = JokeCharacter(
        id: "mr_funny",
        name: "Mr. Funny",
        fullName: "Mr. Funny",
        bio: "Your friendly neighborhood dad joke enthusiast. Bringing wholesome laughs and guaranteed groans since... well, since dads existed.",
        imageName: "MrFunny",
        color: .yellow,
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrBad = JokeCharacter(
        id: "mr_bad",
        name: "Mr. Bad",
        fullName: "Mr. Bad",
        bio: "Dark humor connoisseur. Not for the faint of heart, but perfect for those who laugh at life's absurdities.",
        imageName: "MrBad",
        color: .red,
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrSad = JokeCharacter(
        id: "mr_sad",
        name: "Mr. Sad",
        fullName: "Mr. Sad",
        bio: "Finding humor in melancholy. Sometimes you just need to laugh to keep from crying.",
        imageName: "MrSad",
        color: .blue,
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrPotty = JokeCharacter(
        id: "mr_potty",
        name: "Mr. Potty",
        fullName: "Mr. Potty",
        bio: "Embracing the humor that makes you say 'ew' and 'haha' at the same time. You've been warned.",
        imageName: "MrPotty",
        color: .brown,
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrLove = JokeCharacter(
        id: "mr_love",
        name: "Mr. Love",
        fullName: "Mr. Love",
        bio: "Smooth operator with lines that are so cheesy they just might work. Use responsibly.",
        imageName: "MrLove",
        color: .pink,
        allowedCategories: [.pickupLine]
    )

    /// Find a character by its ID
    static func find(byId id: String) -> JokeCharacter? {
        allCharacters.first { $0.id == id }
    }

    /// Find a character by name (case-insensitive)
    static func find(byName name: String) -> JokeCharacter? {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return allCharacters.first { character in
            character.name.lowercased() == normalizedName ||
            character.id.lowercased() == normalizedName ||
            // Handle variations like "Mr Funny" vs "Mr. Funny"
            character.name.lowercased().replacingOccurrences(of: ".", with: "") == normalizedName.replacingOccurrences(of: ".", with: "")
        }
    }
}
