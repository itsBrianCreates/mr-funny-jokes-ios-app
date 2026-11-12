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

    var body: some View {
        NavigationStack {
            JokeDetailContent(
                joke: joke,
                isCopied: isCopied,
                onShare: onShare,
                onCopy: onCopy,
                onRate: onRate,
                onSave: onSave
            )
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
        .presentationDetents(isWideLayout ? [.large] : [.medium, .large])
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

    /// Tracks whether the joke ID was copied to clipboard
    @State private var isJokeIdCopied = false

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
            }
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

            // Character and Category
            HStack(spacing: 8) {
                // Character indicator (if available)
                if let character = jokeCharacter {
                    CharacterIndicatorView(character: character)
                }

                categoryLabel
            }

            // Rating section
            BinaryRatingView(currentRating: joke.userRating, onRate: onRate)

            Divider()

            // Action buttons - iOS style
            VStack(spacing: 12) {
                actionButtons(verticalPadding: 14)
            }

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

            BinaryRatingView(currentRating: joke.userRating, onRate: onRate)

            HStack(spacing: 10) {
                actionButtons(verticalPadding: 8)
            }

            jokeIdButton
        }
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    /// Who's telling the joke: avatar, name and category
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

            VStack(alignment: .leading, spacing: 2) {
                if let character = jokeCharacter {
                    Text(character.name)
                        .font(.headline)
                }

                categoryLabel
            }
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

    private var categoryLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: joke.category.icon)
            Text(joke.category.rawValue)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// Save, Copy and Share. Stacked in the compact sheet, side by side when wide.
    @ViewBuilder
    private func actionButtons(verticalPadding: CGFloat) -> some View {
        Button {
            onSave()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: joke.isSaved ? "person.fill" : "person")
                    .contentTransition(.symbolEffect(.replace))
                Text(joke.isSaved ? "Saved" : "Save")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.vertical, verticalPadding)
        }
        .buttonStyle(.bordered)
        .tint(joke.isSaved ? .green : .blue)
        .animation(.easeInOut(duration: 0.2), value: joke.isSaved)

        Button {
            onCopy()
        } label: {
            HStack {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                Text(isCopied ? "Copied" : "Copy")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.vertical, verticalPadding)
        }
        .buttonStyle(.bordered)
        .tint(isCopied ? .green : .blue)
        .animation(.easeInOut(duration: 0.2), value: isCopied)

        Button {
            onShare()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.vertical, verticalPadding)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
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
