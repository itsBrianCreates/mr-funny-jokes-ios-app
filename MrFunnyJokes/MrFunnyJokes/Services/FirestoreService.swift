import Foundation
import FirebaseFirestore

/// Service for fetching jokes and characters from Firebase Firestore
final class FirestoreService {
    static let shared = FirestoreService()

    private let db: Firestore
    private let jokesCollection = "jokes"
    private let charactersCollection = "characters"
    private let ratingEventsCollection = "rating_events"
    private let weeklyRankingsCollection = "weekly_rankings"

    // Pagination
    private var lastDocument: DocumentSnapshot?
    private var lastDocumentsByCategory: [JokeCategory: DocumentSnapshot] = [:]
    private var lastDocumentsByCharacter: [String: DocumentSnapshot] = [:]

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

    // MARK: - Fetch Jokes

    /// Fetches initial jokes from Firestore
    /// - Parameters:
    ///   - limit: Number of jokes to fetch (default 20)
    ///   - forceRefresh: If true, bypasses Firestore cache and fetches from server
    /// - Returns: Array of Joke objects
    func fetchInitialJokes(limit: Int = 20, forceRefresh: Bool = false) async throws -> [Joke] {
        lastDocument = nil

        let query = db.collection(jokesCollection)
            .order(by: "popularity_score", descending: true)
            .limit(to: limit)

        let snapshot = forceRefresh
            ? try await query.getDocuments(source: .server)
            : try await query.getDocuments()
        lastDocument = snapshot.documents.last

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreJoke.self).toJoke()
        }
    }

    /// Fetches more jokes for infinite scroll
    /// - Parameters:
    ///   - limit: Number of jokes to fetch (default 10)
    /// - Returns: Array of Joke objects
    func fetchMoreJokes(limit: Int = 10) async throws -> [Joke] {
        guard let lastDoc = lastDocument else {
            return try await fetchInitialJokes(limit: limit)
        }

        let query = db.collection(jokesCollection)
            .order(by: "popularity_score", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: limit)

        let snapshot = try await query.getDocuments()

        if let newLastDoc = snapshot.documents.last {
            lastDocument = newLastDoc
        }

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreJoke.self).toJoke()
        }
    }

    /// Fetches jokes by category
    /// - Parameters:
    ///   - category: The joke category to filter by
    ///   - limit: Number of jokes to fetch (default 20)
    ///   - forceRefresh: If true, bypasses Firestore cache and fetches from server
    /// - Returns: Array of Joke objects
    /// - Note: Fetches all jokes and filters client-side to ensure jokes with
    ///         non-standard type values are still categorized correctly by toJoke()
    func fetchJokes(category: JokeCategory, limit: Int = 20, forceRefresh: Bool = false) async throws -> [Joke] {
        lastDocumentsByCategory[category] = nil

        // Fetch more than needed since we filter client-side
        // This ensures we get enough jokes of the desired category
        let fetchMultiplier = 5
        let fetchLimit = limit * fetchMultiplier

        let query = db.collection(jokesCollection)
            .order(by: "popularity_score", descending: true)
            .limit(to: fetchLimit)

        let snapshot = forceRefresh
            ? try await query.getDocuments(source: .server)
            : try await query.getDocuments()

        // Convert all jokes (toJoke handles categorization based on content)
        let allJokes = snapshot.documents.compactMap { document -> (joke: Joke, doc: DocumentSnapshot)? in
            guard let joke = try? document.data(as: FirestoreJoke.self).toJoke() else {
                return nil
            }
            return (joke, document)
        }

        // Filter to only the requested category
        let filteredJokes = allJokes.filter { $0.joke.category == category }

        // Store the last document of the filtered results for pagination
        if let lastFiltered = filteredJokes.last {
            lastDocumentsByCategory[category] = lastFiltered.doc
        }

        // Return up to the requested limit
        return Array(filteredJokes.prefix(limit).map { $0.joke })
    }

    /// Fetches more jokes for a specific category (pagination)
    /// - Parameters:
    ///   - category: The joke category to filter by
    ///   - limit: Number of jokes to fetch (default 10)
    /// - Returns: Array of Joke objects
    func fetchMoreJokes(category: JokeCategory, limit: Int = 10) async throws -> [Joke] {
        guard let lastDoc = lastDocumentsByCategory[category] else {
            return try await fetchJokes(category: category, limit: limit)
        }

        // Fetch more than needed since we filter client-side
        let fetchMultiplier = 5
        let fetchLimit = limit * fetchMultiplier

        let query = db.collection(jokesCollection)
            .order(by: "popularity_score", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: fetchLimit)

        let snapshot = try await query.getDocuments()

        // Convert all jokes (toJoke handles categorization based on content)
        let allJokes = snapshot.documents.compactMap { document -> (joke: Joke, doc: DocumentSnapshot)? in
            guard let joke = try? document.data(as: FirestoreJoke.self).toJoke() else {
                return nil
            }
            return (joke, document)
        }

        // Filter to only the requested category
        let filteredJokes = allJokes.filter { $0.joke.category == category }

        // Update pagination cursor to the last document we processed
        // (even if it wasn't the desired category, to continue pagination)
        if let newLastDoc = snapshot.documents.last {
            lastDocumentsByCategory[category] = newLastDoc
        }

        return Array(filteredJokes.prefix(limit).map { $0.joke })
    }

    /// Fetches initial jokes for "All Jokes" feed (no category filtering)
    /// - Parameters:
    ///   - limit: Total number of jokes to fetch (default 24)
    ///   - forceRefresh: If true, bypasses Firestore cache and fetches from server
    /// - Returns: Array of Joke objects from all categories, shuffled
    func fetchInitialJokesAllCategories(countPerCategory: Int = 8, forceRefresh: Bool = false) async throws -> [Joke] {
        // Reset pagination for "All Jokes" feed
        lastDocument = nil

        // Calculate total limit based on countPerCategory * number of categories
        let totalLimit = countPerCategory * JokeCategory.allCases.count

        // Fetch ALL jokes without type filtering - every joke in the database
        // should be eligible to appear in the "All Jokes" feed
        let query = db.collection(jokesCollection)
            .order(by: "popularity_score", descending: true)
            .limit(to: totalLimit)

        let snapshot = forceRefresh
            ? try await query.getDocuments(source: .server)
            : try await query.getDocuments()

        lastDocument = snapshot.documents.last

        let allJokes = snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreJoke.self).toJoke()
        }

        // Shuffle to mix categories for variety
        return allJokes.shuffled()
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

    /// Fetches jokes by character
    /// - Parameters:
    ///   - characterName: The character name to filter by
    ///   - limit: Number of jokes to fetch (default 20)
    /// - Returns: Array of Joke objects
    func fetchJokes(byCharacter characterName: String, limit: Int = 20) async throws -> [Joke] {
        let query = db.collection(jokesCollection)
            .whereField("character", isEqualTo: characterName)
            .order(by: "popularity_score", descending: true)
            .limit(to: limit)

        let snapshot = try await query.getDocuments()

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreJoke.self).toJoke()
        }
    }

    // MARK: - Character Pagination

    /// Fetches initial jokes for a character view with server-side pagination
    /// - Parameters:
    ///   - characterId: The character ID to fetch jokes for
    ///   - limit: Number of jokes to fetch (default 50)
    /// - Returns: Array of Joke objects sorted by popularity score
    /// - Note: Requires composite index on (character, popularity_score) in Firestore.
    ///         Create index at: Firebase Console > Firestore > Indexes > Add Index
    ///         Collection: jokes, Fields: character (Ascending), popularity_score (Descending)
    func fetchInitialJokesForCharacter(characterId: String, limit: Int = 50) async throws -> [Joke] {
        // Reset pagination for this character
        lastDocumentsByCharacter[characterId] = nil

        let query = db.collection(jokesCollection)
            .whereField("character", isEqualTo: characterId)
            .order(by: "popularity_score", descending: true)
            .limit(to: limit)

        let snapshot = try await query.getDocuments()
        lastDocumentsByCharacter[characterId] = snapshot.documents.last

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreJoke.self).toJoke()
        }
    }

    /// Fetches more jokes for a character view (server-side pagination)
    /// - Parameters:
    ///   - characterId: The character ID for pagination tracking
    ///   - limit: Number of jokes to fetch (default 50)
    /// - Returns: Tuple of (jokes array, hasMoreInDatabase flag)
    func fetchMoreJokesForCharacter(characterId: String, limit: Int = 50) async throws -> (jokes: [Joke], hasMore: Bool) {
        guard let lastDoc = lastDocumentsByCharacter[characterId] else {
            // No pagination cursor - fetch initial batch instead
            let jokes = try await fetchInitialJokesForCharacter(characterId: characterId, limit: limit)
            return (jokes, !jokes.isEmpty)
        }

        let query = db.collection(jokesCollection)
            .whereField("character", isEqualTo: characterId)
            .order(by: "popularity_score", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: limit)

        let snapshot = try await query.getDocuments()

        if let newLastDoc = snapshot.documents.last {
            lastDocumentsByCharacter[characterId] = newLastDoc
        }

        let jokes = snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreJoke.self).toJoke()
        }

        // hasMore is true if we got a full batch (there might be more)
        return (jokes, jokes.count == limit)
    }

    /// Resets pagination for a specific character
    func resetCharacterPagination(characterId: String) {
        lastDocumentsByCharacter[characterId] = nil
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

    // MARK: - Rating Events (for Weekly Top 10)

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

    /// Fetches the current week's rankings
    /// - Returns: WeeklyRankings object if available, nil otherwise
    func fetchWeeklyRankings() async throws -> WeeklyRankings? {
        let weekId = getCurrentWeekId()

        let document = try await db.collection(weeklyRankingsCollection).document(weekId).getDocument()

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

    /// Returns the date range for the current week in Eastern Time
    func getCurrentWeekDateRange() -> (start: Date, end: Date)? {
        let calendar = Calendar(identifier: .iso8601)
        var easternCalendar = calendar
        easternCalendar.timeZone = TimeZone(identifier: "America/New_York")!

        let now = Date()

        guard let weekInterval = easternCalendar.dateInterval(of: .weekOfYear, for: now) else {
            return nil
        }

        return (weekInterval.start, weekInterval.end.addingTimeInterval(-1))
    }

    // MARK: - Reset Pagination

    /// Resets pagination state for fetching fresh data
    func resetPagination() {
        lastDocument = nil
        lastDocumentsByCategory.removeAll()
        lastDocumentsByCharacter.removeAll()
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
