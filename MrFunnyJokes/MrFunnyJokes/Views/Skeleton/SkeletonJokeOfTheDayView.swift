import SwiftUI

// MARK: - Skeleton Joke of the Day View
// Placeholder view that matches the exact structure of JokeOfTheDayView.
// Uses the brand yellow light background to maintain visual consistency
// with the actual hero card.

struct SkeletonJokeOfTheDayView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header badge placeholder - matches "JOKE OF THE DAY" text
            badgePlaceholder

            // Setup text placeholder - larger font (.title2) = taller lines
            setupTextPlaceholder

            // Category and rating row placeholder
            metadataRowPlaceholder
        }
        .padding(20)
        .background(.brandYellowLight, in: RoundedRectangle(cornerRadius: 20))
        .shimmer()
    }

    // MARK: - Badge Placeholder
    // Matches the uppercase "JOKE OF THE DAY" badge text

    private var badgePlaceholder: some View {
        SkeletonShape(
            width: 110,
            height: 12,
            cornerRadius: 3
        )
        .opacity(0.6)  // Slightly more subtle to match caption style
    }

    // MARK: - Setup Text Placeholder
    // Matches .title2.weight(.semibold) - larger text (~22pt)

    private var setupTextPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
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
    // Matches category icon + text and optional rating emoji

    private var metadataRowPlaceholder: some View {
        HStack {
            // Category icon + text placeholder
            HStack(spacing: 4) {
                SkeletonShape(width: 14, height: 14, cornerRadius: 3)
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
