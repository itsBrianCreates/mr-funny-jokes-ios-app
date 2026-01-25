import SwiftUI
import WidgetKit

// MARK: - Accessory Circular View

/// Lock screen circular widget displaying character avatar only.
/// Uses AccessoryWidgetBackground for standard translucent circle appearance.
struct AccessoryCircularView: View {
    let joke: SharedJokeOfTheDay

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let imageName = characterImageName(for: joke.character) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .padding(6)
                    .clipShape(Circle())
            } else {
                // Fallback if no character image
                Image(systemName: "face.smiling")
                    .font(.title)
            }
        }
        .widgetURL(URL(string: "mrfunnyjokes://home"))
    }
}

// MARK: - Accessory Rectangular View

/// Lock screen rectangular widget displaying character name and joke setup.
/// Character name takes priority; joke setup truncates with ellipsis if needed.
struct AccessoryRectangularView: View {
    let joke: SharedJokeOfTheDay

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Character name (priority - always visible)
            if let name = characterDisplayName(for: joke.character) {
                Text(name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
            }
            // Joke setup (truncates if needed)
            Text(joke.setup)
                .font(.caption)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "mrfunnyjokes://home"))
    }
}

// MARK: - Accessory Inline View

/// Lock screen inline widget displaying character name followed by joke text.
/// Uses ViewThatFits to adapt content to available space.
struct AccessoryInlineView: View {
    let joke: SharedJokeOfTheDay

    var body: some View {
        ViewThatFits {
            // Full format: "Mr. Funny: Why did the..."
            if let name = characterDisplayName(for: joke.character) {
                Text("\(name): \(joke.setup)")
            }
            // Fallback: just the setup
            Text(joke.setup)
        }
        .widgetURL(URL(string: "mrfunnyjokes://home"))
    }
}
