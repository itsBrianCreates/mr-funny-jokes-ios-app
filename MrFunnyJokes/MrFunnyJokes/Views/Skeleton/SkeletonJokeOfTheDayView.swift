import SwiftUI

// MARK: - Skeleton Joke of the Day View
// Placeholder view that matches the structure and height of JokeOfTheDayView with a
// two-line setup, so the cards below barely move when the real joke takes its place.
// Uses the brand yellow light background to maintain visual consistency
// with the actual hero card.

struct SkeletonJokeOfTheDayView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // "Joke of the Day"
            SkeletonShape(width: 110, height: 13, cornerRadius: 3)
                .padding(.vertical, 2.5)

            // Two lines of .title2 (28pt line height, 3pt line spacing)
            VStack(alignment: .leading, spacing: 11) {
                SkeletonShape(height: 20, cornerRadius: 4)
                GeometryReader { geo in
                    SkeletonShape(width: geo.size.width * 0.7, height: 20, cornerRadius: 4)
                }
                .frame(height: 20)
            }
            .padding(.top, 14)
            .padding(.bottom, 10)

            // The teller, then Laugh, Share, More
            HStack(spacing: 6) {
                SkeletonShape(width: 24, height: 24, cornerRadius: 12)
                SkeletonShape(width: 60, height: 11, cornerRadius: 3)
                Spacer(minLength: 0)
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonShape(width: 30, height: 18, cornerRadius: 5)
                        .padding(.leading, 12)
                }
            }
            .frame(height: 44)
        }
        .padding([.horizontal, .top], 20)
        .padding(.bottom, 8)
        .background(.brandYellowLight, in: RoundedRectangle(cornerRadius: JokeOfTheDayView.cornerRadius, style: .continuous))
        .shimmer()
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
