import UIKit

final class HapticManager {
    static let shared = HapticManager()

    // Pre-stored generators for high-frequency haptic methods
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {}

    /// Pre-prepares the Taptic Engine to eliminate cold-start delay on first use.
    /// Call during app launch (e.g., splash screen) before user interaction begins.
    func warmUp() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    // Light tap for card interactions
    func lightTap() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    // Medium impact for punchline reveal
    func mediumImpact() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    // Heavy impact for special moments (on-demand, rarely used)
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    // Success notification for copy/share
    func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    // Selection feedback for ratings
    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    // Soft impact for subtle feedback (on-demand, rarely used)
    func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    // Rigid impact for button presses (on-demand, rarely used)
    func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
}
