import SwiftUI

/// "Browse by topic": the grid shown on the Search tab until the person starts typing
struct TopicBrowseView: View {
    let topics: [(topic: JokeTopic, count: Int)]
    let onSelect: (JokeTopic) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

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
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("\(count) jokes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
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
            HStack(spacing: 12) {
                Text(topic.emoji)
                    .font(.title)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(topic.name) jokes")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(count) jokes for the season")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(topic.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
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
