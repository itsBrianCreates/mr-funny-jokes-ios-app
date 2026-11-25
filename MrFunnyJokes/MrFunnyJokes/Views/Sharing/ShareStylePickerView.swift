import SwiftUI

/// "Create image": pick how the share card looks, see it live, then share it.
/// Always dark, so the card is the brightest thing on screen.
struct ShareStylePickerView: View {
    let joke: Joke
    /// Where the picker was opened from, for analytics
    var surface: JokeShareService.Surface = .moreMenu

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isWideLayout) private var isWideLayout

    @State private var style = ShareCardPreferences.style
    @State private var format = ShareCardPreferences.format

    private let background = Color(hex: 0x151311)

    var body: some View {
        VStack(spacing: 0) {
            header

            if isWideLayout {
                // Short, wide windows (iPhone Duo open): card on the left, controls beside it
                HStack(spacing: 32) {
                    preview
                    VStack(spacing: 20) {
                        Spacer(minLength: 0)
                        controls
                        shareButton
                    }
                    .frame(width: 340)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            } else {
                preview
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                VStack(spacing: 18) {
                    controls
                    shareButton
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onChange(of: style) { _, newStyle in
            HapticManager.shared.selection()
            ShareCardPreferences.style = newStyle
        }
        .onChange(of: format) { _, newFormat in
            HapticManager.shared.selection()
            ShareCardPreferences.format = newFormat
        }
    }

    private var header: some View {
        ZStack {
            Text("Create image")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .accessibilityLabel("Close")
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    /// The card as large as the space allows, for either format
    private var preview: some View {
        GeometryReader { geometry in
            let aspect = format.size.width / format.size.height
            let width = min(geometry.size.width, geometry.size.height * aspect)
            ShareCardPreview(joke: joke, style: style, format: format, width: max(width, 1))
                .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var controls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                ForEach(ShareCardStyle.allCases) { option in
                    styleButton(option)
                }
            }

            Picker("Format", selection: $format) {
                ForEach(ShareCardFormat.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    /// A small copy of the real card in that style, so the choice is what you get
    private func styleButton(_ option: ShareCardStyle) -> some View {
        let isSelected = option == style
        return Button {
            withAnimation(.snappy(duration: 0.2)) { style = option }
        } label: {
            VStack(spacing: 6) {
                ShareCardPreview(joke: joke, style: option, format: .square, width: 62)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.white, lineWidth: isSelected ? 2.5 : 0)
                    )
                Text(option.title)
                    .font(.caption.weight(isSelected ? .bold : .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.title) style")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Primary buttons are white on dark and never take the character's color
    private var shareButton: some View {
        Button {
            JokeShareService.shared.share(joke, from: surface, style: style, format: format)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ShareStylePickerView(
        joke: Joke(
            category: .dadJoke,
            setup: "What do you call a running turkey?",
            punchline: "Fast food!",
            character: "mr_funny"
        )
    )
}
