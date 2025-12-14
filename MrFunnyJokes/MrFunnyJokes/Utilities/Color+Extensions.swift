import SwiftUI

extension Color {
    /// Accessible yellow for tab bar - meets WCAG contrast ratios
    static let accessibleYellow = Color(
        light: Color(red: 216/255, green: 167/255, blue: 0/255),    // #D8A700
        dark: Color(red: 242/255, green: 201/255, blue: 76/255)     // #F2C94C
    )

    /// Brand yellow (#FFE135) - the signature Mr. Funny Jokes yellow
    /// Used prominently for featured content like Joke of the Day
    static let brandYellow = Color(red: 1.0, green: 0.882, blue: 0.208)  // #FFE135

    /// Softer brand yellow for backgrounds that need less intensity
    static let brandYellowLight = Color(
        light: Color(red: 1.0, green: 0.95, blue: 0.8),   // Very soft yellow for light mode
        dark: Color(red: 0.25, green: 0.22, blue: 0.1)    // Warm dark background for dark mode
    )

    /// Darker brown for Mr. Potty - more visible than standard brown
    static let pottyBrown = Color(
        light: Color(red: 101/255, green: 67/255, blue: 33/255),   // #654321 - darker chocolate brown
        dark: Color(red: 139/255, green: 90/255, blue: 43/255)     // #8B5A2B - warm saddle brown for dark mode
    )

    /// Standard card background - subtle gray for cards throughout the app
    static let cardBackground = Color(
        light: Color(red: 0.96, green: 0.96, blue: 0.97),  // Light gray
        dark: Color(red: 0.15, green: 0.15, blue: 0.16)    // Dark gray
    )
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - ShapeStyle Extension for leading-dot syntax support

extension ShapeStyle where Self == Color {
    /// Accessible yellow that meets WCAG contrast ratios
    static var accessibleYellow: Color { Color.accessibleYellow }

    /// Brand yellow (#FFE135) - the signature Mr. Funny Jokes yellow
    static var brandYellow: Color { Color.brandYellow }

    /// Softer brand yellow for backgrounds
    static var brandYellowLight: Color { Color.brandYellowLight }

    /// Darker brown for Mr. Potty
    static var pottyBrown: Color { Color.pottyBrown }

    /// Standard card background - subtle gray
    static var cardBackground: Color { Color.cardBackground }
}
