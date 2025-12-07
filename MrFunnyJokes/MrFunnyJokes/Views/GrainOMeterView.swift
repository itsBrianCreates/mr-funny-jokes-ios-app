import SwiftUI

struct GroanOMeterView: View {
    let currentRating: Int?
    let onRate: (Int) -> Void

    // 1-5 rating scale (index 0-4 maps to rating 1-5)
    private let ratingOptions: [(emoji: String, name: String)] = [
        ("🫠", "Horrible"),
        ("😩", "Groan-worthy"),
        ("😐", "Meh"),
        ("😄", "Funny"),
        ("😂", "Hilarious")
    ]

    @State private var selectedIndex: Int? = nil
    @GestureState private var isDragging = false

    // iOS minimum tap target is 44pt
    private let circleSize: CGFloat = 48
    private let containerPadding: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row with label and current rating name
            HStack {
                Text("Rate joke")
                    .font(.headline)

                Spacer()

                Text(currentRatingName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .animation(.none, value: displayIndex ?? -1)
            }

            // Emoji slider in pill container
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let itemWidth = totalWidth / CGFloat(ratingOptions.count)
                let circleOffset = (itemWidth - circleSize) / 2

                ZStack(alignment: .leading) {
                    // Pill container background
                    Capsule()
                        .fill(.quaternary.opacity(0.5))

                    // Circular glass indicator - only show when there's a selection
                    if let index = displayIndex {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: circleSize, height: circleSize)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                            .offset(x: indicatorOffset(itemWidth: itemWidth, circleOffset: circleOffset, index: index))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: displayIndex)
                    }

                    // Emoji row
                    HStack(spacing: 0) {
                        ForEach(0..<ratingOptions.count, id: \.self) { index in
                            Text(ratingOptions[index].emoji)
                                .font(.system(size: 24))
                                .frame(width: itemWidth, height: circleSize)
                                .opacity(displayIndex == index ? 1.0 : (displayIndex == nil ? 0.6 : 0.5))
                                .scaleEffect(displayIndex == index ? 1.15 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: displayIndex)
                        }
                    }
                }
                .frame(height: circleSize + containerPadding * 2)
                .contentShape(Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isDragging) { _, state, _ in
                            state = true
                        }
                        .onChanged { value in
                            let newIndex = indexFromLocation(value.location.x, itemWidth: itemWidth)
                            if newIndex != selectedIndex {
                                selectedIndex = newIndex
                                HapticManager.shared.lightTap()
                            }
                        }
                        .onEnded { value in
                            let finalIndex = indexFromLocation(value.location.x, itemWidth: itemWidth)

                            // Save the rating (index 0-4 maps to rating 1-5)
                            onRate(finalIndex + 1)
                        }
                )
            }
            .frame(height: circleSize + containerPadding * 2)
        }
        .onAppear {
            // Convert rating (1-5) to index (0-4), nil if unrated
            selectedIndex = currentRating.map { $0 - 1 }
        }
        .onChange(of: currentRating) { _, newValue in
            // Convert rating (1-5) to index (0-4), nil if unrated
            selectedIndex = newValue.map { $0 - 1 }
        }
    }

    private var displayIndex: Int? {
        if isDragging {
            return selectedIndex
        }
        // Convert rating (1-5) to index (0-4), nil if unrated
        return currentRating.map { $0 - 1 }
    }

    private var currentRatingName: String {
        guard let index = displayIndex, index >= 0, index < ratingOptions.count else {
            return "Tap to rate"
        }
        return ratingOptions[index].name
    }

    private func indicatorOffset(itemWidth: CGFloat, circleOffset: CGFloat, index: Int) -> CGFloat {
        CGFloat(index) * itemWidth + circleOffset
    }

    private func indexFromLocation(_ x: CGFloat, itemWidth: CGFloat) -> Int {
        let index = Int(x / itemWidth)
        return max(0, min(ratingOptions.count - 1, index))
    }
}

struct CompactGroanOMeterView: View {
    let rating: Int?

    private let emojis = ["🫠", "😩", "😐", "😄", "😂"]

    var body: some View {
        if let rating = rating, rating >= 1, rating <= 5 {
            Text(emojis[rating - 1])
                .font(.callout)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        GroanOMeterView(currentRating: 3) { rating in
            print("Selected rating: \(rating)")
        }

        GroanOMeterView(currentRating: nil) { rating in
            print("Selected rating: \(rating)")
        }

        GroanOMeterView(currentRating: 5) { rating in
            print("Selected rating: \(rating)")
        }

        Divider()

        HStack {
            CompactGroanOMeterView(rating: 1)
            CompactGroanOMeterView(rating: 2)
            CompactGroanOMeterView(rating: 3)
            CompactGroanOMeterView(rating: 4)
            CompactGroanOMeterView(rating: 5)
        }
    }
    .padding()
}
