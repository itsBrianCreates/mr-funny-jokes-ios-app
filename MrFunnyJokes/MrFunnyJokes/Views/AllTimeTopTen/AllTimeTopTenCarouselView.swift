import SwiftUI

/// The way into the All-Time Top 10 from Home: two compact cards side by side, one for
/// the funniest jokes and one for the worst, each with its vote face. No heading above
/// them; the cards say what they are.
struct AllTimeTopTenCarouselView: View {
    @ObservedObject var viewModel: AllTimeRankingsViewModel
    let onCardTap: (RankingType) -> Void

    var body: some View {
        HStack(spacing: 12) {
            if viewModel.isLoading {
                AllTimeTopTenCardSkeleton()
                AllTimeTopTenCardSkeleton()
            } else {
                ForEach(RankingType.allCases) { type in
                    Button {
                        HapticManager.shared.mediumImpact()
                        onCardTap(type)
                    } label: {
                        AllTimeTopTenCard(type: type)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - All-Time Top Ten Card

/// The face, which list it is, and "Top 10" under it
struct AllTimeTopTenCard: View {
    let type: RankingType

    var body: some View {
        HStack(spacing: 10) {
            FaceIcon(type)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                // The word that differs leads, so the two cards don't scan the same
                Text(type.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Top 10")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        // Neutral, like the joke cards: the face carries the color
        .background(.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.title), top 10")
    }
}

// MARK: - Skeleton Loader

struct AllTimeTopTenCardSkeleton: View {
    var body: some View {
        HStack(spacing: 10) {
            SkeletonShape(width: 30, height: 30, cornerRadius: 15)

            VStack(alignment: .leading, spacing: 2) {
                SkeletonShape(width: 60, height: 18, cornerRadius: 4)
                SkeletonShape(width: 96, height: 16, cornerRadius: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .shimmer()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        AllTimeTopTenCarouselView(
            viewModel: AllTimeRankingsViewModel(),
            onCardTap: { type in
                print("Tapped: \(type)")
            }
        )

        HStack(spacing: 12) {
            AllTimeTopTenCard(type: .hilarious)
            AllTimeTopTenCard(type: .horrible)
        }

        HStack(spacing: 12) {
            AllTimeTopTenCardSkeleton()
            AllTimeTopTenCardSkeleton()
        }

        Spacer()
    }
    .padding()
}
