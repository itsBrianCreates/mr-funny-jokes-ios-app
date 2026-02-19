import SwiftUI

struct BinaryRatingView: View {
    let currentRating: Int?
    let onRate: (Int) -> Void

    enum RatingOption: CaseIterable {
        case hilarious
        case horrible

        var emoji: String {
            switch self {
            case .hilarious: return "😂"
            case .horrible: return "🫠"
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
            case .horrible: return .red
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
                onRate(option.rating)
            }
        } label: {
            HStack(spacing: 8) {
                Text(option.emoji)
                    .font(.title3)
                Text(option.name)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(isSelected ? option.selectedColor.opacity(0.2) : Color(.tertiarySystemFill))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? option.selectedColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CompactRatingView: View {
    let rating: Int?

    var body: some View {
        if let rating = rating {
            switch rating {
            case 5:
                Text("😂")
                    .font(.callout)
            case 1:
                Text("🫠")
                    .font(.callout)
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
