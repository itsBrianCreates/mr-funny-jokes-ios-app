import SwiftUI

/// A horizontal scrolling carousel displaying all character personas
/// Inspired by Apple Fitness+ trainer carousel design
struct CharacterCarouselView: View {
    let characters: [JokeCharacter]
    let onCharacterTap: (JokeCharacter) -> Void

    init(
        characters: [JokeCharacter] = JokeCharacter.allCharacters,
        onCharacterTap: @escaping (JokeCharacter) -> Void
    ) {
        self.characters = characters
        self.onCharacterTap = onCharacterTap
    }

    /// Matches the feed's horizontal padding so the first circle lines up with the cards
    private let edgeInset: CGFloat = 16

    /// Width of the scroll viewport, used to center the circles when they all fit
    @State private var viewportWidth: CGFloat = 0

    var body: some View {
        // Horizontal scrolling carousel
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(characters) { character in
                    CharacterCircleView(character: character)
                        .onTapGesture {
                            HapticManager.shared.lightTap()
                            onCharacterTap(character)
                        }
                }
            }
            .padding(.vertical, 4)
            // Centered on wide screens (iPhone Duo inner display); scrolls as before when narrow
            .frame(minWidth: max(0, viewportWidth - edgeInset * 2))
        }
        .contentMargins(.horizontal, edgeInset, for: .scrollContent)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            viewportWidth = width
        }
        // Clip to the scroll view's own frame (scroll views otherwise draw into the safe
        // area, under the iPhone Duo's control rail), then bleed that frame to the
        // safe-area edges so circles still scroll off the screen edge on iPhone.
        .clipShape(Rectangle())
        .padding(.horizontal, -edgeInset)
    }
}

// MARK: - Character Circle View

/// A circular view displaying a character's icon and name
struct CharacterCircleView: View {
    let character: JokeCharacter

    /// Size of the circular image
    private let circleSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
            // Circular character image
            Image(character.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: circleSize, height: circleSize)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(character.color.opacity(0.3), lineWidth: 2)
                )

            // Character name
            Text(character.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(width: circleSize)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    VStack {
        CharacterCarouselView { character in
            print("Tapped: \(character.name)")
        }
        Spacer()
    }
    .padding(.top)
}
