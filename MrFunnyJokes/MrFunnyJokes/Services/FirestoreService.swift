import Foundation
import FirebaseFirestore

/// Service for fetching jokes and characters from Firebase Firestore
/// - Note: @MainActor keeps callers on one actor. Network I/O still runs off the main thread.
@MainActor
final class FirestoreService {
    static let shared = FirestoreService()

    private let db: Firestore
    private let jokesCollection = "jokes"
    private let charactersCollection = "characters"
    private let ratingEventsCollection = "rating_events"
    private let weeklyRankingsCollection = "weekly_rankings"

    private init() {
        // Configure Firestore for optimal performance
        let settings = FirestoreSettings()

        // Enable persistent cache for faster loads on subsequent launches
        // 50MB cache provides good balance between storage and performance
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 50 * 1024 * 1024 as NSNumber)

        let firestore = Firestore.firestore()
        firestore.settings = settings
        self.db = firestore
    }

    // MARK: - Fetch Catalog

    /// The newest `updated_at` in a catalog fetch, kept at Firestore's full precision so
    /// the next "what changed since" query doesn't return the same document again
    struct CatalogCursor: Codable, Equatable {
        let seconds: Int64
        let nanoseconds: Int32
    }

    /// Fetches the joke catalog: all of it, or only jokes added or edited after `cursor`.
    /// - Returns: The jokes, and a cursor for the newest one (nil when none came back)
    /// - Note: Always asks the server. A cache answer could be a partial catalog, and
    ///         the caller would store it as the whole thing.
    func fetchCatalog(updatedAfter cursor: CatalogCursor? = nil) async throws -> (jokes: [Joke], cursor: CatalogCursor?) {
        var query: Query = db.collection(jokesCollection)
        if let cursor {
            let timestamp = Timestamp(seconds: cursor.seconds, nanoseconds: cursor.nanoseconds)
            query = query.whereField("updated_at", isGreaterThan: timestamp)
        }

        let snapshot = try await query.getDocuments(source: .server)

        var jokes: [Joke] = []
        var newest: Timestamp?
        for document in snapshot.documents {
            guard let firestoreJoke = try? document.data(as: FirestoreJoke.self) else { continue }
            jokes.append(firestoreJoke.toJoke())
            if let updatedAt = firestoreJoke.updatedAt,
               newest.map({ updatedAt.compare($0) == .orderedDescending }) ?? true {
                newest = updatedAt
            }
        }

        return (jokes, newest.map { CatalogCursor(seconds: $0.seconds, nanoseconds: $0.nanoseconds) })
    }

    /// Fetches the Joke of the Day from the daily_jokes collection
    /// - Parameter date: The date to fetch the joke for (defaults to today)
    /// - Returns: The designated Joke of the Day, or nil if not found
    func fetchJokeOfTheDay(for date: Date = Date()) async throws -> Joke? {
        // Format date as document ID (e.g., "2025-12-07")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "America/New_York") // Use consistent timezone
        let dateString = dateFormatter.string(from: date)

        // Try to fetch from daily_jokes collection
        let dailyJokeDoc = try await db.collection("daily_jokes").document(dateString).getDocument()

        if dailyJokeDoc.exists, let data = dailyJokeDoc.data() {
            // Check if it has a joke_id reference to fetch from jokes collection
            if let jokeId = data["joke_id"] as? String {
                return try await fetchJoke(byId: jokeId)
            }

            // Otherwise, try to decode the joke directly from the document
            if let firestoreJoke = try? dailyJokeDoc.data(as: FirestoreJoke.self) {
                return firestoreJoke.toJoke()
            }
        }

        // No joke found for this date
        return nil
    }

    /// Fetches a random joke as fallback for Joke of the Day
    /// - Returns: A random Joke object from top popular jokes
    func fetchRandomJoke() async throws -> Joke? {
        // Fetch a few top jokes and pick one randomly
        let query = db.collection(jokesCollection)
            .order(by: "popularity_score", descending: true)
            .limit(to: 50)

        let snapshot = try await query.getDocuments()
        let jokes = snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreJoke.self).toJoke()
        }

        // Christmas jokes accumulate popularity_score during December, so the
        // top-50 pool stays full of them year-round — exclude them off-season
        if !SeasonalHelper.isChristmasSeason() {
            let nonChristmas = jokes.filter { !$0.isChristmasJoke }
            if !nonChristmas.isEmpty {
                return nonChristmas.randomElement()
            }
        }

        return jokes.randomElement()
    }

    /// Fetches a joke by its Firestore document ID
    /// - Parameter id: The Firestore document ID
    /// - Returns: The Joke object if found
    func fetchJoke(byId id: String) async throws -> Joke? {
        let document = try await db.collection(jokesCollection).document(id).getDocument()

        guard document.exists else { return nil }

        return try document.data(as: FirestoreJoke.self).toJoke()
    }

    /// Searches jokes by text with optimized fetching
    /// - Parameters:
    ///   - searchText: Text to search for
    ///   - limit: Maximum number of results (default 20)
    /// - Returns: Array of matching Joke objects
    /// - Note: Since Firestore doesn't support full-text search, this fetches a limited
    ///         set of popular jokes and filters client-side. For comprehensive search,
    ///         ensure jokes are loaded locally first (SearchView does this automatically).
    func searchJokes(searchText: String, limit: Int = 20) async throws -> [Joke] {
        // Firestore doesn't support full-text search natively
        // Fetch a limited set of jokes ordered by popularity and filter client-side
        // This balances search coverage with performance
        // For production at scale, consider using Algolia or Firebase Extensions
        let fetchLimit = 300 // Fetch top 300 jokes for searching (cached after first load)

        let query = db.collection(jokesCollection)
            .order(by: "popularity_score", descending: true)
            .limit(to: fetchLimit)

        // Use cache when available for faster response
        let snapshot = try await query.getDocuments()
        let searchLower = searchText.lowercased()

        let matchingJokes = snapshot.documents.compactMap { document -> Joke? in
            guard let firestoreJoke = try? document.data(as: FirestoreJoke.self) else {
                return nil
            }

            let joke = firestoreJoke.toJoke()

            // Search in setup, punchline, tags, and type
            if joke.setup.lowercased().contains(searchLower) ||
                joke.punchline.lowercased().contains(searchLower) ||
                (joke.tags?.contains { $0.lowercased().contains(searchLower) } ?? false) ||
                joke.category.rawValue.lowercased().contains(searchLower) {
                return joke
            }

            return nil
        }

        // Sort by popularity and return top results
        return matchingJokes
            .sorted { $0.popularityScore > $1.popularityScore }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Fetch Characters

    /// Fetches all characters from Firestore
    /// - Returns: Array of FirestoreCharacter objects
    func fetchCharacters() async throws -> [FirestoreCharacter] {
        let snapshot = try await db.collection(charactersCollection).getDocuments()

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreCharacter.self)
        }
    }

    // MARK: - Update Ratings

    /// Updates the rating for a joke in Firestore
    /// - Parameters:
    ///   - jokeId: The Firestore document ID of the joke
    ///   - rating: The new rating value (1-5)
    func updateJokeRating(jokeId: String, rating: Int) async throws {
        let jokeRef = db.collection(jokesCollection).document(jokeId)

        _ = try await db.runTransaction { transaction, errorPointer in
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(jokeRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard let oldRatingCount = document.data()?["rating_count"] as? Int,
                  let oldRatingSum = document.data()?["rating_sum"] as? Int else {
                return nil
            }

            let newRatingCount = oldRatingCount + 1
            let newRatingSum = oldRatingSum + rating
            let newRatingAvg = Double(newRatingSum) / Double(newRatingCount)

            transaction.updateData([
                "rating_count": newRatingCount,
                "rating_sum": newRatingSum,
                "rating_avg": newRatingAvg
            ], forDocument: jokeRef)

            return nil
        }
    }

    /// Updates likes/dislikes for a joke in Firestore
    /// - Parameters:
    ///   - jokeId: The Firestore document ID of the joke
    ///   - isLike: true for like, false for dislike
    func updateJokeLike(jokeId: String, isLike: Bool) async throws {
        let jokeRef = db.collection(jokesCollection).document(jokeId)

        let field = isLike ? "likes" : "dislikes"
        try await jokeRef.updateData([
            field: FieldValue.increment(Int64(1))
        ])
    }

    // MARK: - Rating Events & Rankings

    /// Logs a rating event for weekly rankings aggregation
    /// - Parameters:
    ///   - jokeId: The Firestore document ID of the joke
    ///   - rating: The rating value (1-5)
    ///   - deviceId: Anonymous device identifier for deduplication
    func logRatingEvent(jokeId: String, rating: Int, deviceId: String) async throws {
        // Calculate week ID in Eastern Time (e.g., "2024-W03")
        let weekId = getCurrentWeekId()

        // Create composite key for deduplication: deviceId_jokeId_weekId
        let documentId = "\(deviceId)_\(jokeId)_\(weekId)"

        let eventData: [String: Any] = [
            "joke_id": jokeId,
            "rating": rating,
            "device_id": deviceId,
            "week_id": weekId,
            "timestamp": FieldValue.serverTimestamp()
        ]

        // Use setData with merge to allow updating if user re-rates same joke same week
        try await db.collection(ratingEventsCollection).document(documentId).setData(eventData, merge: true)
    }

    /// Fetches the all-time rankings
    /// - Returns: WeeklyRankings object if available, nil otherwise
    func fetchAllTimeRankings() async throws -> WeeklyRankings? {
        let document = try await db.collection(weeklyRankingsCollection).document("all_time").getDocument()

        guard document.exists else { return nil }

        return try document.data(as: WeeklyRankings.self)
    }

    /// Fetches jokes by their Firestore IDs (for loading ranked jokes)
    /// - Parameter ids: Array of Firestore document IDs
    /// - Returns: Dictionary mapping joke IDs to Joke objects
    func fetchJokes(byIds ids: [String]) async throws -> [String: Joke] {
        guard !ids.isEmpty else { return [:] }

        // Firestore 'in' queries are limited to 30 items
        // Split into batches if needed
        var result: [String: Joke] = [:]

        for batch in ids.chunked(into: 30) {
            let snapshot = try await db.collection(jokesCollection)
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments()

            for document in snapshot.documents {
                if let joke = try? document.data(as: FirestoreJoke.self).toJoke() {
                    result[document.documentID] = joke
                }
            }
        }

        return result
    }

    /// Returns the current ISO week ID in Eastern Time (e.g., "2024-W03")
    private func getCurrentWeekId() -> String {
        let calendar = Calendar(identifier: .iso8601)
        var easternCalendar = calendar
        easternCalendar.timeZone = TimeZone(identifier: "America/New_York")!

        let now = Date()
        let year = easternCalendar.component(.yearForWeekOfYear, from: now)
        let week = easternCalendar.component(.weekOfYear, from: now)

        return String(format: "%d-W%02d", year, week)
    }
}

// MARK: - Array Chunking Helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Error Types

enum FirestoreError: Error, LocalizedError {
    case documentNotFound
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "The requested document was not found."
        case .decodingError:
            return "Failed to decode the document data."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
