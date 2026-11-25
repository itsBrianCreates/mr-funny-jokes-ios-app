import SwiftUI

/// How much of a joke is showing
enum JokeReveal: Int, Comparable {
    /// The setup only
    case setup
    /// Knock-knock only: the "… who?" reply is in, the punchline is not
    case reply
    /// The whole joke
    case all

    static func < (lhs: JokeReveal, rhs: JokeReveal) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Joke Artwork

/// The joke itself in big rounded type: setup, then the punchline in a tilted pill.
/// Knock-knock jokes become a chat, picked from the joke's type. Used by the full
/// screen view and by share cards, so a shared image looks like what was on screen.
///
/// Every measurement hangs off `size` (the setup's point size), so the same layout
/// works at any scale. Parts not yet revealed still take up their space: nothing
/// moves when the punchline pops in.
struct JokeArtwork: View {
    let joke: Joke
    let colors: JokeSurfaceColors
    /// Point size of the setup text
    let size: CGFloat
    var reveal: JokeReveal = .all
    /// Shows the teller's picture beside their bubbles in a knock-knock
    var showsAvatars = false
    /// A soft shadow under the pill, for layouts over a photo
    var pillShadow = false

    var body: some View {
        if joke.category == .knockKnock {
            chat
        } else {
            standard
        }
    }

    // MARK: Setup and punchline

    private var standard: some View {
        VStack(alignment: .leading, spacing: size * 0.36) {
            // A setup that stops mid-sentence trails off until the punchline finishes it
            Text(reveal == .all ? joke.setup : joke.cardText)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(colors.text)
                .lineSpacing(size * 0.02)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            if joke.hasPunchline {
                pill(joke.punchlineLines.joined(separator: "\n"), fontSize: size * 0.74)
                    .revealed(reveal == .all)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A short punchline sits at a jaunty angle; a paragraph reads better straight
    private func tilt(for text: String) -> Angle {
        switch text.count {
        case ...44: return .degrees(-2)
        case ...90: return .degrees(-1)
        default: return .zero
        }
    }

    private func pill(_ text: String, fontSize: CGFloat) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(colors.pillText)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, fontSize * 0.62)
            .padding(.vertical, fontSize * 0.42)
            .background(colors.pill, in: RoundedRectangle(cornerRadius: fontSize * 0.7, style: .continuous))
            .shadow(color: .black.opacity(pillShadow ? 0.14 : 0), radius: fontSize * 0.4, y: fontSize * 0.2)
            .rotationEffect(tilt(for: text), anchor: .leading)
    }

    // MARK: Knock-knock chat

    private struct ChatLine: Identifiable {
        let id: Int
        let text: String
        /// The person at the door answering ("Who's there?", "Lettuce who?")
        let isReply: Bool
        let isPunchline: Bool
        let showsAt: JokeReveal
    }

    private var chatLines: [ChatLine] {
        let setup = joke.setupLines
        let punchline = joke.punchlineLines
        var lines: [ChatLine] = []

        for text in setup {
            lines.append(ChatLine(id: lines.count, text: text, isReply: Self.isReply(text), isPunchline: false, showsAt: .setup))
        }
        for (index, text) in punchline.enumerated() {
            // "Lettuce who?" comes first, then the answer
            let isWho = index == 0 && punchline.count > 1 && Self.isReply(text)
            lines.append(ChatLine(
                id: lines.count,
                text: text,
                isReply: isWho,
                isPunchline: !isWho && index == punchline.count - 1,
                showsAt: isWho ? .reply : .all
            ))
        }
        return lines
    }

    private static func isReply(_ text: String) -> Bool {
        let lowered = text.lowercased().replacingOccurrences(of: "’", with: "'")
        return lowered.hasPrefix("who's there") || lowered.hasSuffix("who?")
    }

    private var chat: some View {
        let bubbleSize = size * 0.64
        return VStack(alignment: .leading, spacing: bubbleSize * 0.42) {
            ForEach(chatLines) { line in
                HStack(alignment: .bottom, spacing: bubbleSize * 0.3) {
                    if line.isReply {
                        Spacer(minLength: bubbleSize * 1.6)
                        bubble(line, fontSize: bubbleSize)
                    } else {
                        if showsAvatars { avatar(diameter: bubbleSize * 1.5) }
                        bubble(line, fontSize: line.isPunchline ? bubbleSize * 1.12 : bubbleSize)
                        Spacer(minLength: bubbleSize * (line.isPunchline ? 0.4 : 1.6))
                    }
                }
                .revealed(reveal >= line.showsAt)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bubble(_ line: ChatLine, fontSize: CGFloat) -> some View {
        let radius = fontSize * 0.95
        let tail = fontSize * 0.28
        return Text(line.text)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(line.isReply ? colors.replyText : colors.pillText)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, fontSize * 0.7)
            .padding(.vertical, fontSize * 0.46)
            .background(
                line.isReply ? colors.reply : colors.pill,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: line.isReply ? radius : tail,
                    bottomTrailingRadius: line.isReply ? tail : radius,
                    topTrailingRadius: radius,
                    style: .continuous
                )
            )
            .shadow(color: .black.opacity(pillShadow && line.isPunchline ? 0.14 : 0), radius: fontSize * 0.4, y: fontSize * 0.2)
            .rotationEffect(line.isPunchline ? tilt(for: line.text) : .zero, anchor: .leading)
    }

    @ViewBuilder
    private func avatar(diameter: CGFloat) -> some View {
        if let teller = joke.teller {
            Image(teller.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: max(diameter * 0.05, 1.5)))
                .accessibilityHidden(true)
        }
    }
}

/// Keeps the view's space while hidden, so revealing it moves nothing else.
/// It pops in from half size, or just fades in with Reduce Motion on.
private struct Revealed: ViewModifier {
    let isRevealed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isRevealed || reduceMotion ? 1 : 0.5, anchor: .leading)
            .opacity(isRevealed ? 1 : 0)
            .accessibilityHidden(!isRevealed)
    }
}

private extension View {
    func revealed(_ isRevealed: Bool) -> some View {
        modifier(Revealed(isRevealed: isRevealed))
    }
}

// MARK: - Portrait Fade

/// A mask for a character portrait sitting in a lower right corner. The portraits are
/// square photos on the character's color; fading the top and left edges lets one sit
/// on that color with no visible edge.
struct PortraitEdgeFade: View {
    var body: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.22)],
                       startPoint: .leading, endPoint: .trailing)
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.16)],
                               startPoint: .top, endPoint: .bottom)
            }
    }
}

// MARK: - Word Fit

extension JokeArtwork {
    /// The largest setup size, up to `limit`, at which every word of the joke fits on
    /// one line of `width`. Text breaks a word that is wider than its line, which
    /// leaves a stray "?" on a line by itself ("mathematician" / "?").
    static func largestSizeKeepingWordsWhole(for joke: Joke, width: CGFloat, upTo limit: CGFloat) -> CGFloat {
        // Knock-knock bubbles are set small enough that this doesn't come up
        guard joke.category != .knockKnock, width > 0 else { return limit }

        // Measured once at a reference size; width grows in step with point size
        let reference: CGFloat = 100
        let base = UIFont.systemFont(ofSize: reference, weight: .heavy)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: reference) } ?? base
        func widestWord(in text: String) -> CGFloat {
            text.split(whereSeparator: \.isWhitespace)
                .map { (String($0) as NSString).size(withAttributes: [.font: font]).width }
                .max() ?? 0
        }

        // Width each part needs per point of setup size. The pill's type is 0.74 of
        // the setup's, with 0.62 of its own size as padding on each side.
        let setupNeed = widestWord(in: joke.setup + " " + joke.cardText) / reference
        let pillNeed = joke.hasPunchline
            ? (widestWord(in: joke.punchlineLines.joined(separator: " ")) / reference + 2 * 0.62) * 0.74
            : 0
        let need = max(setupNeed, pillNeed) * 1.03
        guard need > 0 else { return limit }
        return min(limit, (width / need).rounded(.down))
    }
}

// MARK: - Fitting

/// Draws `content` at the largest of `sizes` that fits the height on offer.
/// A two-word joke gets poster type; a paragraph steps down until it fits.
/// When nothing fits, the last (smallest) size is used.
struct LargestThatFits<Content: View>: View {
    let sizes: [CGFloat]
    @ViewBuilder let content: (CGFloat) -> Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes, id: \.self) { size in
                content(size)
            }
        }
    }
}

extension LargestThatFits {
    /// Sizes from `base` down to `smallest`, each about 12% smaller than the last
    static func ladder(from base: CGFloat, downTo smallest: CGFloat) -> [CGFloat] {
        var sizes: [CGFloat] = []
        var size = base
        // Rounded sizes can land on the same number; ViewThatFits traps on a repeated ID
        while size.rounded() > smallest.rounded() {
            if sizes.last != size.rounded() { sizes.append(size.rounded()) }
            size *= 0.88
        }
        sizes.append(smallest.rounded())
        return sizes
    }
}
