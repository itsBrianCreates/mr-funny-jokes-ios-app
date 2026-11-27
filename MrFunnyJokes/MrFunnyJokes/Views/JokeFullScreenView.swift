import SwiftUI

/// Jokes on the whole screen, one at a time. Swiping left, or Next, moves to the next
/// joke and swiping right goes back; pulling down closes.
///
/// Opened from the Joke of the Day card, the widget, the daily notification, shared
/// links (`mrfunnyjokes.app/j/<id>`) and "Open full screen" on any joke card.
struct JokeFullScreenView: View {
    @ObservedObject var viewModel: JokeViewModel
    /// The joke to open on
    let openedJoke: Joke
    let isJokeOfTheDay: Bool
    /// The list the joke was opened from, which swiping moves through. Without one
    /// (Joke of the Day, widget, notification, shared link) the Home feed follows.
    var list: [Joke] = []
    /// The system appearance, passed in because this view hides the status bar and
    /// paints its own colors
    let isDark: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Every joke that can be swiped to, fixed when the screen opens
    @State private var queue: [Joke] = []
    @State private var index = 0
    /// How far the pages have been dragged sideways
    @State private var dragOffset: CGFloat = 0
    /// True while a page change is sliding into place
    @State private var isSettling = false
    @State private var pageWidth: CGFloat = 0

    private var jokes: [Joke] { queue.isEmpty ? [openedJoke] : queue }
    private var hasNext: Bool { index < jokes.count - 1 }
    private var hasPrevious: Bool { index > 0 }

    /// The joke on screen and the one on each side of it
    private var window: [(position: Int, joke: Joke)] {
        (max(index - 1, 0)...min(index + 1, jokes.count - 1)).map { ($0, jokes[$0]) }
    }

    var body: some View {
        ZStack {
            ForEach(window, id: \.joke.id) { entry in
                JokeFullScreenPage(
                    viewModel: viewModel,
                    openedJoke: entry.joke,
                    isJokeOfTheDay: isJokeOfTheDay(entry.joke),
                    isDark: isDark,
                    onNext: entry.position < jokes.count - 1 ? { move(by: 1) } : nil,
                    onPrevious: entry.position > 0 ? { move(by: -1) } : nil
                )
                .offset(x: CGFloat(entry.position - index) * pageWidth + dragOffset)
                .accessibilityHidden(entry.position != index)
            }
        }
        .background {
            // The whole screen's width, safe area included: pages are painted edge to edge
            Color.clear
                .ignoresSafeArea()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard !isSettling else { return }
                    let translation = value.translation
                    guard abs(translation.width) > abs(translation.height) else { return }
                    // Nothing that way: the page gives a little, then springs back
                    let isBlocked = translation.width < 0 ? !hasNext : !hasPrevious
                    dragOffset = isBlocked ? translation.width / 3 : translation.width
                }
                .onEnded { value in
                    guard !isSettling else { return }
                    let translation = value.translation
                    // Pull down to close
                    if translation.height > 120, abs(translation.width) < 100 {
                        dismiss()
                        return
                    }
                    let flick = value.predictedEndTranslation.width
                    if hasNext, translation.width < -80 || (dragOffset < 0 && flick < -pageWidth / 2) {
                        move(by: 1)
                    } else if hasPrevious, translation.width > 80 || (dragOffset > 0 && flick > pageWidth / 2) {
                        move(by: -1)
                    } else {
                        withAnimation(.snappy(duration: 0.25)) { dragOffset = 0 }
                    }
                }
        )
        .statusBarHidden()
        .onAppear(perform: buildQueue)
        .accessibilityAction(.escape) { dismiss() }
    }

    private func isJokeOfTheDay(_ joke: Joke) -> Bool {
        if let id = joke.firestoreId, id == viewModel.jokeOfTheDay?.firestoreId { return true }
        return isJokeOfTheDay && joke.id == openedJoke.id
    }

    /// The list the joke came from, opened at that joke; otherwise the joke followed
    /// by the Home feed. Set once, so nothing reorders while the reader swipes.
    private func buildQueue() {
        guard queue.isEmpty else { return }
        var seen = Set<UUID>()
        let source = list.contains { $0.id == openedJoke.id } ? list : [openedJoke] + viewModel.homeFeedOrder
        queue = source.filter { seen.insert($0.id).inserted }
        index = queue.firstIndex { $0.id == openedJoke.id } ?? 0
    }

    /// Slides to the next (1) or previous (-1) joke
    private func move(by step: Int) {
        guard !isSettling, jokes.indices.contains(index + step) else { return }
        HapticManager.shared.lightTap()
        let land = {
            // Swap which joke is in the middle and put the pages back, in one step
            // with no animation, so nothing is seen to jump
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                index += step
                dragOffset = 0
            }
            isSettling = false
            viewModel.markJokeImpression(jokes[index])
        }
        guard !reduceMotion, pageWidth > 0 else {
            land()
            return
        }
        isSettling = true
        withAnimation(.snappy(duration: 0.3)) {
            dragOffset = -CGFloat(step) * pageWidth
        } completion: {
            land()
        }
    }
}

// MARK: - One Joke

/// A joke on the whole screen, in its teller's color, with nothing behind the words. It opens on the setup; a tap
/// anywhere pops the punchline in. Knock-knock jokes play out as a chat.
private struct JokeFullScreenPage: View {
    @ObservedObject var viewModel: JokeViewModel
    /// The joke as it was when opened. Ratings, saves and counts are read fresh
    /// from the view model on every render.
    let openedJoke: Joke
    let isJokeOfTheDay: Bool
    /// The system appearance, passed in because this view hides the status bar and
    /// paints its own colors
    let isDark: Bool
    /// Slides to the joke after this one; nil on the last
    let onNext: (() -> Void)?
    /// Slides back to the joke before this one; nil on the first
    let onPrevious: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isWideLayout) private var isWideLayout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Setup type size. Grows with the reader's text size, then steps down to fit.
    @ScaledMetric(relativeTo: .largeTitle) private var typeSize: CGFloat = 46

    @State private var reveal: JokeReveal = .setup
    @State private var showingStylePicker = false
    @State private var pickerSurface: JokeShareService.Surface = .moreMenu
    @State private var hintPulse = false

    private var joke: Joke {
        viewModel.joke(matching: openedJoke) ?? openedJoke
    }

    private var surface: JokeShareService.Surface { .fullScreen }

    private var palette: JokePalette { .palette(for: joke.teller) }

    /// Light: the character's color edge to edge. Dark: near black, with the
    /// character's color kept for the punchline.
    private var colors: JokeSurfaceColors {
        (isDark ? ShareCardStyle.dark : ShareCardStyle.bigFace).colors(for: palette)
    }

    private var isFullyRevealed: Bool {
        reveal == .all || !joke.hasPunchline
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                colors.background
                    .ignoresSafeArea()

                // A camera in a corner (iPhone Duo, closed) makes the safe area
                // narrower all the way down. Only the top buttons need to stay clear
                // of it; the joke and the actions use the whole width.
                let insets = geometry.safeAreaInsets
                let fullWidth = geometry.size.width + insets.leading + insets.trailing
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                        // No status bar or notch above the buttons to space them
                        .padding(.top, insets.top < 20 ? 24 : 8)
                        .padding(.leading, insets.leading)
                        .padding(.trailing, insets.trailing)
                    if isWideLayout {
                        // A wide window (iPhone Duo, open): the joke is one column in
                        // the middle of the screen, with the actions centered under it
                        let width = Self.wideColumnWidth(in: fullWidth)
                        VStack(alignment: .leading, spacing: 0) {
                            labels
                                .padding(.bottom, 18)
                            fittedJoke(width: width)
                        }
                        .frame(maxWidth: width, alignment: .leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        actionRow
                            .frame(maxWidth: .infinity)
                    } else {
                        labels
                            .padding(.top, 14)
                            .padding(.bottom, 18)
                        fittedJoke(width: fullWidth - 48)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        actionRow
                    }
                }
                .padding(.horizontal, isWideLayout ? 32 : 24)
                .ignoresSafeArea(.container, edges: .horizontal)
            }
            .contentShape(Rectangle())
            .onTapGesture { revealNext() }
        }
        .fullScreenCover(isPresented: $showingStylePicker) {
            ShareStylePickerView(joke: joke, surface: pickerSurface)
        }
        .onAppear {
            if !joke.hasPunchline { reveal = .all }
            viewModel.refreshCounts(for: joke)
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                hintPulse = true
            }
        }
        .accessibilityAction(named: "Show punchline") { revealNext() }
        .accessibilityAction(named: "Next joke") { onNext?() }
        .accessibilityAction(named: "Previous joke") { onPrevious?() }
    }

    // MARK: - Top

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                chromeIcon("xmark")
            }
            .accessibilityLabel("Close")

            Spacer()

            Menu {
                JokeMoreMenuItems(
                    joke: joke,
                    onCreateImage: {
                        pickerSurface = .moreMenu
                        showingStylePicker = true
                    },
                    onCopy: { viewModel.copyJoke(joke) },
                    onSave: { viewModel.saveJoke(joke) },
                    onNotFunny: { viewModel.rateJoke(joke, rating: joke.userRating == 1 ? 0 : 1) }
                )
            } label: {
                chromeIcon("ellipsis")
            }
            .accessibilityLabel("More")
        }
    }

    private func chromeIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.body.weight(.bold))
            .foregroundStyle(colors.text)
            .frame(width: 44, height: 44)
            .background(colors.text.opacity(0.12), in: Circle())
    }

    /// Who tells it: their picture, then the same lines as the Home card. The joke
    /// of the day says so, with the teller and date under it in the quieter color;
    /// any other joke just names its teller, in that quieter color.
    private var labels: some View {
        HStack(spacing: 10) {
            if let teller = joke.teller {
                Image(teller.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    // The picture's own background is the page's color; the ring sets it apart
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                if isJokeOfTheDay {
                    Text("Joke of the Day")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(colors.text)
                    Text([joke.teller?.name, JokeOfTheDayView.todayString].compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(colors.text.opacity(0.7))
                } else if let teller = joke.teller {
                    Text(teller.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.text.opacity(0.7))
                }
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Joke

    /// The joke at the largest type that fits; one too long for the screen scrolls
    private func fittedJoke(width: CGFloat) -> some View {
        // A long word caps the type, so it is never broken across lines
        let largest = JokeArtwork.largestSizeKeepingWordsWhole(for: joke, width: width, upTo: typeSize)
        let smallest = min(typeSize * 0.52, largest)
        return ViewThatFits(in: .vertical) {
            ForEach(LargestThatFits<JokeArtwork>.ladder(from: largest, downTo: smallest), id: \.self) { size in
                artwork(size: size)
            }
            ScrollView {
                artwork(size: smallest)
                    .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// Wide windows: lines of a readable length
    private static func wideColumnWidth(in width: CGFloat) -> CGFloat {
        min(width * 0.7, 700)
    }

    private func artwork(size: CGFloat) -> some View {
        JokeArtwork(
            joke: joke,
            colors: colors,
            size: size,
            reveal: joke.hasPunchline ? reveal : .all,
            showsAvatars: true,
            pillShadow: false
        )
        .overlay(alignment: .bottomLeading) {
            if !isFullyRevealed && reveal == .setup {
                tapHint
            }
        }
    }

    /// Sits where the punchline is about to appear
    private var tapHint: some View {
        Label("Tap for the punchline", systemImage: "hand.tap.fill")
            .font(.title3.weight(.bold))
            .foregroundStyle(colors.text)
            .opacity(reduceMotion ? 0.75 : (hintPulse ? 0.9 : 0.45))
            .transition(.opacity)
            .accessibilityHidden(true)
    }

    private func revealNext() {
        guard !isFullyRevealed else { return }
        let pop: Animation = reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.36, dampingFraction: 0.58)
        HapticManager.shared.mediumImpact()
        viewModel.markJokeViewed(joke)

        // A knock-knock answers the door first, then delivers
        let hasReplyStep = joke.category == .knockKnock && joke.punchlineLines.count > 1 && reveal == .setup
        if hasReplyStep {
            withAnimation(pop) { reveal = .reply }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.65))
                HapticManager.shared.mediumImpact()
                withAnimation(pop) { reveal = .all }
            }
        } else {
            withAnimation(pop) { reveal = .all }
        }
    }

    // MARK: - Laugh, Share, Image, Next

    private var actionRow: some View {
        let counts = viewModel.counts(for: joke)
        return HStack(spacing: 0) {
            LaughButton(
                isOn: joke.userRating == 5,
                label: JokeEngagement.compact(counts.laughs),
                tint: colors.text
            ) { isOn in
                viewModel.laugh(joke, isOn: isOn, surface: surface.rawValue)
            }

            Button {
                JokeShareService.shared.share(joke, from: surface)
            } label: {
                StackedActionLabel(
                    systemImage: "square.and.arrow.up",
                    label: JokeEngagement.compact(counts.shares),
                    tint: colors.text
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")

            Button {
                pickerSurface = .stylePicker
                showingStylePicker = true
            } label: {
                StackedActionLabel(systemImage: "photo", label: "Image", tint: colors.text)
            }
            .buttonStyle(.plain)

            // The visible way to the next joke; swiping left does the same
            if let onNext {
                Button(action: onNext) {
                    StackedActionLabel(systemImage: "arrow.right", label: "Next", tint: colors.text)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next joke")
            }
        }
        .padding(.bottom, isWideLayout ? 20 : 6)
        .frame(maxWidth: isWideLayout ? 520 : .infinity)
    }
}

// MARK: - Opening

/// A joke to show full screen
struct FullScreenJoke: Identifiable {
    let joke: Joke
    let isJokeOfTheDay: Bool
    /// The list it was opened from, to swipe through
    var list: [Joke] = []

    var id: UUID { joke.id }
}

/// Opens a joke full screen over whatever is showing. Set once in `MainContentView`.
struct OpenFullScreenJokeAction {
    let action: (Joke, Bool, [Joke]) -> Void

    /// `list` is the list the joke is in, which swiping then moves through
    func callAsFunction(_ joke: Joke, isJokeOfTheDay: Bool = false, list: [Joke] = []) {
        action(joke, isJokeOfTheDay, list)
    }
}

private struct OpenFullScreenJokeKey: EnvironmentKey {
    static let defaultValue: OpenFullScreenJokeAction? = nil
}

private struct JokePagingListKey: EnvironmentKey {
    static let defaultValue: [Joke] = []
}

extension EnvironmentValues {
    /// The jokes of the list on screen, in order. A joke opened full screen from one
    /// of its cards swipes through these.
    var jokePagingList: [Joke] {
        get { self[JokePagingListKey.self] }
        set { self[JokePagingListKey.self] = newValue }
    }

    var openFullScreenJoke: OpenFullScreenJokeAction? {
        get { self[OpenFullScreenJokeKey.self] }
        set { self[OpenFullScreenJokeKey.self] = newValue }
    }
}
