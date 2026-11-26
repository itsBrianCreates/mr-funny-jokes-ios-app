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
| Widget deep link: `mrfunnyjokes://jotd` | URL scheme for navigation from widget. Opens today's joke in `JokeFullScreenView` |
| Joke of the Day card (`JokeOfTheDayView`) | "Joke of the Day", the setup in `.title2` semibold, then one row: the teller's small picture and name on the left, Laugh / Share / More on the right. No date, no border, no divider, no "tap" hint. Tapping the joke or the teller opens it full screen through `\.openFullScreenJoke` (one `fullScreenCover` owned by `MainContentView`); the buttons act in place. Horrible lives under More as "Not funny" |
| Feed cards are the same card without the title (`JokeCardLayout`, `InlineJokeActions`) | Home, Search, topic and character cards end in the same row: teller on the left (joke type on a character's page), Laugh / Share / More on the right, each at least 44 by 44pt. The text and the left of the row open the joke; a card is no longer one big button. The joke type and the rating emoji left the Home card: Laugh shows a Hilarious, More shows a "Not funny". Feed counts come from the catalog copy plus this session's changes, so they can trail the live number by up to a week; the Joke of the Day and full screen read live |
| Laugh is the Hilarious rating (`LaughButton`) | No new data model: on is `rateJoke(5)`, off clears the rating. A rating change that adds or removes a laugh moves the joke's `likes` by one (`JokeEngagement.likesDelta`, applied in both view models). Before 1.4 nothing wrote `likes`; `scripts/backfill-laughs.js` carried the earlier Hilarious votes over from `rating_events`, one per device, and `--horrible` did the same for `dislikes` (both run 2026-11-25) |
| Vote counts on the rating buttons (`BinaryRatingView`) | The joke sheet shows how many people voted Hilarious and Horrible beside each label, zero included. Hilarious is the joke's `likes`; Horrible is `dislikes`, moved by `JokeEngagement.dislikesDelta` in both view models. The sheet reads both from Firestore when it opens (`JokeDetailContent.voteCounts`) and adds the reader's own change on top |
| Counts always show (`JokeEngagement`) | Laugh and Share show their number under the icon, zero included, shortened like 1.2K (`JokeEngagement.compact`). Counts are read live for the Joke of the Day and any joke opened full screen (`JokeViewModel.liveCounts`), kept apart from `jokes` so a catalog merge can't put stale counts back. Count writes never bump `updated_at` |
| Full screen joke (`JokeFullScreenView`) | The teller's color edge to edge in light mode; near black in dark, with the color kept for the punchline. No portrait or avatar: the header is the Home card's two lines of text. Opens on the setup, a tap anywhere reveals the punchline. Laugh / Share / Image sit on the flat color at the bottom. Opened from the card, the widget, the daily notification and shared links. Status bar hidden, pull down to close |
| One joke layout for screen and image (`JokeArtwork`) | Setup in heavy rounded type and the punchline in a tilted pill; knock-knock jokes become chat bubbles, chosen from the joke type. Every measurement hangs off one type size and `LargestThatFits` steps that size down until the joke fits, so a one-liner is a poster and a long joke still fits. Unrevealed parts keep their space, so nothing moves on reveal. A long punchline loses its tilt |
| Share cards (`JokeShareCardView`) | Styles Bold, Light, Dark, Big face in the teller's colors (`JokePalette`); Square 1080x1080 and Story 1080x1920 (text kept clear of the top 270 and bottom 300). Laid out at export size and rendered with `ImageRenderer`; `ShareCardPreview` scales the same view down. Footer is the teller and `mrfunnyjokes.app`, never the app name. Last style and format are remembered (`ShareCardPreferences`) |
| Share is one tap, Image is the picker (`JokeDetailContent.actionRow`) | The joke sheet's actions are one row of round buttons with a label under each, like the iOS share sheet: Share (the only filled one) sends the image in the style used last, Image opens Create image, then Save (a bookmark) and Copy. The button is called Image, not Styles: it says what you get. Rating stays as pills, so voting and actions read as two groups with no divider. The sheet opens as tall as its content (`.height` detent from the measured layout), so the actions are never cut off at half height. Pressing and holding any joke card (`.jokeCardMenu`) offers Share, Image, Open full screen, Copy and Save. `ShareStylePickerView` sets `\.colorScheme` in the environment, not `preferredColorScheme`, which turned the sheet under it dark for good |
| Every Share sends an image and a link (`JokeShareService`) | The card image plus `https://mrfunnyjokes.app/j/<firestoreId>`, from the Joke of the Day, the full screen view, the style picker and the joke sheet. Copy stays plain text. A completed share sheet or a Copy adds one to the joke's `shares` (`countShare`); a cancelled sheet adds nothing |
| Share links are Universal Links | `applinks:mrfunnyjokes.app` (Associated Domains) for `/j/*`. With the app, the link opens that joke full screen; without it, a web page built on request by the `jokePage` Cloud Function behind Firebase Hosting (`functions/joke-page.js`, `hosting/public`) with a "Get the app" button (`ct=share_card`). An unknown ID opens Home, or the home page on the web |
| Topic deep link: `mrfunnyjokes://topic/<topicId>` | Switches to Search and sets `searchNavigationPath` to that topic's `JokeDestination`, the same page as tapping it in Browse. Pushed joke pages carry `.id(destination)` so swapping one topic for another at the same depth doesn't keep the old list, and a page opened before the catalog loads fills in when it lands (new jokes are added at the end) |
| App Store rating ask (`ReviewPromptService`) | Asked with `\.requestReview` right after a joke is newly rated Hilarious, once 3 such ratings have been given across launches. Never on the first launch, never while anything is presented (it waits for the sheet to close), once per app version. State is in `UserDefaults` (`reviewPrompt*` keys). iOS may still show nothing, so `review_prompted` counts asks |
| Cloud Functions for aggregation | Replaced local cron scripts |
| Client-side category filtering | Firestore query misses non-standard type values. The whole catalog is in memory, so picking a category fetches nothing |
| Whole catalog on the device (`JokeCatalogService`) | Feeds are built from a local copy of every joke, not a "top N by `popularity_score`" query. That query returned the same jokes every launch (the score is 0 on every document). First sync downloads everything; later syncs fetch only documents whose `updated_at` moved; a full re-download runs weekly to drop deleted jokes. Any script that edits a joke must bump `updated_at` or installed apps won't see the edit for up to a week |
| Fresh-first order, fixed per visit (`JokeFeedOrdering`) | Home and character feeds share one order: unseen jokes added in the last 30 days, other unseen, scrolled past but never opened, then opened or rated (the last two least recently seen first). Computed once at launch, pull-to-refresh, or return after 30+ minutes in the background, never while scrolling, so cards don't move under the reader. Seen/opened/rated jokes drop down on the next visit |
| First launch opens on 30 starter jokes (`StarterJokes.json`) | A new install has no catalog, and waiting for the download kept people on the splash. The starter jokes are real catalog jokes (same document IDs) shipped in the app; the catalog is merged in behind them when it lands, without moving any card already in the feed (`mergeCatalogKeepingOrder`). The in-season shortcut on Home waits for the next fresh feed, since it would push cards down. If the download fails it is tried again when the connection returns or the app is reopened (`downloadCatalogIfMissing`). On a normal connection the whole catalog arrives behind the splash and the starter jokes are never seen |
| Home waits on the network for 1.5s at most (`launchNetworkBudget`) | The splash lifts once what's on the device is shown and the catalog sync and joke of the day have answered or 1.5s have passed, whichever is first. Late answers go in without moving cards: the catalog is merged, the joke of the day replaces a placeholder of the same height |
| Topics live in the Search tab (`JokeTopic`, `TopicBrowseView`) | Browsing by subject is a grid shown on the Search tab until the person types; the Home filter stays joke-type only. A topic is a curated group of one or more tags and appears only once it has 15 jokes, so the list stays short (13 today) and thin topics show up by themselves when the catalog fills them. `wordplay` is not a topic: most jokes carry it. The in-season topic also gets a one-row shortcut on Home |
| One row of chips on the opened joke (`JokeLinksRow`) | Teller, joke type and up to two topics, each a chip that opens more jokes like it. One rule: a capsule is tappable. The page you're already on shows as plain text; a teller with one joke type (Mr. Love) shows no type chip. Chips look ~30pt tall but have a 44pt tap area. Chips that don't fit move into a native "…" menu, so the row is always one line. Never on cards: a topic there can give the punchline away |
| Joke pages open through `\.openJokes` and `JokeDestination` | Every tab's `NavigationStack` is path-based, registers the pages once with `.jokeDestinations(viewModel:)`, and supplies its own open action, so a character, joke-type or topic page opens in the current tab on top of any page. `JokeDetailSheet` wraps the action to close the sheet first. Pages set `\.currentJokeDestination` so jokes there don't link back to them |
| Search field pinned with `.navigationBarDrawer(displayMode: .always)` | The browse grid scrolls, and the default drawer hides the field until pulled down |
| `Joke.id` derived from the Firestore ID | Same UUID every time a joke is decoded, so selection and scroll anchors survive a catalog sync |
| Node.js 22 for Cloud Functions | Node.js 20 was retired by Google on 2026-10-30; nothing deploys on it |
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

### Deep Links
URL scheme `mrfunnyjokes://`, handled in `MainContentView.handleDeepLink`:

| Link | Opens |
|------|-------|
| `mrfunnyjokes://jotd` | Home, with the joke of the day full screen (widgets use this) |
| `mrfunnyjokes://joke/<jokeId>` | That joke full screen, the same as a shared link. An unknown ID opens Home |
| `https://mrfunnyjokes.app/j/<jokeId>` | Universal Link in shared jokes. Same as above; logs `share_link_opened` |
| `mrfunnyjokes://home` | Home tab |
| `mrfunnyjokes://me` | Me tab |
| `mrfunnyjokes://search` | Search tab |
| `mrfunnyjokes://topic/<topicId>` | That topic's page on the Search tab, e.g. `topic/christmas`, `topic/thanksgiving`. IDs are `JokeTopic.all` ids. An unknown ID just opens Search |

Test in the simulator: `xcrun simctl openurl booted "mrfunnyjokes://topic/christmas"`. A Universal Link only opens the app once `mrfunnyjokes.app` is serving the association file; until then test the joke page with `mrfunnyjokes://joke/<jokeId>`.

### Sharing Analytics
| Event | Parameters |
|-------|------------|
| `joke_laughed` | `joke_id`, `character`, `surface` (`home_card`, `full_screen`, `feed_card`) |
| `share_started` | `joke_id`, `surface` (`home_card`, `full_screen`, `more_menu`, `style_picker`, `joke_sheet`, `card_menu`, `feed_card`) |
| `share_completed` | `joke_id`, `style` (`bold`, `light`, `dark`, `big_face`), `format` (`square`, `story`), `destination` (the share sheet's activity type) |
| `share_link_opened` | `joke_id` |

### Checking Share Cards
Debug builds write every style and format for a spread of joke shapes (short, long, one-liner, mid-sentence, knock-knock) to the app's `Documents/ShareCards`:

`xcrun simctl launch booted com.mrfunnyjokes.app -renderShareCards`

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
| `functions/joke-page.js` | The mrfunnyjokes.app joke and home pages |
| `hosting/public/.well-known/apple-app-site-association` | Which links open the app (`/j/*`) |
| `Utilities/SeasonalHelper.swift` | Season detection and `Joke.isChristmasJoke` extension |
