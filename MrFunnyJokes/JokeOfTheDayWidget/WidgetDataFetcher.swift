import Foundation

/// Fetches Joke of the Day directly from Firestore REST API for widget use.
/// This bypasses Firebase SDK to avoid deadlock issues in widget extensions.
/// Uses URLSession async/await with graceful error handling.
struct WidgetDataFetcher {

    private static let projectId = "mr-funny-jokes"
    private static let baseURL = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents"

    /// Eastern Time timezone for consistent date calculation with Cloud Functions
    private static let easternTime = TimeZone(identifier: "America/New_York")!

    /// Fetch today's Joke of the Day from Firestore
    /// - Returns: SharedJokeOfTheDay if successful, nil on any error
    static func fetchJokeOfTheDay() async -> SharedJokeOfTheDay? {
        // Get today's date in ET timezone (matches Cloud Function schedule)
        let dateString = todayDateString()

        // Step 1: Fetch the daily_jokes document to get the joke_id
        guard let jokeId = await fetchDailyJokeId(for: dateString) else {
            return nil
        }

        // Step 2: Fetch the actual joke document
        return await fetchJoke(id: jokeId)
    }

    /// Get today's date formatted as YYYY-MM-DD in Eastern Time
    private static func todayDateString() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = easternTime

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = easternTime

        return formatter.string(from: Date())
    }

    /// Fetch the joke_id from the daily_jokes collection
    private static func fetchDailyJokeId(for dateString: String) async -> String? {
        let urlString = "\(baseURL)/daily_jokes/\(dateString)"

        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Check for HTTP success
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Parse Firestore REST response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fields = json["fields"] as? [String: Any],
                  let jokeIdField = fields["joke_id"] as? [String: Any],
                  let jokeId = jokeIdField["stringValue"] as? String else {
                return nil
            }

            return jokeId
        } catch {
            return nil
        }
    }

    /// Fetch the joke document and convert to SharedJokeOfTheDay
    private static func fetchJoke(id jokeId: String) async -> SharedJokeOfTheDay? {
        let urlString = "\(baseURL)/jokes/\(jokeId)"

        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Check for HTTP success
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Parse Firestore REST response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fields = json["fields"] as? [String: Any] else {
                return nil
            }

            // Extract required text field
            guard let textField = fields["text"] as? [String: Any],
                  let text = textField["stringValue"] as? String else {
                return nil
            }

            // Extract optional fields
            let character = (fields["character"] as? [String: Any])?["stringValue"] as? String
            let category = (fields["type"] as? [String: Any])?["stringValue"] as? String

            // Split text into setup and punchline
            let (setup, punchline) = splitJokeText(text)

            return SharedJokeOfTheDay(
                id: jokeId,
                setup: setup,
                punchline: punchline,
                category: category,
                firestoreId: jokeId,
                character: character,
                lastUpdated: Date()
            )
        } catch {
            return nil
        }
    }

    /// Split joke text into setup and punchline using common delimiters
    private static func splitJokeText(_ text: String) -> (setup: String, punchline: String) {
        // Try delimiters in order of preference
        let delimiters = ["\n\n", " - ", "? ", "! "]

        for delimiter in delimiters {
            if let range = text.range(of: delimiter) {
                let setup = String(text[..<range.lowerBound])
                let punchline = String(text[range.upperBound...])

                // For "? " and "! " delimiters, include the punctuation in setup
                if delimiter == "? " {
                    return (setup + "?", punchline)
                } else if delimiter == "! " {
                    return (setup + "!", punchline)
                }

                return (setup, punchline)
            }
        }

        // No delimiter found - use entire text as setup, empty punchline
        return (text, "")
    }
}
