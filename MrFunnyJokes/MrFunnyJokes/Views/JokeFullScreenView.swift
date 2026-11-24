import SwiftUI

/// A joke on the whole screen, in its teller's color. It opens on the setup; a tap
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
    /// True when the joke is long enough to run over the portrait
    @State private var jokeCoversPortrait = false
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
            ZStack(alignment: .bottomTrailing) {
                colors.background
                    .ignoresSafeArea()

                portrait(in: geometry.size)

                // Keeps Laugh and Share readable where they cross the portrait
                LinearGradient(colors: [colors.background.opacity(0), colors.background.opacity(0.92)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

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

    private var labels: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isJokeOfTheDay {
                Text("Joke of the Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.text.opacity(0.75))
            }
            Text([joke.teller?.name, joke.typeLabel].compactMap { $0 }.joined(separator: " · "))
                .font(.headline.weight(.heavy))
                .foregroundStyle(colors.text)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Joke

    /// The joke at the largest type that fits. It first tries to stay clear of the
    /// portrait; a long joke runs over it (the portrait dims) and, past that, scrolls.
    private func jokeArea(in size: CGSize) -> some View {
        let clearance = isWideLayout ? 0 : portraitSide(in: size) * 0.6
        let clearSizes = LargestThatFits<JokeArtwork>.ladder(from: typeSize, downTo: typeSize * 0.7)
        let coveringSizes = LargestThatFits<JokeArtwork>.ladder(from: typeSize * 0.86, downTo: typeSize * 0.52)

        return ViewThatFits(in: .vertical) {
            ForEach(clearSizes, id: \.self) { size in
                artwork(size: size)
                    .padding(.bottom, clearance)
                    .preference(key: CoversPortraitKey.self, value: false)
            }
            ForEach(coveringSizes, id: \.self) { size in
                artwork(size: size)
                    .preference(key: CoversPortraitKey.self, value: !isWideLayout)
            }
            ScrollView {
                artwork(size: typeSize * 0.52)
                    .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .preference(key: CoversPortraitKey.self, value: !isWideLayout)
        }
        // Wide windows: the joke keeps to the left, the portrait to the right
        .frame(maxWidth: isWideLayout ? size.width * 0.56 : .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onPreferenceChange(CoversPortraitKey.self) { covers in
            jokeCoversPortrait = covers
        }
    }

    private func artwork(size: CGFloat) -> some View {
        JokeArtwork(
            joke: joke,
            colors: colors,
            size: size,
            reveal: joke.hasPunchline ? reveal : .all,
            showsAvatars: true,
            pillShadow: true
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
            .font(.subheadline.weight(.bold))
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

    // MARK: - Portrait

    private func portraitSide(in size: CGSize) -> CGFloat {
        isWideLayout
            ? min(size.height * 0.92, size.width * 0.44)
            : min(size.width * 0.95, size.height * 0.46, 430)
    }

    @ViewBuilder
    private func portrait(in size: CGSize) -> some View {
        if let teller = joke.teller {
            let side = portraitSide(in: size)
            Image(teller.imageName)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: side, height: side)
                .mask { portraitMask }
                .opacity(jokeCoversPortrait ? 0.16 : 1)
                .offset(x: side * 0.08, y: side * 0.04)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: jokeCoversPortrait)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The portrait is a square photo on the character's color. On the color it only
    /// needs its top and left edges faded; on near black it becomes a soft spotlight.
    @ViewBuilder
    private var portraitMask: some View {
        if isDark {
            RadialGradient(
                stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                center: .center, startRadius: 0, endRadius: 230
            )
        } else {
            PortraitEdgeFade()
        }
    }

    // MARK: - Laugh, Share, Styles

    private var actionRow: some View {
        let counts = viewModel.counts(for: joke)
        return HStack(spacing: 0) {
            LaughButton(
                isOn: joke.userRating == 5,
                label: JokeEngagement.laughLabel(counts.laughs),
                tint: colors.text
            ) { isOn in
                viewModel.laugh(joke, isOn: isOn, surface: surface.rawValue)
            }

            Button {
                JokeShareService.shared.share(joke, from: surface)
            } label: {
                StackedActionLabel(
                    systemImage: "square.and.arrow.up",
                    label: JokeEngagement.shareLabel(counts.shares),
                    tint: colors.text
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")

            Button {
                pickerSurface = .stylePicker
                showingStylePicker = true
            } label: {
                StackedActionLabel(systemImage: "square.on.square", label: "Styles", tint: colors.text)
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

private struct CoversPortraitKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
