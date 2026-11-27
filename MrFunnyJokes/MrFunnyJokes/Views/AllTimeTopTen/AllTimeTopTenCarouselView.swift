import SwiftUI

/// The way into the All-Time Top 10 from Home: one banner, Funny against Not funny.
/// Each end shows its face and how many votes the community has cast that way, on a
/// soft wash that runs from the Funny yellow to the Not funny red. Each half opens
/// its own list.
struct AllTimeTopTenCarouselView: View {
    @ObservedObject var viewModel: AllTimeRankingsViewModel
    let onCardTap: (RankingType) -> Void

    var body: some View {
        if viewModel.isLoading {
            AllTimeTopTenCardSkeleton()
        } else {
            AllTimeTopTenCard(
                funnyVotes: viewModel.totalHilariousRatings,
                notFunnyVotes: viewModel.totalHorribleRatings,
                onTap: { type in
                    HapticManager.shared.mediumImpact()
                    onCardTap(type)
                }
            )
        }
    }
}

// MARK: - All-Time Top Ten Card

struct AllTimeTopTenCard: View {
    let funnyVotes: Int
    let notFunnyVotes: Int
    let onTap: (RankingType) -> Void

    private let shape = RoundedRectangle(cornerRadius: 16)

    var body: some View {
        HStack(spacing: 0) {
            side(.hilarious, votes: funnyVotes)
            side(.horrible, votes: notFunnyVotes)
        }
        .overlay {
            // Sits between the two halves; a tap here lands on whichever half is under it
            Text("Top 10")
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .background {
            // Quieter than the Joke of the Day: the faces' colors at low strength
            shape.fill(
                LinearGradient(
                    colors: [FaceIcon.laughTint.opacity(0.24), FaceIcon.horribleTint.opacity(0.18)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .clipShape(shape)
    }

    /// One end of the banner: the face on the outside, then the list's name with its vote total under it
    private func side(_ type: RankingType, votes: Int) -> some View {
        let isFunny = type == .hilarious
        return Button {
            onTap(type)
        } label: {
            HStack(spacing: 8) {
                if isFunny { face(type) }
                VStack(alignment: isFunny ? .leading : .trailing, spacing: 1) {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    // "votes" says what the number is, now that nothing else does
                    Text("\(JokeEngagement.compact(votes)) votes")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(JokeCardMetrics.quietColor)
                }
                .lineLimit(1)
                if !isFunny { face(type) }
            }
            .frame(maxWidth: .infinity, alignment: isFunny ? .leading : .trailing)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Top 10 \(type.rawValue.lowercased()) jokes")
        .accessibilityValue("\(votes) votes")
    }

    private func face(_ type: RankingType) -> some View {
        FaceIcon(type)
            .frame(width: 28, height: 28)
    }
}

// MARK: - Skeleton Loader

struct AllTimeTopTenCardSkeleton: View {
    var body: some View {
        HStack(spacing: 8) {
            SkeletonShape(width: 28, height: 28, cornerRadius: 14)
            SkeletonShape(width: 48, height: 30, cornerRadius: 4)
            Spacer(minLength: 0)
            SkeletonShape(width: 60, height: 30, cornerRadius: 4)
            Spacer(minLength: 0)
            SkeletonShape(width: 48, height: 30, cornerRadius: 4)
            SkeletonShape(width: 28, height: 28, cornerRadius: 14)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .shimmer()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        AllTimeTopTenCard(funnyVotes: 324, notFunnyVotes: 127, onTap: { _ in })
        AllTimeTopTenCard(funnyVotes: 12840, notFunnyVotes: 0, onTap: { _ in })
        AllTimeTopTenCardSkeleton()
        Spacer()
    }
    .padding()
}
