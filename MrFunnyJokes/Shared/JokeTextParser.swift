import Foundation

/// Splits a joke's stored text into the part shown on cards (setup) and the part
/// revealed on tap (punchline). Shared by the app and the widget so both agree.
///
/// Firestore stores one `text` field. A blank line marks the reveal point:
///
///     Do you believe in love at first sight,
///
///     or should I walk by again?
///
/// Text without a blank line falls back to the older delimiters.
enum JokeTextParser {

    // MARK: - Splitting

    static func split(_ rawText: String, isKnockKnock: Bool = false) -> (setup: String, punchline: String) {
        let text = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Explicit reveal point
        if let range = text.range(of: #"\n[ \t]*\n\s*"#, options: .regularExpression) {
            let setup = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let punchline = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !setup.isEmpty && !punchline.isEmpty {
                return (setup, punchline)
            }
        }

        if isKnockKnock || self.isKnockKnock(text) {
            return splitKnockKnock(text)
        }

        for delimiter in ["\n", " - ", "? ", "! "] {
            guard let range = text.range(of: delimiter) else { continue }
            var setup = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let punchline = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !setup.isEmpty, !punchline.isEmpty else { continue }
            // "? " and "! " are consumed by the split; put the mark back
            if delimiter == "? " { setup += "?" }
            if delimiter == "! " { setup += "!" }
            return (setup, punchline)
        }

        return (text, "")
    }

    /// True when the text starts with "knock" and asks "who's there"
    static func isKnockKnock(_ text: String) -> Bool {
        let lowercased = text.lowercased().replacingOccurrences(of: "’", with: "'")
        return lowercased.hasPrefix("knock") && lowercased.contains("who's there")
    }

    /// Setup is "Knock, knock. / Who's there? / Name." and everything after is the punchline.
    /// Both come back with one part per line.
    private static func splitKnockKnock(_ text: String) -> (setup: String, punchline: String) {
        // Already one part per line
        if text.contains("\n") {
            let lines = nonEmptyLines(text)
            guard lines.count > 3 else { return (lines.joined(separator: "\n"), "") }
            return (lines.prefix(3).joined(separator: "\n"), lines.dropFirst(3).joined(separator: "\n"))
        }

        // One line: "Knock, knock. Who's there? Honey bee. Honey bee who? Honey bee a dear…"
        guard let whosThere = text.range(of: #"who['’]s there\?"#, options: [.regularExpression, .caseInsensitive]) else {
            return (text, "")
        }
        let opener = String(text[..<whosThere.lowerBound]).trimmingCharacters(in: .whitespaces)
        let question = String(text[whosThere])
        let afterQuestion = String(text[whosThere.upperBound...]).trimmingCharacters(in: .whitespaces)

        var setupLines = opener.isEmpty ? [question] : [opener, question]

        // The name is the first sentence after "Who's there?"
        guard let nameEnd = afterQuestion.range(of: #"[.!?…]\s+"#, options: .regularExpression) else {
            if !afterQuestion.isEmpty { setupLines.append(afterQuestion) }
            return (setupLines.joined(separator: "\n"), "")
        }
        let name = String(afterQuestion[..<nameEnd.lowerBound]) + String(afterQuestion[nameEnd.lowerBound])
        setupLines.append(name)

        let reply = String(afterQuestion[nameEnd.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (setupLines.joined(separator: "\n"), knockKnockLines(reply).joined(separator: "\n"))
    }

    // MARK: - Display

    /// One part of a knock-knock joke per line. Handles the single-line form
    /// ("Knock, knock. Who's there? Nobel.") that older caches still hold.
    static func knockKnockLines(_ text: String) -> [String] {
        if text.contains("\n") {
            return nonEmptyLines(text)
        }

        if text.lowercased().hasPrefix("knock"),
           let whosThere = text.range(of: #"who['’]s there\?"#, options: [.regularExpression, .caseInsensitive]) {
            let opener = String(text[..<whosThere.lowerBound]).trimmingCharacters(in: .whitespaces)
            let name = String(text[whosThere.upperBound...]).trimmingCharacters(in: .whitespaces)
            return [opener, String(text[whosThere]), name].filter { !$0.isEmpty }
        }

        if let who = text.range(of: #"\bwho\?\s+"#, options: [.regularExpression, .caseInsensitive]) {
            let question = String(text[..<who.upperBound]).trimmingCharacters(in: .whitespaces)
            let answer = String(text[who.upperBound...]).trimmingCharacters(in: .whitespaces)
            return [question, answer].filter { !$0.isEmpty }
        }

        return text.isEmpty ? [] : [text]
    }

    /// The setup as shown on cards, widgets and notifications. A setup that stops
    /// mid-sentence ("Do you believe in love at first sight,") trails off with "…".
    static func teaser(setup: String, punchline: String, isKnockKnock: Bool = false) -> String {
        if isKnockKnock {
            return knockKnockLines(setup).joined(separator: "\n")
        }
        guard !punchline.isEmpty, !endsSentence(setup) else { return setup }
        let trimmed = setup.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:—–-"))
        return trimmed + "…"
    }

    /// The whole joke as plain text, for copying, sharing and speech.
    /// Mid-sentence splits read as one sentence again.
    static func fullText(setup: String, punchline: String, isKnockKnock: Bool = false) -> String {
        if isKnockKnock {
            return (knockKnockLines(setup) + knockKnockLines(punchline)).joined(separator: "\n")
        }
        guard !punchline.isEmpty else { return setup }
        if endsSentence(setup) {
            return "\(setup)\n\n\(punchline)"
        }
        // "so crowded—" + "people are dying to get in." has no space in the original
        let isTightDash = setup.hasSuffix("—") && !setup.hasSuffix(" —")
        return setup + (isTightDash ? "" : " ") + punchline
    }

    /// Whether the setup finishes its sentence, ignoring a closing quote or bracket
    private static func endsSentence(_ text: String) -> Bool {
        let closers = CharacterSet(charactersIn: "\"'”’)")
        let core = text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: closers)
        guard let last = core.last else { return true }
        return ".?!…".contains(last)
    }

    private static func nonEmptyLines(_ text: String) -> [String] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
