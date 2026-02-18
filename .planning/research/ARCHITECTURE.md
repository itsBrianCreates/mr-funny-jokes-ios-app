# Architecture: Binary Rating System & All-Time Top 10

**Domain:** iOS joke app -- rating system migration, leaderboard redesign, Me tab redesign
**Researched:** 2026-02-17
**Confidence:** HIGH (analysis based on full codebase read of all affected files)

## Executive Summary

The v1.1.0 milestone modifies the rating pipeline end-to-end: from user tap through local storage, Firestore sync, Cloud Function aggregation, and back to leaderboard display. The existing architecture is well-structured for this change -- MVVM boundaries are clean, the rating flow is centralized in two ViewModels (JokeViewModel, CharacterDetailViewModel), and the Cloud Function is a self-contained aggregation script. The key architectural insight is that the binary rating change is primarily a **narrowing** of an existing pipeline, not a new system. Most components shrink or simplify rather than grow.

---

## Current Architecture (Pre-v1.1.0)

### Rating Data Flow

```
User taps emoji (1-5)
    |
    v
ViewModel.rateJoke(joke, rating)     [JokeViewModel.swift:863 / CharacterDetailViewModel.swift:223]
    |
    +---> LocalStorageService.saveRating()   [UserDefaults: jokeRatings dict, String:Int]
    |     LocalStorageService.saveRatingTimestamp()   [UserDefaults: jokeRatingTimestamps dict]
    |
    +---> FirestoreService.updateJokeRating()   [Transaction: rating_count++, rating_sum+=, rating_avg recalc]
    |
    +---> (if rating==1 or rating==5) FirestoreService.logRatingEvent()   [rating_events collection]
    |
    +---> (CharacterDetailVM only) NotificationCenter.post(.jokeRatingDidChange)
              |
              v
         JokeViewModel.handleRatingNotification()   [Cross-VM sync for Me tab]
```

### Leaderboard Data Flow

```
Cloud Function (daily midnight ET)
    |
    v
Read rating_events where week_id == currentWeekId
    |
    v
aggregateRatings(): rating 4-5 -> hilarious count, rating 1-2 -> horrible count
    |
    v
rankTopN(): sort by count, take top 10
    |
    v
Save to weekly_rankings/{weekId}
    |
    ===== iOS App reads =====
    |
    v
MonthlyRankingsViewModel.loadRankings()
    |
    +---> FirestoreService.fetchWeeklyRankings()   [reads weekly_rankings/{currentWeekId}]
    +---> FirestoreService.fetchJokes(byIds:)      [hydrates joke data for display]
    |
    v
MonthlyTopTenCarouselView / MonthlyTopTenDetailView
```

### Me Tab Data Flow

```
JokeViewModel.jokes array (all loaded jokes with userRating applied)
    |
    v
Computed properties filter by rating value:
    hilariousJokes: filter { userRating == 5 }
    funnyJokes:     filter { userRating == 4 }
    mehJokes:       filter { userRating == 3 }
    groanJokes:     filter { userRating == 2 }
    horribleJokes:  filter { userRating == 1 }
    |
    v
MeView.swift renders 5 sections with emoji headers
```

---

## Target Architecture (Post-v1.1.0)

### Binary Rating Data Flow

```
User taps Hilarious or Horrible (segmented control)
    |
    v
ViewModel.rateJoke(joke, rating)     [rating: 1=horrible, 5=hilarious -- values preserved]
    |
    +---> LocalStorageService.saveRating()   [UNCHANGED: still stores Int]
    |     LocalStorageService.saveRatingTimestamp()   [UNCHANGED]
    |
    +---> FirestoreService.updateJokeRating()   [UNCHANGED: transaction still works]
    |
    +---> FirestoreService.logRatingEvent()   [NOW ALWAYS -- both ratings are logged]
    |
    +---> (CharacterDetailVM only) NotificationCenter.post(.jokeRatingDidChange)
              |
              v
         JokeViewModel.handleRatingNotification()   [UNCHANGED]
```

### All-Time Leaderboard Data Flow

```
Cloud Function (daily midnight ET)
    |
    v
Read ALL rating_events (no week_id filter)     <-- KEY CHANGE
    |
    v
aggregateRatings(): rating >= 4 -> hilarious, rating <= 2 -> horrible     [UNCHANGED logic]
    |
    v
rankTopN(): sort by count, take top 10     [UNCHANGED]
    |
    v
Save to alltime_rankings/latest     <-- NEW collection, single document
    |
    ===== iOS App reads =====
    |
    v
AllTimeRankingsViewModel.loadRankings()     <-- RENAMED
    |
    +---> FirestoreService.fetchAllTimeRankings()     <-- NEW method
    +---> FirestoreService.fetchJokes(byIds:)         [UNCHANGED]
    |
    v
AllTimeTopTenCarouselView / AllTimeTopTenDetailView     <-- RENAMED views
```

### Me Tab Data Flow (Simplified)

```
JokeViewModel.jokes array (all loaded jokes with userRating applied)
    |
    v
TWO computed properties:
    hilariousJokes: filter { userRating == 5 }     [UNCHANGED]
    horribleJokes:  filter { userRating == 1 }     [UNCHANGED]
    |
    v
MeView.swift with segmented control (Hilarious | Horrible) matching Top 10 screen
```

---

## Component Change Map

### Modified Components (MODIFY)

| Component | File | Change Summary |
|-----------|------|----------------|
| **Joke model** | `Models/Joke.swift` | Remove `ratingEmoji` computed property (5-point), replace `ratingEmojis` array with binary. Add `binaryRatingEmoji` computed property. |
| **JokeViewModel** | `ViewModels/JokeViewModel.swift` | Remove funnyJokes/mehJokes/groanJokes computed properties and filtered variants. Simplify `rateJoke()` to only accept 1 or 5. Remove `clampedRating` logic. Always log rating events (remove the `if clampedRating == 1 or 5` guard). |
| **CharacterDetailViewModel** | `ViewModels/CharacterDetailViewModel.swift` | Same `rateJoke()` simplification. Always log rating events. |
| **FirestoreService** | `Services/FirestoreService.swift` | Add `fetchAllTimeRankings()` method. Add `alltimeRankingsCollection` constant. Modify `logRatingEvent()` to drop week_id from new document IDs and event data. |
| **FirestoreModels** | `Models/FirestoreModels.swift` | Add `AllTimeRankings` struct (simpler than `WeeklyRankings` -- no week_start/week_end). Keep `RankedJokeEntry`, `RankedJoke`, `RankingType` unchanged. |
| **LocalStorageService** | `Services/LocalStorageService.swift` | Add one-time migration method to remap existing ratings: 4->5 (hilarious), 2->1 (horrible), remove 3s. |
| **GrainOMeterView** | `Views/GrainOMeterView.swift` | Replace 5-emoji slider with binary segmented control. Replace `CompactGroanOMeterView` with binary emoji display. |
| **JokeCardView** | `Views/JokeCardView.swift` | Update `CompactGroanOMeterView` usage to binary emoji. |
| **JokeDetailSheet** | `Views/JokeDetailSheet.swift` | Update `GroanOMeterView` reference to new binary rating view. |
| **MeView** | `Views/MeView.swift` | Redesign from 5-section list to segmented control with two lists. |
| **JokeFeedView** | `Views/JokeFeedView.swift` | Update references from `MonthlyTopTen*` to `AllTimeTopTen*`. |
| **Cloud Functions** | `functions/index.js` | Remove week_id filter from `fetchRatingEvents()`. Write to `alltime_rankings/latest`. Remove week date range calculations. |

### New Components (CREATE)

| Component | File | Purpose |
|-----------|------|---------|
| **BinaryRatingView** | `Views/BinaryRatingView.swift` | Segmented control replacing `GroanOMeterView`. |
| **CompactBinaryRatingView** | `Views/BinaryRatingView.swift` | Inline emoji for cards replacing `CompactGroanOMeterView`. |
| **AllTimeRankingsViewModel** | `ViewModels/AllTimeRankingsViewModel.swift` | Refactored from `MonthlyRankingsViewModel`. Fetches from `alltime_rankings/latest`. |
| **AllTimeTopTenCarouselView** | `Views/AllTimeTopTen/AllTimeTopTenCarouselView.swift` | Renamed from `MonthlyTopTenCarouselView`. Header says "All-Time Top 10". |
| **AllTimeTopTenDetailView** | `Views/AllTimeTopTen/AllTimeTopTenDetailView.swift` | Renamed from `MonthlyTopTenDetailView`. No date range subtitle. |

### Deleted Components (DELETE)

| Component | File | Reason |
|-----------|------|--------|
| **MonthlyRankingsViewModel** | `ViewModels/MonthlyRankingsViewModel.swift` | Replaced by `AllTimeRankingsViewModel`. |
| **MonthlyTopTenCarouselView** | `Views/MonthlyTopTen/MonthlyTopTenCarouselView.swift` | Replaced by `AllTimeTopTenCarouselView`. |
| **MonthlyTopTenDetailView** | `Views/MonthlyTopTen/MonthlyTopTenDetailView.swift` | Replaced by `AllTimeTopTenDetailView`. |
| **MonthlyTopTen directory** | `Views/MonthlyTopTen/` | Replaced by `Views/AllTimeTopTen/`. `RankedJokeCard` moves to new directory. |

### Unchanged Components

| Component | Why Unchanged |
|-----------|---------------|
| **SharedStorageService** | Widget data unaffected by rating changes |
| **WidgetDataFetcher** | REST API, no rating logic |
| **NotificationManager** | Independent of rating system |
| **NetworkMonitor** | Infrastructure, no rating logic |
| **HapticManager** | Used by new views the same way |
| **SeasonalHelper** | Feed sorting, independent of rating logic |
| **SearchView** | Displays jokes, does not interact with ratings directly |
| **CharacterCarouselView** | Navigation only |
| **SplashScreenView** | Loading screen only |

---

## Firestore Collection Changes

### rating_events (MODIFY)

**Current document ID format:** `{deviceId}_{jokeId}_{weekId}`
**New document ID format:** `{deviceId}_{jokeId}` (drop week_id suffix)

**Current fields:**
```
joke_id: string
rating: integer (1-5)
device_id: string
week_id: string (e.g., "2026-W07")
timestamp: timestamp
```

**New fields:**
```
joke_id: string
rating: integer (1 or 5 only)
device_id: string
timestamp: timestamp
```

**Migration consideration:** Existing events with week_id are still valid data. The Cloud Function simply stops filtering by week_id. Existing document IDs with week_id suffix remain -- they represent historical per-week votes. New events use the simplified ID format. The aggregation function reads ALL events regardless of document ID format, counting the most recent rating per device per joke.

**Important:** The current document ID includes week_id, meaning one device can rate the same joke differently each week. Removing week_id from the new document ID means a user's rating becomes permanent (can change but not have separate per-week ratings). This is the correct behavior for all-time rankings.

### alltime_rankings (NEW)

**Single document:** `alltime_rankings/latest`

```
hilarious: array[{joke_id, count, rank}]
horrible: array[{joke_id, count, rank}]
total_hilarious_ratings: integer
total_horrible_ratings: integer
computed_at: timestamp
```

No week_start/week_end fields. No week_id. Simpler schema.

### weekly_rankings (DEPRECATE)

Keep the collection (no cost to leaving it). Stop writing to it. Stop reading from it. Can be cleaned up later.

### jokes (NO CHANGE)

The jokes collection fields (rating_count, rating_sum, rating_avg, likes, dislikes, popularity_score) remain unchanged. The `updateJokeRating()` transaction still works -- it receives 1 or 5 instead of 1-5. Over time, rating_avg will naturally converge toward a binary average, which is fine for popularity_score ordering.

---

## Integration Points Per ViewModel

### JokeViewModel Integration Points

| Integration | Current | New | Impact |
|------------|---------|-----|--------|
| `rateJoke()` clamping | `min(max(rating, 1), 5)` | Assert rating is 1 or 5 | LOW |
| Rating event logging | Only if rating == 1 or 5 | Always log | LOW |
| `hilariousJokes` computed | `filter { userRating == 5 }` | Unchanged | NONE |
| `horribleJokes` computed | `filter { userRating == 1 }` | Unchanged | NONE |
| `funnyJokes` computed | `filter { userRating == 4 }` | DELETE | LOW |
| `mehJokes` computed | `filter { userRating == 3 }` | DELETE | LOW |
| `groanJokes` computed | `filter { userRating == 2 }` | DELETE | LOW |
| `filteredFunnyJokes` | Exists | DELETE | LOW |
| `filteredMehJokes` | Exists | DELETE | LOW |
| `filteredGroanJokes` | Exists | DELETE | LOW |
| `ratedJokes` computed | `filter { userRating != nil }` | Unchanged | NONE |
| `filteredRatedJokes` | Category filter on ratedJokes | Unchanged | NONE |
| Session rated tracking | `sessionRatedJokeIds` | Unchanged | NONE |
| Sort cache invalidation | On rating change | Unchanged | NONE |
| Cross-VM notification | Handles any Int rating | Unchanged | NONE |

### CharacterDetailViewModel Integration Points

| Integration | Current | New | Impact |
|------------|---------|-----|--------|
| `rateJoke()` clamping | `min(max(rating, 1), 5)` | Assert rating is 1 or 5 | LOW |
| Rating event logging | Only if rating == 1 or 5 | Always log | LOW |
| Notification posting | Posts any rating value | Posts 1 or 5 | LOW |

### MonthlyRankingsViewModel -> AllTimeRankingsViewModel

| Integration | Current | New | Impact |
|------------|---------|-----|--------|
| `loadRankings()` | `fetchWeeklyRankings()` | `fetchAllTimeRankings()` | MEDIUM |
| `monthDateRange` property | Formatted week date range | DELETE | LOW |
| `formatDateRange()` method | Week formatting | DELETE | LOW |
| `hilariousJokes` / `horribleJokes` | Populated from rankings | Unchanged pattern | NONE |
| `getJokesForCountdown()` | Returns reversed list | Unchanged | NONE |

### FirestoreService Integration Points

| Integration | Current | New | Impact |
|------------|---------|-----|--------|
| `logRatingEvent()` | Uses `getCurrentWeekId()` for doc ID | Drop week_id from doc ID | MEDIUM |
| `fetchWeeklyRankings()` | Reads `weekly_rankings/{weekId}` | Add `fetchAllTimeRankings()` reading `alltime_rankings/latest` | MEDIUM |
| `getCurrentWeekId()` | Used by logRatingEvent and fetchWeeklyRankings | Can be deprecated | LOW |
| `updateJokeRating()` | Transaction with any Int | Unchanged | NONE |
| `fetchJokes(byIds:)` | Batch fetch for leaderboard | Unchanged | NONE |

---

## Local Rating Migration Strategy

### UserDefaults Migration (On-Device)

Existing UserDefaults data (`jokeRatings` dictionary):
```
{
    "firestoreId_abc": 5,    // hilarious -> keep as 5
    "firestoreId_def": 4,    // funny -> remap to 5 (hilarious)
    "firestoreId_ghi": 3,    // meh -> DELETE
    "firestoreId_jkl": 2,    // groan -> remap to 1 (horrible)
    "firestoreId_mno": 1     // horrible -> keep as 1
}
```

**Migration logic (runs once on app update):**
```swift
func migrateRatingsToBinary() {
    var ratings = loadRatingsSync()
    var timestamps = loadRatingTimestampsSync()
    var modified = false

    for (key, rating) in ratings {
        switch rating {
        case 4:
            ratings[key] = 5  // Funny -> Hilarious
            modified = true
        case 2:
            ratings[key] = 1  // Groan -> Horrible
            modified = true
        case 3:
            ratings.removeValue(forKey: key)  // Meh -> Drop
            timestamps.removeValue(forKey: key)
            modified = true
        default:
            break  // 1 and 5 stay as-is
        }
    }

    if modified {
        saveRatingsSync(ratings)
        saveRatingTimestampsSync(timestamps)
    }
}
```

**When to run:** In `LocalStorageService.init()` or triggered by JokeViewModel on first launch after update. Use a UserDefaults flag (`binaryMigrationComplete`) to run exactly once.

### Firestore Migration (Server-Side)

Existing `rating_events` collection has documents with ratings 1-5 and week_id fields.

**No server-side migration of existing data needed.** The Cloud Function already treats 4-5 as hilarious and 1-2 as horrible. Rating 3 events are already ignored. The only change is removing the week_id filter from the aggregation query. Old data maps correctly to binary semantics as-is.

---

## Patterns to Follow

### Pattern 1: Segmented Control for Binary Choice
**What:** Use SwiftUI `Picker` with `.segmented` style for Hilarious/Horrible selection, matching the existing pattern in `MonthlyTopTenDetailView.swift:54-61`.

**Example:**
```swift
Picker("Rating", selection: $selectedRating) {
    Text("\(RankingType.hilarious.emoji) Hilarious").tag(5)
    Text("\(RankingType.horrible.emoji) Horrible").tag(1)
}
.pickerStyle(.segmented)
```

**Why:** Consistent with existing UI pattern in the app. Native SwiftUI component. Two-option segmented control is the natural iOS pattern for binary choices.

### Pattern 2: Rating Value Preservation
**What:** Keep using Int values 1 and 5 internally for ratings rather than introducing a new enum or Bool.

**Why:** Minimizes migration surface. `updateJokeRating()` transaction math still works. LocalStorageService dictionary stays `[String: Int]`. Cross-VM notifications stay the same shape. The Cloud Function aggregation logic is unchanged. Only the UI changes -- fewer allowed values, not different value types.

### Pattern 3: Feature Flag for Migration Timing
**What:** Use a UserDefaults flag to gate the one-time local rating migration.

**Example:**
```swift
private let migrationKey = "binaryRatingMigrationV1"

func migrateIfNeeded() {
    guard !userDefaults.bool(forKey: migrationKey) else { return }
    migrateRatingsToBinary()
    userDefaults.set(true, forKey: migrationKey)
}
```

**Why:** Ensures migration runs exactly once. Safe for users who update later. Idempotent if somehow called twice.

### Pattern 4: Rename-and-Replace for View Hierarchy
**What:** Create new `AllTimeTopTen/` directory with renamed views rather than modifying in-place.

**Why:** Git history stays clean. Old Monthly views can be deleted in a single commit. Avoids confusing "Monthly" references lingering in code. The views are small enough (under 200 lines each) that recreation is trivial.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Introducing a Rating Enum
**What:** Creating a `BinaryRating` enum with `.hilarious` and `.horrible` cases.

**Why bad:** Forces changes to every layer -- LocalStorageService dictionary type, notification userInfo, FirestoreService parameters, Firestore field types. All for a simple "only allow 1 or 5" constraint.

**Instead:** Keep Int. Validate at the UI layer that only 1 or 5 can be passed. Add a comment documenting the constraint.

### Anti-Pattern 2: Dual Collection Strategy
**What:** Writing to both `weekly_rankings` and `alltime_rankings` during transition.

**Why bad:** Doubles write costs, creates maintenance burden, no consumer reads weekly_rankings anymore.

**Instead:** Stop writing to `weekly_rankings` entirely. If needed for rollback, the old Cloud Function code is in git history.

### Anti-Pattern 3: Migrating Firestore rating_events In-Place
**What:** Running a script to update all existing rating_events documents to remap ratings and remove week_id.

**Why bad:** Expensive write operation on production. Unnecessary because the Cloud Function aggregation already handles the mapping correctly (4-5 -> hilarious, 1-2 -> horrible, 3 ignored).

**Instead:** Leave existing events untouched. New events use binary values. Aggregation reads all events and produces correct results either way.

### Anti-Pattern 4: Separate MeViewModel
**What:** Creating a new `MeViewModel` to manage Me tab state.

**Why bad:** The Me tab's data comes from `JokeViewModel.jokes` array with `userRating` applied. Creating a separate ViewModel would require either duplicating the jokes array or adding complex synchronization.

**Instead:** Keep Me tab state in JokeViewModel (current pattern). The computed properties `hilariousJokes` and `horribleJokes` already exist and work correctly.

---

## Suggested Build Order

The build order is driven by data dependencies. The binary rating system is the foundation -- everything else reads from it.

### Phase 1: Data Layer & Cloud Function (Foundation)

**Must come first because all UI depends on correct data.**

1. LocalStorageService migration method with UserDefaults flag
2. FirestoreService modifications: `logRatingEvent()` drops week_id, add `fetchAllTimeRankings()`
3. FirestoreModels: Add `AllTimeRankings` struct
4. Cloud Function update: Remove week_id filter, write to `alltime_rankings/latest`
5. Deploy Cloud Function and run manually to populate initial data

**Rationale:** Until the Cloud Function runs and `alltime_rankings/latest` exists, the iOS app has nothing to display in the leaderboard. Until the local migration runs, the Me tab shows stale 5-point data.

### Phase 2: Rating UI (Core Interaction)

**Depends on Phase 1 (data layer ready).**

1. BinaryRatingView: new segmented control replacing GroanOMeterView
2. CompactBinaryRatingView: inline emoji for cards
3. JokeDetailSheet: swap GroanOMeterView for BinaryRatingView
4. JokeCardView: swap CompactGroanOMeterView for CompactBinaryRatingView
5. JokeViewModel.rateJoke() simplification (binary only, always log events)
6. CharacterDetailViewModel.rateJoke() same simplification
7. Joke model: update rating emoji computed properties

**Rationale:** Rating UI is the most-used interaction. Once data layer is ready, this is the highest-impact change.

### Phase 3: Me Tab Redesign

**Depends on Phase 1 (migration) and Phase 2 (binary ratings working).**

1. JokeViewModel: remove funnyJokes/mehJokes/groanJokes and filtered variants
2. MeView: replace 5-section list with segmented control + two lists
3. Verify migrated ratings display correctly

**Rationale:** Me tab depends on both the data migration and the new rating UI.

### Phase 4: All-Time Leaderboard

**Depends on Phase 1 (Cloud Function deployed and data populated).**

1. AllTimeRankingsViewModel: create from MonthlyRankingsViewModel
2. AllTimeTopTenCarouselView: create from MonthlyTopTenCarouselView
3. AllTimeTopTenDetailView: create from MonthlyTopTenDetailView
4. Move RankedJokeCard.swift to `AllTimeTopTen/` directory
5. JokeFeedView: update references from Monthly to AllTime
6. Delete MonthlyTopTen directory and MonthlyRankingsViewModel

**Rationale:** Leaderboard is display-only and depends on the Cloud Function having populated data. It can be built last because it does not block the rating flow.

---

## Scalability Considerations

| Concern | Current (433 jokes) | At 2K jokes | At 10K jokes |
|---------|---------------------|-------------|--------------|
| **All-time aggregation** | Reads a few hundred rating_events | Reads ~5K events | Reads ~50K events, may need batching |
| **Single rankings doc** | Under 1KB | Under 1KB | Under 1KB (only top 10) |
| **Local migration** | Under 100 ratings | Under 500 ratings | Consider async migration |
| **Me tab filtering** | In-memory filter, instant | In-memory filter, under 10ms | May need index or pagination |

**At current scale (433 jokes, under 100 users):** No scalability concerns. All operations are sub-second.

**Future consideration:** If rating_events grows past 100K documents, the Cloud Function should use Firestore aggregation queries or maintain running counters instead of re-reading all events daily.

---

## Sources

All findings based on direct codebase analysis of the following files:

- `MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` (1046 lines)
- `MrFunnyJokes/MrFunnyJokes/ViewModels/CharacterDetailViewModel.swift` (350 lines)
- `MrFunnyJokes/MrFunnyJokes/ViewModels/MonthlyRankingsViewModel.swift` (147 lines)
- `MrFunnyJokes/MrFunnyJokes/Services/FirestoreService.swift` (575 lines)
- `MrFunnyJokes/MrFunnyJokes/Services/LocalStorageService.swift` (498 lines)
- `MrFunnyJokes/MrFunnyJokes/Models/Joke.swift` (154 lines)
- `MrFunnyJokes/MrFunnyJokes/Models/FirestoreModels.swift` (270 lines)
- `MrFunnyJokes/MrFunnyJokes/Views/GrainOMeterView.swift` (173 lines)
- `MrFunnyJokes/MrFunnyJokes/Views/MeView.swift` (224 lines)
- `MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift` (179 lines)
- `MrFunnyJokes/MrFunnyJokes/Views/JokeDetailSheet.swift` (270 lines)
- `MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift` (258 lines)
- `MrFunnyJokes/MrFunnyJokes/Views/MonthlyTopTen/MonthlyTopTenCarouselView.swift` (184 lines)
- `MrFunnyJokes/MrFunnyJokes/Views/MonthlyTopTen/MonthlyTopTenDetailView.swift` (153 lines)
- `MrFunnyJokes/MrFunnyJokes/Views/MonthlyTopTen/RankedJokeCard.swift` (238 lines)
- `functions/index.js` (239 lines)
- `.planning/PROJECT.md`
- `.planning/codebase/INTEGRATIONS.md`
- `.planning/codebase/CONVENTIONS.md`
