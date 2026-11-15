import Foundation

// MARK: - Seasonal Content

/// Utility for determining seasonal content windows.
///
/// Two things use these: holiday jokes sink to the bottom of feeds outside their
/// season, and the holiday in season gets a card on Home and leads the topic grid.
/// All dates use the device's local calendar since users experience seasons locally.
enum SeasonalHelper {

    /// Returns true if the date falls within the Christmas season (Nov 1 - Dec 31).
    /// This is when Christmas jokes are welcome in feeds. The Home card starts later:
    /// see `isChristmasFeatureSeason`.
    static func isChristmasSeason(date: Date = Date()) -> Bool {
        let month = Calendar.current.component(.month, from: date)
        return month == 11 || month == 12
    }

    /// Returns true from the day after Thanksgiving through Dec 31: when Christmas takes
    /// over the Home card from Thanksgiving
    static func isChristmasFeatureSeason(date: Date = Date()) -> Bool {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else { return false }
        if month == 12 { return true }
        return month == 11 && day > thanksgivingDayOfMonth(year: year)
    }

    /// Returns true from Nov 1 through Thanksgiving Day
    static func isThanksgivingSeason(date: Date = Date()) -> Bool {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else { return false }
        return month == 11 && day <= thanksgivingDayOfMonth(year: year)
    }

    /// Returns true for the 30 days before Halloween and the day itself (Oct 1 - Oct 31)
    static func isHalloweenSeason(date: Date = Date()) -> Bool {
        Calendar.current.component(.month, from: date) == 10
    }

    /// The day of November that US Thanksgiving falls on: the fourth Thursday (22 - 28)
    static func thanksgivingDayOfMonth(year: Int) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        guard let novemberFirst = calendar.date(from: DateComponents(year: year, month: 11, day: 1)) else { return 28 }
        let weekday = calendar.component(.weekday, from: novemberFirst)  // 1 = Sunday, 5 = Thursday
        let firstThursday = 1 + (5 - weekday + 7) % 7
        return firstThursday + 21
    }
}

// MARK: - Joke Seasonal Classification

extension Joke {

    /// Returns true if this joke has the "christmas" tag
    /// Only checks for exact "christmas" tag — does not match "holidays" or other holiday tags
    var isChristmasJoke: Bool {
        tags?.contains("christmas") ?? false
    }

    /// Returns true for a holiday joke outside its season: Christmas outside Nov 1 - Dec 31,
    /// Thanksgiving outside Nov 1 - Thanksgiving Day, Halloween outside October.
    /// A joke tagged for two holidays is in season during either.
    func isOutOfSeason(on date: Date = Date()) -> Bool {
        guard let tags else { return false }

        var isSeasonal = false
        if tags.contains("christmas") {
            if SeasonalHelper.isChristmasSeason(date: date) { return false }
            isSeasonal = true
        }
        if tags.contains("thanksgiving") {
            if SeasonalHelper.isThanksgivingSeason(date: date) { return false }
            isSeasonal = true
        }
        if tags.contains("halloween") {
            if SeasonalHelper.isHalloweenSeason(date: date) { return false }
            isSeasonal = true
        }
        return isSeasonal
    }
}
