import Foundation
import FirebaseFirestore

/// Service for fetching jokes and characters from Firebase Firestore
final class FirestoreService {
    static let shared = FirestoreService()

    private let db: Firestore
    private let jokesCollection = "jokes"
    private let charactersCollection = "characters"

    // Pagination
    private var lastDocument: DocumentSnapshot?
    private var lastDocumentsByCategory: [JokeCategory: DocumentSnapshot] = [:]

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
    func fetchJokes(category: JokeCategory, limit: Int = 20, forceRefresh: Bool = false) async throws -> [Joke] {
        lastDocumentsByCategory[category] = nil

        let query = db.collection(jokesCollection)
            .whereField("type", isEqualTo: category.firestoreType)
            .order(by: "popularity_score", descending: true)
            .limit(to: limit)

        let snapshot = forceRefresh
            ? try await query.getDocuments(source: .server)
            : try await query.getDocuments()
        lastDocumentsByCategory[category] = snapshot.documents.last

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreJoke.self).toJoke()
        }
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

        let query = db.collection(jokesCollection)
            .whereField("type", isEqualTo: category.firestoreType)
            .order(by: "popularity_score", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: limit)

        let snapshot = try await query.getDocuments()

        if let newLastDoc = snapshot.documents.last {
            lastDocumentsByCategory[category] = newLastDoc
        }

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreJoke.self).toJoke()
        }
    }

    /// Fetches initial jokes for all categories
    /// - Parameters:
    ///   - countPerCategory: Number of jokes per category (default 8)
    ///   - forceRefresh: If true, bypasses Firestore cache and fetches from server
    /// - Returns: Array of Joke objects from all categories
    func fetchInitialJokesAllCategories(countPerCategory: Int = 8, forceRefresh: Bool = false) async throws -> [Joke] {
        var allJokes: [Joke] = []

        // Fetch from all categories concurrently
        await withTaskGroup(of: [Joke].self) { group in
            for category in JokeCategory.allCases {
                group.addTask {
                    do {
                        return try await self.fetchJokes(category: category, limit: countPerCategory, forceRefresh: forceRefresh)
                    } catch {
                        print("Error fetching \(category) jokes: \(error)")
                        return []
                    }
                }
            }

            for await jokes in group {
                allJokes.append(contentsOf: jokes)
            }
        }

        // Shuffle to mix categories
        return allJokes.shuffled()
    }

    /// Fetches a random joke for Joke of the Day
    /// - Returns: A random Joke object
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

    /// Searches jokes by text
    /// - Parameters:
    ///   - searchText: Text to search for
    ///   - limit: Maximum number of results (default 20)
    /// - Returns: Array of matching Joke objects
    func searchJokes(searchText: String, limit: Int = 20) async throws -> [Joke] {
        // Firestore doesn't support full-text search natively
        // This fetches all jokes and filters client-side
        // For production, consider using Algolia or Firebase Extensions
        let query = db.collection(jokesCollection)
            .order(by: "popularity_score", descending: true)
            .limit(to: 100)

        let snapshot = try await query.getDocuments()
        let searchLower = searchText.lowercased()

        return snapshot.documents.compactMap { document -> Joke? in
            guard let firestoreJoke = try? document.data(as: FirestoreJoke.self) else {
                return nil
            }

            let joke = firestoreJoke.toJoke()

            // Search in setup, punchline, and tags
            if joke.setup.lowercased().contains(searchLower) ||
                joke.punchline.lowercased().contains(searchLower) ||
                (joke.tags?.contains { $0.lowercased().contains(searchLower) } ?? false) {
                return joke
            }

            return nil
        }.prefix(limit).map { $0 }
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

    // MARK: - Reset Pagination

    /// Resets pagination state for fetching fresh data
    func resetPagination() {
        lastDocument = nil
        lastDocumentsByCategory.removeAll()
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
