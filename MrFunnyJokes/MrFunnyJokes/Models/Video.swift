import Foundation
import FirebaseFirestore

// MARK: - Video Model

/// Represents a video in the app
struct Video: Identifiable, Codable, Equatable {
    let id: UUID
    let firestoreId: String?
    let title: String
    let description: String
    let character: String              // Primary character (backward compatibility)
    let characters: [String]?          // All featured characters (for multi-character videos)
    let videoUrl: String
    let thumbnailUrl: String?
    let duration: Double
    let tags: [String]
    let likes: Int
    let views: Int
    let createdAt: Date?

    // Local state (not stored in Firestore)
    var isWatched: Bool
    var isLiked: Bool

    /// Returns all characters featured in the video
    /// Falls back to primary character if characters array is not set
    var allCharacters: [String] {
        characters ?? [character]
    }

    enum CodingKeys: String, CodingKey {
        case id, firestoreId, title, description, character, characters
        case videoUrl, thumbnailUrl, duration, tags
        case likes, views, createdAt, isWatched, isLiked
    }

    init(
        id: UUID = UUID(),
        firestoreId: String? = nil,
        title: String,
        description: String = "",
        character: String,
        characters: [String]? = nil,
        videoUrl: String,
        thumbnailUrl: String? = nil,
        duration: Double = 0,
        tags: [String] = [],
        likes: Int = 0,
        views: Int = 0,
        createdAt: Date? = nil,
        isWatched: Bool = false,
        isLiked: Bool = false
    ) {
        self.id = id
        self.firestoreId = firestoreId
        self.title = title
        self.description = description
        self.character = character
        self.characters = characters
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.tags = tags
        self.likes = likes
        self.views = views
        self.createdAt = createdAt
        self.isWatched = isWatched
        self.isLiked = isLiked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        firestoreId = try container.decodeIfPresent(String.self, forKey: .firestoreId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        character = try container.decode(String.self, forKey: .character)
        characters = try container.decodeIfPresent([String].self, forKey: .characters)
        videoUrl = try container.decode(String.self, forKey: .videoUrl)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
        views = try container.decodeIfPresent(Int.self, forKey: .views) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        isWatched = try container.decodeIfPresent(Bool.self, forKey: .isWatched) ?? false
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
    }

    /// Returns the URL for playback
    var playbackURL: URL? {
        URL(string: videoUrl)
    }

    /// Formatted duration string (e.g., "0:45" or "1:30")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Firestore Video Model

/// Represents a video document from the Firestore "videos" collection
struct FirestoreVideo: Codable, Identifiable {
    @DocumentID var id: String?
    let title: String
    let description: String?
    let character: String              // Primary character (backward compatibility)
    let characters: [String]?          // All featured characters (for multi-character videos)
    let videoUrl: String
    let thumbnailUrl: String?
    let duration: Double?
    let tags: [String]?
    let likes: Int?
    let views: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case character
        case characters
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case duration
        case tags
        case likes
        case views
        case createdAt = "created_at"
    }

    /// Converts Firestore video to the app's Video model
    func toVideo() -> Video {
        Video(
            id: UUID(),
            firestoreId: id,
            title: title,
            description: description ?? "",
            character: character,
            characters: characters,
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            duration: duration ?? 0,
            tags: tags ?? [],
            likes: likes ?? 0,
            views: views ?? 0,
            createdAt: createdAt
        )
    }
}
