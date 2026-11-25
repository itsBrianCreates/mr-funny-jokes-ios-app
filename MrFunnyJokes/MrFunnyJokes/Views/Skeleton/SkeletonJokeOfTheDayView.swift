import SwiftUI

// MARK: - Skeleton Joke of the Day View
// Placeholder view that matches the structure and height of JokeOfTheDayView with a
// two-line setup, so the cards below barely move when the real joke takes its place.
// Uses the brand yellow light background to maintain visual consistency
// with the actual hero card.

struct SkeletonJokeOfTheDayView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Avatar, "Joke of the Day" and the teller and date
            HStack(spacing: 12) {
                SkeletonShape(width: 44, height: 44, cornerRadius: 22)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonShape(width: 110, height: 13, cornerRadius: 3)
                    SkeletonShape(width: 160, height: 11, cornerRadius: 3)
                        .opacity(0.6)
                }
                Spacer(minLength: 0)
            }

            // Two lines of .title2 (28pt line height, 3pt line spacing)
            VStack(alignment: .leading, spacing: 11) {
                SkeletonShape(height: 20, cornerRadius: 4)
                GeometryReader { geo in
                    SkeletonShape(width: geo.size.width * 0.7, height: 20, cornerRadius: 4)
                }
                .frame(height: 20)
            }
            .padding(.top, 22)
            .padding(.bottom, 18)

            // Laugh, Share, More
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        SkeletonShape(width: 24, height: 24, cornerRadius: 12)
                        SkeletonShape(width: 28, height: 10, cornerRadius: 3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
            }
            .padding(.horizontal, -12)
            .padding(.bottom, -12)
        }
        .padding(20)
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
