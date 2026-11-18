import StoreKit
import SwiftUI

/// Decides when to ask for an App Store rating.
///
/// The ask comes right after a positive rating, once the person has given a few of them:
/// that's when they're most likely to be enjoying the app. It is never made on the first
/// launch, never over a sheet, and at most once per app version. iOS has the final say
/// and may still show nothing (it caps the prompt at three times a year).
@MainActor
final class ReviewPromptService: ObservableObject {
    static let shared = ReviewPromptService()

    /// Positive ratings, counted across launches, before the first ask
    static let positiveRatingsNeeded = 3

    /// True from the positive rating that earns the ask until the ask is made.
    /// Not persisted: if the app closes first, the next positive rating earns it again.
    @Published private(set) var isPromptPending = false

    private enum Keys {
        static let hasLaunchedBefore = "reviewPromptHasLaunchedBefore"
        static let positiveRatingCount = "reviewPromptPositiveRatingCount"
        static let lastPromptedVersion = "reviewPromptLastPromptedVersion"
    }

    private let defaults = UserDefaults.standard
    private let isFirstLaunch: Bool

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private init() {
        isFirstLaunch = !defaults.bool(forKey: Keys.hasLaunchedBefore)
        defaults.set(true, forKey: Keys.hasLaunchedBefore)
    }

    /// True for a rating that counts toward the ask ("Hilarious")
    static func isPositive(_ rating: Int?) -> Bool {
        (rating ?? 0) >= 4
    }

    /// Call from `rateJoke` when a joke goes from not-positive to positive
    func recordPositiveRating() {
        let count = defaults.integer(forKey: Keys.positiveRatingCount) + 1
        defaults.set(count, forKey: Keys.positiveRatingCount)

        guard count >= Self.positiveRatingsNeeded,
              !isFirstLaunch,
              defaults.string(forKey: Keys.lastPromptedVersion) != appVersion else { return }
        isPromptPending = true
    }

    /// Call just before asking, so this version never asks twice
    func markPrompted() {
        isPromptPending = false
        defaults.set(appVersion, forKey: Keys.lastPromptedVersion)
        AnalyticsService.shared.logReviewPrompted(
            appVersion: appVersion,
            positiveRatings: defaults.integer(forKey: Keys.positiveRatingCount)
        )
    }

    /// True while anything is presented over the app: a joke sheet, Settings, the share sheet
    var isSheetOpen: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains { $0.rootViewController?.presentedViewController != nil }
    }
}

// MARK: - View Modifier

/// Makes the ask once one is pending and nothing is presented over the app.
/// Most ratings happen in the joke sheet, so this usually fires just after it closes.
private struct ReviewPromptModifier: ViewModifier {
    @ObservedObject private var service = ReviewPromptService.shared
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task(id: service.isPromptPending) {
                guard service.isPromptPending else { return }

                // The first wait lets the rating animation finish; later ones wait out a sheet
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(0.8))
                    guard !Task.isCancelled else { return }

                    if scenePhase == .active, !service.isSheetOpen {
                        service.markPrompted()
                        requestReview()
                        return
                    }
                }
            }
    }
}

extension View {
    /// Attach once, at the root of the app
    func reviewPrompt() -> some View {
        modifier(ReviewPromptModifier())
    }
}
