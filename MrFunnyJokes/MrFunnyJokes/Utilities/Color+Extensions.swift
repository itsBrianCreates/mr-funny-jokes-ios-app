import SwiftUI

extension Color {
    /// Accessible yellow that meets WCAG contrast ratios in both light and dark modes
    /// Uses a deep golden/amber tone for better text contrast against backgrounds
    static let accessibleYellow = Color(
        light: Color(red: 0.70, green: 0.50, blue: 0.0),  // Deep amber for light mode
        dark: Color(red: 0.90, green: 0.68, blue: 0.05)   // Rich gold for dark mode
    )

    /// Brand yellow (#FFE135) - the signature Mr. Funny Jokes yellow
    /// Used prominently for featured content like Joke of the Day
    static let brandYellow = Color(red: 1.0, green: 0.882, blue: 0.208)  // #FFE135

    /// Softer brand yellow for backgrounds that need less intensity
    static let brandYellowLight = Color(
        light: Color(red: 1.0, green: 0.95, blue: 0.8),   // Very soft yellow for light mode
        dark: Color(red: 0.25, green: 0.22, blue: 0.1)    // Warm dark background for dark mode
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
}
