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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Characters")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

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
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
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
            // Circular character icon
            ZStack {
                // Background circle
                Circle()
                    .fill(character.color.opacity(0.15))
                    .frame(width: circleSize, height: circleSize)

                // Character icon
                Image(systemName: character.sfSymbol)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(character.color)
            }
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
