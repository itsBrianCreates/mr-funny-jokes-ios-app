import SwiftUI

/// The way into the All-Time Top 10 from Home: one row like the in-season topic card,
/// with both vote faces and a line that says what's inside. It opens the Funny list;
/// the page's own switch goes to Not funny.
struct AllTimeTopTenCarouselView: View {
    @ObservedObject var viewModel: AllTimeRankingsViewModel
    let onCardTap: (RankingType) -> Void

    var body: some View {
        if viewModel.isLoading {
            AllTimeTopTenCardSkeleton()
        } else {
            Button {
                HapticManager.shared.mediumImpact()
                onCardTap(.hilarious)
            } label: {
                AllTimeTopTenCard()
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - All-Time Top Ten Card

struct AllTimeTopTenCard: View {
    private let faceSize: CGFloat = 26

    var body: some View {
        HStack(spacing: 12) {
            // The two faces overlap, Funny in front
            HStack(spacing: -8) {
                FaceIcon(.hilarious)
                    .frame(width: faceSize, height: faceSize)
                    .zIndex(1)
                FaceIcon(.horrible)
                    .frame(width: faceSize, height: faceSize)
            }

            // The same two words as the switch on the page it opens
            Text("Top 10 funny and not funny")
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Neutral, like the joke cards: the faces carry the color
        .background(.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Top 10 funny and not funny jokes")
    }
}

// MARK: - Skeleton Loader

struct AllTimeTopTenCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonShape(width: 44, height: 26, cornerRadius: 13)
            SkeletonShape(width: 190, height: 18, cornerRadius: 4)
            Spacer(minLength: 0)
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
        AllTimeTopTenCard()
        AllTimeTopTenCardSkeleton()
        Spacer()
    }
    .padding()
}
