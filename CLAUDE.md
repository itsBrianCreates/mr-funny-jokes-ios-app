# Mr. Funny Jokes — Claude Code Configuration

## Project Overview

iOS joke app with character personas (Mr. Funny, Mr. Potty, Mr. Bad, Mr. Love, Mr. Sad). SwiftUI + Firebase Firestore backend. Includes home/lock screen widgets, Siri integration, and infinite scroll feeds.

**Platform:** iOS 18.0+ (iPhone only)
**Architecture:** MVVM with SwiftUI
**Backend:** Firebase Firestore + Cloud Functions

---

## Code Conventions

### Class Structure

```swift
@MainActor
final class SomeViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published private(set) var isLoading = false

    private let service = SomeService.shared
}
```

- **Always** use `@MainActor` on ViewModels
- **Always** use `final class` for ViewModels and Services
- **Always** use `private(set)` for read-only published properties
- **Never** subclass — composition over inheritance

### Naming

| Type | Pattern | Example |
|------|---------|---------|
| ViewModels | `*ViewModel` | `JokeViewModel`, `CharacterDetailViewModel` |
| Views | `*View` | `JokeCardView`, `JokeFeedView` |
| Services | `*Service` | `FirestoreService`, `LocalStorageService` |
| Singletons | `static shared` | `FirestoreService.shared` |

### Haptics

All user interactions trigger haptic feedback:

```swift
HapticManager.shared.lightTap()      // Card interactions
HapticManager.shared.mediumImpact()  // Punchline reveal
HapticManager.shared.selection()     // Ratings
HapticManager.shared.success()       // Copy/share
```

### SwiftUI Guidelines

Use native SwiftUI components. Do not invent custom implementations when a native component exists.

**When custom components are OK:**
- Native components don't support the required design
- Branded visual elements (gradient cards, character avatars)
- Performance requires optimization beyond native capabilities

---

## Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| Widget uses REST API, not Firebase SDK | SDK causes deadlock issue #13070 |
| Widget deep link: `mrfunnyjokes://jotd` | URL scheme for navigation from widget |
| Cloud Functions for aggregation | Replaced local cron scripts |
| Client-side category filtering | Firestore query misses non-standard type values |
| Background load on first scroll | Preserves app launch performance |
| Session-rated visibility | Rated jokes stay visible until pull-to-refresh |
| Node.js 20 for Cloud Functions | Required by firebase-functions v7 |
| @AppStorage for promo dismissal | Simple persistent state without extra infrastructure |
| Seasonal demotion at filteredJokes level | Applied after all other filters; clean separation of concerns |
| Scoped withAnimation over implicit .animation() | Prevents scroll container animation interference on iOS 18 |
| YouTube promo as standalone LazyVStack item | Prevents scroll anchor shifts from conditional content in ForEach |

---

## Bug Prevention Patterns

### Value Copy Pitfall (SwiftUI)

**Problem:** `@State` arrays hold value copies, not references. Filtered results become stale.

**Bad:**
```swift
@State var cachedResults: [Joke] = []  // Holds stale copies
```

**Good:**
```swift
@State var cachedResultIds: [String] = []  // Store IDs
var searchResults: [Joke] {  // Lookup fresh data
    cachedResultIds.compactMap { id in
        viewModel.jokes.first { $0.firestoreId == id }
    }
}
```

### Notification Data Pitfall

**Problem:** Notifications between ViewModels need full objects, not just IDs.

**Bad:**
```swift
NotificationCenter.default.post(
    name: .jokeRatingDidChange,
    userInfo: ["jokeId": joke.id, "rating": rating]  // Missing joke object
)
```

**Good:**
```swift
let jokeData = try? JSONEncoder().encode(joke)
NotificationCenter.default.post(
    name: .jokeRatingDidChange,
    userInfo: ["jokeId": joke.id, "rating": rating, "jokeData": jokeData]
)
```

### ForEach Identity Pitfall (ScrollView)

**Problem:** `ForEach(Array(collection.enumerated()))` creates unstable identities — items get new indices when the array changes, causing scroll jumps on iOS 18.

**Bad:**
```swift
ForEach(Array(feedJokes.enumerated()), id: \.offset) { index, joke in
    JokeCardView(joke: joke)
}
```

**Good:**
```swift
ForEach(feedJokes) { joke in  // Uses Identifiable conformance
    JokeCardView(joke: joke)
}
```

### Animation on Scroll Containers Pitfall

**Problem:** `.animation()` modifiers on ScrollView/LazyVStack cause scroll position jumps when state changes (loading, offline status) trigger re-renders.

**Bad:**
```swift
ScrollView {
    LazyVStack {
        ForEach(jokes) { joke in ... }
    }
}
.animation(.default, value: viewModel.isLoadingMore)  // Disrupts scroll position
```

**Good:**
```swift
// In ViewModel — animate at the mutation site
func loadMore() async {
    let results = await fetch()
    withAnimation { self.isLoadingMore = false }  // Scoped animation
}
```

**Rule:** Always use `withAnimation` at the mutation site in the ViewModel. Never put `.animation()` on scroll containers.

### Cross-ViewModel Communication

Use Combine for notification subscriptions:

```swift
NotificationCenter.default.publisher(for: .jokeRatingDidChange)
    .sink { [weak self] notification in
        self?.handleRatingNotification(notification)
    }
    .store(in: &cancellables)
```

---

## Widget Extension Notes

The widget extension (`JokeOfTheDayWidget`) has special constraints:

- **No Firebase SDK** — Use REST API via `WidgetDataFetcher`
- **App Groups** — Shared storage via `group.com.mrfunnyjokes`
- **Fallback cache** — Main app populates cache for widget offline use
- **Deep links** — `mrfunnyjokes://jotd` opens joke detail sheet

---

## Project Structure

```
MrFunnyJokes/
├── App/                  # Entry point
├── Models/               # Data structures
├── ViewModels/           # @MainActor ObservableObject classes
├── Views/                # SwiftUI views
├── Services/             # Firebase, storage, network
├── Utilities/            # Helpers (HapticManager, SeasonalHelper, etc.)
├── Shared/               # Code shared with widget
└── JokeOfTheDayWidget/   # Widget extension
```

---

## Skills

### `/add-jokes`
Process and batch-insert jokes to Firestore. Handles categorization, duplicate checking, and Firebase schema compliance. Trigger with "add these jokes" or `/add-jokes`.

### `/CodeStory`
Generate social media content from coding session activity. Trigger with "CodeStory" or `/CodeStory`.

---

## Session Tracking

While working on this project, log notable moments to `.social-draft-{username}.md`:
- Technical wins and clever solutions
- Progress milestones
- Lessons learned and debugging adventures
- Interesting decisions and tradeoffs

Say "CodeStory" to generate social media drafts from your session notes.

---

## Quick Reference

### Valid Characters
`mr_funny`, `mr_potty`, `mr_bad`, `mr_love`, `mr_sad`

### Valid Joke Types
`dad_joke`, `knock_knock`, `pickup_line`

### Valid Tags
`animals`, `food`, `work`, `school`, `sports`, `music`, `technology`, `science`, `health`, `weather`, `holidays`, `halloween`, `thanksgiving`, `christmas`, `family`, `travel`, `wordplay`, `religious`

### Seasonal Content
- Christmas jokes identified by `tags: ["christmas"]` (only this tag — not "holidays")
- Demoted outside Nov 1 - Dec 31 via `SeasonalHelper.isChristmasSeason()`
- Demotion applied in `filteredJokes` computed properties (both `JokeViewModel` and `CharacterDetailViewModel`)
- Pattern: partition array into non-seasonal + seasonal, then concatenate

### Key Files
| File | Purpose |
|------|---------|
| `.planning/PROJECT.md` | Project context and requirements |
| `.planning/STATE.md` | Current milestone and phase status |
| `.planning/codebase/CONVENTIONS.md` | Detailed code patterns |
| `scripts/add-jokes.js` | Joke batch insertion script |
| `Utilities/SeasonalHelper.swift` | Season detection and `Joke.isChristmasJoke` extension |
