import Foundation
import UserNotifications

/// Manages local push notifications for the Joke of the Day feature
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    // MARK: - Published Properties

    @Published var isAuthorized = false
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
            if notificationsEnabled {
                scheduleJokeOfTheDayNotification()
            } else {
                cancelAllNotifications()
            }
        }
    }

    @Published var notificationHour: Int {
        didSet {
            UserDefaults.standard.set(notificationHour, forKey: Keys.notificationHour)
            if notificationsEnabled {
                scheduleJokeOfTheDayNotification()
            }
        }
    }

    @Published var notificationMinute: Int {
        didSet {
            UserDefaults.standard.set(notificationMinute, forKey: Keys.notificationMinute)
            if notificationsEnabled {
                scheduleJokeOfTheDayNotification()
            }
        }
    }

    // MARK: - Constants

    private enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationHour = "notificationHour"
        static let notificationMinute = "notificationMinute"
        static let hasRequestedPermission = "hasRequestedNotificationPermission"
    }

    private let jokeOfTheDayNotificationId = "jokeOfTheDayNotification"

    // MARK: - Initialization

    override private init() {
        // Load saved preferences with defaults (9:00 AM)
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: Keys.notificationsEnabled)
        self.notificationHour = UserDefaults.standard.object(forKey: Keys.notificationHour) as? Int ?? 9
        self.notificationMinute = UserDefaults.standard.object(forKey: Keys.notificationMinute) as? Int ?? 0

        super.init()

        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Check current authorization status
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized

                // If not authorized but user had enabled notifications, disable them
                if settings.authorizationStatus == .denied && self?.notificationsEnabled == true {
                    self?.notificationsEnabled = false
                }
            }
        }
    }

    /// Request notification permissions
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )

            await MainActor.run {
                self.isAuthorized = granted
                UserDefaults.standard.set(true, forKey: Keys.hasRequestedPermission)

                if granted && !self.notificationsEnabled {
                    // Auto-enable notifications when permission is granted
                    self.notificationsEnabled = true
                }
            }

            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }

    /// Check if we've already requested permission
    var hasRequestedPermission: Bool {
        UserDefaults.standard.bool(forKey: Keys.hasRequestedPermission)
    }

    // MARK: - Scheduling

    /// Schedule the daily Joke of the Day notification
    func scheduleJokeOfTheDayNotification() {
        guard notificationsEnabled else { return }

        // Cancel existing notification first
        cancelAllNotifications()

        // Get the joke of the day content
        let jokeContent = getJokeOfTheDayContent()

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = jokeContent.title
        content.body = jokeContent.body
        content.sound = .default
        content.userInfo = ["type": "jokeOfTheDay"]

        // Create daily trigger at the specified time
        var dateComponents = DateComponents()
        dateComponents.hour = notificationHour
        dateComponents.minute = notificationMinute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        // Create and schedule the request
        let request = UNNotificationRequest(
            identifier: jokeOfTheDayNotificationId,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                print("Joke of the Day notification scheduled for \(self.notificationHour):\(String(format: "%02d", self.notificationMinute))")
            }
        }
    }

    /// Cancel all scheduled notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [jokeOfTheDayNotificationId]
        )
    }

    // MARK: - Content Generation

    /// Get content for the joke notification
    private func getJokeOfTheDayContent() -> (title: String, body: String) {
        // Try to get the saved joke of the day
        if let joke = SharedStorageService.shared.loadJokeOfTheDay(),
           joke.id != "placeholder" {

            // Get character name for the title
            let characterName = getCharacterDisplayName(joke.character)

            return (
                title: "\(characterName) has a joke for you!",
                body: joke.setup
            )
        }

        // Fallback content
        return (
            title: "Your Daily Joke Awaits!",
            body: "Tap to see today's joke and start your day with a laugh!"
        )
    }

    /// Convert character ID to display name
    private func getCharacterDisplayName(_ characterId: String?) -> String {
        guard let id = characterId else { return "Mr. Funny" }

        switch id {
        case "mr_funny": return "Mr. Funny"
        case "mr_potty": return "Mr. Potty"
        case "mr_bad": return "Mr. Bad"
        case "mr_love": return "Mr. Love"
        case "mr_sad": return "Mr. Sad"
        default: return "Mr. Funny"
        }
    }

    // MARK: - Time Formatting

    /// Get the notification time as a Date for DatePicker binding
    var notificationTime: Date {
        get {
            var components = DateComponents()
            components.hour = notificationHour
            components.minute = notificationMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            notificationHour = components.hour ?? 9
            notificationMinute = components.minute ?? 0
        }
    }

    /// Formatted time string for display
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: notificationTime)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let type = userInfo["type"] as? String, type == "jokeOfTheDay" {
            // Post notification to navigate to home tab and show joke of the day
            NotificationCenter.default.post(
                name: .didTapJokeOfTheDayNotification,
                object: nil
            )
        }

        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didTapJokeOfTheDayNotification = Notification.Name("didTapJokeOfTheDayNotification")
}
