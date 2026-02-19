import SwiftUI

/// A section showing "All-Time Top 10" header with chevron and two category cards below
struct AllTimeTopTenCarouselView: View {
    @ObservedObject var viewModel: AllTimeRankingsViewModel
    let onCardTap: (RankingType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row with title and chevron
            AllTimeTop10Header {
                HapticManager.shared.mediumImpact()
                onCardTap(.hilarious) // Default to hilarious when tapping header
            }

            // Two cards side by side
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    AllTimeTopTenCardSkeleton()
                    AllTimeTopTenCardSkeleton()
                } else {
                    AllTimeTopTenCard(
                        type: .hilarious,
                        totalRatings: viewModel.totalHilariousRatings,
                        hasData: viewModel.hasDataFor(type: .hilarious)
                    )
                    .onTapGesture {
                        HapticManager.shared.mediumImpact()
                        onCardTap(.hilarious)
                    }

                    AllTimeTopTenCard(
                        type: .horrible,
                        totalRatings: viewModel.totalHorribleRatings,
                        hasData: viewModel.hasDataFor(type: .horrible)
                    )
                    .onTapGesture {
                        HapticManager.shared.mediumImpact()
                        onCardTap(.horrible)
                    }
                }
            }
        }
    }
}

// MARK: - Header with Chevron

struct AllTimeTop10Header: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text("All-Time Top 10")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.leading, 2) // Align with card content
        }
        .buttonStyle(.plain)
    }
}

// MARK: - All-Time Top Ten Card

/// A compact card for Hilarious or Horrible category - soft background style
struct AllTimeTopTenCard: View {
    let type: RankingType
    let totalRatings: Int
    let hasData: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Emoji
            Text(type.emoji)
                .font(.system(size: 32))

            // Title
            Text(type.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            // Subtitle - rating count or status
            if hasData && totalRatings > 0 {
                Text("\(totalRatings) ratings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Rate jokes to rank")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }
}

// MARK: - Skeleton Loader

struct AllTimeTopTenCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Emoji skeleton
            SkeletonShape(width: 32, height: 32, cornerRadius: 8)

            // Title skeleton
            SkeletonShape(width: 90, height: 16, cornerRadius: 4)

            // Subtitle skeleton
            SkeletonShape(width: 110, height: 14, cornerRadius: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .shimmer()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Full carousel view
        AllTimeTopTenCarouselView(
            viewModel: {
                let vm = AllTimeRankingsViewModel()
                return vm
            }(),
            onCardTap: { type in
                print("Tapped: \(type)")
            }
        )
        .padding(.horizontal)

        Divider()

        // Skeleton state
        VStack(alignment: .leading, spacing: 12) {
            AllTimeTop10Header {}

            HStack(spacing: 12) {
                AllTimeTopTenCardSkeleton()
                AllTimeTopTenCardSkeleton()
            }
        }
        .padding(.horizontal)

        Divider()

        // Individual cards with data
        VStack(alignment: .leading, spacing: 12) {
            AllTimeTop10Header {}

            HStack(spacing: 12) {
                AllTimeTopTenCard(
                    type: .hilarious,
                    totalRatings: 2847,
                    hasData: true
                )

                AllTimeTopTenCard(
                    type: .horrible,
                    totalRatings: 1523,
                    hasData: true
                )
            }
        }
        .padding(.horizontal)

        Spacer()
    }
    .padding(.top)
}
