import Foundation
import FirebaseAnalytics

/// Service for logging analytics events to Firebase Analytics.
/// Wraps Analytics.logEvent() with app-specific event methods.
/// Phase 20 will wire these methods into ViewModels.
final class AnalyticsService {
    static let shared = AnalyticsService()

    private init() {}

    // MARK: - Rating Events

    /// Log when a user rates a joke as Hilarious or Horrible
    func logJokeRated(jokeId: String, character: String, rating: String) {
        Analytics.logEvent("joke_rated", parameters: [
            "joke_id": jokeId,
            "character": character,
            "rating": rating
        ])
    }

    // MARK: - Share Events

    /// Log when a user copies or shares a joke
    func logJokeShared(jokeId: String, method: String) {
        Analytics.logEvent("joke_shared", parameters: [
            "joke_id": jokeId,
            "method": method
        ])
    }

    // MARK: - Navigation Events

    /// Log when a user selects a character from the home screen
    func logCharacterSelected(characterId: String) {
        Analytics.logEvent("character_selected", parameters: [
            "character_id": characterId
        ])
    }

    /// Log when a user opens a topic, and from where ("search", "home" or "deep_link")
    func logTopicSelected(topicId: String, source: String) {
        Analytics.logEvent("topic_selected", parameters: [
            "topic_id": topicId,
            "source": source
        ])
    }

    // MARK: - Review Events

    /// Log when we ask iOS to show the App Store rating prompt.
    /// iOS decides whether it actually appears, so this counts asks, not prompts seen.
    func logReviewPrompted(appVersion: String, positiveRatings: Int) {
        Analytics.logEvent("review_prompted", parameters: [
            "app_version": appVersion,
            "positive_ratings": positiveRatings
        ])
    }
}
