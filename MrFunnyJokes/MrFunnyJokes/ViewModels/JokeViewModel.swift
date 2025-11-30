import SwiftUI

@MainActor
final class JokeViewModel: ObservableObject {
    @Published var jokes: [Joke] = []
    @Published var selectedCategory: JokeCategory? = nil
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var copiedJokeId: UUID?

    /// Tracks initial app launch loading state for skeleton display
    @Published var isInitialLoading = true

    private let storage = LocalStorageService.shared
    private let api = JokeAPIService.shared
    private var copyTask: Task<Void, Never>?

    var filteredJokes: [Joke] {
        guard let category = selectedCategory else {
            return jokes
        }
        return jokes.filter { $0.category == category }
    }

    // Jokes that have been rated by the user
    var ratedJokes: [Joke] {
        jokes.filter { $0.userRating != nil }
    }

    // Jokes grouped by rating (1-4 scale)
    // 4 = Hilarious, 3 = Funny, 2 = Meh, 1 = Groan-worthy
    var hilariousJokes: [Joke] {
        jokes.filter { $0.userRating == 4 }
    }

    var funnyJokes: [Joke] {
        jokes.filter { $0.userRating == 3 }
    }

    var mehJokes: [Joke] {
        jokes.filter { $0.userRating == 2 }
    }

    var groanJokes: [Joke] {
        jokes.filter { $0.userRating == 1 }
    }

    /// Joke of the Day - deterministically selected based on the current date
    /// Returns the same joke for everyone on any given day
    var jokeOfTheDay: Joke? {
        guard !jokes.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % jokes.count
        // Sort by ID to ensure consistent ordering regardless of shuffle
        let sortedJokes = jokes.sorted { $0.id.uuidString < $1.id.uuidString }
        return sortedJokes[index]
    }

    init() {
        loadJokes()
    }

    // MARK: - Loading

    func loadJokes() {
        // Load hardcoded jokes first (offline-first)
        let hardcoded = storage.loadHardcodedJokes()
        let cached = storage.loadCachedJokes()

        // Combine and deduplicate
        var allJokes = hardcoded
        for joke in cached {
            if !allJokes.contains(where: { $0.setup == joke.setup }) {
                allJokes.append(joke)
            }
        }

        jokes = allJokes.shuffled()

        // Mark initial loading complete after data is ready
        // Small delay ensures skeleton is briefly visible for smooth transition
        if isInitialLoading {
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                isInitialLoading = false
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true

        // Fetch new jokes from API with cancellation support
        let newJokes = await withTaskCancellationHandler {
            await api.fetchMultipleJokes(count: 5)
        } onCancel: {
            // Task was cancelled, nothing to clean up
        }

        // Check if task was cancelled before updating UI
        guard !Task.isCancelled else {
            isRefreshing = false
            return
        }

        // Cache them
        for joke in newJokes {
            storage.appendCachedJoke(joke)
        }

        // Reload all jokes
        loadJokes()

        isRefreshing = false
    }

    // MARK: - Ratings

    func rateJoke(_ joke: Joke, rating: Int) {
        HapticManager.shared.selection()

        // Rating 0 means remove rating
        if rating == 0 {
            storage.removeRating(for: joke.id)
            if let index = jokes.firstIndex(where: { $0.id == joke.id }) {
                jokes[index].userRating = nil
            }
        } else {
            // Validate rating range (1-4)
            let clampedRating = min(max(rating, 1), 4)
            storage.saveRating(for: joke.id, rating: clampedRating)
            if let index = jokes.firstIndex(where: { $0.id == joke.id }) {
                jokes[index].userRating = clampedRating
            }
        }
    }

    // MARK: - Sharing

    func shareJoke(_ joke: Joke) {
        HapticManager.shared.success()

        let text = "\(joke.setup)\n\n\(joke.punchline)\n\n— Mr. Funny Jokes"

        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        // Get the key window scene safely
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return
        }

        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // Handle iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        topVC.present(activityVC, animated: true)
    }

    func copyJoke(_ joke: Joke) {
        HapticManager.shared.success()

        let text = "\(joke.setup)\n\n\(joke.punchline)"
        UIPasteboard.general.string = text

        // Show copied indicator
        copiedJokeId = joke.id

        // Cancel any existing copy task
        copyTask?.cancel()

        // Hide after delay with proper cancellation
        copyTask = Task { [weak self, jokeId = joke.id] in
            do {
                try await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                if self?.copiedJokeId == jokeId {
                    self?.copiedJokeId = nil
                }
            } catch {
                // Task was cancelled, ignore
            }
        }
    }

    // MARK: - Category Selection

    func selectCategory(_ category: JokeCategory?) {
        HapticManager.shared.lightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedCategory = category
        }
    }
}
