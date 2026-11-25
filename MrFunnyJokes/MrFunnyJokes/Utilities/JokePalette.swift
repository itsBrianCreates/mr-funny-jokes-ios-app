import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// A character's colors for the full screen joke view and share cards. Fixed colors,
/// not light/dark adaptive: a share card looks the same whatever the phone is set to.
struct JokePalette {
    /// The character's signature color
    let color: Color
    /// Text on `color`
    let onColor: Color
    /// The background painted into the character's portrait, so the portrait
    /// can sit on it without a visible edge
    let portraitBackground: Color
    /// The character's color for text on white
    let inkOnLight: Color
    /// A very dark shade of the color, for reply bubbles
    let deep: Color
    /// The punchline pill on `color`, and its text
    let pillOnColor: Color
    let onPillOnColor: Color
    /// The punchline pill on a near-black background, and its text
    let pillOnDark: Color
    let onPillOnDark: Color
    /// Near-black background for the Dark style
    let darkBackground: Color

    static let mrFunny = JokePalette(
        color: Color(hex: 0xFDCA01), onColor: Color(hex: 0x2A1F00),
        portraitBackground: Color(hex: 0xFDCA01), inkOnLight: Color(hex: 0x2A1F00),
        deep: Color(hex: 0x2A1F00),
        pillOnColor: .white, onPillOnColor: Color(hex: 0x2A1F00),
        pillOnDark: Color(hex: 0xFDCA01), onPillOnDark: Color(hex: 0x2A1F00),
        darkBackground: Color(hex: 0x171512)
    )

    static let mrLove = JokePalette(
        color: Color(hex: 0xC2185B), onColor: .white,
        portraitBackground: Color(hex: 0xD91C72), inkOnLight: Color(hex: 0xC2185B),
        deep: Color(hex: 0x4A0A24),
        pillOnColor: .white, onPillOnColor: Color(hex: 0xB01552),
        pillOnDark: Color(hex: 0xD91C72), onPillOnDark: .white,
        darkBackground: Color(hex: 0x181214)
    )

    static let mrBad = JokePalette(
        color: Color(hex: 0xEB2B20), onColor: .white,
        portraitBackground: Color(hex: 0xEA2A20), inkOnLight: Color(hex: 0xD32218),
        deep: Color(hex: 0x3A0A07),
        pillOnColor: .white, onPillOnColor: Color(hex: 0xC81F15),
        pillOnDark: Color(hex: 0xEB2B20), onPillOnDark: .white,
        darkBackground: Color(hex: 0x191312)
    )

    static let mrSad = JokePalette(
        color: Color(hex: 0x0A75E7), onColor: .white,
        portraitBackground: Color(hex: 0x067AF0), inkOnLight: Color(hex: 0x0A5FC0),
        deep: Color(hex: 0x062F5E),
        pillOnColor: .white, onPillOnColor: Color(hex: 0x0A3F80),
        pillOnDark: Color(hex: 0x0A75E7), onPillOnDark: .white,
        darkBackground: Color(hex: 0x111418)
    )

    static let mrPotty = JokePalette(
        color: Color(hex: 0x50260E), onColor: Color(hex: 0xFFF3DC),
        portraitBackground: Color(hex: 0x4F270E), inkOnLight: Color(hex: 0x50260E),
        deep: Color(hex: 0x1F0E04),
        pillOnColor: Color(hex: 0xFFF3DC), onPillOnColor: Color(hex: 0x50260E),
        pillOnDark: Color(hex: 0xFFF3DC), onPillOnDark: Color(hex: 0x50260E),
        darkBackground: Color(hex: 0x171311)
    )

    static func palette(for character: JokeCharacter?) -> JokePalette {
        switch character?.id {
        case "mr_love": return .mrLove
        case "mr_bad": return .mrBad
        case "mr_sad": return .mrSad
        case "mr_potty": return .mrPotty
        default: return .mrFunny
        }
    }
}

/// The colors one joke layout needs, whatever it is drawn on
struct JokeSurfaceColors {
    var background: Color
    var border: Color? = nil
    /// Setup text, labels and footer
    var text: Color
    /// The punchline pill, and the teller's bubbles in a knock-knock
    var pill: Color
    var pillText: Color
    /// The other side of a knock-knock ("Who's there?")
    var reply: Color
    var replyText: Color
}

extension Joke {
    /// The character telling this joke. `character` holds an ID or a name depending on its source.
    var teller: JokeCharacter? {
        character.flatMap { JokeCharacter.find(byName: $0) }
    }

    /// "Dad joke", "Knock knock", "Pickup line"
    var typeLabel: String {
        switch category {
        case .dadJoke: return "Dad joke"
        case .knockKnock: return "Knock knock"
        case .pickupLine: return "Pickup line"
        }
    }

    var hasPunchline: Bool {
        !punchlineLines.isEmpty
    }
}
