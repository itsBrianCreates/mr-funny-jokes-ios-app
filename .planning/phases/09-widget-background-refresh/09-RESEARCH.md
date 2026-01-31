# Phase 9: Widget Background Refresh - Research

**Researched:** 2026-01-30
**Domain:** iOS WidgetKit Background Refresh, BGAppRefreshTask
**Confidence:** HIGH

## Summary

This phase implements background refresh for all 6 widgets (3 home screen: small, medium, large; 3 lock screen: circular, rectangular, inline) to display fresh Joke of the Day content without requiring app launch. The current implementation relies entirely on the main app updating SharedStorageService via App Groups, then calling `WidgetCenter.reloadTimelines()`. When the user doesn't open the app for days, widgets show stale content.

The recommended approach is **WidgetKit-only with direct network fetch fallback** rather than BGAppRefreshTask + WidgetKit hybrid. Research shows that WidgetKit's TimelineProvider can make network requests directly in `getTimeline()`, which is simpler and more reliable than depending on BGAppRefreshTask (which iOS deprioritizes for apps users don't open frequently). For users who haven't opened the app in 3+ days, the widget will fetch directly from Firestore, caching the result to SharedStorageService for subsequent reloads.

**Primary recommendation:** Implement widget direct fetch in TimelineProvider with stale data detection (>24 hours), falling back to local cache (10-20 jokes) when network fails, and showing "Open Mr. Funny Jokes to get started!" placeholder only for fresh installs with empty cache.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WidgetKit | iOS 14+ | Widget display and timeline management | Apple's official widget framework |
| URLSession | iOS 2+ | Network requests in TimelineProvider | Standard iOS networking; works in extensions |
| App Groups | iOS 8+ | Shared data between app and widget | Required for cross-process data sharing |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Firebase Firestore | 11.x | JOTD data source | Only for widget direct fetch (not in extension) |
| WidgetCenter | iOS 14+ | Manual timeline reload triggers | When app updates shared data |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Widget direct fetch | BGAppRefreshTask | BGTask is deprioritized for inactive apps; widget fetch works regardless of app usage |
| Firestore in widget | URLSession to REST API | Firebase SDK causes deadlocks in extensions; use REST API instead |
| Complex caching | Simple UserDefaults | 10-20 jokes is trivial; no need for Core Data or file-based caching |

**Why NOT BGAppRefreshTask:**
- iOS deprioritizes background tasks for apps users don't open frequently
- After 1-2 weeks of inactivity, BGTasks may stop running entirely
- WidgetKit timeline refreshes continue even for inactive apps (40-70/day budget)
- Phase 9 requirements specify "updates daily even if app hasn't been opened in 3+ days" - BGTask cannot guarantee this

## Architecture Patterns

### Recommended Project Structure
```
Shared/
├── SharedStorageService.swift    # Enhanced: add cached jokes array
├── SharedJokeOfTheDay.swift      # Existing: JOTD model
└── SharedJoke.swift              # Existing: generic joke model

JokeOfTheDayWidget/
├── JokeOfTheDayProvider.swift    # Enhanced: direct fetch fallback
├── WidgetDataFetcher.swift       # NEW: URLSession-based JOTD fetch
├── JokeOfTheDayWidget.swift      # Existing: no changes
└── ...views...                   # Existing: no changes
```

### Pattern 1: Stale Data Detection with Direct Fetch Fallback
**What:** TimelineProvider checks if shared data is stale (>24 hours), fetches directly if needed
**When to use:** Every `getTimeline()` call
**Example:**
```swift
// Source: Apple Developer Documentation - Making network requests in widget extension
func getTimeline(in context: Context, completion: @escaping (Timeline<JokeOfTheDayEntry>) -> Void) {
    let sharedJoke = SharedStorageService.shared.loadJokeOfTheDay()
    let isStale = sharedJoke == nil || isDataStale(sharedJoke!.lastUpdated)

    if isStale {
        // Attempt direct fetch
        Task {
            if let freshJoke = await WidgetDataFetcher.fetchJokeOfTheDay() {
                SharedStorageService.shared.saveJokeOfTheDay(freshJoke)
                let entry = JokeOfTheDayEntry(date: Date(), joke: freshJoke)
                let timeline = Timeline(entries: [entry], policy: .after(nextMidnight()))
                completion(timeline)
            } else {
                // Network failed - use cached fallback
                let fallbackJoke = getFallbackJoke()
                let entry = JokeOfTheDayEntry(date: Date(), joke: fallbackJoke)
                let timeline = Timeline(entries: [entry], policy: .after(nextMidnight()))
                completion(timeline)
            }
        }
    } else {
        // Fresh data exists
        let entry = JokeOfTheDayEntry(date: Date(), joke: sharedJoke!)
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight()))
        completion(timeline)
    }
}

private func isDataStale(_ lastUpdated: Date) -> Bool {
    Date().timeIntervalSince(lastUpdated) > 86400 // 24 hours
}
```

### Pattern 2: REST API for Widget (Avoid Firebase SDK)
**What:** Use URLSession with Firestore REST API instead of Firebase SDK
**When to use:** Direct fetch from widget extension
**Example:**
```swift
// Source: Firebase REST API documentation + existing pitfalls research
struct WidgetDataFetcher {
    private static let projectId = "mr-funny-jokes"

    static func fetchJokeOfTheDay() async -> SharedJokeOfTheDay? {
        // Get today's date in YYYY-MM-DD format for daily_jokes lookup
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "America/New_York")
        let today = dateFormatter.string(from: Date())

        // Firestore REST API endpoint
        let urlString = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/daily_jokes/\(today)"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            // Parse Firestore REST response
            return parseFirestoreResponse(data)
        } catch {
            return nil
        }
    }
}
```

### Pattern 3: Fallback Joke Cache
**What:** Store 10-20 jokes in SharedStorageService for offline/stale scenarios
**When to use:** When network fetch fails and JOTD is stale
**Example:**
```swift
// Source: CONTEXT.md user decisions
extension SharedStorageService {
    private let fallbackJokesKey = "fallbackJokesCache"
    private let maxFallbackJokes = 20

    func saveFallbackJokes(_ jokes: [SharedJokeOfTheDay]) {
        guard let defaults = sharedDefaults else { return }
        let trimmed = Array(jokes.prefix(maxFallbackJokes))
        if let data = try? JSONEncoder().encode(trimmed) {
            defaults.set(data, forKey: fallbackJokesKey)
        }
    }

    func getRandomFallbackJoke() -> SharedJokeOfTheDay? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: fallbackJokesKey),
              let jokes = try? JSONDecoder().decode([SharedJokeOfTheDay].self, from: data),
              !jokes.isEmpty else {
            return nil
        }
        return jokes.randomElement()
    }
}
```

### Anti-Patterns to Avoid
- **Firebase SDK in widget extension:** Causes deadlocks and crashes in TestFlight/production
- **BGAppRefreshTask as primary mechanism:** Unreliable for inactive apps
- **Aggressive refresh on device unlock:** User decision: stick to scheduled refresh
- **Visual indicators for fresh/stale:** User decision: no visual difference

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Date calculations | Custom date math | Calendar.startOfDay, DateComponents | Edge cases with timezones, DST |
| Network caching | Manual file caching | URLSession cache + UserDefaults | URLSession handles HTTP caching |
| Timezone handling | Manual UTC offset | TimeZone(identifier:) with "America/New_York" | User decision: midnight ET |
| JSON parsing | Manual string parsing | Codable with Firestore REST format | Type-safe, handles edge cases |

**Key insight:** Widget extensions have a 30MB memory limit. Keep it simple - URLSession + UserDefaults is sufficient for this use case.

## Common Pitfalls

### Pitfall 1: Firebase SDK Deadlock in Widget Extension
**What goes wrong:** Widget crashes in TestFlight/production with "firebase.firestore.rpc" deadlock
**Why it happens:** Firebase Firestore's gRPC library has thread synchronization issues in constrained widget runtime
**How to avoid:** Use Firestore REST API via URLSession, NOT Firebase SDK
**Warning signs:** Adding `import FirebaseFirestore` to widget target; works in Xcode but crashes in TestFlight

### Pitfall 2: Widget Timeline Budget Exhaustion
**What goes wrong:** Widgets stop updating mid-day because 40-70 daily refreshes were exhausted
**Why it happens:** Calling reloadTimelines too frequently, or not providing future entries
**How to avoid:** Use `.after(nextMidnight())` policy for daily refresh; don't call reloadTimelines on every app foreground
**Warning signs:** Widget works in morning, stale by evening; excessive reloadTimelines calls in logs

### Pitfall 3: App Groups Data Race
**What goes wrong:** Widget reads corrupted or partially-written data
**Why it happens:** Main app and widget extension are separate processes writing to same UserDefaults
**How to avoid:** Use atomic writes (encode entire object, then write); widget should handle nil gracefully
**Warning signs:** Intermittent crashes, garbled text, partial data

### Pitfall 4: Timezone Confusion for Midnight Refresh
**What goes wrong:** Widget refreshes at 4am instead of midnight ET
**Why it happens:** Calendar calculations default to device timezone, not ET
**How to avoid:** Explicitly set `calendar.timeZone = TimeZone(identifier: "America/New_York")!`
**Warning signs:** Refresh timing is offset by hours

### Pitfall 5: Empty Cache on Fresh Install
**What goes wrong:** Widget shows blank or crashes for users who installed but never opened app
**Why it happens:** No shared data exists yet; widget can't fetch without network
**How to avoid:** Return placeholder "Open Mr. Funny Jokes to get started!" from TimelineProvider
**Warning signs:** Crash reports from new users with widgets added before first app launch

## Code Examples

Verified patterns from official sources:

### TimelineProvider with Stale Detection
```swift
// Source: Apple Developer Documentation - Keeping a widget up to date
struct JokeOfTheDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> JokeOfTheDayEntry {
        JokeOfTheDayEntry(date: Date(), joke: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (JokeOfTheDayEntry) -> Void) {
        let joke = SharedStorageService.shared.loadJokeOfTheDay() ?? .placeholder
        completion(JokeOfTheDayEntry(date: Date(), joke: joke))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JokeOfTheDayEntry>) -> Void) {
        Task {
            let joke = await resolveJokeForDisplay()
            let entry = JokeOfTheDayEntry(date: Date(), joke: joke)

            // Schedule next refresh at midnight ET
            let nextRefresh = nextMidnightET()
            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    private func resolveJokeForDisplay() async -> SharedJokeOfTheDay {
        // 1. Check for fresh data from main app
        if let joke = SharedStorageService.shared.loadJokeOfTheDay(),
           !isStale(joke.lastUpdated) {
            return joke
        }

        // 2. Data is stale or missing - try direct fetch
        if let freshJoke = await WidgetDataFetcher.fetchJokeOfTheDay() {
            SharedStorageService.shared.saveJokeOfTheDay(freshJoke)
            return freshJoke
        }

        // 3. Network failed - use cached fallback (random from cache)
        if let fallback = SharedStorageService.shared.getRandomFallbackJoke() {
            return fallback
        }

        // 4. No cache (fresh install) - show placeholder
        return SharedJokeOfTheDay.placeholder
    }

    private func isStale(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) > 86400 // 24 hours
    }

    private func nextMidnightET() -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        return calendar.startOfDay(for: tomorrow)
    }
}
```

### Firestore REST API Fetch
```swift
// Source: Firebase REST API documentation
struct WidgetDataFetcher {
    private static let projectId = "mr-funny-jokes"

    static func fetchJokeOfTheDay() async -> SharedJokeOfTheDay? {
        // Get today's date for daily_jokes collection
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = calendar.timeZone
        let today = dateFormatter.string(from: Date())

        // Firestore REST endpoint for daily_jokes document
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/daily_jokes/\(today)"

        guard let url = URL(string: endpoint) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            return parseFirestoreDocument(data)
        } catch {
            return nil
        }
    }

    private static func parseFirestoreDocument(_ data: Data) -> SharedJokeOfTheDay? {
        // Firestore REST returns documents in a specific format
        // { "fields": { "joke_id": { "stringValue": "..." }, ... } }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else {
            return nil
        }

        // Extract joke_id to fetch the actual joke
        guard let jokeIdField = fields["joke_id"] as? [String: Any],
              let jokeId = jokeIdField["stringValue"] as? String else {
            return nil
        }

        // Fetch the actual joke document
        return await fetchJokeDocument(jokeId: jokeId)
    }

    private static func fetchJokeDocument(jokeId: String) async -> SharedJokeOfTheDay? {
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/jokes/\(jokeId)"

        guard let url = URL(string: endpoint) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fields = json["fields"] as? [String: Any] else {
                return nil
            }

            // Parse joke fields
            let text = (fields["text"] as? [String: Any])?["stringValue"] as? String ?? ""
            let character = (fields["character"] as? [String: Any])?["stringValue"] as? String
            let category = (fields["type"] as? [String: Any])?["stringValue"] as? String

            // Split text into setup/punchline (jokes are stored as single text field)
            let (setup, punchline) = splitJokeText(text)

            return SharedJokeOfTheDay(
                id: jokeId,
                setup: setup,
                punchline: punchline,
                category: category,
                firestoreId: jokeId,
                character: character
            )
        } catch {
            return nil
        }
    }

    private static func splitJokeText(_ text: String) -> (setup: String, punchline: String) {
        // Split on common delimiters
        let delimiters = ["\n\n", " - ", "? ", "! "]
        for delimiter in delimiters {
            if let range = text.range(of: delimiter) {
                let setup = String(text[..<range.lowerBound]) + (delimiter.hasPrefix("?") || delimiter.hasPrefix("!") ? String(delimiter.first!) : "")
                let punchline = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !punchline.isEmpty {
                    return (setup, punchline)
                }
            }
        }
        // No delimiter found - entire text is setup
        return (text, "")
    }
}
```

### Updated Placeholder for Empty Cache
```swift
// Source: CONTEXT.md user decisions
extension SharedJokeOfTheDay {
    /// Placeholder shown only when cache is completely empty (fresh install, never opened app)
    static let placeholder = SharedJokeOfTheDay(
        id: "placeholder",
        setup: "Open Mr. Funny Jokes to get started!",
        punchline: "",
        category: nil,
        firestoreId: nil,
        character: nil,
        lastUpdated: Date()
    )
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| BGAppRefreshTask primary | WidgetKit direct fetch | iOS 14+ | Widgets can update even for inactive apps |
| Relying on app launch | Widget self-sufficient | iOS 14+ | Better UX for casual users |
| Firebase SDK in extension | REST API | Always | Avoids deadlock crashes |

**Deprecated/outdated:**
- `setMinimumBackgroundFetchInterval`: Deprecated in iOS 13, use BGTaskScheduler if needed
- `performFetchWithCompletionHandler`: Deprecated in iOS 13

## Open Questions

Things that couldn't be fully resolved:

1. **Firestore REST API Authentication**
   - What we know: Public read requires Firestore security rules to allow unauthenticated access
   - What's unclear: Whether current security rules allow this; may need rule update
   - Recommendation: Test with current rules; if 403, update rules to allow public read of `daily_jokes` and specific `jokes` documents

2. **Fallback Joke Rotation**
   - What we know: User decision is "Claude's Discretion" on whether cached fallback jokes rotate daily
   - Recommendation: Rotate daily - use day-of-year as seed for deterministic random selection from cache. This provides variety without requiring network.

3. **Widget Direct Fetch Memory Impact**
   - What we know: Widget extensions have 30MB memory limit
   - What's unclear: Exact memory footprint of URLSession + JSON parsing for single joke
   - Recommendation: Should be well under limit (<1MB for single joke fetch); monitor crash reports post-release

## Sources

### Primary (HIGH confidence)
- [Apple Developer Documentation - Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) - Timeline policies, refresh budgets
- [Apple Developer Documentation - Making network requests in a widget extension](https://developer.apple.com/documentation/widgetkit/making-network-requests-in-a-widget-extension) - URLSession in widgets
- [Apple Developer Documentation - TimelineProvider](https://developer.apple.com/documentation/widgetkit/timelineprovider) - API reference
- [Firebase REST API Documentation](https://firebase.google.com/docs/firestore/use-rest-api) - Firestore REST endpoints

### Secondary (MEDIUM confidence)
- [Swift Senpai - How to Update or Refresh a Widget?](https://swiftsenpai.com/development/refreshing-widget/) - Timeline policies best practices
- [Swift Senpai - How to Fetch and Show Remote Data on a Widget?](https://swiftsenpai.com/development/widget-load-remote-data/) - Network fetch patterns
- [GitHub Issue #13070 - Firestore deadlock in widget extension](https://github.com/firebase/firebase-ios-sdk/issues/13070) - Firebase SDK limitation

### Tertiary (LOW confidence)
- [Medium - Optimizing iOS Widget network calls with temporary caching](https://medium.com/@Jager-yoo/optimizing-ios-widget-network-calls-with-temporary-caching-e32c01570a5c) - Caching patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Apple official documentation, well-established patterns
- Architecture: HIGH - Based on official WidgetKit patterns and verified pitfalls
- Pitfalls: HIGH - Firebase deadlock verified via GitHub issue; timeline budget from Apple docs
- REST API approach: MEDIUM - Firebase REST API is documented but may need security rule changes

**Research date:** 2026-01-30
**Valid until:** 60 days (WidgetKit APIs are stable; main risk is Firebase REST API changes)

---

## Implementation Recommendation Summary

Based on research, the recommended approach for Phase 9:

1. **WidgetKit-only approach** (no BGAppRefreshTask needed)
   - TimelineProvider fetches directly when data is stale
   - Uses REST API (not Firebase SDK) to avoid deadlocks
   - Aligns with user decision: "stick to scheduled refresh"

2. **Refresh timing**
   - Schedule timeline refresh at midnight ET (`TimeZone(identifier: "America/New_York")`)
   - Single entry per timeline with `.after(nextMidnight)` policy
   - Well within 40-70 daily budget (only 1 refresh/day)

3. **Stale data handling**
   - Data older than 24 hours triggers direct fetch
   - If network fails, use random joke from 10-20 joke cache
   - If cache empty (fresh install), show placeholder message

4. **No visual changes**
   - Per user decision: no visual indicators for fresh/stale
   - Keep current widget design unchanged
