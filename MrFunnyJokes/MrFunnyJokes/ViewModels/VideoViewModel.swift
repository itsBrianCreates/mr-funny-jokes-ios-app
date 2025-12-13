import SwiftUI
import Combine
import AVKit

@MainActor
final class VideoViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var currentIndex: Int = 0
    @Published var scrolledIndex: Int? = 0
    @Published var isLoading = false
    @Published var isInitialLoading = true
    @Published var isFirstVideoReady = false
    @Published var isLoadingMore = false
    @Published var hasMoreVideos = true
    @Published var selectedCharacter: String? = nil

    /// Network monitor for detecting connectivity status
    private let networkMonitor = NetworkMonitor.shared

    /// Indicates if we're currently offline
    @Published private(set) var isOffline = false

    /// Preloaded AVPlayer for the first video (for instant playback when tab opens)
    /// Note: These are intentionally not @Published to avoid "Publishing changes from within view updates"
    /// warning when consumePreloadedPlayer is called during view body evaluation
    private(set) var preloadedPlayer: AVPlayer?
    private(set) var preloadedVideoId: String?

    private let videoService = VideoService.shared
    private let storage = LocalStorageService.shared
    private var networkCancellable: AnyCancellable?
    private var loadMoreTask: Task<Void, Never>?
    private var preloadStatusObserver: NSKeyValueObservation?

    /// Number of videos to fetch per batch
    private let batchSize = 10

    /// Currently playing video
    var currentVideo: Video? {
        guard currentIndex >= 0 && currentIndex < videos.count else { return nil }
        return videos[currentIndex]
    }

    init() {
        // Subscribe to network connectivity changes
        networkCancellable = networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
            }

        // Set initial offline state
        isOffline = networkMonitor.isOffline

        // Start loading videos
        Task {
            await loadInitialVideos()
        }
    }

    // MARK: - Load Videos

    /// Load initial videos from Firestore
    private func loadInitialVideos() async {
        isInitialLoading = true

        do {
            let newVideos = try await videoService.fetchInitialVideos(limit: batchSize)

            if !newVideos.isEmpty {
                // Apply local state (watched, liked)
                videos = applyLocalState(to: newVideos)

                // Preload the first video's AVPlayer for instant playback
                preloadFirstVideo()
            }

            hasMoreVideos = newVideos.count >= batchSize
        } catch {
            print("Failed to load videos: \(error)")
        }

        isInitialLoading = false
    }

    /// Preload the first video's AVPlayer so it's ready when user opens Videos tab
    private func preloadFirstVideo() {
        guard let firstVideo = videos.first,
              let url = firstVideo.playbackURL,
              preloadedVideoId != firstVideo.firestoreId else { return }

        // Clean up any existing preloaded player
        cleanupPreloadedPlayer()

        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session for preload: \(error)")
        }

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = false

        // Observe when the player is ready to play
        preloadStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self, weak playerItem] _, _ in
            guard let playerItem = playerItem else { return }
            DispatchQueue.main.async {
                if playerItem.status == .readyToPlay {
                    self?.isFirstVideoReady = true
                    self?.preloadStatusObserver?.invalidate()
                    self?.preloadStatusObserver = nil
                }
            }
        }

        preloadedPlayer = player
        preloadedVideoId = firstVideo.firestoreId
    }

    /// Clean up preloaded player resources
    private func cleanupPreloadedPlayer() {
        preloadStatusObserver?.invalidate()
        preloadStatusObserver = nil
        preloadedPlayer?.pause()
        preloadedPlayer = nil
        preloadedVideoId = nil
    }

    /// Consume the preloaded player (transfers ownership to VideoPlayerView)
    func consumePreloadedPlayer(for videoId: String?) -> AVPlayer? {
        guard let videoId = videoId, videoId == preloadedVideoId else { return nil }
        let player = preloadedPlayer

        // Clear references - ownership transfers to caller
        // Safe to do synchronously since these properties are not @Published
        preloadedPlayer = nil
        preloadedVideoId = nil
        preloadStatusObserver?.invalidate()
        preloadStatusObserver = nil

        return player
    }

    /// Refresh the video feed
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        isFirstVideoReady = false

        // Clean up existing preloaded player
        cleanupPreloadedPlayer()

        videoService.resetPagination()
        hasMoreVideos = true
        currentIndex = 0
        scrolledIndex = 0

        do {
            let newVideos: [Video]
            if let character = selectedCharacter {
                newVideos = try await videoService.fetchVideos(byCharacter: character, limit: batchSize)
            } else {
                newVideos = try await videoService.fetchInitialVideos(limit: batchSize)
            }

            videos = applyLocalState(to: newVideos)
            hasMoreVideos = newVideos.count >= batchSize

            // Preload the new first video
            if !newVideos.isEmpty {
                preloadFirstVideo()
            }
        } catch {
            print("Failed to refresh videos: \(error)")
        }

        isLoading = false
    }

    // MARK: - Infinite Scroll

    /// Called when user swipes to a new video
    func videoDidAppear(at index: Int) {
        currentIndex = index

        // Mark video as watched
        if index < videos.count {
            markVideoWatched(videos[index])
        }

        // Check if we need to load more
        if index >= videos.count - 3 {
            loadMore()
        }
    }

    /// Load more videos for infinite scroll
    func loadMore() {
        guard !isLoadingMore && !isLoading && hasMoreVideos else { return }

        loadMoreTask?.cancel()
        loadMoreTask = Task {
            await performLoadMore()
        }
    }

    private func performLoadMore() async {
        isLoadingMore = true

        do {
            let newVideos: [Video]
            if let character = selectedCharacter {
                newVideos = try await videoService.fetchMoreVideos(byCharacter: character, limit: batchSize)
            } else {
                newVideos = try await videoService.fetchMoreVideos(limit: batchSize)
            }

            guard !Task.isCancelled else {
                isLoadingMore = false
                return
            }

            if newVideos.isEmpty {
                hasMoreVideos = false
            } else {
                // Add to end of list, avoiding duplicates
                let newVideosWithState = applyLocalState(to: newVideos)
                var updatedVideos = videos
                for video in newVideosWithState {
                    if !updatedVideos.contains(where: { $0.firestoreId == video.firestoreId }) {
                        updatedVideos.append(video)
                    }
                }
                videos = updatedVideos
            }
        } catch {
            print("Failed to load more videos: \(error)")
        }

        isLoadingMore = false
    }

    // MARK: - Character Filter

    /// Filter videos by character
    func selectCharacter(_ characterId: String?) {
        HapticManager.shared.lightTap()
        selectedCharacter = characterId
        hasMoreVideos = true
        videoService.resetPagination()
        currentIndex = 0
        scrolledIndex = 0

        Task {
            await refresh()
        }
    }

    // MARK: - Video Interactions

    /// Mark a video as watched
    func markVideoWatched(_ video: Video) {
        guard let firestoreId = video.firestoreId else { return }

        // Update local state
        if let index = videos.firstIndex(where: { $0.firestoreId == firestoreId }) {
            videos[index].isWatched = true
        }

        // Save to local storage
        storage.markVideoWatched(firestoreId: firestoreId)

        // Increment view count in Firestore (fire and forget)
        Task {
            do {
                try await videoService.incrementViewCount(videoId: firestoreId)
            } catch {
                print("Failed to increment view count: \(error)")
            }
        }
    }

    /// Toggle like on a video
    func toggleLike(_ video: Video) {
        guard let firestoreId = video.firestoreId else { return }

        HapticManager.shared.selection()

        // Find and update local state
        guard let index = videos.firstIndex(where: { $0.firestoreId == firestoreId }) else { return }

        let wasLiked = videos[index].isLiked
        videos[index].isLiked = !wasLiked

        // Update like count locally for immediate feedback
        if wasLiked {
            videos[index] = Video(
                id: videos[index].id,
                firestoreId: videos[index].firestoreId,
                title: videos[index].title,
                description: videos[index].description,
                character: videos[index].character,
                videoUrl: videos[index].videoUrl,
                thumbnailUrl: videos[index].thumbnailUrl,
                duration: videos[index].duration,
                tags: videos[index].tags,
                likes: max(0, videos[index].likes - 1),
                views: videos[index].views,
                createdAt: videos[index].createdAt,
                isWatched: videos[index].isWatched,
                isLiked: false
            )
        } else {
            videos[index] = Video(
                id: videos[index].id,
                firestoreId: videos[index].firestoreId,
                title: videos[index].title,
                description: videos[index].description,
                character: videos[index].character,
                videoUrl: videos[index].videoUrl,
                thumbnailUrl: videos[index].thumbnailUrl,
                duration: videos[index].duration,
                tags: videos[index].tags,
                likes: videos[index].likes + 1,
                views: videos[index].views,
                createdAt: videos[index].createdAt,
                isWatched: videos[index].isWatched,
                isLiked: true
            )
        }

        // Save to local storage
        storage.setVideoLiked(firestoreId: firestoreId, liked: !wasLiked)

        // Sync to Firestore
        Task {
            do {
                if wasLiked {
                    try await videoService.decrementLikeCount(videoId: firestoreId)
                } else {
                    try await videoService.incrementLikeCount(videoId: firestoreId)
                }
            } catch {
                print("Failed to update like count: \(error)")
            }
        }
    }

    // MARK: - Loading State

    /// Called when the first video player is ready to play
    func firstVideoDidBecomeReady() {
        guard !isFirstVideoReady else { return }
        isFirstVideoReady = true
    }

    // MARK: - Helpers

    /// Apply local state (watched, liked) to videos
    private func applyLocalState(to videos: [Video]) -> [Video] {
        videos.map { video -> Video in
            var mutableVideo = video
            if let firestoreId = video.firestoreId {
                mutableVideo.isWatched = storage.isVideoWatched(firestoreId: firestoreId)
                mutableVideo.isLiked = storage.isVideoLiked(firestoreId: firestoreId)
            }
            return mutableVideo
        }
    }
}
