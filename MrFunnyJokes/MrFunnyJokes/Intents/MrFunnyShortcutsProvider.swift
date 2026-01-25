import AppIntents

/// Provides App Shortcuts for automatic Siri registration
/// Shortcuts appear in the Shortcuts app immediately after installation
struct MrFunnyShortcutsProvider: AppShortcutsProvider {
    /// App Shortcuts that are automatically registered with Siri
    /// CRITICAL: Every phrase MUST include `.applicationName` for Siri to recognize the app
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TellJokeIntent(),
            phrases: [
                "Tell me a joke from \(.applicationName)",
                "Tell me a joke with \(.applicationName)",
                "Give me a joke from \(.applicationName)"
            ],
            shortTitle: "Tell Me a Joke",
            systemImageName: "face.smiling"
        )
    }
}
