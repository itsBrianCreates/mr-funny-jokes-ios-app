import AppIntents
import SwiftUI

/// App Intent for Siri voice-activated joke delivery
/// Users say "Hey Siri, tell me a joke from Mr. Funny Jokes" and Siri speaks the joke
struct TellJokeIntent: AppIntent {
    static var title: LocalizedStringResource = "Tell Me a Joke"
    static var description = IntentDescription("Tells a random joke from Mr. Funny Jokes")

    /// Do NOT open app - speak the joke instead (hands-free experience)
    static var openAppWhenRun: Bool = false

    /// Required default initializer for AppIntent protocol
    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let joke = SharedStorageService.shared.getRandomCachedJoke() else {
            return .result(
                dialog: IntentDialog("I don't have any jokes cached right now. Open the app to load some!"),
                view: EmptyJokeSnippetView()
            )
        }

        let spokenText = formatJokeForSpeech(joke)
        return .result(
            dialog: IntentDialog(stringLiteral: spokenText),
            view: JokeSnippetView(joke: joke)
        )
    }

    /// Format joke text for natural speech delivery
    /// Includes character intro and natural pauses using punctuation
    private func formatJokeForSpeech(_ joke: SharedJoke) -> String {
        let characterName = getCharacterName(joke.character)

        if joke.type == "knock_knock" {
            // Knock-knock format with dramatic pauses (per CONTEXT.md)
            return "Here's one from \(characterName). \(joke.setup)... \(joke.punchline). Want another?"
        } else {
            // Standard joke format with natural pause between setup and punchline
            return "Here's one from \(characterName). \(joke.setup)... \(joke.punchline). Want another?"
        }
    }

    /// Map character ID to display name
    private func getCharacterName(_ characterId: String?) -> String {
        guard let id = characterId else { return "Mr. Funny" }

        switch id {
        case "mr_funny": return "Mr. Funny"
        case "mr_potty": return "Mr. Potty"
        case "mr_bad": return "Mr. Bad"
        case "mr_love": return "Mr. Love"
        case "mr_sad": return "Mr. Sad"
        default: return "Mr. Funny"
        }
    }
}
