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
| Client-side category filtering | Firestore query misses non-standard type values. The whole catalog is in memory, so picking a category fetches nothing |
| Whole catalog on the device (`JokeCatalogService`) | Feeds are built from a local copy of every joke, not a "top N by `popularity_score`" query. That query returned the same jokes every launch (the score is 0 on every document). First sync downloads everything; later syncs fetch only documents whose `updated_at` moved; a full re-download runs weekly to drop deleted jokes. Any script that edits a joke must bump `updated_at` or installed apps won't see the edit for up to a week |
| Fresh-first order, fixed per visit (`JokeFeedOrdering`) | Home and character feeds share one order: unseen jokes added in the last 30 days, other unseen, scrolled past but never opened, then opened or rated (the last two least recently seen first). Computed once at launch, pull-to-refresh, or return after 30+ minutes in the background, never while scrolling, so cards don't move under the reader. Seen/opened/rated jokes drop down on the next visit |
| Topics live in the Search tab (`JokeTopic`, `TopicBrowseView`) | Browsing by subject is a grid shown on the Search tab until the person types; the Home filter stays joke-type only. A topic is a curated group of one or more tags and appears only once it has 15 jokes, so the list stays short (13 today) and thin topics show up by themselves when the catalog fills them. `wordplay` is not a topic: most jokes carry it. The in-season topic also gets a one-row shortcut on Home |
| Search field pinned with `.navigationBarDrawer(displayMode: .always)` | The browse grid scrolls, and the default drawer hides the field until pulled down |
| `Joke.id` derived from the Firestore ID | Same UUID every time a joke is decoded, so selection and scroll anchors survive a catalog sync |
| Node.js 20 for Cloud Functions | Required by firebase-functions v7 |
| @AppStorage for promo dismissal | Simple persistent state without extra infrastructure |
| Seasonal demotion at filteredJokes level | Applied after all other filters; clean separation of concerns |
| Scoped withAnimation over implicit .animation() | Prevents scroll container animation interference on iOS 18 |
| YouTube promo as standalone LazyVStack item | Prevents scroll anchor shifts from conditional content in ForEach |
| `JokeListDetailView` for Home, Me, Search and character pages | One list-detail container, so jokes open the same way everywhere: sheet on compact widths, pane beside the list at 700pt+ (iPhone Duo inner display). Selection is a joke ID so it survives fold/unfold |
| `\.isWideLayout` environment value set in `MainContentView` | Sheets can't measure the window they're presented over; the root measures once and every tab, pushed screen and sheet reads it |
| Large-only sheet detent when `isWideLayout` | Wide windows are short (Duo inner display is 951×669pt); a medium sheet cuts off rating and actions |
| Blank line in `text` marks the punchline | Firestore keeps one `text` field: setup, blank line, punchline. `JokeTextParser` (in `Shared/`, used by app and widget) splits on it; cards, widgets and notifications show `cardText` only. Where to split a one-liner is an editorial call no heuristic gets right, so it lives in the data. Never re-create a joke document to fix its text: saved jokes, ratings and rankings are keyed by document ID |
| Build with the iOS 27 SDK for iPhone Duo | A 26.x-SDK build runs letterboxed at phone size on the inner display |

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

### Stretched Grid Card Pitfall

**Problem:** Cards in a `LazyVGrid` row stretch to the tallest card. Pinning a card's bottom row with a flexible frame lets that row steal height from the text above, which then truncates to one line. A `Spacer` avoids that but doubles the `VStack` spacing on every card.

**Good:**
```swift
Text(joke.setup)
    .fixedSize(horizontal: false, vertical: true)  // Text keeps all its lines

metadataRow
    .frame(maxHeight: .infinity, alignment: .bottom)  // Row takes what's left
```

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
`animals`, `food`, `work`, `school`, `sports`, `music`, `technology`, `science`, `health`, `weather`, `nature`, `holidays`, `halloween`, `thanksgiving`, `christmas`, `family`, `travel`, `romantic`, `movies`, `wordplay`, `religious`

Tags decide which topic a joke shows under in the Search tab (see `JokeTopic.all`). A joke tagged only `wordplay` appears under no topic. `scripts/normalize-tags.js` merges stray tags into these, in place

### Seasonal Content
- Holiday jokes are identified by tag: `christmas`, `thanksgiving`, `halloween` (only these — not "holidays")
- Feed seasons (`SeasonalHelper`): Christmas Nov 1 - Dec 31, Thanksgiving Nov 1 - Thanksgiving Day, Halloween Oct 1 - Oct 31. Outside its season a holiday joke sinks to the bottom of feeds (`Joke.isOutOfSeason`, applied in `filteredJokes` of both `JokeViewModel` and `CharacterDetailViewModel`) and is left out of the JOTD fallback pool
- Home card and top of the topic grid (`JokeTopic.isInSeason`): Halloween Oct 1 - Oct 31, Thanksgiving Nov 1 - Thanksgiving Day, Christmas from the day after Thanksgiving through Dec 31. The windows don't overlap, so only one holiday is featured at a time. A holiday needs 15 jokes to get a card
- Thanksgiving is computed as the fourth Thursday of November
- Pattern: partition array into in-season + out-of-season, then concatenate

### Joke Text Format
- Stored `text` = setup + blank line + punchline. `scripts/add-jokes.js` takes `setup` and `punchline` and builds it; a joke with no punchline is rejected
- A setup may stop mid-sentence (`"Is it hot in here,"` / `"or is it just you?"`); the app adds the trailing "…" on cards and rejoins the sentence for share/copy
- Knock-knock: setup is three lines (`Knock, knock.` / `Who's there?` / `Name.`), punchline is `Name who?` plus the answer
- Older single-line knock-knocks are still parsed (name-based, so "Honey bee" works)
- `scripts/resplit-jokes.js` changes where existing jokes split, in place (text only, same document IDs)

### Key Files
| File | Purpose |
|------|---------|
| `.planning/PROJECT.md` | Project context and requirements |
| `.planning/STATE.md` | Current milestone and phase status |
| `.planning/codebase/CONVENTIONS.md` | Detailed code patterns |
| `scripts/add-jokes.js` | Joke batch insertion script |
| `Utilities/SeasonalHelper.swift` | Season detection and `Joke.isChristmasJoke` extension |
