import SwiftUI

/// "Browse by topic": the grid shown on the Search tab until the person starts typing
struct TopicBrowseView: View {
    let topics: [(topic: JokeTopic, count: Int)]
    let onSelect: (JokeTopic) -> Void

    /// Grows with Dynamic Type, so large text gets one wide column instead of
    /// two columns of cut-off names. Wide enough that a wide window (iPhone Duo)
    /// gets four columns with every name on one line, not five with names broken
    /// mid-word; an iPhone still gets two.
    @ScaledMetric(relativeTo: .headline) private var minimumTileWidth: CGFloat = 170

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: minimumTileWidth), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Browse by topic")
                    .font(.title2.weight(.bold))

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(topics, id: \.topic.id) { entry in
                        TopicTile(topic: entry.topic, count: entry.count) {
                            onSelect(entry.topic)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Topic Tile

private struct TopicTile: View {
    let topic: JokeTopic
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.lightTap()
            onTap()
        } label: {
            // One compact row per tile, so the whole list fits in about a screen
            HStack(spacing: 10) {
                Text(topic.emoji)
                    .font(.title)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)

                    Text("\(count) jokes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            // Every tile in a row is as tall as the tallest, so a name on two
            // lines doesn't leave its neighbours shorter
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(topic.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Seasonal Topic Card

/// One-row shortcut on Home to the topic that's in season ("Christmas jokes")
struct SeasonalTopicCardView: View {
    let topic: JokeTopic
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.lightTap()
            onTap()
        } label: {
            // One line: the season's picture, its name, and a chevron
            HStack(spacing: 12) {
                Text(topic.emoji)
                    .font(.title2)
                    .accessibilityHidden(true)

                Text("\(topic.name) jokes")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // Neutral, like the joke cards: on Home only the Joke of the Day is tinted
            .background(.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        TopicBrowseView(
            topics: JokeTopic.all.map { ($0, 24) },
            onSelect: { _ in }
        )
        .navigationTitle("Search")
    }
}
