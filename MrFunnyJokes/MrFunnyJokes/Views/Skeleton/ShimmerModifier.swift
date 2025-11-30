import SwiftUI
import Foundation

// MARK: - Shimmer Effect Modifier
// A subtle pulsing animation applied to skeleton placeholder views.
// Uses opacity animation for a gentle "breathing" effect that indicates loading
// while being performant and non-distracting.

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .opacity(0.4 + 0.3 * sin(phase))
            .onAppear {
                // Continuous pulse animation with smooth easing
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    phase = .pi
                }
            }
    }
}

// MARK: - Convenience Extension

extension View {
    /// Applies a subtle shimmer/pulse effect to indicate loading state
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shape View
// A reusable placeholder shape for skeleton layouts.
// Provides consistent styling for text lines, badges, and icons.

struct SkeletonShape: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 4) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(skeletonFillColor)
            .frame(width: width, height: height)
    }

    // Skeleton fill color - subtle gray that works in both light and dark modes
    private var skeletonFillColor: Color {
        Color(
            light: Color(white: 0.85),
            dark: Color(white: 0.25)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // Preview skeleton shapes with shimmer
        VStack(alignment: .leading, spacing: 8) {
            SkeletonShape(width: 100, height: 12)
            SkeletonShape(height: 20)
            SkeletonShape(width: 200, height: 16)
        }
        .shimmer()
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    .padding()
}
