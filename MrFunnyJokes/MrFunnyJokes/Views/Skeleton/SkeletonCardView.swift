import SwiftUI

// MARK: - Skeleton Card View
// Placeholder view that matches the exact structure of JokeCardView.
// Shows grey placeholder shapes where text content will appear.

struct SkeletonCardView: View {
    // Vary line counts/widths for visual variety in the feed
    let lineCount: Int
    let lastLineWidth: CGFloat

    init(lineCount: Int = 2, lastLineWidth: CGFloat = 0.6) {
        self.lineCount = lineCount
        self.lastLineWidth = lastLineWidth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Setup text placeholder - matches .title3 font height (~20pt)
            setupTextPlaceholder

            // The teller, then Laugh, Share, More: as tall as the real row's 44pt buttons
            metadataRowPlaceholder
                .frame(height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .shimmer()
    }

    // MARK: - Setup Text Placeholder

    private var setupTextPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<lineCount, id: \.self) { index in
                // Last line is shorter for natural text appearance
                if index == lineCount - 1 {
                    GeometryReader { geo in
                        SkeletonShape(
                            width: geo.size.width * lastLineWidth,
                            height: 18,
                            cornerRadius: 4
                        )
                    }
                    .frame(height: 18)
                } else {
                    SkeletonShape(height: 18, cornerRadius: 4)
                }
            }
        }
    }

    // MARK: - Metadata Row Placeholder

    private var metadataRowPlaceholder: some View {
        HStack(spacing: 4) {
            // Teller picture and name
            SkeletonShape(width: 20, height: 20, cornerRadius: 10)
            SkeletonShape(width: 60, height: 12, cornerRadius: 3)

            Spacer()

            // Laugh, Share, More
            ForEach(0..<3, id: \.self) { _ in
                SkeletonShape(width: 28, height: 16, cornerRadius: 4)
                    .padding(.leading, 10)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            SkeletonCardView(lineCount: 1, lastLineWidth: 0.8)
            SkeletonCardView(lineCount: 2, lastLineWidth: 0.5)
            SkeletonCardView(lineCount: 3, lastLineWidth: 0.7)
        }
        .padding()
    }
}
