# Technology Stack: v1.1.0 Rating Simplification & All-Time Top 10

**Project:** Mr. Funny Jokes
**Researched:** 2026-02-17
**Overall Confidence:** HIGH (verified against existing codebase patterns, Apple docs, Firebase docs)

---

## Executive Summary

This milestone requires **zero new dependencies**. Every capability needed -- binary rating UI, data migration, all-time aggregation -- is achievable with the existing SwiftUI, Firebase Firestore, and Cloud Functions stack. The changes are refactoring-heavy, not library-heavy.

The existing codebase already contains patterns for every piece of this milestone:
- Segmented `Picker` for Hilarious/Horrible toggle (in `MonthlyTopTenDetailView.swift`)
- Rating event logging that only captures values 1 and 5 (in `JokeViewModel.swift`)
- Batch migration scripts with dry-run support (in `scripts/migrate-holiday-tags.js`)
- Cloud Function aggregation logic (in `functions/index.js`)

The primary work is removing complexity (5-point scale, time-windowed queries, 5-section Me tab) and simplifying to binary choices throughout.

---

## Recommended Stack Changes

### 1. Rating UI: Native `Picker` with `.segmented` Style

| Aspect | Decision |
|--------|----------|
| **Component** | `Picker` with `.pickerStyle(.segmented)` |
| **Why** | Already used in `MonthlyTopTenDetailView.swift` (lines 54-58) for the Hilarious/Horrible toggle -- proven pattern in this codebase |
| **Why not custom** | Native segmented control handles accessibility, dynamic type, dark mode, and RTL automatically. Two options is the ideal use case. |
| **Confidence** | HIGH -- verified in existing codebase and [Apple SegmentedPickerStyle docs](https://developer.apple.com/documentation/swiftui/segmentedpickerstyle) |

**Implementation pattern (reuses existing `RankingType` enum):**

```swift
// Already exists in FirestoreModels.swift (lines 196-222)
enum RankingType: String, CaseIterable, Identifiable {
    case hilarious = "Hilarious"
    case horrible = "Horrible"
    var id: String { rawValue }
    var emoji: String { ... }
}

// Rating UI in JokeDetailSheet -- same pattern as MonthlyTopTenDetailView
Picker("Rating", selection: $selectedRating) {
    ForEach(RankingType.allCases) { type in
        Text("\(type.emoji) \(type.rawValue)").tag(type)
    }
}
.pickerStyle(.segmented)
```

**What replaces what:**

| Current Component | Replacement | File |
|-------------------|-------------|------|
| `GroanOMeterView` (5-emoji drag slider) | `Picker(.segmented)` with Hilarious/Horrible | `GrainOMeterView.swift` |
| `CompactGroanOMeterView` (single emoji badge) | Binary emoji badge (only shows Hilarious or Horrible emoji) | `GrainOMeterView.swift` |
| `Joke.ratingEmojis` (5-element array) | Simplified to 2 emojis | `Joke.swift` |
| `Joke.ratingEmoji` (5-way switch) | Binary switch (1 or 5) | `Joke.swift` |

**What NOT to do:**
- Do NOT build a custom segmented control. The native `Picker(.segmented)` handles all styling and is already used in the codebase.
- Do NOT use a `Toggle` -- semantically wrong for a rating. Toggle implies on/off state, not positive/negative assessment.

### 2. Joke Model: Keep `userRating: Int?`, Constrain to Binary Values

| Aspect | Decision |
|--------|----------|
| **Current** | `userRating: Int?` (1-5 scale) |
| **New** | `userRating: Int?` (1 = Horrible, 5 = Hilarious, nil = unrated) |
| **Why keep Int** | Backward compatibility with LocalStorageService UserDefaults data and entire rating pipeline |
| **Confidence** | HIGH -- minimizes changes across the stack |

**Rationale for keeping the Int type:**
The `userRating` field flows through: `LocalStorageService` (UserDefaults `[String: Int]` dictionary), `FirestoreService` (rating_events documents), `JokeViewModel` (rateJoke method), `CharacterDetailViewModel` (notification sync via Combine), and `Joke` model (Codable). Changing to an enum or Bool would require touching every layer.

Instead, constrain values to `{1, 5, nil}` at the UI layer (the new binary Picker) and keep the storage layer unchanged. The `rateJoke()` method already calls `min(max(rating, 1), 5)` for clamping.

**Critical insight:** Existing ratings of 2, 3, 4 in UserDefaults will be handled by the one-time migration (see section 4 below). After migration, only 1 and 5 values will exist in local storage.

### 3. Me Tab: Segmented Control Instead of 5 Sections

| Aspect | Decision |
|--------|----------|
| **Current** | List with 5 collapsible sections (Hilarious, Funny, Meh, Groan-Worthy, Horrible) |
| **New** | Segmented Picker (Hilarious/Horrible) with flat joke list below |
| **UI pattern** | Same as `MonthlyTopTenDetailView` -- Picker at top, content below |
| **Confidence** | HIGH -- reusing established UI pattern from Top 10 screen |

**What gets removed from `JokeViewModel`:**

| Computed Property | Action |
|-------------------|--------|
| `funnyJokes` (rating == 4) | Remove |
| `mehJokes` (rating == 3) | Remove |
| `groanJokes` (rating == 2) | Remove |
| `filteredFunnyJokes` | Remove |
| `filteredMehJokes` | Remove |
| `filteredGroanJokes` | Remove |
| `hilariousJokes` (rating == 5) | Keep |
| `horribleJokes` (rating == 1) | Keep |

### 4. LocalStorageService: One-Time Rating Migration

| Aspect | Decision |
|--------|----------|
| **Approach** | In-place migration on app launch, one-time, gated by UserDefaults flag |
| **Logic** | Ratings 4-5 become 5 (Hilarious), ratings 1-2 become 1 (Horrible), rating 3 removed |
| **Storage** | Same UserDefaults key (`jokeRatings`), same `[String: Int]` type |
| **Confidence** | HIGH -- simple dictionary transformation, no schema change |

```swift
private let ratingMigrationKey = "hasCompletedBinaryRatingMigration"

func migrateRatingsToBinary() {
    guard !userDefaults.bool(forKey: ratingMigrationKey) else { return }

    var migratedRatings: [String: Int] = [:]
    let ratings = loadRatingsSync()

    for (key, value) in ratings {
        switch value {
        case 4, 5: migratedRatings[key] = 5  // Hilarious
        case 1, 2: migratedRatings[key] = 1  // Horrible
        case 3: break  // Drop neutral ratings
        default: break
        }
    }

    saveRatingsSync(migratedRatings)
    userDefaults.set(true, forKey: ratingMigrationKey)
}
```

### 5. Cloud Functions: All-Time Aggregation

| Aspect | Decision |
|--------|----------|
| **Runtime** | Node.js 20 (unchanged) |
| **Dependencies** | `firebase-admin` ^13.0.0, `firebase-functions` ^7.0.0 (unchanged) |
| **Architecture** | Modify existing `functions/index.js` -- remove time windowing |
| **Confidence** | HIGH -- same patterns, simpler logic |

**Key changes to `functions/index.js`:**

| Current | New |
|---------|-----|
| `fetchRatingEvents(weekId)` queries by `week_id` field | `fetchAllRatingEvents()` queries entire `rating_events` collection |
| `saveWeeklyRankings(weekId, ...)` saves per-week doc | `saveAllTimeRankings(...)` saves single `all_time` doc |
| `getCurrentWeekId()` computes ISO week | Remove (not needed) |
| `getWeekDateRange(weekId)` computes week boundaries | Remove (not needed) |
| Document ID: `"2026-W07"` | Document ID: `"all_time"` |
| `aggregateRatings()` checks `rating >= 4` and `rating <= 2` | Simplify to `rating === 5` and `rating === 1` (post-migration) |

**Collection naming decision:** Keep the collection named `weekly_rankings`. Renaming would require coordinating iOS client + Cloud Function + document migration simultaneously. The `all_time` document ID within `weekly_rankings` is pragmatic. This tech debt was already acknowledged in `STATE.md`.

**Performance at current scale:** With 433 jokes and low user traffic, querying the entire `rating_events` collection is safe. Firestore reads are priced per document, not per query -- the daily cost for scanning all rating events is negligible. If the collection grows past 10K documents, consider adding a `count()` aggregation or running totals. For now, full-scan aggregation in the daily Cloud Function is the simplest correct approach.

### 6. Firestore Migration Script: Convert Existing rating_events

| Aspect | Decision |
|--------|----------|
| **Script** | `scripts/migrate-ratings.js` (new file) |
| **Pattern** | Follows `scripts/migrate-holiday-tags.js` conventions exactly |
| **Runtime** | Node.js ESM with `firebase-admin` ^12.0.0 (existing `scripts/package.json`) |
| **Features** | `--dry-run` flag, batch writes (500 per batch), structured logging |
| **Confidence** | HIGH -- established migration script pattern in codebase |

**Migration logic for `rating_events` collection:**

| Current rating value | Action | New value |
|---------------------|--------|-----------|
| 5 | Keep as-is | 5 (Hilarious) |
| 4 | Update | 5 (Hilarious) |
| 3 | Delete document | (removed) |
| 2 | Update | 1 (Horrible) |
| 1 | Keep as-is | 1 (Horrible) |

**Why a standalone script, not a Cloud Function:**
- One-time data migration, not ongoing processing
- Matches existing project convention (`migrate-holiday-tags.js`, `migrate-joke-ids.js`)
- Dry-run capability for safety and verification
- Can be run and verified before deploying the updated Cloud Function

**Batch write limits:** Firestore allows 500 operations per batch. With `FieldValue.serverTimestamp()`, this drops to ~250 (each timestamp counts as an extra write). Since this migration does NOT need server timestamps (only updating the `rating` field), the full 500-per-batch limit applies.

### 7. FirestoreService.swift: Fetch All-Time Rankings

| Aspect | Decision |
|--------|----------|
| **Change** | `fetchWeeklyRankings()` fetches `"all_time"` document instead of current week ID |
| **Scope** | Single line change: document ID from `getCurrentWeekId()` to `"all_time"` |
| **Confidence** | HIGH -- trivial change |

```swift
// Current (line 477)
let document = try await db.collection(weeklyRankingsCollection).document(weekId).getDocument()

// New
let document = try await db.collection(weeklyRankingsCollection).document("all_time").getDocument()
```

The `WeeklyRankings` Codable model may need minor adjustments since `week_start` and `week_end` fields won't exist on the `all_time` document. Options:
- Make `weekStart` and `weekEnd` optional in the model
- Or create a simpler `AllTimeRankings` model without date fields

**Recommendation:** Make the date fields optional in `WeeklyRankings`. Less code than a new model, and the existing `MonthlyRankingsViewModel` already handles the case where date range is empty.

---

## What NOT to Add

| Technology | Why Not |
|------------|---------|
| Custom segmented control library | Native `Picker(.segmented)` is sufficient and already used in codebase |
| SwiftUI `Toggle` for binary rating | Semantically wrong -- Toggle implies on/off, not good/bad |
| Firestore Pipeline/Enterprise aggregations | Overkill for 433 jokes; requires Enterprise edition |
| Distributed counters for rankings | Only needed at 1 write/sec contention; this app has ~10 ratings/day |
| New Firestore collection for rankings | Reuse `weekly_rankings` with `all_time` document |
| Database migration tool (Flyway, Liquibase) | Firestore is schemaless; Node.js scripts are the project's convention |
| Any new Swift packages | Nothing requires third-party libraries |
| Any new npm packages | `firebase-admin` and `firebase-functions` cover everything |
| SwiftData or Core Data for local ratings | UserDefaults `[String: Int]` is sufficient for key-value rating storage |
| New `BinaryRating` enum type | Int with constrained values is simpler; avoids cascading type changes |

---

## Existing Stack -- Unchanged

| Component | Version | Status |
|-----------|---------|--------|
| SwiftUI | iOS 18.0+ | Unchanged |
| Firebase Firestore iOS SDK | via SPM | Unchanged |
| Firebase Cloud Functions | Node.js 20, firebase-functions ^7.0.0 | Logic changes only |
| firebase-admin (scripts) | ^12.0.0 | Unchanged |
| firebase-admin (functions) | ^13.0.0 | Unchanged |
| WidgetKit | iOS 18.0+ | Unchanged -- widgets do not show ratings |
| UserDefaults | Foundation | Unchanged -- same key and type for ratings |
| Combine | Foundation | Unchanged -- notification sync between ViewModels |
| App Intents (Siri) | iOS 18.0+ | Unchanged -- Siri does not interact with ratings |

---

## Integration Points

Changes flow through these existing integration points:

```
User taps Hilarious or Horrible on segmented Picker
    |
    v
JokeDetailSheet (Picker replaces GroanOMeterView)
    |
    v
JokeViewModel.rateJoke(joke, rating: 5 or 1)
    |
    +---> LocalStorageService.saveRating()       -- unchanged method, same key/type
    |
    +---> FirestoreService.updateJokeRating()    -- unchanged transaction
    |
    +---> FirestoreService.logRatingEvent()      -- unchanged, already only logs 1 and 5
    |         (line 906-908: if clampedRating == 1 || clampedRating == 5)
    |
    +---> NotificationCenter.post(.jokeRatingDidChange)  -- unchanged
              |
              v
         CharacterDetailViewModel (receives via Combine, unchanged)
```

**Key insight:** The existing `rateJoke()` method in `JokeViewModel.swift` (lines 906-908) already only logs rating events for values 1 and 5:
```swift
if clampedRating == 1 || clampedRating == 5 {
    let deviceId = storage.getDeviceId()
    try await firestoreService.logRatingEvent(
        jokeId: firestoreId,
        rating: clampedRating,
        deviceId: deviceId
    )
}
```

This means the Firestore rating event pipeline is already binary-ready. The only change is constraining the UI to offer only values 1 and 5.

---

## Files Requiring Changes

### Swift Files (Modify)

| File | Change | Complexity |
|------|--------|------------|
| `Views/GrainOMeterView.swift` | Replace 5-emoji slider with binary Picker; simplify CompactGroanOMeterView | Medium |
| `Models/Joke.swift` | Simplify `ratingEmoji` and `ratingEmojis` to binary | Low |
| `ViewModels/JokeViewModel.swift` | Remove `funnyJokes`, `mehJokes`, `groanJokes` computed properties and their filtered variants; simplify Me tab data | Low |
| `Views/MeView.swift` | Replace 5-section list with segmented control (Hilarious/Horrible) + flat list | Medium |
| `Views/MonthlyTopTen/MonthlyTopTenDetailView.swift` | Rename "Monthly Top 10" to "All-Time Top 10"; remove date range | Low |
| `Views/MonthlyTopTen/MonthlyTopTenCarouselView.swift` | Rename header text; remove date range reference | Low |
| `ViewModels/MonthlyRankingsViewModel.swift` | Remove date range logic; rename for clarity | Low |
| `Services/FirestoreService.swift` | Change `fetchWeeklyRankings()` to fetch `"all_time"` doc | Low |
| `Services/LocalStorageService.swift` | Add one-time `migrateRatingsToBinary()` method | Low |
| `Models/FirestoreModels.swift` | Make `weekStart`/`weekEnd` optional in `WeeklyRankings` | Low |

### Cloud Functions / Scripts (Modify or Create)

| File | Change | Complexity |
|------|--------|------------|
| `functions/index.js` | Remove time-windowed queries; aggregate all rating_events; save to `all_time` doc | Medium |
| `scripts/migrate-ratings.js` | **New file** -- migrate existing rating_events (4,5 to 5; 1,2 to 1; 3 deleted) | Low |
| `scripts/package.json` | Add `migrate-ratings` npm script | Low |

### Files NOT Changing

| File | Why Unchanged |
|------|---------------|
| `Views/JokeCardView.swift` | Still renders `CompactGroanOMeterView` -- just displays different values |
| `Views/JokeDetailSheet.swift` | Only changes via its `GroanOMeterView` subview being replaced |
| `Views/CharacterDetailView.swift` | Rating sync via NotificationCenter unchanged |
| `ViewModels/CharacterDetailViewModel.swift` | Handles any Int rating value; constrained at UI layer |
| All Widget files | Widgets do not display or interact with ratings |
| `Services/NetworkMonitor.swift` | No network-related changes |
| `Services/NotificationManager.swift` | Notifications unrelated to ratings |
| `scripts/add-jokes.js` | Joke insertion unrelated to rating changes |

---

## Firestore `jokes` Collection: No Schema Change

| Field | Status | Notes |
|-------|--------|-------|
| `rating_count` | Keep | Still counts total ratings |
| `rating_sum` | Keep | Sum of 1s and 5s -- coarser but still valid for averages |
| `rating_avg` | Keep | Will trend toward extremes (closer to 1.0 or 5.0), which is expected |
| `likes` / `dislikes` | Keep | Currently unused in UI but harmless to retain |
| `popularity_score` | Keep | Existing calculation still works with any rating values |

The `updateJokeRating()` transaction in `FirestoreService.swift` does not need to change -- it works with any integer rating value and atomically updates count/sum/avg.

---

## Installation / Dependency Changes

```bash
# No new dependencies to install.
# No package changes needed.

# New migration script:
# scripts/migrate-ratings.js

# Run migration workflow:
cd scripts
node migrate-ratings.js --dry-run    # Preview changes
node migrate-ratings.js              # Execute migration

# Deploy updated Cloud Function:
cd functions
firebase deploy --only functions
```

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Rating UI | `Picker(.segmented)` | Custom HStack with animated buttons | Unnecessary complexity; native picker handles a11y, dark mode, dynamic type for free |
| Rating UI | `Picker(.segmented)` | Two separate `Button` views | Segmented control visually communicates mutual exclusivity |
| Rating storage | Keep `Int` (1 or 5) | New `enum BinaryRating` | Requires touching every layer (storage, model, notification, Codable); Int with constrained values is simpler |
| Rating storage | Keep `Int` (1 or 5) | `Bool` (liked/disliked) | Loses compatibility with existing UserDefaults dictionary and Firestore rating pipeline |
| All-time doc | Single `all_time` doc in `weekly_rankings` | New `rankings` collection | More coordination work (client + function + migration) for no functional benefit |
| All-time doc | Single `all_time` doc in `weekly_rankings` | Rename collection to `rankings` | Can do later; cosmetic debt is acknowledged and harmless |
| Cloud Function | Full scan of `rating_events` | Write-time incremental counters | 433 jokes, ~10 ratings/day; full scan is simpler and self-correcting. Incremental is premature optimization |
| Data migration | Node.js batch script | Cloud Function trigger | One-time operation; script gives dry-run, logging, and manual control |
| Local migration | One-time UserDefaults transform | No migration (let users re-rate) | Users lose their rating history; poor UX for existing users |

---

## Sources

### Verified Against Official Documentation (HIGH confidence)
- [Apple: SegmentedPickerStyle](https://developer.apple.com/documentation/swiftui/segmentedpickerstyle) -- native SwiftUI segmented control
- [Apple: PickerStyle](https://developer.apple.com/documentation/swiftui/pickerstyle) -- picker style options
- [Firebase: Transactions and Batched Writes](https://firebase.google.com/docs/firestore/manage-data/transactions) -- 500 operation batch limit
- [Firebase: Write-time Aggregations](https://firebase.google.com/docs/firestore/solutions/aggregation) -- aggregation patterns
- [Firebase: Best Practices](https://firebase.google.com/docs/firestore/best-practices) -- rate limiting guidance

### Verified Against Existing Codebase (HIGH confidence)
- `MonthlyTopTenDetailView.swift` (lines 54-58) -- existing segmented Picker with `RankingType`
- `JokeViewModel.swift` (lines 906-908) -- rating events already filtered to 1 and 5
- `migrate-holiday-tags.js` -- migration script pattern (dry-run, batch writes, logging)
- `functions/index.js` -- Cloud Function aggregation pattern
- `FirestoreModels.swift` (lines 196-222) -- `RankingType` enum with Hilarious/Horrible

### Community Resources (MEDIUM confidence)
- [Hacking with Swift: Segmented Control](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-segmented-control-and-read-values-from-it) -- SwiftUI segmented control patterns
- [Firestore Batch Writes Over 500](https://gist.github.com/MorenoMdz/516c590f2a034bf39c55708574831da8) -- chunking pattern for large migrations

---

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Rating UI (segmented Picker) | HIGH | Already used in codebase; native SwiftUI component; Apple docs verified |
| Rating model (keep Int) | HIGH | Minimizes changes; existing pipeline already binary-ready |
| Local migration (UserDefaults) | HIGH | Simple dictionary transformation; one-time gated operation |
| Cloud Function changes | HIGH | Same runtime/dependencies; logic simplification (removing time windowing) |
| Firestore migration script | HIGH | Follows established codebase pattern (migrate-holiday-tags.js) |
| All-time ranking performance | HIGH | 433 jokes, low traffic; full-scan aggregation is safe and self-correcting |
| Collection naming (keep weekly_rankings) | MEDIUM | Pragmatic but cosmetically misleading; acceptable tech debt |

---

## Roadmap Implications

**Phase ordering recommendation:**

1. **Data migration first** (scripts + Cloud Function) -- establish the all-time ranking data before changing the client
2. **Rating UI simplification** (model + views) -- binary Picker, remove 5-point components
3. **Me tab redesign** -- depends on simplified rating model
4. **Top 10 rename** -- "Monthly" to "All-Time" across views

**Key dependencies:**
- Cloud Function must be deployed before the iOS client change, so `all_time` document exists when the app fetches it
- `scripts/migrate-ratings.js` must run before Cloud Function deployment to clean up existing data
- Local UserDefaults migration runs automatically on app launch -- no deployment dependency
