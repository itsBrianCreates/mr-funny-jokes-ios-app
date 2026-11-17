import SwiftUI

// MARK: - Skeleton Joke of the Day View
// Placeholder view that matches the structure and height of JokeOfTheDayView with a
// two-line setup, so the cards below barely move when the real joke takes its place.
// Uses the brand yellow light background to maintain visual consistency
// with the actual hero card.

struct SkeletonJokeOfTheDayView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header badge placeholder - matches "JOKE OF THE DAY" text
            badgePlaceholder

            // Setup text placeholder - two lines of .title3
            setupTextPlaceholder

            // Character and rating row placeholder
            metadataRowPlaceholder
        }
        .padding(16)
        .background(.brandYellowLight, in: RoundedRectangle(cornerRadius: 20))
        .shimmer()
    }

    // MARK: - Badge Placeholder
    // Matches the uppercase "JOKE OF THE DAY" badge text

    private var badgePlaceholder: some View {
        SkeletonShape(
            width: 130,
            height: 28,
            cornerRadius: 6
        )
        .opacity(0.6)  // Slightly more subtle to match caption style
    }

    // MARK: - Setup Text Placeholder
    // Matches two lines of .title3.weight(.semibold) (~25pt line height)

    private var setupTextPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            SkeletonShape(height: 22, cornerRadius: 4)
            GeometryReader { geo in
                SkeletonShape(
                    width: geo.size.width * 0.75,
                    height: 22,
                    cornerRadius: 4
                )
            }
            .frame(height: 22)
        }
    }

    // MARK: - Metadata Row Placeholder
    // Matches the character avatar and name, and the rating prompt

    private var metadataRowPlaceholder: some View {
        HStack {
            // Avatar + name placeholder
            HStack(spacing: 12) {
                SkeletonShape(width: 44, height: 44, cornerRadius: 22)
                SkeletonShape(width: 80, height: 12, cornerRadius: 3)
            }

            Spacer()

            // Rating emoji placeholder
            SkeletonShape(width: 20, height: 16, cornerRadius: 4)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            SkeletonJokeOfTheDayView()
        }
        .padding()
    }
}
