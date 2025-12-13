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

    /// All available characters in the app (for jokes UI - excludes Brian)
    static let allCharacters: [JokeCharacter] = [
        .mrFunny,
        .mrBad,
        .mrLove,
        .mrPotty,
        .mrSad
    ]

    /// All characters including video-only characters like Brian
    static let allCharactersIncludingVideoOnly: [JokeCharacter] = [
        .mrFunny,
        .mrBad,
        .mrLove,
        .mrPotty,
        .mrSad,
        .brian
    ]

    // MARK: - Character Definitions

    static let mrFunny = JokeCharacter(
        id: "mr_funny",
        name: "Mr. Funny",
        fullName: "Mr. Funny",
        bio: "Dad jokes so good, they're bad. So bad, they're good. Your kids will hate you. You're welcome.",
        imageName: "MrFunny",
        color: .accessibleYellow,
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrBad = JokeCharacter(
        id: "mr_bad",
        name: "Mr. Bad",
        fullName: "Mr. Bad",
        bio: "Dark humor for twisted minds. If you laughed at that funeral scene, you're in the right place.",
        imageName: "MrBad",
        color: .red,
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrSad = JokeCharacter(
        id: "mr_sad",
        name: "Mr. Sad",
        fullName: "Mr. Sad",
        bio: "Jokes so bleak they circle back to funny. Laugh now, cry later. Or both at once.",
        imageName: "MrSad",
        color: .blue,
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrPotty = JokeCharacter(
        id: "mr_potty",
        name: "Mr. Potty",
        fullName: "Mr. Potty",
        bio: "Farts, butts, and bodily functions. Juvenile? Absolutely. Hilarious? Also yes.",
        imageName: "MrPotty",
        color: .pottyBrown,
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrLove = JokeCharacter(
        id: "mr_love",
        name: "Mr. Love",
        fullName: "Mr. Love",
        bio: "Pickup lines so smooth, they actually work. Trust me. I've never been rejected. Not once.",
        imageName: "MrLove",
        color: .pink,
        allowedCategories: [.pickupLine]
    )

    /// Brian - the creator, appears in videos only
    static let brian = JokeCharacter(
        id: "brian",
        name: "Brian",
        fullName: "Brian",
        bio: "The guy behind the characters. Sometimes I show up in videos too.",
        imageName: "Brian",
        color: .accessibleYellow,
        allowedCategories: [] // Videos only, no jokes
    )

    /// Find a character by its ID (searches all characters including video-only)
    static func find(byId id: String) -> JokeCharacter? {
        allCharactersIncludingVideoOnly.first { $0.id == id }
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
