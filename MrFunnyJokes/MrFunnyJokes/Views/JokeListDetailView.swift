import SwiftUI

// MARK: - Wide Layout Environment

enum AdaptiveLayout {
    /// Windows at least this wide get side-by-side layouts
    /// (iPhone Duo inner display, landscape Max, iPhone Mirroring).
    static let wideMinWidth: CGFloat = 700
}

private struct IsWideLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when the app window is wide enough for side-by-side layouts. Set once at the
    /// root so sheets, which can't measure the window they're presented over, adapt too.
    var isWideLayout: Bool {
        get { self[IsWideLayoutKey.self] }
        set { self[IsWideLayoutKey.self] = newValue }
    }
}

// MARK: - Joke List-Detail View

/// A joke list that opens the selected joke in a sheet on compact widths and in a pane
/// beside the list on wide ones (iPhone Duo inner display, landscape Max).
///
/// The selection is an ID so the pane and sheet always read fresh ratings and saves, and
/// it survives fold and unfold: unfolding hands an open sheet to the pane, folding hands
/// the pane's joke back to a sheet.
struct JokeListDetailView<ListContent: View>: View {
    @Binding var selectedJokeId: UUID?
    /// The selected joke, looked up fresh from the owning view model on every render
    let selectedJoke: Joke?
    let isCopied: (Joke) -> Bool
    let onShare: (Joke) -> Void
    let onCopy: (Joke) -> Void
    let onRate: (Joke, Int) -> Void
    let onSave: (Joke) -> Void
    /// False when the screen already paints its own color behind the pane (character pages)
    var showsPaneWash = true
    /// The list. `isSplit` is true while the detail pane is showing, so rows can
    /// highlight the selected joke.
    @ViewBuilder let list: (_ isSplit: Bool) -> ListContent

    @State private var containerWidth: CGFloat = 0

    private var isSplit: Bool {
        containerWidth >= AdaptiveLayout.wideMinWidth
    }

    private var listPaneWidth: CGFloat {
        min(max(containerWidth * 0.42, 340), 440)
    }

    private var compactSheetJoke: Binding<Joke?> {
        Binding(
            get: { isSplit ? nil : selectedJoke },
            set: { joke in
                if joke == nil, !isSplit { selectedJokeId = nil }
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            list(isSplit)
                .frame(width: isSplit ? listPaneWidth : nil)

            if isSplit {
                Divider()
                    .ignoresSafeArea(edges: .vertical)
                detailPane
            }
        }
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            containerWidth = width
        }
        .sheet(item: compactSheetJoke) { joke in
            JokeDetailSheet(
                joke: joke,
                isCopied: isCopied(joke),
                onDismiss: { selectedJokeId = nil },
                onShare: { onShare(joke) },
                onCopy: { onCopy(joke) },
                onRate: { rating in onRate(joke, rating) },
                onSave: { onSave(joke) }
            )
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let joke = selectedJoke {
            JokeDetailContent(
                joke: joke,
                isCopied: isCopied(joke),
                onShare: { onShare(joke) },
                onCopy: { onCopy(joke) },
                onRate: { rating in onRate(joke, rating) },
                onSave: { onSave(joke) },
                showsWash: showsPaneWash
            )
            // New identity per joke resets its scroll position and copied-ID state
            .id(joke.id)
        } else {
            JokePanePlaceholder()
        }
    }
}

extension JokeListDetailView {
    /// Home, Me and Search: jokes owned by the main `JokeViewModel`
    init(
        viewModel: JokeViewModel,
        selectedJokeId: Binding<UUID?>,
        @ViewBuilder list: @escaping (_ isSplit: Bool) -> ListContent
    ) {
        let id = selectedJokeId.wrappedValue
        let jokeOfTheDay = viewModel.jokeOfTheDay
        self.init(
            selectedJokeId: selectedJokeId,
            selectedJoke: id.flatMap { id in
                jokeOfTheDay?.id == id ? jokeOfTheDay : viewModel.jokes.first { $0.id == id }
            },
            isCopied: { viewModel.copiedJokeId == $0.id },
            onShare: { viewModel.shareJoke($0) },
            onCopy: { viewModel.copyJoke($0) },
            onRate: { viewModel.rateJoke($0, rating: $1) },
            onSave: { viewModel.saveJoke($0) },
            list: list
        )
    }

    /// Character pages: jokes owned by that page's `CharacterDetailViewModel`
    init(
        viewModel: CharacterDetailViewModel,
        selectedJokeId: Binding<UUID?>,
        @ViewBuilder list: @escaping (_ isSplit: Bool) -> ListContent
    ) {
        let id = selectedJokeId.wrappedValue
        self.init(
            selectedJokeId: selectedJokeId,
            selectedJoke: id.flatMap { id in viewModel.jokes.first { $0.id == id } },
            isCopied: { viewModel.copiedJokeId == $0.id },
            onShare: { viewModel.shareJoke($0) },
            onCopy: { viewModel.copyJoke($0) },
            onRate: { viewModel.rateJoke($0, rating: $1) },
            onSave: { viewModel.saveJoke($0) },
            showsPaneWash: false,
            list: list
        )
    }
}

// MARK: - Joke Pane Placeholder

/// Shown in the detail pane until a joke is picked, so punchlines aren't spoiled
struct JokePanePlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: -14) {
                ForEach(JokeCharacter.allCharacters) { character in
                    Image(character.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color(.systemBackground), lineWidth: 3)
                        )
                }
            }
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Pick a joke, any joke")
                    .font(.title2.weight(.bold))

                Text("Tap one and the punchline lands here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Placeholder") {
    JokePanePlaceholder()
}
