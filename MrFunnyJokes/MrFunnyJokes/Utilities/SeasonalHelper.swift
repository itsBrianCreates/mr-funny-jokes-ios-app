import Foundation

// MARK: - Seasonal Content

/// Utility for determining seasonal content windows
/// Used to demote off-season jokes (e.g., Christmas jokes in February)
enum SeasonalHelper {

    /// Returns true if the date falls within the Christmas season (Nov 1 - Dec 31)
    /// Uses the device's local calendar since users experience seasons locally
    static func isChristmasSeason(date: Date = Date()) -> Bool {
        let month = Calendar.current.component(.month, from: date)
        return month == 11 || month == 12
    }
}

// MARK: - Joke Seasonal Classification

extension Joke {

    /// Returns true if this joke has the "christmas" tag
    /// Only checks for exact "christmas" tag — does not match "holidays" or other holiday tags
    var isChristmasJoke: Bool {
        tags?.contains("christmas") ?? false
    }
}
