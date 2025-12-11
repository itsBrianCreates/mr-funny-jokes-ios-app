import Foundation
import FirebaseFirestore

/// Service for fetching videos from Firebase Firestore
final class VideoService {
    static let shared = VideoService()

    private let db: Firestore
    private let videosCollection = "videos"

    // Pagination
    private var lastDocument: DocumentSnapshot?
    private var lastDocumentsByCharacter: [String: DocumentSnapshot] = [:]

    private init() {
        self.db = Firestore.firestore()
    }

    // MARK: - Fetch Videos

    /// Fetches initial videos from Firestore
    /// - Parameters:
    ///   - limit: Number of videos to fetch (default 10)
    ///   - forceRefresh: If true, bypasses Firestore cache and fetches from server
    /// - Returns: Array of Video objects
    func fetchInitialVideos(limit: Int = 10, forceRefresh: Bool = false) async throws -> [Video] {
        lastDocument = nil

        let query = db.collection(videosCollection)
            .order(by: "created_at", descending: true)
            .limit(to: limit)

        let snapshot = forceRefresh
            ? try await query.getDocuments(source: .server)
            : try await query.getDocuments()
        lastDocument = snapshot.documents.last

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreVideo.self).toVideo()
        }
    }

    /// Fetches more videos for infinite scroll
    /// - Parameters:
    ///   - limit: Number of videos to fetch (default 10)
    /// - Returns: Array of Video objects
    func fetchMoreVideos(limit: Int = 10) async throws -> [Video] {
        guard let lastDoc = lastDocument else {
            return try await fetchInitialVideos(limit: limit)
        }

        let query = db.collection(videosCollection)
            .order(by: "created_at", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: limit)

        let snapshot = try await query.getDocuments()

        if let newLastDoc = snapshot.documents.last {
            lastDocument = newLastDoc
        }

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreVideo.self).toVideo()
        }
    }

    /// Fetches videos by character
    /// - Parameters:
    ///   - characterId: The character ID to filter by (e.g., "mr_funny")
    ///   - limit: Number of videos to fetch (default 10)
    /// - Returns: Array of Video objects
    /// - Note: Searches the `characters` array field to find videos featuring the character
    func fetchVideos(byCharacter characterId: String, limit: Int = 10) async throws -> [Video] {
        lastDocumentsByCharacter[characterId] = nil

        let query = db.collection(videosCollection)
            .whereField("characters", arrayContains: characterId)
            .order(by: "created_at", descending: true)
            .limit(to: limit)

        let snapshot = try await query.getDocuments()
        lastDocumentsByCharacter[characterId] = snapshot.documents.last

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreVideo.self).toVideo()
        }
    }

    /// Fetches more videos for a specific character (pagination)
    /// - Parameters:
    ///   - characterId: The character ID to filter by
    ///   - limit: Number of videos to fetch (default 10)
    /// - Returns: Array of Video objects
    /// - Note: Searches the `characters` array field to find videos featuring the character
    func fetchMoreVideos(byCharacter characterId: String, limit: Int = 10) async throws -> [Video] {
        guard let lastDoc = lastDocumentsByCharacter[characterId] else {
            return try await fetchVideos(byCharacter: characterId, limit: limit)
        }

        let query = db.collection(videosCollection)
            .whereField("characters", arrayContains: characterId)
            .order(by: "created_at", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: limit)

        let snapshot = try await query.getDocuments()

        if let newLastDoc = snapshot.documents.last {
            lastDocumentsByCharacter[characterId] = newLastDoc
        }

        return snapshot.documents.compactMap { document in
            try? document.data(as: FirestoreVideo.self).toVideo()
        }
    }

    /// Fetches a video by its Firestore document ID
    /// - Parameter id: The Firestore document ID
    /// - Returns: The Video object if found
    func fetchVideo(byId id: String) async throws -> Video? {
        let document = try await db.collection(videosCollection).document(id).getDocument()

        guard document.exists else { return nil }

        return try document.data(as: FirestoreVideo.self).toVideo()
    }

    // MARK: - Update Video Stats

    /// Increments the view count for a video
    /// - Parameter videoId: The Firestore document ID of the video
    func incrementViewCount(videoId: String) async throws {
        let videoRef = db.collection(videosCollection).document(videoId)
        try await videoRef.updateData([
            "views": FieldValue.increment(Int64(1))
        ])
    }

    /// Increments the like count for a video
    /// - Parameter videoId: The Firestore document ID of the video
    func incrementLikeCount(videoId: String) async throws {
        let videoRef = db.collection(videosCollection).document(videoId)
        try await videoRef.updateData([
            "likes": FieldValue.increment(Int64(1))
        ])
    }

    /// Decrements the like count for a video (for unlike)
    /// - Parameter videoId: The Firestore document ID of the video
    func decrementLikeCount(videoId: String) async throws {
        let videoRef = db.collection(videosCollection).document(videoId)
        try await videoRef.updateData([
            "likes": FieldValue.increment(Int64(-1))
        ])
    }

    // MARK: - Reset Pagination

    /// Resets pagination state for fetching fresh data
    func resetPagination() {
        lastDocument = nil
        lastDocumentsByCharacter.removeAll()
    }

    /// Resets pagination for a specific character
    func resetCharacterPagination(characterId: String) {
        lastDocumentsByCharacter[characterId] = nil
    }
}
