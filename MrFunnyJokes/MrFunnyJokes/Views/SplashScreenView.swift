import SwiftUI

/// An engaging splash screen shown on app launch
/// Features animated character circles and delightful loading copy
struct SplashScreenView: View {
    let characters = JokeCharacter.allCharacters

    /// Animation states
    @State private var showTitle = false
    @State private var showCharacters = false
    @State private var showSubtitle = false
    @State private var wavePhase: CGFloat = 0

    /// Loading messages that cycle through
    private let loadingMessages = [
        "Loading some laughs...",
        "Warming up the punchlines...",
        "Gathering the giggles...",
        "Preparing the grins..."
    ]
    @State private var currentMessageIndex = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.brandYellow.opacity(0.3),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App title with playful entrance
                VStack(spacing: 8) {
                    Text("Mr. Funny")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Jokes")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.brandYellow)
                }
                .opacity(showTitle ? 1 : 0)
                .scaleEffect(showTitle ? 1 : 0.8)
                .offset(y: showTitle ? 0 : 20)

                // Animated character circles with wave effect
                TimelineView(.animation(minimumInterval: 0.05)) { timeline in
                    HStack(spacing: 12) {
                        ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                            WaveCharacterCircle(
                                character: character,
                                index: index,
                                date: timeline.date
                            )
                            .opacity(showCharacters ? 1 : 0)
                            .scaleEffect(showCharacters ? 1 : 0.5)
                        }
                    }
                }
                .padding(.horizontal)

                // Loading message with fade transition
                Text(loadingMessages[currentMessageIndex])
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .opacity(showSubtitle ? 1 : 0)
                    .contentTransition(.opacity)
                    .id(currentMessageIndex)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Staggered entrance animations for a polished feel
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showTitle = true
        }

        // Characters appear with staggered spring animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0)) {
                showCharacters = true
            }
        }

        // Subtitle fades in last
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                showSubtitle = true
            }

            // Start cycling through messages
            startMessageCycling()
        }
    }

    private func startMessageCycling() {
        // Use Task with sleep for proper SwiftUI lifecycle management
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentMessageIndex = (currentMessageIndex + 1) % loadingMessages.count
                    }
                }
            }
        }
    }
}

// MARK: - Wave Character Circle

/// A character circle that bounces in a wave pattern using TimelineView
struct WaveCharacterCircle: View {
    let character: JokeCharacter
    let index: Int
    let date: Date

    private let circleSize: CGFloat = 56

    /// Calculate bounce offset based on time and index for wave effect
    private var bounceOffset: CGFloat {
        let timeInterval = date.timeIntervalSinceReferenceDate
        // Each character has a phase offset creating a wave
        let phase = timeInterval * 4 + Double(index) * 0.8
        // Smooth sine wave bounce
        let bounce = sin(phase) * 8
        return bounce
    }

    /// Scale pulse synchronized with bounce
    private var pulseScale: CGFloat {
        let timeInterval = date.timeIntervalSinceReferenceDate
        let phase = timeInterval * 4 + Double(index) * 0.8
        // Subtle scale pulse
        return 1.0 + sin(phase) * 0.05
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Outer glow effect that pulses
                Circle()
                    .fill(character.color.opacity(0.2))
                    .frame(width: circleSize + 8, height: circleSize + 8)
                    .blur(radius: 4)
                    .scaleEffect(pulseScale)

                // Background circle
                Circle()
                    .fill(character.color.opacity(0.15))
                    .frame(width: circleSize, height: circleSize)

                // Character icon
                Image(systemName: character.sfSymbol)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(character.color)
            }
            .overlay(
                Circle()
                    .strokeBorder(character.color.opacity(0.4), lineWidth: 2)
                    .frame(width: circleSize, height: circleSize)
            )
            .shadow(color: character.color.opacity(0.3), radius: 8, y: 4)
            .offset(y: bounceOffset)
            .scaleEffect(pulseScale)
        }
        .frame(width: circleSize + 8)
    }
}

// MARK: - Preview

#Preview {
    SplashScreenView()
}
