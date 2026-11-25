import SwiftUI

/// A joke on the whole screen, in its teller's color, with nothing behind the words. It opens on the setup; a tap
/// anywhere pops the punchline in. Knock-knock jokes play out as a chat.
///
/// Opened from the Joke of the Day card, the widget, the daily notification and
/// shared links (`mrfunnyjokes.app/j/<id>`).
struct JokeFullScreenView: View {
    @ObservedObject var viewModel: JokeViewModel
    /// The joke as it was when opened. Ratings, saves and counts are read fresh
    /// from the view model on every render.
    let openedJoke: Joke
    let isJokeOfTheDay: Bool
    /// The system appearance, passed in because this view hides the status bar and
    /// paints its own colors
    let isDark: Bool

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

                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    labels
                        .padding(.top, 14)
                        .padding(.bottom, 18)
                    jokeArea(in: geometry.size)
                    actionRow
                }
                .padding(.horizontal, 24)
            }
            .contentShape(Rectangle())
            .onTapGesture { revealNext() }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        // Pull down to close
                        if value.translation.height > 120, abs(value.translation.width) < 100 {
                            dismiss()
                        }
                    }
            )
        }
        .statusBarHidden()
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
        .accessibilityAction(.escape) { dismiss() }
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
        .padding(.top, 8)
    }

    private func chromeIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.body.weight(.bold))
            .foregroundStyle(colors.text)
            .frame(width: 44, height: 44)
            .background(colors.text.opacity(0.12), in: Circle())
    }

    /// The same two lines as the Home card: what this is, then who and when.
    /// Any other joke just names its teller.
    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            if isJokeOfTheDay {
                Text("Joke of the Day")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(colors.text)
                Text([joke.teller?.name, JokeOfTheDayView.todayString].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(colors.text.opacity(0.65))
            } else if let teller = joke.teller {
                Text(teller.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(colors.text)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Joke

    /// The joke at the largest type that fits; one too long for the screen scrolls
    private func jokeArea(in size: CGSize) -> some View {
        // Wide windows: keep lines a readable length
        let width = isWideLayout ? size.width * 0.7 : size.width - 48
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
        .frame(maxWidth: isWideLayout ? width : .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    // MARK: - Laugh, Share, Image

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
        }
        .padding(.bottom, 6)
        .frame(maxWidth: isWideLayout ? 420 : .infinity)
    }
}

// MARK: - Opening

/// A joke to show full screen
struct FullScreenJoke: Identifiable {
    let joke: Joke
    let isJokeOfTheDay: Bool

    var id: UUID { joke.id }
}

/// Opens a joke full screen over whatever is showing. Set once in `MainContentView`.
struct OpenFullScreenJokeAction {
    let action: (Joke, Bool) -> Void

    func callAsFunction(_ joke: Joke, isJokeOfTheDay: Bool = false) {
        action(joke, isJokeOfTheDay)
    }
}

private struct OpenFullScreenJokeKey: EnvironmentKey {
    static let defaultValue: OpenFullScreenJokeAction? = nil
}

extension EnvironmentValues {
    var openFullScreenJoke: OpenFullScreenJokeAction? {
        get { self[OpenFullScreenJokeKey.self] }
        set { self[OpenFullScreenJokeKey.self] = newValue }
    }
}
