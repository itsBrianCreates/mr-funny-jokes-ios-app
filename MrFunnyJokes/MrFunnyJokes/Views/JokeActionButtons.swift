import SwiftUI

// MARK: - Laugh Button

/// Laugh is the Hilarious rating: an outline face until tapped, then a filled one with a burst
/// of laughing faces floating up. Tapping again takes the laugh back.
struct LaughButton: View {
    let isOn: Bool
    /// The laugh count
    let label: String
    var tint: Color = .primary
    /// Icon and count side by side, for the bottom row of a card
    var isInline = false
    /// Called with the new state
    let onToggle: (_ isOn: Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burstCount = 0
    @State private var bounce = false

    var body: some View {
        Button {
            let turningOn = !isOn
            onToggle(turningOn)
            guard turningOn else { return }
            HapticManager.shared.success()
            guard !reduceMotion else { return }
            burstCount += 1
            bounce = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
                bounce = false
            }
        } label: {
            let iconHeight = StackedActionLabel.iconHeight(isInline: isInline)
            let layout = StackedActionLabel.layout(isInline: isInline)
            layout {
                ZStack {
                    // Both states are drawn at the same size, so nothing shrinks on a vote
                    if isOn {
                        FaceIcon(mood: .smile, isFilled: true)
                            .frame(width: iconHeight, height: iconHeight)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    } else {
                        FaceIcon(mood: .smile)
                            .frame(width: iconHeight, height: iconHeight)
                            .transition(.opacity)
                    }
                }
                // Inline, lit and unlit take the same space, so the count doesn't shift
                .frame(width: isInline ? iconHeight : nil, height: isInline ? iconHeight : 28)
                .scaleEffect(bounce ? 1.45 : 1)
                .background {
                    LaughBurst(trigger: burstCount)
                }

                Text(label)
                    .font(StackedActionLabel.countFont(isInline: isInline).weight(isOn ? .bold : .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    // On a card the count takes the face's color once it's lit
                    .foregroundStyle(isOn && isInline ? FaceIcon.laughTint : tint)
            }
            .foregroundStyle(tint)
            .actionHitArea(isInline: isInline)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: isOn)
        .animation(.default, value: label)
        .accessibilityLabel("Laugh")
        .accessibilityValue(isOn ? "On, \(label) laughs" : "\(label) laughs")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Five to seven laughing faces that float up from the button, drift, shrink and fade
struct LaughBurst: View {
    let trigger: Int

    private struct Particle: Identifiable {
        let id = UUID()
        let drift: CGFloat
        let rise: CGFloat
        let size: CGFloat
        let delay: Double
        let spin: Double
    }

    @State private var particles: [Particle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                FloatingFace(particle: particle)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            let fresh = (0..<Int.random(in: 5...7)).map { _ in
                Particle(
                    drift: .random(in: -34...34),
                    rise: .random(in: 60...90),
                    size: .random(in: 15...24),
                    delay: .random(in: 0...0.18),
                    spin: .random(in: -25...25)
                )
            }
            particles.append(contentsOf: fresh)
            let ids = Set(fresh.map(\.id))
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.4))
                particles.removeAll { ids.contains($0.id) }
            }
        }
    }

    private struct FloatingFace: View {
        let particle: Particle
        @State private var isFloating = false

        var body: some View {
            FaceIcon(mood: .smile, isFilled: true)
                .frame(width: particle.size, height: particle.size)
                .scaleEffect(isFloating ? 0.5 : 1)
                .rotationEffect(.degrees(isFloating ? particle.spin : 0))
                .offset(x: isFloating ? particle.drift : 0, y: isFloating ? -particle.rise : 0)
                .opacity(isFloating ? 0 : 1)
                .onAppear {
                    withAnimation(.easeOut(duration: 1).delay(particle.delay)) {
                        isFloating = true
                    }
                }
        }
    }
}

// MARK: - Horrible Button

/// The Horrible rating on a feed card: an outline frown until tapped, then a red
/// frowning face that wobbles into place. Tapping again takes the vote back.
struct HorribleButton: View {
    let isOn: Bool
    /// The Horrible count
    let label: String
    var tint: Color = .primary
    let onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wobble = false

    var body: some View {
        Button {
            let turningOn = !isOn
            onToggle()
            guard turningOn, !reduceMotion else { return }
            wobble = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.3)) {
                wobble = false
            }
        } label: {
            let iconHeight = StackedActionLabel.iconHeight(isInline: true)
            HStack(spacing: 5) {
                ZStack {
                    if isOn {
                        FaceIcon(mood: .frown, isFilled: true)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    } else {
                        FaceIcon(mood: .frown)
                            .transition(.opacity)
                    }
                }
                .frame(width: iconHeight, height: iconHeight)
                .scaleEffect(wobble ? 1.35 : 1)
                .rotationEffect(.degrees(wobble ? -20 : 0))

                Text(label)
                    .font(StackedActionLabel.countFont(isInline: true).weight(isOn ? .bold : .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(isOn ? FaceIcon.horribleTint : tint)
            }
            .foregroundStyle(tint)
            .actionHitArea(isInline: true)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: isOn)
        .animation(.default, value: label)
        .accessibilityLabel("Horrible")
        .accessibilityValue(isOn ? "On, \(label) votes" : "\(label) votes")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Face Icon

/// The Laugh and Horrible faces, drawn here so the unlit outline and the lit, filled
/// face are the same size and shape, and used everywhere the app shows the two votes.
/// Unlit is an outline in the current foreground style. Lit, Laugh is a yellow face
/// laughing with its eyes shut and Horrible a red frowning one. No tears: they turn
/// to specks at card size. (The `face.smiling` symbol turns solid in dark mode and
/// has no frowning partner; emoji draw smaller than a symbol of the same size.)
struct FaceIcon: View {
    enum Mood {
        case smile, frown
    }

    let mood: Mood
    var isFilled = false

    /// The lit faces' colors, for the count beside them
    static let laughTint = Color(light: Color(red: 0.76, green: 0.50, blue: 0.0),
                                 dark: Color(red: 1.0, green: 0.80, blue: 0.20))
    static let horribleTint = Color(light: Color(red: 0.83, green: 0.16, blue: 0.14),
                                    dark: Color(red: 1.0, green: 0.42, blue: 0.38))

    /// The lit face for a ranking list
    init(_ type: RankingType) {
        self.init(mood: type == .hilarious ? .smile : .frown, isFilled: true)
    }

    init(mood: Mood, isFilled: Bool = false) {
        self.mood = mood
        self.isFilled = isFilled
    }

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: origin.x + x * side, y: origin.y + y * side)
            }
            func oval(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> Path {
                let center = point(x, y)
                return Path(ellipseIn: CGRect(x: center.x - width * side / 2, y: center.y - height * side / 2,
                                              width: width * side, height: height * side))
            }
            func curve(_ from: (CGFloat, CGFloat), _ control: (CGFloat, CGFloat), _ to: (CGFloat, CGFloat)) -> Path {
                var path = Path()
                path.move(to: point(from.0, from.1))
                path.addQuadCurve(to: point(to.0, to.1), control: point(control.0, control.1))
                return path
            }
            func round(_ width: CGFloat) -> StrokeStyle {
                StrokeStyle(lineWidth: width * side, lineCap: .round, lineJoin: .round)
            }
            let face = CGRect(origin: origin, size: CGSize(width: side, height: side))

            guard isFilled else {
                let line = side * 0.085
                context.stroke(Path(ellipseIn: face.insetBy(dx: line / 2, dy: line / 2)),
                               with: .foreground, lineWidth: line)
                context.fill(oval(0.355, 0.41, 0.095, 0.135), with: .foreground)
                context.fill(oval(0.645, 0.41, 0.095, 0.135), with: .foreground)
                let mouth = mood == .smile
                    ? curve((0.30, 0.59), (0.50, 0.87), (0.70, 0.59))
                    : curve((0.32, 0.72), (0.50, 0.50), (0.68, 0.72))
                context.stroke(mouth, with: .foreground, style: round(0.085))
                return
            }

            func fillFace(top: Color, bottom: Color, edge: Color) {
                let edgeWidth = side * 0.05
                let circle = Path(ellipseIn: face.insetBy(dx: edgeWidth / 2, dy: edgeWidth / 2))
                context.fill(circle, with: .linearGradient(
                    Gradient(colors: [top, bottom]),
                    startPoint: point(0.5, 0), endPoint: point(0.5, 1)
                ))
                context.stroke(circle, with: .color(edge), lineWidth: edgeWidth)
            }

            switch mood {
            case .smile:
                let ink = Color(red: 0.33, green: 0.17, blue: 0.04)
                fillFace(top: Color(red: 1.0, green: 0.89, blue: 0.33),
                         bottom: Color(red: 1.0, green: 0.70, blue: 0.05),
                         edge: Color(red: 0.80, green: 0.50, blue: 0.0))

                // Eyes squeezed shut
                context.stroke(curve((0.25, 0.45), (0.345, 0.30), (0.44, 0.45)), with: .color(ink), style: round(0.075))
                context.stroke(curve((0.56, 0.45), (0.655, 0.30), (0.75, 0.45)), with: .color(ink), style: round(0.075))

                // Wide open mouth: teeth along the top, tongue at the bottom
                var mouth = curve((0.25, 0.56), (0.50, 1.02), (0.75, 0.56))
                mouth.closeSubpath()
                context.fill(mouth, with: .color(ink))
                context.drawLayer { layer in
                    layer.clip(to: mouth)
                    layer.fill(oval(0.50, 0.84, 0.34, 0.20), with: .color(Color(red: 1.0, green: 0.42, blue: 0.42)))
                    layer.fill(Path(CGRect(origin: point(0.2, 0.56), size: CGSize(width: side * 0.6, height: side * 0.075))),
                               with: .color(.white))
                }

            case .frown:
                let ink = Color(red: 0.30, green: 0.03, blue: 0.03)
                fillFace(top: Color(red: 1.0, green: 0.50, blue: 0.44),
                         bottom: Color(red: 0.91, green: 0.24, blue: 0.21),
                         edge: Color(red: 0.70, green: 0.12, blue: 0.11))

                // Worried brows, and the outline's eyes and frown
                context.stroke(curve((0.22, 0.34), (0.33, 0.26), (0.43, 0.25)), with: .color(ink), style: round(0.06))
                context.stroke(curve((0.78, 0.34), (0.67, 0.26), (0.57, 0.25)), with: .color(ink), style: round(0.06))
                context.fill(oval(0.345, 0.46, 0.105, 0.14), with: .color(ink))
                context.fill(oval(0.655, 0.46, 0.105, 0.14), with: .color(ink))
                context.stroke(curve((0.31, 0.75), (0.50, 0.55), (0.69, 0.75)), with: .color(ink), style: round(0.085))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Stacked Action Button

/// An icon with a small label under it, for the Laugh / Share / More row.
/// Inline, the label sits beside a slightly smaller icon and an empty label is left out.
struct StackedActionLabel: View {
    let systemImage: String
    let label: String
    var tint: Color = .primary
    var isInline = false

    /// Height every icon in the row is drawn at, the laughing face included
    static let iconHeight: CGFloat = 23

    /// Inline, a face is as tall as the teller's picture at the other end of the row
    static func iconHeight(isInline: Bool) -> CGFloat {
        isInline ? JokeCardMetrics.rowIconSize : iconHeight
    }

    static func countFont(isInline: Bool) -> Font {
        isInline ? JokeCardMetrics.rowFont : .caption
    }

    static func layout(isInline: Bool) -> AnyLayout {
        isInline ? AnyLayout(HStackLayout(spacing: 5)) : AnyLayout(VStackLayout(spacing: 4))
    }

    var body: some View {
        let iconHeight = Self.iconHeight(isInline: isInline)
        let layout = Self.layout(isInline: isInline)
        layout {
            // Sized by height, not point size: the share arrow is a tall glyph and
            // drew larger than the face beside it at the same point size
            // Inline, a glyph is drawn a little shorter than the round faces and
            // pictures beside it, which is what makes them look the same size
            let glyphHeight = isInline ? iconHeight - 3 : iconHeight
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .fontWeight(.medium)
                .frame(width: glyphHeight - 2, height: glyphHeight)
                .frame(height: isInline ? iconHeight : 28)
            if !(isInline && label.isEmpty) {
                Text(label)
                    .font(Self.countFont(isInline: isInline).weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .foregroundStyle(tint)
        .actionHitArea(isInline: isInline)
    }
}

private extension View {
    /// Stacked buttons share the row's width; inline ones are as wide as their content,
    /// never smaller than 44 by 44
    @ViewBuilder
    func actionHitArea(isInline: Bool) -> some View {
        if isInline {
            self
                .padding(.horizontal, 9)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        } else {
            self
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Card Row

/// Sizes shared by both ends of a card's bottom row, so the teller's picture, the
/// faces and the text beside them match
enum JokeCardMetrics {
    /// The teller's picture and the Laugh and Horrible faces
    static let rowIconSize: CGFloat = 20
    /// The teller's name, and the icons and counts until they're lit: grey, so the
    /// joke and the teller's picture are what the eye lands on
    static let quietColor = Color.primary.opacity(0.6)
    /// The teller's name and the counts (the counts add weight)
    static let rowFont: Font = .footnote
}

/// Laugh and Horrible with their counts, at the trailing end of a feed card's bottom
/// row. Sharing, copying and saving are in the joke sheet and under press and hold.
struct InlineVoteCounts: View {
    let joke: Joke
    let counts: JokeCounts
    /// Called with the new Laugh state
    let onLaugh: (Bool) -> Void
    /// Toggles the Horrible rating
    let onHorrible: () -> Void

    var body: some View {
        // Feed counts come from the catalog copy, which can be up to a week behind
        // and may not include the reader's own vote yet. A lit face never shows 0.
        let laughed = joke.userRating == 5
        let votedHorrible = joke.userRating == 1
        HStack(spacing: 0) {
            LaughButton(
                isOn: laughed,
                label: JokeEngagement.compact(max(counts.laughs, laughed ? 1 : 0)),
                tint: JokeCardMetrics.quietColor,
                isInline: true,
                onToggle: onLaugh
            )
            HorribleButton(
                isOn: votedHorrible,
                label: JokeEngagement.compact(max(counts.horribles, votedHorrible ? 1 : 0)),
                tint: JokeCardMetrics.quietColor,
                onToggle: onHorrible
            )
        }
    }
}

/// Laugh, Share and More on one line, at the trailing end of the Joke of the Day's
/// bottom row.
struct InlineJokeActions: View {
    let joke: Joke
    let counts: JokeCounts
    /// Called with the new Laugh state
    let onLaugh: (Bool) -> Void
    let onShare: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void
    /// The Horrible rating, under More
    let onNotFunny: () -> Void

    @State private var showingStylePicker = false

    var body: some View {
        HStack(spacing: 0) {
            LaughButton(
                isOn: joke.userRating == 5,
                label: JokeEngagement.compact(counts.laughs),
                tint: JokeCardMetrics.quietColor,
                isInline: true,
                onToggle: onLaugh
            )

            Button(action: onShare) {
                StackedActionLabel(
                    systemImage: "square.and.arrow.up",
                    label: JokeEngagement.compact(counts.shares),
                    tint: JokeCardMetrics.quietColor,
                    isInline: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")
            .accessibilityValue("\(counts.shares) shares")

            Menu {
                JokeMoreMenuItems(
                    joke: joke,
                    onCreateImage: { showingStylePicker = true },
                    onCopy: onCopy,
                    onSave: onSave,
                    onNotFunny: onNotFunny
                )
            } label: {
                StackedActionLabel(systemImage: "ellipsis", label: "", tint: JokeCardMetrics.quietColor, isInline: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More")
        }
        .fullScreenCover(isPresented: $showingStylePicker) {
            ShareStylePickerView(joke: joke)
        }
    }
}

// MARK: - More Menu

/// The items under More, shared by the Home card and the full screen view
struct JokeMoreMenuItems: View {
    let joke: Joke
    let onCreateImage: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void
    let onNotFunny: () -> Void

    var body: some View {
        Button(action: onCreateImage) {
            Label("Create image", systemImage: "photo.on.rectangle.angled")
        }
        Button(action: onCopy) {
            Label("Copy joke", systemImage: "doc.on.doc")
        }
        Button(action: onSave) {
            Label(joke.isSaved ? "Saved" : "Save", systemImage: joke.isSaved ? "bookmark.fill" : "bookmark")
        }
        Divider()
        // The Horrible rating. Tapping it again takes it back.
        Button(action: onNotFunny) {
            Label(joke.userRating == 1 ? "Marked not funny" : "Not funny",
                  systemImage: joke.userRating == 1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
        }
    }
}

// MARK: - Card Menu

/// Press and hold a joke card: share its image, pick a style, open it full screen,
/// copy or save, without opening the joke sheet first.
private struct JokeCardMenu: ViewModifier {
    let joke: Joke
    let onCopy: () -> Void
    let onSave: () -> Void

    @Environment(\.openFullScreenJoke) private var openFullScreenJoke
    @Environment(\.jokePagingList) private var pagingList
    @State private var showingStylePicker = false

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    JokeShareService.shared.share(joke, from: .cardMenu)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button {
                    showingStylePicker = true
                } label: {
                    Label("Image", systemImage: "photo")
                }
                if let openFullScreenJoke {
                    Button {
                        openFullScreenJoke(joke, list: pagingList)
                    } label: {
                        Label("Open full screen", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                }
                Divider()
                Button(action: onCopy) {
                    Label("Copy joke", systemImage: "doc.on.doc")
                }
                Button(action: onSave) {
                    Label(joke.isSaved ? "Saved" : "Save", systemImage: joke.isSaved ? "bookmark.fill" : "bookmark")
                }
            }
            .fullScreenCover(isPresented: $showingStylePicker) {
                ShareStylePickerView(joke: joke, surface: .cardMenu)
            }
    }
}

extension View {
    func jokeCardMenu(joke: Joke, onCopy: @escaping () -> Void, onSave: @escaping () -> Void) -> some View {
        modifier(JokeCardMenu(joke: joke, onCopy: onCopy, onSave: onSave))
    }
}

#Preview {
    struct Demo: View {
        @State private var isOn = false
        var body: some View {
            HStack {
                LaughButton(isOn: isOn, label: isOn ? "1" : "0") { isOn = $0 }
                StackedActionLabel(systemImage: "square.and.arrow.up", label: "0")
                StackedActionLabel(systemImage: "ellipsis", label: "More")
            }
            .padding(.top, 120)
            .padding()
        }
    }
    return Demo()
}
