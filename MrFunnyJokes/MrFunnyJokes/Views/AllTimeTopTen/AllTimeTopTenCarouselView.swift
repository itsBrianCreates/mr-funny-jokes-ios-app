import SwiftUI

/// The way into the All-Time Top 10 from Home: one line, like the seasonal card above it.
/// Both faces, "Top 10 jokes", then how many ratings the lists are built from and a chevron.
/// Opens the Funny list; the switch on that page leads to Not funny.
struct AllTimeTopTenCarouselView: View {
    @ObservedObject var viewModel: AllTimeRankingsViewModel
    let onCardTap: (RankingType) -> Void

    var body: some View {
        if viewModel.isLoading {
            AllTimeTopTenCardSkeleton()
        } else {
            AllTimeTopTenCard(
                totalRatings: viewModel.totalHilariousRatings + viewModel.totalHorribleRatings,
                onTap: {
                    HapticManager.shared.lightTap()
                    onCardTap(.hilarious)
                }
            )
        }
    }
}

// MARK: - All-Time Top Ten Card

struct AllTimeTopTenCard: View {
    /// Funny and Not funny ratings together, across every joke
    let totalRatings: Int
    let onTap: () -> Void

    private var ratingsText: String {
        "\(JokeEngagement.compact(totalRatings)) \(totalRatings == 1 ? "rating" : "ratings")"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Funny in front, Not funny tucked behind it
                HStack(spacing: -8) {
                    FaceIcon(.hilarious)
                        .frame(width: 26, height: 26)
                        .zIndex(1)
                    FaceIcon(.horrible)
                        .frame(width: 26, height: 26)
                }
                .accessibilityHidden(true)

                Text("Top 10 jokes")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                // The number says what it counts; nothing shows before the first rating
                if totalRatings > 0 {
                    Text(ratingsText)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(JokeCardMetrics.quietColor)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // Neutral, like the joke cards: on Home only the Joke of the Day is tinted
            .background(.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Top 10 jokes")
        .accessibilityValue(totalRatings > 0 ? ratingsText : "")
        .accessibilityHint("Shows the funniest and the least funny jokes")
    }
}

// MARK: - Skeleton Loader

struct AllTimeTopTenCardSkeleton: View {
    var body: some View {
        HStack(spacing: 8) {
            SkeletonShape(width: 44, height: 26, cornerRadius: 13)
            SkeletonShape(width: 110, height: 18, cornerRadius: 4)
            Spacer(minLength: 0)
            SkeletonShape(width: 70, height: 16, cornerRadius: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .shimmer()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        AllTimeTopTenCard(totalRatings: 451, onTap: {})
        AllTimeTopTenCard(totalRatings: 12840, onTap: {})
        AllTimeTopTenCard(totalRatings: 0, onTap: {})
        AllTimeTopTenCardSkeleton()
        Spacer()
    }
    .padding()
}
