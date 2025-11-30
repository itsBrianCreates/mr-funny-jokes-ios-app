import SwiftUI

extension Color {
    /// Accessible yellow that meets WCAG contrast ratios in both light and dark modes
    /// Uses a deep golden/amber tone for better text contrast against backgrounds
    static let accessibleYellow = Color(
        light: Color(red: 0.70, green: 0.50, blue: 0.0),  // Deep amber for light mode
        dark: Color(red: 0.90, green: 0.68, blue: 0.05)   // Rich gold for dark mode
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
