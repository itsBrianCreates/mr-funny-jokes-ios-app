import SwiftUI

// MARK: - Skeleton Feed View
// Complete skeleton layout matching the JokeFeedView structure.
// Displays immediately on app launch before data loads,
// providing users with a familiar layout structure.

struct SkeletonFeedView: View {
    // Predefined card configurations for visual variety
    // Each tuple: (lineCount, lastLineWidthRatio)
    private let cardConfigs: [(Int, CGFloat)] = [
        (2, 0.6),   // 2 lines, last line 60% width
        (1, 0.85),  // 1 line, 85% width
        (3, 0.5),   // 3 lines, last line 50% width
        (2, 0.7),   // 2 lines, last line 70% width
        (2, 0.4),   // 2 lines, last line 40% width
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Joke of the Day hero section skeleton
                SkeletonJokeOfTheDayView()

                // Regular joke cards skeleton
                ForEach(0..<cardConfigs.count, id: \.self) { index in
                    let config = cardConfigs[index]
                    SkeletonCardView(
                        lineCount: config.0,
                        lastLineWidth: config.1
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        // Disable scrolling during skeleton state for cleaner UX
        .scrollDisabled(true)
    }
}

#Preview {
    NavigationStack {
        SkeletonFeedView()
            .navigationTitle("All Jokes")
            .navigationBarTitleDisplayMode(.large)
    }
}
