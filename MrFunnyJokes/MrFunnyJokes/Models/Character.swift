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
    /// Soft background color for featured cards (Joke of the Day, widgets)
    let backgroundColor: Color
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
        .mrLove,
        .mrPotty,
        .mrSad
    ]

    // MARK: - Character Definitions

    static let mrFunny = JokeCharacter(
        id: "mr_funny",
        name: "Mr. Funny",
        fullName: "Mr. Funny",
        bio: "Dad jokes so good, they're bad. So bad, they're good. Your kids will hate you. You're welcome.",
        imageName: "MrFunny",
        color: .accessibleYellow,
        backgroundColor: Color(
            light: Color(red: 1.0, green: 0.98, blue: 0.94),   // Warm cream
            dark: Color(red: 0.18, green: 0.16, blue: 0.10)    // Warm dark
        ),
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrBad = JokeCharacter(
        id: "mr_bad",
        name: "Mr. Bad",
        fullName: "Mr. Bad",
        bio: "Dark humor for twisted minds. If you laughed at that funeral scene, you're in the right place.",
        imageName: "MrBad",
        color: .red,
        backgroundColor: Color(
            light: Color(red: 1.0, green: 0.95, blue: 0.95),   // Soft red/pink tint
            dark: Color(red: 0.18, green: 0.12, blue: 0.12)    // Dark red tint
        ),
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrSad = JokeCharacter(
        id: "mr_sad",
        name: "Mr. Sad",
        fullName: "Mr. Sad",
        bio: "Jokes so bleak they circle back to funny. Laugh now, cry later. Or both at once.",
        imageName: "MrSad",
        color: .blue,
        backgroundColor: Color(
            light: Color(red: 0.94, green: 0.96, blue: 1.0),   // Soft blue tint
            dark: Color(red: 0.10, green: 0.12, blue: 0.18)    // Dark blue tint
        ),
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrPotty = JokeCharacter(
        id: "mr_potty",
        name: "Mr. Potty",
        fullName: "Mr. Potty",
        bio: "Farts, butts, and bodily functions. Juvenile? Absolutely. Hilarious? Also yes.",
        imageName: "MrPotty",
        color: .pottyBrown,
        backgroundColor: Color(
            light: Color(red: 0.98, green: 0.96, blue: 0.93),  // Soft tan/beige
            dark: Color(red: 0.16, green: 0.14, blue: 0.10)    // Dark brown tint
        ),
        allowedCategories: [.dadJoke, .knockKnock]
    )

    static let mrLove = JokeCharacter(
        id: "mr_love",
        name: "Mr. Love",
        fullName: "Mr. Love",
        bio: "Pickup lines so smooth, they actually work. Trust me. I've never been rejected. Not once.",
        imageName: "MrLove",
        color: .pink,
        backgroundColor: Color(
            light: Color(red: 1.0, green: 0.95, blue: 0.97),   // Soft pink tint
            dark: Color(red: 0.18, green: 0.12, blue: 0.14)    // Dark pink tint
        ),
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
