import SwiftUI

// MARK: - Style and Format

enum ShareCardStyle: String, CaseIterable, Identifiable {
    case bold
    case light
    case dark
    case bigFace = "big_face"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bold: return "Bold"
        case .light: return "Light"
        case .dark: return "Dark"
        case .bigFace: return "Big face"
        }
    }

    func colors(for palette: JokePalette) -> JokeSurfaceColors {
        switch self {
        case .bold, .bigFace:
            return JokeSurfaceColors(
                background: self == .bigFace ? palette.portraitBackground : palette.color,
                text: palette.onColor,
                pill: palette.pillOnColor,
                pillText: palette.onPillOnColor,
                reply: palette.deep,
                replyText: .white
            )
        case .light:
            return JokeSurfaceColors(
                background: .white,
                border: palette.color,
                text: palette.inkOnLight,
                pill: palette.color,
                pillText: palette.onColor,
                reply: Color(hex: 0xEFECE6),
                replyText: Color(hex: 0x1F1E1D)
            )
        case .dark:
            return JokeSurfaceColors(
                background: palette.darkBackground,
                text: .white,
                pill: palette.pillOnDark,
                pillText: palette.onPillOnDark,
                reply: Color(hex: 0x34302C),
                replyText: .white
            )
        }
    }
}

enum ShareCardFormat: String, CaseIterable, Identifiable {
    case square
    case story

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: return "Square"
        case .story: return "Story"
        }
    }

    /// Export size in pixels. The card is laid out in these units too.
    var size: CGSize {
        switch self {
        case .square: return CGSize(width: 1080, height: 1080)
        case .story: return CGSize(width: 1080, height: 1920)
        }
    }
}

/// The style and format used last time, so Share on a card goes straight to the share sheet
enum ShareCardPreferences {
    private static let styleKey = "shareCardStyle"
    private static let formatKey = "shareCardFormat"

    static var style: ShareCardStyle {
        get { UserDefaults.standard.string(forKey: styleKey).flatMap(ShareCardStyle.init) ?? .bold }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: styleKey) }
    }

    static var format: ShareCardFormat {
        get { UserDefaults.standard.string(forKey: formatKey).flatMap(ShareCardFormat.init) ?? .square }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: formatKey) }
    }
}

// MARK: - Share Card

/// The image that goes out when a joke is shared. Laid out at export size
/// (1080 wide); `ShareCardPreview` scales it down for the screen.
///
/// The whole joke is always on the card. The type steps down until it fits, so a
/// one-liner fills the card and a long joke or a knock-knock still fits on it.
struct JokeShareCardView: View {
    let joke: Joke
    let style: ShareCardStyle
    let format: ShareCardFormat

    static let siteName = "mrfunnyjokes.app"

    private var palette: JokePalette { .palette(for: joke.teller) }
    private var colors: JokeSurfaceColors { style.colors(for: palette) }
    private var size: CGSize { format.size }

    /// Stories keep clear of the app chrome Instagram and others draw at the top and bottom
    private var insets: EdgeInsets {
        switch format {
        case .square: return EdgeInsets(top: 84, leading: 84, bottom: 76, trailing: 84)
        case .story: return EdgeInsets(top: 270, leading: 84, bottom: 300, trailing: 84)
        }
    }

    private var portraitSide: CGFloat {
        format == .square ? 680 : 1000
    }

    /// Type sizes to try, largest first. A short joke starts at poster size so it
    /// fills the card; longer ones start smaller so they don't crowd the footer.
    private var typeSizes: [CGFloat] {
        let length = joke.setup.count + joke.punchline.count
        var base: CGFloat
        switch length {
        case ..<45: base = 122
        case ..<90: base = 102
        default: base = 88
        }
        if joke.category == .knockKnock { base = 96 }
        if format == .story { base *= 1.12 }
        return LargestThatFits<JokeArtwork>.ladder(from: base, downTo: 30)
    }

    private var showsPortrait: Bool {
        style == .bigFace && joke.teller != nil
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            colors.background

            if style == .bigFace, let teller = joke.teller {
                portrait(teller)
            }

            VStack(alignment: .leading, spacing: 40) {
                LargestThatFits(sizes: typeSizes) { typeSize in
                    JokeArtwork(joke: joke, colors: colors, size: typeSize, pillShadow: style == .bigFace)
                }
                // Stories center the joke, unless a face needs the lower half
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: format == .story && !showsPortrait ? .leading : .topLeading)
                // Big face: the joke stays above the face
                .padding(.bottom, showsPortrait ? portraitSide * (format == .square ? 0.46 : 0.44) : 0)

                footer
            }
            .padding(insets)

            if let border = colors.border {
                Rectangle()
                    .strokeBorder(border, lineWidth: 14)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if style == .bigFace, joke.teller != nil {
            // The face is the signature here, so the name and site stack on the left
            VStack(alignment: .leading, spacing: 10) {
                tellerName
                siteLabel
            }
        } else {
            HStack(spacing: 22) {
                if let teller = joke.teller {
                    Image(teller.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 104)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(style == .light ? palette.color : .white, lineWidth: 5))
                }
                tellerName
                Spacer(minLength: 20)
                siteLabel
            }
        }
    }

    private var tellerName: some View {
        Text(joke.teller?.name ?? "Mr. Funny Jokes")
            .font(.system(size: 40, weight: .heavy, design: .rounded))
            .foregroundStyle(colors.text)
            .lineLimit(1)
    }

    private var siteLabel: some View {
        Text(Self.siteName)
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundStyle(colors.text)
            .lineLimit(1)
    }

    // MARK: Portrait

    /// The character's portrait in the lower right. It is a square photo on the
    /// character's color, so its top and left edges fade into the card.
    private func portrait(_ teller: JokeCharacter) -> some View {
        Image(teller.imageName)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: portraitSide, height: portraitSide)
            .mask { PortraitEdgeFade() }
            .offset(x: portraitSide * 0.06, y: portraitSide * 0.05)
    }
}

// MARK: - Preview and Export

/// A share card scaled to fit a width on screen, with rounded corners.
/// The exported image is the same card at full size, square-cornered.
struct ShareCardPreview: View {
    let joke: Joke
    let style: ShareCardStyle
    let format: ShareCardFormat
    let width: CGFloat

    var body: some View {
        let scale = width / format.size.width
        JokeShareCardView(joke: joke, style: style, format: format)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width, height: format.size.height * scale, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 64 * scale, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel("Share image preview, \(style.title) style")
    }
}

extension JokeShareCardView {
    /// The card as an image at its export size (1080 x 1080 or 1080 x 1920)
    @MainActor
    static func render(joke: Joke, style: ShareCardStyle, format: ShareCardFormat) -> UIImage? {
        let renderer = ImageRenderer(content: JokeShareCardView(joke: joke, style: style, format: format))
        renderer.scale = 1
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(format.size)
        return renderer.uiImage
    }
}

#Preview("Styles") {
    let joke = Joke(
        category: .dadJoke,
        setup: "What do you call a running turkey?",
        punchline: "Fast food!",
        character: "mr_funny"
    )
    return ScrollView {
        VStack(spacing: 16) {
            ForEach(ShareCardStyle.allCases) { style in
                ShareCardPreview(joke: joke, style: style, format: .square, width: 300)
            }
        }
        .padding()
    }
}

#Preview("Knock knock") {
    ShareCardPreview(
        joke: Joke(
            category: .knockKnock,
            setup: "Knock, knock.\nWho's there?\nLettuce.",
            punchline: "Lettuce who?\nLettuce in, it's cold out here!",
            character: "mr_potty"
        ),
        style: .dark,
        format: .story,
        width: 260
    )
}
