# Phase 3: Siri Integration - Research

**Researched:** 2026-01-24
**Domain:** App Intents framework for Siri voice integration (iOS 17+)
**Confidence:** HIGH

## Summary

This phase implements voice-activated joke delivery using Apple's App Intents framework. The App Intents framework (introduced iOS 16, enhanced in iOS 17/18) is the modern replacement for SiriKit Intent Definition files. It provides a Swift-native way to create Siri shortcuts, Spotlight integration, and the Shortcuts app actions.

The implementation follows a well-documented pattern: create an `AppIntent` struct that fetches a random joke from the SharedStorageService (App Groups), returns an `IntentDialog` for Siri to speak, and provides a `ShowsSnippetView` for visual display. The `AppShortcutsProvider` protocol auto-registers shortcuts, making them available immediately after app installation without user configuration.

The app already has App Groups configured (`group.com.bvanaski.mrfunnyjokes`) and SharedStorageService for widget data sharing. The Siri intent will access cached jokes through this existing infrastructure, ensuring offline support.

**Primary recommendation:** Create a `TellJokeIntent` conforming to `AppIntent` that reads from SharedStorageService and returns dialog + visual snippet, with an `AppShortcutsProvider` for auto-registration using phrases containing `.applicationName`.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| AppIntents | iOS 16+ (enhanced 17+) | Create Siri intents, shortcuts | Apple's modern framework replacing SiriKit definitions |
| SwiftUI | iOS 17+ | Visual snippet views | Native UI for intent results |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `AppShortcutsProvider` protocol | Auto-register shortcuts | Always - makes shortcuts available without user setup |
| `SiriTipView` | Discoverability | Show users the Siri phrase in-app |
| App Groups | Shared data access | Access cached jokes from intent (runs in background) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| App Intents | SiriKit Intent Definition files | Intent Definition files are legacy/deprecated; App Intents is pure Swift |
| ShowsSnippetView | openAppWhenRun=true | Opening app breaks voice-only experience |
| SharedStorageService | Direct UserDefaults | UserDefaults not accessible from extension without App Groups |

**No installation required:** App Intents is a system framework included in iOS SDK.

## Architecture Patterns

### Recommended Project Structure
```
MrFunnyJokes/
├── Intents/                    # New folder in main app target
│   ├── TellJokeIntent.swift    # The AppIntent implementation
│   ├── JokeSnippetView.swift   # SwiftUI view for visual result
│   └── MrFunnyShortcutsProvider.swift  # AppShortcutsProvider
├── Shared/
│   ├── SharedStorageService.swift  # Existing - extend for joke cache
│   └── SharedJokeOfTheDay.swift    # Existing model
```

### Pattern 1: AppIntent with Dialog and Snippet
**What:** Create an intent that returns both spoken text and visual UI
**When to use:** When Siri should speak a result AND show something on screen
**Example:**
```swift
// Source: Apple Developer Documentation, verified via web research
import AppIntents
import SwiftUI

struct TellJokeIntent: AppIntent {
    static var title: LocalizedStringResource = "Tell Me a Joke"
    static var description = IntentDescription("Tells a random joke from Mr. Funny Jokes")

    // Do NOT open app - speak the joke instead
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let joke = SharedStorageService.shared.getRandomCachedJoke() else {
            return .result(
                dialog: "I don't have any jokes cached right now. Open the app to load some!",
                view: ErrorSnippetView()
            )
        }

        let spokenText = formatJokeForSpeech(joke)
        return .result(
            dialog: IntentDialog(stringLiteral: spokenText),
            view: JokeSnippetView(joke: joke)
        )
    }
}
```

### Pattern 2: AppShortcutsProvider with Required Phrase Format
**What:** Auto-register shortcuts with voice phrases
**When to use:** Always - required for Siri to recognize your app's commands
**Example:**
```swift
// Source: Apple Developer Documentation, CreateWithSwift tutorial
import AppIntents

struct MrFunnyShortcutsProvider: AppShortcutsProvider {
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
```

### Pattern 3: Visual Snippet with Tap-to-Navigate
**What:** SwiftUI view displayed by Siri with tap action
**When to use:** When tapping the result should open the app to a specific location
**Example:**
```swift
import SwiftUI
import AppIntents

struct JokeSnippetView: View {
    let joke: SharedJoke

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(joke.characterImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                Text(joke.characterName)
                    .font(.headline)
            }
            Text(joke.text)
                .font(.body)
        }
        .padding()
        // Tapping opens app via deep link
    }
}
```

### Anti-Patterns to Avoid
- **Setting openAppWhenRun=true for voice-only intents:** Breaks the hands-free experience; user asked Siri, they want to hear it not see the app
- **Hardcoding app name in phrases:** Must use `.applicationName` placeholder or Siri won't recognize the app
- **Returning empty dialog:** Siri will say nothing, confusing users
- **Network calls in perform():** Intents run in background with limited time; network may fail; use cached data
- **Missing default initializer:** AppIntent requires `init() {}` - Swift compiler error if missing

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auto-registering shortcuts | Manual "Add to Siri" button | `AppShortcutsProvider` | Auto-registration is seamless; manual buttons are iOS 15 pattern |
| Spoken response formatting | Custom speech synthesis | `IntentDialog` | System handles voice rendering, localization, rate |
| Visual result display | Opening app to show result | `ShowsSnippetView` | Snippets show in Siri UI without launching app |
| Shortcut discoverability | Custom tooltip | `SiriTipView` | Native component, dismisses permanently after interaction |
| Pause in speech | SSML tags | Ellipsis or period | IntentDialog uses punctuation for natural pauses |

**Key insight:** App Intents framework handles the complexity of Siri integration. Custom speech synthesis or complex audio timing is unnecessary - punctuation in dialog text creates natural pauses.

## Common Pitfalls

### Pitfall 1: Missing `.applicationName` in Phrases
**What goes wrong:** Shortcuts fail to register; Siri says "I don't see an app for that"
**Why it happens:** Every phrase MUST include the `.applicationName` placeholder - this is validated at compile time
**How to avoid:** Always structure phrases as `"verb \(.applicationName)"` or `"verb with \(.applicationName)"`
**Warning signs:** App Shortcuts not appearing in Shortcuts app after install

### Pitfall 2: Intent Runs in Background - No Network
**What goes wrong:** Network calls timeout or fail silently
**Why it happens:** When `openAppWhenRun=false`, intent runs in background process with limited capabilities and network is deprioritized
**How to avoid:** Use ONLY cached/local data in `perform()`. Pre-cache data in main app.
**Warning signs:** "Something went wrong" errors when device is online

### Pitfall 3: openAppWhenRun Cannot Be Dynamic
**What goes wrong:** Trying to conditionally open app based on runtime data
**Why it happens:** `openAppWhenRun` is static and evaluated BEFORE `perform()` runs
**How to avoid:** Create separate intents with different `openAppWhenRun` values; chain with `opensIntent:` if needed
**Warning signs:** App opens when you didn't want it to, or doesn't when you did

### Pitfall 4: Testing Only in Simulator
**What goes wrong:** Works in simulator, fails on device; Siri not recognizing phrases
**Why it happens:** Siri integration has device-specific behaviors; simulator doesn't fully support voice commands
**How to avoid:** Always test on physical device. Use Shortcuts app to trigger intents during development.
**Warning signs:** "It works on my machine" syndrome

### Pitfall 5: Multilingual App Name Recognition
**What goes wrong:** Siri fails to recognize app name when spoken in non-English accent
**Why it happens:** If app name is English but user's Siri language is different, recognition fails
**How to avoid:** Add `INAlternativeAppNames` to Info.plist with phonetic/alternative spellings
**Warning signs:** User reports "Siri doesn't understand my app name"

### Pitfall 6: Forgetting Default Initializer
**What goes wrong:** Compiler error "Type 'TellJokeIntent' does not conform to protocol 'AppIntent'"
**Why it happens:** AppIntent protocol requires a default initializer `init() {}`
**How to avoid:** Always add `init() {}` to your intent struct
**Warning signs:** Cryptic protocol conformance errors

## Code Examples

Verified patterns from official sources:

### Complete TellJokeIntent Implementation
```swift
// Source: Synthesized from Apple WWDC sessions and developer tutorials
import AppIntents
import SwiftUI

struct TellJokeIntent: AppIntent {
    static var title: LocalizedStringResource = "Tell Me a Joke"
    static var description = IntentDescription("Tells a random joke from Mr. Funny Jokes")

    static var openAppWhenRun: Bool = false

    // Required default initializer
    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Get random joke from cached collection
        guard let joke = SharedStorageService.shared.getRandomCachedJoke() else {
            return .result(
                dialog: IntentDialog("I don't have any jokes cached right now. Open the app to load some!"),
                view: EmptyJokeSnippetView()
            )
        }

        // Format joke with character intro and natural pauses
        let spokenText = formatJokeForSpeech(joke)

        return .result(
            dialog: IntentDialog(stringLiteral: spokenText),
            view: JokeSnippetView(joke: joke)
        )
    }

    private func formatJokeForSpeech(_ joke: SharedJoke) -> String {
        let characterName = JokeCharacter.find(byId: joke.character ?? "mr_funny")?.name ?? "Mr. Funny"

        if joke.type == "knock_knock" {
            // Knock-knock format with dramatic pauses
            return "Here's one from \(characterName). Knock knock... Who's there?... \(joke.setup)... \(joke.punchline). Want another?"
        } else {
            // Standard joke format
            return "Here's one from \(characterName). \(joke.setup)... \(joke.punchline). Want another?"
        }
    }
}
```

### AppShortcutsProvider with Phrase Variations
```swift
// Source: Apple Developer Documentation, CreateWithSwift tutorial
import AppIntents

struct MrFunnyShortcutsProvider: AppShortcutsProvider {
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
```

### SharedStorageService Extension for Siri
```swift
// Extension to existing SharedStorageService.swift
extension SharedStorageService {
    private let cachedJokesKey = "cachedJokesForSiri"
    private let recentlyToldKey = "recentlyToldJokeIds"
    private let maxRecentlyTold = 10

    /// Save jokes for Siri access (call from main app after fetch)
    func saveCachedJokesForSiri(_ jokes: [SharedJoke]) {
        guard let defaults = sharedDefaults else { return }
        do {
            let data = try JSONEncoder().encode(jokes)
            defaults.set(data, forKey: cachedJokesKey)
        } catch {
            print("Failed to encode jokes for Siri: \(error)")
        }
    }

    /// Get random joke avoiding recent repeats
    func getRandomCachedJoke() -> SharedJoke? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: cachedJokesKey),
              let jokes = try? JSONDecoder().decode([SharedJoke].self, from: data),
              !jokes.isEmpty else {
            return nil
        }

        let recentIds = defaults.stringArray(forKey: recentlyToldKey) ?? []

        // Try to find a joke not recently told
        let unseenJokes = jokes.filter { !recentIds.contains($0.id) }
        let selectedJoke = unseenJokes.randomElement() ?? jokes.randomElement()!

        // Track this joke as recently told
        var updatedRecent = recentIds
        updatedRecent.append(selectedJoke.id)
        if updatedRecent.count > maxRecentlyTold {
            updatedRecent.removeFirst()
        }
        defaults.set(updatedRecent, forKey: recentlyToldKey)

        return selectedJoke
    }
}
```

### JokeSnippetView for Visual Display
```swift
import SwiftUI

struct JokeSnippetView: View {
    let joke: SharedJoke

    private var character: JokeCharacter {
        JokeCharacter.find(byId: joke.character ?? "mr_funny") ?? .mrFunny
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(character.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                Text(character.name)
                    .font(.headline)
                    .foregroundStyle(character.color)
            }

            Text(joke.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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
```

### SiriTipView for Discoverability
```swift
// Add to a relevant view in the app (e.g., Settings or Home)
import AppIntents

struct SiriShortcutTip: View {
    @State private var isVisible = true

    var body: some View {
        if isVisible {
            SiriTipView(intent: TellJokeIntent())
                .siriTipViewStyle(.automatic)
                .padding()
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SiriKit Intent Definition files (.intentdefinition) | App Intents framework | iOS 16 (2022) | Pure Swift, no XML files, better type safety |
| Manual "Add to Siri" button | AppShortcutsProvider auto-registration | iOS 16 | Zero-config for users; shortcuts available immediately |
| INIntentResponse for speech | IntentDialog | iOS 16 | Simpler API, better voice rendering |
| Static intents only | SnippetIntent with interactive views | iOS 18/26 | Interactive snippets (future consideration) |

**Deprecated/outdated:**
- `.intentdefinition` files: Replaced by `AppIntent` protocol
- `INIntent` subclassing: Use `AppIntent` struct conformance
- `INAddVoiceShortcutButton`: Use `SiriTipView` instead
- `INVoiceShortcutCenter`: Use `AppShortcutsProvider` auto-registration

## Open Questions

Things that couldn't be fully resolved:

1. **Exact pause timing in IntentDialog**
   - What we know: Punctuation (periods, ellipses) creates natural pauses
   - What's unclear: Exact duration of pauses cannot be controlled; no SSML support in IntentDialog
   - Recommendation: Use ellipsis `...` for dramatic pauses, test on device for timing feel

2. **Deep link navigation from snippet tap**
   - What we know: Snippets are views, but interactivity is limited to Button(intent:)
   - What's unclear: Whether tapping non-button areas can trigger app navigation (likely not without openAppWhenRun)
   - Recommendation: Use `openAppWhenRun=true` for a separate "ShowJokeInAppIntent" or rely on app's deep link URL scheme with a Link/Button

3. **Siri offline behavior in iOS 18.2+**
   - What we know: Some users report offline Siri broken in iOS 18.2
   - What's unclear: Whether App Intents are affected
   - Recommendation: Test on device; App Intents should work since they run locally, but voice recognition may require network

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation - App Intents (structure verified via multiple tutorials)
- WWDC22: Dive into App Intents - https://developer.apple.com/videos/play/wwdc2022/10032/
- WWDC25: Get to know App Intents - https://developer.apple.com/videos/play/wwdc2025/244/

### Secondary (MEDIUM confidence)
- CreateWithSwift: Performing your app actions with Siri through App Shortcuts Provider - https://www.createwithswift.com/performing-your-app-actions-with-siri-through-app-shortcuts-provider/
- Superwall: App Intents Tutorial - https://superwall.com/blog/an-app-intents-field-guide-for-ios-developers/
- AlexPaul.dev: Enhancing Your iOS App with App Intents - https://alexpaul.dev/2025/03/06/app-intents-app-shortcuts-and-siri/
- AppCoda: Integrating Siri Shortcuts into SwiftUI Apps - https://www.appcoda.com/app-intents-shortcuts/
- Instil: Hey Siri, How Do I Use App Intents? - https://instil.co/blog/siri-with-app-intents/

### Tertiary (LOW confidence)
- Medium articles on App Intents pitfalls (blocked 403, summarized from search snippets)
- Apple Developer Forums discussions on openAppWhenRun behavior

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - App Intents is the documented Apple framework for this purpose
- Architecture: HIGH - Pattern is well-established across multiple tutorials and WWDC sessions
- Pitfalls: MEDIUM - Some based on developer forum posts, not all verified firsthand

**Research date:** 2026-01-24
**Valid until:** 60 days (App Intents framework is stable, minimal iOS API changes expected)
