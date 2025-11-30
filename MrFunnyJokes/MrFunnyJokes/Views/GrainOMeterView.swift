import SwiftUI

struct GroanOMeterView: View {
    let currentRating: Int?
    let onRate: (Int) -> Void

    // 0 = no rating, 1-4 = actual ratings
    private let ratingOptions: [(emoji: String, name: String)] = [
        ("🚫", "No Rating"),
        ("😩", "Groan-worthy"),
        ("😐", "Meh"),
        ("😄", "Funny"),
        ("😂", "Hilarious")
    ]

    @State private var selectedIndex: Int = 0
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
                    .animation(.none, value: displayIndex)
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

                    // Circular glass indicator
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: circleSize, height: circleSize)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .offset(x: indicatorOffset(itemWidth: itemWidth, circleOffset: circleOffset))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: displayIndex)

                    // Emoji row
                    HStack(spacing: 0) {
                        ForEach(0..<ratingOptions.count, id: \.self) { index in
                            Text(ratingOptions[index].emoji)
                                .font(.system(size: 24))
                                .frame(width: itemWidth, height: circleSize)
                                .opacity(displayIndex == index ? 1.0 : 0.5)
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

                            // Save the rating (0 means remove rating, 1-4 are actual ratings)
                            if finalIndex == 0 {
                                onRate(0)
                            } else {
                                onRate(finalIndex)
                            }
                        }
                )
            }
            .frame(height: circleSize + containerPadding * 2)
        }
        .onAppear {
            selectedIndex = currentRating ?? 0
        }
        .onChange(of: currentRating) { _, newValue in
            selectedIndex = newValue ?? 0
        }
    }

    private var displayIndex: Int {
        if isDragging {
            return selectedIndex
        }
        return currentRating ?? 0
    }

    private var currentRatingName: String {
        let index = displayIndex
        guard index >= 0 && index < ratingOptions.count else { return "" }
        return ratingOptions[index].name
    }

    private func indicatorOffset(itemWidth: CGFloat, circleOffset: CGFloat) -> CGFloat {
        CGFloat(displayIndex) * itemWidth + circleOffset
    }

    private func indexFromLocation(_ x: CGFloat, itemWidth: CGFloat) -> Int {
        let index = Int(x / itemWidth)
        return max(0, min(ratingOptions.count - 1, index))
    }
}

struct CompactGroanOMeterView: View {
    let rating: Int?

    private let emojis = ["😩", "😐", "😄", "😂"]

    var body: some View {
        if let rating = rating, rating >= 1, rating <= 4 {
            Text(emojis[rating - 1])
                .font(.callout)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        GroanOMeterView(currentRating: 2) { rating in
            print("Selected rating: \(rating)")
        }

        GroanOMeterView(currentRating: nil) { rating in
            print("Selected rating: \(rating)")
        }

        GroanOMeterView(currentRating: 4) { rating in
            print("Selected rating: \(rating)")
        }

        Divider()

        HStack {
            CompactGroanOMeterView(rating: 1)
            CompactGroanOMeterView(rating: 2)
            CompactGroanOMeterView(rating: 3)
            CompactGroanOMeterView(rating: 4)
        }
    }
    .padding()
}
