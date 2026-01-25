import SwiftUI

/// Visual snippet view displayed by Siri when telling a joke
/// Shows the character avatar and full joke text
struct JokeSnippetView: View {
    let joke: SharedJoke

    /// Maps character ID to character image asset name
    private var characterImageName: String {
        switch joke.character {
        case "mr_funny": return "MrFunny"
        case "mr_potty": return "MrPotty"
        case "mr_bad": return "MrBad"
        case "mr_love": return "MrLove"
        case "mr_sad": return "MrSad"
        default: return "MrFunny"
        }
    }

    /// Maps character ID to display name
    private var characterName: String {
        switch joke.character {
        case "mr_funny": return "Mr. Funny"
        case "mr_potty": return "Mr. Potty"
        case "mr_bad": return "Mr. Bad"
        case "mr_love": return "Mr. Love"
        case "mr_sad": return "Mr. Sad"
        default: return "Mr. Funny"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(characterImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                Text(characterName)
                    .font(.headline)
            }

            Text(joke.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Empty state snippet view when no jokes are cached
struct EmptyJokeSnippetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "face.smiling")
                .font(.largeTitle)
            Text("No jokes cached")
                .font(.headline)
            Text("Open the app to load jokes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview("Joke Snippet") {
    JokeSnippetView(joke: SharedJoke(
        id: "preview",
        setup: "Why don't scientists trust atoms?",
        punchline: "Because they make up everything!",
        character: "mr_funny",
        type: "dad_joke"
    ))
}

#Preview("Empty Snippet") {
    EmptyJokeSnippetView()
}
