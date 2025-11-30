import SwiftUI

struct YouTubePromoCardView: View {
    /// YouTube red color for the subscribe button
    private let youtubeRed = Color(red: 1.0, green: 0, blue: 0) // #FF0000

    /// YouTube channel URL with subscription confirmation
    private let youtubeURL = URL(string: "https://www.youtube.com/@MrLearnFunnyJokes?sub_confirmation=1")!

    /// Light background for the promo card - distinct from joke cards
    private var promoBackground: Color {
        Color(
            light: Color(red: 0.98, green: 0.96, blue: 0.98), // Very soft lavender/gray
            dark: Color(red: 0.15, green: 0.14, blue: 0.16)   // Subtle purple-gray for dark mode
        )
    }

    @Environment(\.openURL) private var openURL
    @State private var isAppearing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Text content
            VStack(alignment: .leading, spacing: 8) {
                Text("Mr. Funny Jokes is on YouTube!")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Subscribe so you never miss a groan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Subscribe button
            Button {
                HapticManager.shared.mediumImpact()
                openURL(youtubeURL)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.body.weight(.medium))
                    Text("Subscribe on YouTube")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(youtubeRed, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(promoBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isAppearing ? 1 : 0.95)
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            YouTubePromoCardView()
            YouTubePromoCardView()
        }
        .padding()
    }
}
