import SwiftUI

struct BinaryRatingView: View {
    let currentRating: Int?
    /// How many people voted each way. Shown beside the label, zero included; nil hides it.
    var hilariousCount: Int? = nil
    var horribleCount: Int? = nil
    let onRate: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // The same reactions as the Laugh and Horrible buttons on a card
    @State private var burstCount = 0
    @State private var bounce = false
    @State private var wobble = false

    /// A new vote gets the card's reaction: Hilarious bounces and sends faces
    /// floating up, Horrible wobbles
    private func celebrate(_ option: RatingOption) {
        switch option {
        case .hilarious:
            HapticManager.shared.success()
            guard !reduceMotion else { return }
            burstCount += 1
            bounce = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { bounce = false }
        case .horrible:
            guard !reduceMotion else { return }
            wobble = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.3)) { wobble = false }
        }
    }

    private func count(for option: RatingOption) -> Int? {
        switch option {
        case .hilarious: return hilariousCount
        case .horrible: return horribleCount
        }
    }

    enum RatingOption: CaseIterable {
        case hilarious
        case horrible

        var mood: FaceIcon.Mood {
            switch self {
            case .hilarious: return .smile
            case .horrible: return .frown
            }
        }

        var name: String {
            switch self {
            case .hilarious: return "Hilarious"
            case .horrible: return "Horrible"
            }
        }

        var rating: Int {
            switch self {
            case .hilarious: return 5
            case .horrible: return 1
            }
        }

        var selectedColor: Color {
            switch self {
            case .hilarious: return .accessibleYellow
            case .horrible: return FaceIcon.horribleTint
            }
        }
    }

    private var selectedOption: RatingOption? {
        guard let currentRating else { return nil }
        switch currentRating {
        case 5: return .hilarious
        case 1: return .horrible
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rate joke")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(RatingOption.allCases, id: \.name) { option in
                    ratingButton(for: option)
                }
            }
        }
    }

    private func ratingButton(for option: RatingOption) -> some View {
        let isSelected = selectedOption == option

        return Button {
            HapticManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                // A second tap on your own vote takes it back, as on a card
                onRate(isSelected ? 0 : option.rating)
            }
            if !isSelected { celebrate(option) }
        } label: {
            HStack(spacing: 8) {
                // The same faces as the cards: an outline until it's your vote
                FaceIcon(mood: option.mood, isFilled: isSelected)
                    .frame(width: 22, height: 22)
                    .scaleEffect(option == .hilarious ? (bounce ? 1.45 : 1) : (wobble ? 1.35 : 1))
                    .rotationEffect(.degrees(option == .horrible && wobble ? -20 : 0))
                    .background {
                        if option == .hilarious {
                            LaughBurst(trigger: burstCount)
                        }
                    }
                Text(option.name)
                    .font(.subheadline.weight(.medium))
                if let count = count(for: option) {
                    Text(JokeEngagement.compact(count))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(isSelected ? option.selectedColor.opacity(0.2) : Color(.tertiarySystemFill))
            )
            // Not clipped: the floating faces rise out of the pill
            .contentShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? option.selectedColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name)
        .accessibilityValue(count(for: option).map { "\($0) votes" } ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct CompactRatingView: View {
    let rating: Int?

    var body: some View {
        if let rating = rating {
            switch rating {
            case 5:
                FaceIcon(mood: .smile, isFilled: true)
                    .frame(width: 18, height: 18)
            case 1:
                FaceIcon(mood: .frown, isFilled: true)
                    .frame(width: 18, height: 18)
            default:
                EmptyView()
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        BinaryRatingView(currentRating: nil) { rating in
            print("Selected rating: \(rating)")
        }

        BinaryRatingView(currentRating: 1) { rating in
            print("Selected rating: \(rating)")
        }

        BinaryRatingView(currentRating: 5) { rating in
            print("Selected rating: \(rating)")
        }

        Divider()

        HStack {
            CompactRatingView(rating: 1)
            CompactRatingView(rating: 5)
            CompactRatingView(rating: nil)
        }
    }
    .padding()
}
