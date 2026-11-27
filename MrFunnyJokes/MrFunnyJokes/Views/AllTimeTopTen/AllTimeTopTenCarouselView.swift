import SwiftUI

/// The way into the All-Time Top 10 from Home: one banner, Funny against Not funny.
/// A small "Top 10 jokes" label, then each end's face, name and community vote total,
/// then a bar showing how the votes split, on a soft wash that runs from the Funny
/// yellow to the Not funny red. Each half opens its own list.
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
        VStack(spacing: 0) {
            // A small label, so the middle of the row below stays empty at any width
            Text("Top 10 jokes")
                .font(.caption)
                .foregroundStyle(JokeCardMetrics.quietColor)
                .padding(.top, 10)
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                side(.hilarious, votes: funnyVotes)
                side(.horrible, votes: notFunnyVotes)
            }

            voteBar
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .allowsHitTesting(false)
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

    /// How the community's votes split: yellow for Funny, red for Not funny.
    /// Even when nobody has voted; neither side shrinks to nothing.
    private var voteBar: some View {
        let total = funnyVotes + notFunnyVotes
        let funnyShare = total == 0 ? 0.5 : min(max(Double(funnyVotes) / Double(total), 0.06), 0.94)
        return GeometryReader { geometry in
            let gap: CGFloat = 3
            let width = max(geometry.size.width - gap, 0)
            HStack(spacing: gap) {
                // The face's own yellow; the count's amber reads as mustard on a bar
                Capsule()
                    .fill(Color(red: 1.0, green: 0.76, blue: 0.10))
                    .frame(width: width * funnyShare)
                Capsule()
                    .fill(FaceIcon.horribleTint)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
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
                    Text(JokeEngagement.compact(votes))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(JokeCardMetrics.quietColor)
                }
                .lineLimit(1)
                if !isFunny { face(type) }
            }
            .frame(maxWidth: .infinity, alignment: isFunny ? .leading : .trailing)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 10)
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
