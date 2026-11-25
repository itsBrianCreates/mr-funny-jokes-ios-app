import SwiftUI

struct JokeDetailSheet: View {
    let joke: Joke
    let isCopied: Bool
    let onDismiss: () -> Void
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void
    let onSave: () -> Void

    @Environment(\.isWideLayout) private var isWideLayout
    @Environment(\.openJokes) private var openJokes

    /// Height of the joke, rating and actions, measured once they're laid out
    @State private var contentHeight: CGFloat?

    /// The sheet opens just tall enough to show everything down to the actions, so
    /// a long joke doesn't leave them cut off at half height. Until the content is
    /// measured it's the usual half-height sheet.
    private var detents: Set<PresentationDetent> {
        if isWideLayout { return [.large] }
        guard let contentHeight else { return [.medium, .large] }
        // 56 is the sheet's own bar with the close button
        return [.height(contentHeight + 56), .large]
    }

    /// Tapping a chip in the sheet closes the sheet first; the page is pushed on the
    /// screen underneath
    private var openJokesClosingSheet: OpenJokesAction? {
        guard let openJokes else { return nil }
        return OpenJokesAction { destination in
            onDismiss()
            openJokes(destination)
        }
    }

    var body: some View {
        NavigationStack {
            JokeDetailContent(
                joke: joke,
                isCopied: isCopied,
                onShare: onShare,
                onCopy: onCopy,
                onRate: onRate,
                onSave: onSave,
                onContentHeightChange: { contentHeight = $0 }
            )
            .environment(\.openJokes, openJokesClosingSheet)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        // Wide windows are short (iPhone Duo inner display, landscape): a half-height
        // sheet there cuts off the rating and actions, so open at full height.
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Joke Detail Content

/// Punchline, rating and actions for a joke. Shown inside `JokeDetailSheet` on compact
/// widths and in the feed's detail pane on wide ones (iPhone Duo inner display).
struct JokeDetailContent: View {
    let joke: Joke
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void
    let onSave: () -> Void

    /// The wash of the teller's color behind the wide layout. Off where the screen
    /// behind already has one (character pages).
    var showsWash = true

    /// Reports the compact layout's height, so the sheet can open tall enough to show all of it
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    /// Tracks whether the joke ID was copied to clipboard
    @State private var isJokeIdCopied = false
    @State private var showingStylePicker = false

    /// Vote counts read from Firestore when the joke opens, and the reader's rating
    /// at that moment. The catalog's own counts can be a week old.
    @State private var freshCounts: JokeCounts?
    @State private var ratingWhenFetched: Int?

    /// Counts for the rating buttons: the fetched numbers, moved by any vote the
    /// reader has cast or changed since
    private var voteCounts: (hilarious: Int, horrible: Int) {
        guard let freshCounts else { return (joke.likes, joke.dislikes) }
        let likes = JokeEngagement.likesDelta(previousRating: ratingWhenFetched, newRating: joke.userRating)
        let dislikes = JokeEngagement.dislikesDelta(previousRating: ratingWhenFetched, newRating: joke.userRating)
        return (max(freshCounts.laughs + likes, 0), max(freshCounts.horribles + dislikes, 0))
    }

    @Environment(\.isWideLayout) private var isWideLayout

    /// The character associated with this joke, if any
    private var jokeCharacter: JokeCharacter? {
        guard let characterName = joke.character else { return nil }
        return JokeCharacter.find(byName: characterName)
    }

    /// Character color, or brand yellow when the joke has no character
    private var accentColor: Color {
        jokeCharacter?.color ?? .accessibleYellow
    }

    var body: some View {
        ScrollView {
            if isWideLayout {
                wideLayout
            } else {
                compactLayout
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        onContentHeightChange?(height)
                    }
            }
        }
        .task(id: joke.firestoreId) {
            guard let id = joke.firestoreId,
                  let counts = try? await FirestoreService.shared.fetchJokeCounts(jokeId: id) else { return }
            ratingWhenFetched = joke.userRating
            freshCounts = counts
        }
        .background(alignment: .top) {
            if isWideLayout && showsWash {
                // Soft wash of the teller's color, echoing the character page
                LinearGradient(
                    colors: [accentColor.opacity(0.22), accentColor.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
                // Runs under the nav bar and the Duo's control rail instead of stopping short
                .ignoresSafeArea(edges: [.top, .horizontal])
            }
        }
    }

    // MARK: - Compact Layout (sheet on iPhone and the Duo outer display)

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Setup and Punchline - formatted differently for knock-knock jokes
            if joke.category == .knockKnock {
                knockKnockContent
            } else {
                standardContent
            }

            // Teller, joke type and topics: each chip opens more jokes like this one
            JokeLinksRow(joke: joke)

            // Rating section
            BinaryRatingView(
                currentRating: joke.userRating,
                hilariousCount: voteCounts.hilarious,
                horribleCount: voteCounts.horrible,
                onRate: onRate
            )

            // No divider: round actions under pill ratings already read as two groups
            actionRow

            jokeIdButton

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Wide Layout (detail pane and sheets on the Duo inner display)

    /// Short, wide windows: the teller up top, a bold punchline, and the
    /// actions in one row so everything fits without scrolling.
    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: 20) {
            tellerHeader

            VStack(alignment: .leading, spacing: 12) {
                ForEach(joke.setupLines, id: \.self) { line in
                    Text(line)
                        .font(.title2.weight(.medium))
                }
            }

            punchlineText(lines: joke.punchlineLines)

            BinaryRatingView(
                currentRating: joke.userRating,
                hilariousCount: voteCounts.hilarious,
                horribleCount: voteCounts.horrible,
                onRate: onRate
            )

            actionRow

            jokeIdButton
        }
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    /// Who's telling the joke: their picture, then the chips for teller, type and topics
    private var tellerHeader: some View {
        HStack(spacing: 12) {
            if let character = jokeCharacter {
                Image(character.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(character.color, lineWidth: 2)
                    )
            }

            // The picture beside it already shows who's telling the joke
            JokeLinksRow(joke: joke, showsCharacterAvatar: false)
        }
    }

    /// The punchline: same size as the setup, in bold, no container. One-liners
    /// have no punchline and show nothing.
    @ViewBuilder
    private func punchlineText(lines: [String]) -> some View {
        let lines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.title2.weight(.bold))
                }
            }
        }
    }

    // MARK: - Shared Pieces

    /// One row of round buttons, the shape of the iOS share sheet: Share, Image,
    /// Save, Copy. Share is the only filled one and goes out in one tap with the
    /// style used last; Image opens the picker to change how the image looks first.
    private var actionRow: some View {
        HStack(alignment: .top, spacing: 0) {
            Button {
                onShare()
            } label: {
                // The glyph's weight is in its box, below the arrow, so centered it looks low
                CircleActionLabel(systemImage: "square.and.arrow.up", title: "Share", style: .prominent, iconNudge: -2)
            }

            Button {
                HapticManager.shared.lightTap()
                showingStylePicker = true
            } label: {
                CircleActionLabel(systemImage: "photo", title: "Image")
            }
            .fullScreenCover(isPresented: $showingStylePicker) {
                ShareStylePickerView(joke: joke, surface: .stylePicker)
            }

            Button {
                onSave()
            } label: {
                CircleActionLabel(
                    systemImage: joke.isSaved ? "bookmark.fill" : "bookmark",
                    title: joke.isSaved ? "Saved" : "Save",
                    style: joke.isSaved ? .done : .plain
                )
            }

            Button {
                onCopy()
            } label: {
                CircleActionLabel(
                    systemImage: isCopied ? "checkmark" : "doc.on.doc",
                    title: isCopied ? "Copied" : "Copy",
                    style: isCopied ? .done : .plain
                )
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: joke.isSaved)
        .animation(.easeInOut(duration: 0.2), value: isCopied)
    }

    /// Joke ID for Firebase reference - tap to copy
    @ViewBuilder
    private var jokeIdButton: some View {
        if let jokeId = joke.firestoreId {
            Button {
                UIPasteboard.general.string = jokeId
                isJokeIdCopied = true

                // Reset after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isJokeIdCopied = false
                }
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text(isJokeIdCopied ? "Copied!" : "Joke ID")
                        Image(systemName: isJokeIdCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.caption2)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .font(.caption2)
                    .foregroundColor(isJokeIdCopied ? .green : Color(.tertiaryLabel))

                    Text(jokeId)
                        .font(.caption.monospaced())
                        .foregroundStyle(isJokeIdCopied ? .green : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isJokeIdCopied ? Color.green.opacity(0.1) : Color.clear)
                )
                .animation(.easeInOut(duration: 0.2), value: isJokeIdCopied)
            }
            .buttonStyle(.plain)
            .padding(.top, isWideLayout ? 0 : 8)
        }
    }

    // MARK: - Standard Joke Content

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Setup
            Text(joke.setup)
                .font(.title2.weight(.medium))

            // Punchline (one-liners have none; skip it rather than leave a gap)
            if !joke.punchline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(joke.punchline)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Knock-Knock Joke Content

    private var knockKnockContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Parse and format the setup (e.g., "Knock knock. Who's there? Lettuce.")
            ForEach(joke.setupLines, id: \.self) { line in
                Text(line)
                    .font(.title3.weight(.medium))
            }

            // Punchline (e.g., "Lettuce who? Lettuce in, it's cold out here!")
            ForEach(joke.punchlineLines, id: \.self) { line in
                Text(line)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview("Dad Joke") {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            JokeDetailSheet(
                joke: Joke(
                    category: .dadJoke,
                    setup: "Why don't scientists trust atoms?",
                    punchline: "Because they make up everything!",
                    userRating: 5,
                    firestoreId: "0CDqve8AUmDb0VbXWwdQ",
                    character: "Mr. Funny"
                ),
                isCopied: false,
                onDismiss: {},
                onShare: {},
                onCopy: {},
                onRate: { _ in },
                onSave: {}
            )
        }
}

#Preview("Knock-Knock") {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            JokeDetailSheet(
                joke: Joke(
                    category: .knockKnock,
                    setup: "Knock, knock.\nWho's there?\nNobel.",
                    punchline: "Nobel who?\nNo bell… that's why I knocked.",
                    userRating: 1,
                    firestoreId: "ABC123XYZ456example",
                    character: "Mr. Potty"
                ),
                isCopied: false,
                onDismiss: {},
                onShare: {},
                onCopy: {},
                onRate: { _ in },
                onSave: {}
            )
        }
}

// MARK: - Circle Action Label

/// An icon in a circle with a one-word label under it. Each one takes an equal
/// share of the row, so the whole column is the tap area.
private struct CircleActionLabel: View {
    enum Style {
        /// Gray circle: the default
        case plain
        /// Filled blue: the one action the row leads with
        case prominent
        /// Green: the action has just been done (Saved, Copied)
        case done
    }

    let systemImage: String
    let title: String
    var style: Style = .plain
    /// Moves the icon up (negative) or down inside the circle, for glyphs that look off-center
    var iconNudge: CGFloat = 0

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(iconColor)
                .offset(y: iconNudge)
                .frame(width: 56, height: 56)
                .background(circleColor, in: Circle())

            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var iconColor: Color {
        switch style {
        case .plain: return .primary
        case .prominent: return .white
        case .done: return .green
        }
    }

    private var circleColor: Color {
        switch style {
        case .plain: return Color(.secondarySystemFill)
        case .prominent: return .blue
        case .done: return Color.green.opacity(0.18)
        }
    }
}
