import UIKit
import LinkPresentation

extension Notification.Name {
    /// Posted when a share sheet finishes with a share. `userInfo["firestoreId"]` is the joke.
    static let jokeShareDidComplete = Notification.Name("jokeShareDidComplete")
}

/// Shares a joke as an image plus a link that opens the joke in the app
/// (or on the web, for people who don't have it).
@MainActor
final class JokeShareService {
    static let shared = JokeShareService()

    /// Where the share was started, for analytics
    enum Surface: String {
        case homeCard = "home_card"
        case fullScreen = "full_screen"
        case moreMenu = "more_menu"
        case stylePicker = "style_picker"
        case jokeSheet = "joke_sheet"
    }

    static let siteURL = URL(string: "https://mrfunnyjokes.app")!

    private init() {}

    /// `https://mrfunnyjokes.app/j/<firestoreId>`: a Universal Link, so it opens the app
    /// on that joke when installed. Jokes without a Firestore ID link to the home page.
    static func link(for joke: Joke) -> URL {
        guard let id = joke.firestoreId, !id.isEmpty else { return siteURL }
        return siteURL.appendingPathComponent("j").appendingPathComponent(id)
    }

    /// Opens the iOS share sheet with the joke's card image and link.
    /// Style and format default to the ones used last time.
    func share(
        _ joke: Joke,
        from surface: Surface,
        style: ShareCardStyle = ShareCardPreferences.style,
        format: ShareCardFormat = ShareCardPreferences.format
    ) {
        HapticManager.shared.success()

        let jokeId = joke.firestoreId ?? joke.id.uuidString
        AnalyticsService.shared.logShareStarted(jokeId: jokeId, surface: surface.rawValue)

        let link = Self.link(for: joke)
        var items: [Any] = []
        if let image = JokeShareCardView.render(joke: joke, style: style, format: format) {
            items.append(ShareImageItem(image: image, title: Self.title(for: joke)))
        } else {
            // No image: the words still go out
            items.append(joke.formattedTextForSharing(characterName: joke.teller?.name ?? "Mr. Funny Jokes"))
        }
        items.append(link)

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { activityType, completed, _, _ in
            guard completed else { return }
            Task { @MainActor in
                AnalyticsService.shared.logShareCompleted(
                    jokeId: jokeId,
                    style: style.rawValue,
                    format: format.rawValue,
                    destination: activityType?.rawValue ?? "unknown"
                )
                guard let firestoreId = joke.firestoreId else { return }
                NotificationCenter.default.post(
                    name: .jokeShareDidComplete,
                    object: nil,
                    userInfo: ["firestoreId": firestoreId]
                )
                try? await FirestoreService.shared.incrementJokeShares(jokeId: firestoreId)
            }
        }

        guard let presenter = Self.topViewController() else { return }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }

    private static func title(for joke: Joke) -> String {
        "A joke from \(joke.teller?.name ?? "Mr. Funny Jokes")"
    }

    private static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              var top = window.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

/// The card image, with a title and thumbnail for the top of the share sheet
private final class ShareImageItem: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        image
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        metadata.iconProvider = NSItemProvider(object: image)
        return metadata
    }
}
