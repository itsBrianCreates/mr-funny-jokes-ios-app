import SwiftUI

// MARK: - Joke Destinations

/// A page of jokes that an opened joke can link to
enum JokeDestination: Hashable {
    case character(JokeCharacter)
    case jokeType(JokeCategory)
    case topic(JokeTopic)
}

/// Opens a page of jokes. Each tab's `NavigationStack` supplies its own, so the page
/// opens in the tab the person is in, on top of whatever page they are on.
struct OpenJokesAction {
    let action: (JokeDestination) -> Void

    func callAsFunction(_ destination: JokeDestination) {
        action(destination)
    }
}

private struct OpenJokesKey: EnvironmentKey {
    static let defaultValue: OpenJokesAction? = nil
}

private struct TopicJokeCountsKey: EnvironmentKey {
    static let defaultValue: [String: Int] = [:]
}

private struct CurrentJokeDestinationKey: EnvironmentKey {
    static let defaultValue: JokeDestination? = nil
}

extension EnvironmentValues {
    /// Set by `MainContentView` on each tab. Nil where pages can't be opened (previews).
    var openJokes: OpenJokesAction? {
        get { self[OpenJokesKey.self] }
        set { self[OpenJokesKey.self] = newValue }
    }

    /// Joke count for every topic that has a page (see `JokeTopic.browsable`), by topic ID.
    /// A topic missing from here is too thin to link to.
    var topicJokeCounts: [String: Int] {
        get { self[TopicJokeCountsKey.self] }
        set { self[TopicJokeCountsKey.self] = newValue }
    }

    /// The page this view is on, so a joke there doesn't link to the page it's already on
    var currentJokeDestination: JokeDestination? {
        get { self[CurrentJokeDestinationKey.self] }
        set { self[CurrentJokeDestinationKey.self] = newValue }
    }
}

extension View {
    /// Registers the pages `JokeDestination` can open. Apply once inside each `NavigationStack`.
    func jokeDestinations(viewModel: JokeViewModel) -> some View {
        navigationDestination(for: JokeDestination.self) { destination in
            switch destination {
            case .character(let character):
                CharacterDetailView(character: character)
            case .jokeType(let category):
                JokeTypeDetailView(viewModel: viewModel, category: category)
            case .topic(let topic):
                TopicDetailView(viewModel: viewModel, topic: topic)
            }
        }
    }
}

// MARK: - Joke Links Row

/// Who told an opened joke, what kind it is and what it's about, as one row of chips.
/// Every chip opens more jokes like this one: the teller's page, the joke type, a topic.
///
/// One rule for the row: if it's in a capsule, it's tappable. The page the person is
/// already on shows as plain text instead. Chips that don't fit move into a "…" menu,
/// so the row is always one line and never pushes the rating down.
///
/// Used only after the punchline. Cards keep plain labels: the whole card is the button,
/// and a topic there could give the joke away.
struct JokeLinksRow: View {
    let joke: Joke
    /// Off where the teller's picture is already shown beside the row (wide layout)
    var showsCharacterAvatar = true

    @Environment(\.openJokes) private var openJokes
    @Environment(\.topicJokeCounts) private var topicJokeCounts
    @Environment(\.currentJokeDestination) private var currentDestination

    /// Apple's minimum tap target. Chips look smaller; their tappable area doesn't.
    private let minimumTapSize: CGFloat = 44

    private struct Link: Identifiable {
        let id: String
        let title: String
        var emoji: String?
        var systemImage: String?
        var avatarImageName: String?
        let color: Color
        /// Nil for the page the person is already on: shown, but not a link
        let destination: JokeDestination?
        /// VoiceOver label and overflow-menu title
        let actionTitle: String
    }

    private var links: [Link] {
        var links: [Link] = []
        let character = joke.character.flatMap { JokeCharacter.find(byName: $0) }

        if let character {
            let destination = JokeDestination.character(character)
            links.append(Link(
                id: "character",
                title: character.name,
                avatarImageName: showsCharacterAvatar ? character.imageName : nil,
                color: character.color,
                destination: linkable(destination),
                actionTitle: "More from \(character.name)"
            ))
        }

        // A teller with one joke type (Mr. Love and pickup lines) already leads to the
        // same jokes, so the type would be a second door to the same room
        if character?.hasMultipleCategories ?? true {
            links.append(Link(
                id: "type",
                title: joke.category.rawValue,
                systemImage: joke.category.icon,
                color: .gray,
                destination: linkable(.jokeType(joke.category)),
                actionTitle: "More \(joke.category.rawValue)"
            ))
        }

        // Topics that have a page, most specific (fewest jokes) first
        let topics = JokeTopic.all
            .filter { currentDestination != .topic($0) && topicJokeCounts[$0.id] != nil && $0.contains(joke) }
            .sorted { (topicJokeCounts[$0.id] ?? 0) < (topicJokeCounts[$1.id] ?? 0) }
            .prefix(2)
        for topic in topics {
            links.append(Link(
                id: "topic-\(topic.id)",
                title: topic.name,
                emoji: topic.emoji,
                color: topic.color,
                destination: linkable(.topic(topic)),
                actionTitle: "More \(topic.name) jokes"
            ))
        }

        return links
    }

    /// A destination is a link unless nothing can open it or it's the current page
    private func linkable(_ destination: JokeDestination) -> JokeDestination? {
        guard openJokes != nil, destination != currentDestination else { return nil }
        return destination
    }

    var body: some View {
        let links = links
        if !links.isEmpty {
            // Everything on one line if it fits; otherwise move chips into the menu
            // from the end until what's left does
            ViewThatFits(in: .horizontal) {
                ForEach((1...links.count).reversed(), id: \.self) { visibleCount in
                    row(visible: Array(links.prefix(visibleCount)), overflow: Array(links.dropFirst(visibleCount)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // The 44pt tap area is taller than the chips; don't let it add space
            // above and below the row
            .padding(.vertical, -7)
        }
    }

    private func row(visible: [Link], overflow: [Link]) -> some View {
        HStack(spacing: 6) {
            ForEach(visible) { link in
                if let destination = link.destination {
                    Button {
                        open(destination)
                    } label: {
                        chipLabel(link, isLink: true)
                            .frame(minWidth: minimumTapSize, minHeight: minimumTapSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(link.actionTitle)
                } else {
                    chipLabel(link, isLink: false)
                        .frame(minHeight: minimumTapSize)
                }
            }

            let overflowLinks = overflow.filter { $0.destination != nil }
            if !overflowLinks.isEmpty {
                Menu {
                    ForEach(overflowLinks) { link in
                        Button(link.actionTitle) {
                            if let destination = link.destination { open(destination) }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.15), in: Circle())
                        .frame(width: minimumTapSize, height: minimumTapSize)
                        .contentShape(Rectangle())
                }
                // Match the chips, not the app's yellow accent
                .tint(.primary)
                .accessibilityLabel("More like this")
            }
        }
    }

    private func chipLabel(_ link: Link, isLink: Bool) -> some View {
        HStack(spacing: 4) {
            if let avatarImageName = link.avatarImageName {
                Image(avatarImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }
            if let emoji = link.emoji {
                Text(emoji)
                    .accessibilityHidden(true)
            }
            if let systemImage = link.systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(link.title)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(isLink ? .primary : .secondary)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, isLink ? 10 : 0)
        .padding(.vertical, 6)
        .background {
            if isLink {
                Capsule().fill(link.color.opacity(0.15))
            }
        }
    }

    private func open(_ destination: JokeDestination) {
        HapticManager.shared.lightTap()
        switch destination {
        case .character(let character):
            AnalyticsService.shared.logCharacterSelected(characterId: character.id)
        case .topic(let topic):
            AnalyticsService.shared.logTopicSelected(topicId: topic.id, source: "joke")
        case .jokeType:
            break
        }
        openJokes?(destination)
    }
}
