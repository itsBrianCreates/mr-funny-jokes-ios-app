# Domain Pitfalls: Binary Rating Migration, All-Time Leaderboard, and Me Tab Redesign

**Domain:** Migrating 5-point rating system to binary (Hilarious/Horrible), switching weekly leaderboard to all-time, redesigning Me tab in existing SwiftUI iOS app
**Researched:** 2026-02-17
**Milestone:** v1.1 (subsequent milestone)
**Confidence:** HIGH (verified against codebase analysis, official Firestore/Apple docs, and community patterns)

---

## Critical Pitfalls

Mistakes that cause data loss, app crashes, or require rewrites.

### Pitfall 1: UserDefaults Rating Data Loss During Type Migration

**What goes wrong:** Existing users' ratings are silently lost or corrupted when the rating storage format changes from `Int` (1-5) to a new binary format, because the old dictionary `[String: Int]` is read with incompatible expectations.

**Why it happens:** The current `LocalStorageService` stores ratings as `[String: Int]` in UserDefaults under the key `"jokeRatings"`. The values are integers 1-5. If the new binary system writes a different value type (e.g., `String` like "hilarious"/"horrible", or `Bool`) to the same key, existing data either fails to decode or the old integer values are misinterpreted.

**Consequences:**
- All 433 jokes' ratings vanish for existing users on app update
- Me tab appears empty after update (terrible first impression)
- `loadRatingsSync()` returns `[:]` if dictionary type cast fails: `userDefaults.dictionary(forKey: ratingsKey) as? [String: Int] ?? [:]`
- No crash -- just silent data loss, making it hard to detect

**Warning signs:**
- Changing the value type stored under `"jokeRatings"` key
- Not testing app update scenario (fresh install works, update loses data)
- Testing only on simulator (which starts fresh each time)

**Prevention:**
1. **Keep the storage type as `[String: Int]`** -- map binary to integer values (e.g., Hilarious = 5, Horrible = 1). This makes the migration zero-effort on the UserDefaults side.
2. If a new value scheme is truly needed, create a **new key** (e.g., `"jokeRatings_v2"`) and migrate on first read:
   ```swift
   func migrateRatingsIfNeeded() {
       guard userDefaults.dictionary(forKey: "jokeRatings_v2") == nil,
             let oldRatings = userDefaults.dictionary(forKey: "jokeRatings") as? [String: Int] else { return }

       var newRatings: [String: Int] = [:]
       for (key, value) in oldRatings {
           if value >= 4 { newRatings[key] = 5 }      // Hilarious
           else if value <= 2 { newRatings[key] = 1 }  // Horrible
           // Drop 3s (neutral)
       }
       userDefaults.set(newRatings, forKey: "jokeRatings_v2")
   }
   ```
3. **Never delete the old key** until at least one version has shipped with migration code
4. Run migration in `preloadMemoryCache()` before any reads occur

**Which phase should address:** Phase 1 (Data Migration) -- must be the very first thing implemented before any UI changes.

**Detection:** Test by installing the current App Store version, rating several jokes, then installing the development build over it. Verify ratings persist.

**Source:** [Beware UserDefaults: a tale of hard to find bugs, and lost data](https://christianselig.com/2024/10/beware-userdefaults/), [Managing Data Persistence with UserDefaults](https://www.momentslog.com/development/ios/managing-data-persistence-with-userdefaults-best-practices-and-common-pitfalls)

---

### Pitfall 2: Firestore rating_events Collection Mixed Schema (Old + New Documents)

**What goes wrong:** The `rating_events` collection contains a mix of old documents (rating: 1-5, week_id: "2026-W04") and new documents (rating: 1 or 5, no week_id or different format). The Cloud Function aggregation logic breaks or produces incorrect counts because it doesn't handle both schemas.

**Why it happens:** Existing rating events have `rating` values of 1-5 and are keyed with `week_id` for deduplication. When the system switches to binary (only 1 or 5), existing events with rating 2, 3, or 4 are not directly compatible with the new aggregation logic. The document ID format `{deviceId}_{jokeId}_{weekId}` also embeds the week concept.

**Consequences:**
- All-time aggregation either double-counts old data or ignores it entirely
- Old ratings of 2 (intended as "bad" on 5-point scale) are excluded if new logic only counts `rating == 1`
- Old ratings of 4 (intended as "good" on 5-point scale) are excluded if new logic only counts `rating == 5`
- Leaderboard appears empty or wildly inaccurate at launch

**Warning signs:**
- Changing the Cloud Function aggregation to only count `rating == 1` or `rating == 5`
- Not running a one-time migration of existing rating_events
- Querying without `week_id` filter but documents still contain `week_id` field (harmless but confusing)

**Prevention:**
1. **Keep treating 4-5 as hilarious and 1-2 as horrible** in the aggregation function. The existing Cloud Function already does this correctly. Do not narrow the filter.
2. **New events should still write `rating: 5` for hilarious and `rating: 1` for horrible** -- the aggregation function's `rating >= 4` and `rating <= 2` checks cover both old and new data naturally.
3. For the all-time switch: remove the `week_id` filter in `fetchRatingEvents()` and instead query ALL events:
   ```javascript
   // OLD (weekly)
   const snapshot = await db.collection(RATING_EVENTS_COLLECTION)
     .where("week_id", "==", weekId)
     .get();

   // NEW (all-time) -- WARNING: needs pagination for scale, see Pitfall 5
   const snapshot = await db.collection(RATING_EVENTS_COLLECTION)
     .get();
   ```
4. **Do NOT delete or modify existing rating_events documents** -- they are your historical data and the aggregation handles them already.

**Which phase should address:** Phase 2 (Cloud Function update) -- the aggregation function changes must be backward-compatible with existing data.

**Source:** [How to handle Firebase Firestore data migration and schema evolution](https://bootstrapped.app/guide/how-to-handle-firebase-firestore-data-migration-and-schema-evolution), [Schema Versioning with Google Firestore](https://www.captaincodeman.com/schema-versioning-with-google-firestore)

---

### Pitfall 3: Firestore Document Write Limit Breaks Rating Counters During Migration

**What goes wrong:** When running a batch migration script to update all joke documents' `rating_count`/`rating_sum`/`rating_avg` fields to reflect new binary aggregation, Firestore's 1-write-per-second-per-document limit causes transaction failures and data inconsistency.

**Why it happens:** The current `updateJokeRating()` uses a Firestore transaction to read-then-write `rating_count`, `rating_sum`, `rating_avg`. If a migration script is recalculating these fields for 433 jokes while users are simultaneously rating jokes, transactions will conflict and retry-fail.

**Consequences:**
- Migration script partially completes, leaving some jokes with old aggregate data and others with new
- Live user ratings during migration window are lost due to transaction conflicts
- `rating_avg` becomes meaningless (mixing 5-point and binary averages)

**Warning signs:**
- Running migration script during peak usage hours
- Not disabling live rating writes during migration
- Computing new averages that mix old 5-point ratings with new binary ratings

**Prevention:**
1. **Do NOT recalculate `rating_avg` from existing data** -- the field becomes meaningless when mixing scales. Instead, add new fields:
   ```
   hilarious_count: integer (count of 4-5 ratings, all-time)
   horrible_count: integer (count of 1-2 ratings, all-time)
   ```
2. Keep existing `rating_count`, `rating_sum`, `rating_avg` frozen as historical data (or remove them from UI)
3. Populate new fields via Cloud Function that reads all rating_events once and batch-writes new counters
4. Run migration during low-traffic window (late night ET)
5. Use batch writes (max 500 per batch) rather than individual transactions

**Which phase should address:** Phase 2 (Cloud Function / backend changes) -- compute new aggregate fields before the client UI switches.

**Source:** [Write-time aggregations | Firestore](https://firebase.google.com/docs/firestore/solutions/aggregation), [Understand reads and writes at scale | Firestore](https://firebase.google.com/docs/firestore/understand-reads-writes-scale)

---

### Pitfall 4: GroanOMeter Gesture Handling Regression

**What goes wrong:** Replacing the 5-emoji drag slider (`GroanOMeterView`) with a 2-button binary choice breaks the existing gesture-based interaction pattern, causing the `DragGesture` code to crash or produce unexpected behavior if the new view reuses any of the old logic.

**Why it happens:** The current `GroanOMeterView` is tightly coupled to a 5-item array with `DragGesture` that maps x-position to index 0-4 then converts to rating 1-5. If you try to adapt this to 2 items, the gesture math produces incorrect indices, or the capsule layout looks broken at 2 items.

**Consequences:**
- Ratings fire for wrong value (e.g., tapping "Horrible" saves as "Hilarious")
- Drag gesture extends beyond button boundaries
- Animation springs calibrated for 5 items look wrong with 2 items
- `CompactGroanOMeterView` shows wrong emoji if still indexing into 5-element array with binary value

**Warning signs:**
- Reusing `GroanOMeterView` with modified `ratingOptions` array instead of building new component
- Keeping `DragGesture` for a 2-button interface (drag makes no sense with 2 options)
- Not updating `CompactGroanOMeterView` which hardcodes `["silly_face", "groan", "meh", "smile", "laugh"]` array
- Not updating `Joke.ratingEmoji` computed property which switches on 1-5

**Prevention:**
1. **Build a new `BinaryRatingView`** -- do not modify `GroanOMeterView`. The interaction model is fundamentally different (tap, not drag).
2. Replace the `DragGesture` with simple `Button` taps + haptic feedback
3. Update ALL rating display touchpoints:
   - `Joke.ratingEmoji` computed property (line 84-94 of Joke.swift)
   - `Joke.ratingEmojis` static array (line 96)
   - `CompactGroanOMeterView` (line 134-145 of GrainOMeterView.swift)
   - `JokeCardView` where it shows `CompactGroanOMeterView` (line 71-73)
   - `JokeDetailSheet` where it uses `GroanOMeterView` (line 48)
4. Keep `onRate: (Int) -> Void` callback signature -- just constrain to 1 or 5

**Which phase should address:** Phase 3 (UI changes) -- after data layer is stable, replace the rating UI.

**Detection:** After UI change, rate a joke as Hilarious, dismiss sheet, verify the compact view shows the correct emoji. Re-open sheet and verify the correct button appears selected.

---

### Pitfall 5: All-Time Aggregation Query Timeout on rating_events Collection

**What goes wrong:** Switching from `where("week_id", "==", weekId)` to fetching ALL rating_events causes the Cloud Function to timeout or hit Firestore's 60-second deadline as the collection grows.

**Why it happens:** The current design queries rating_events filtered to one week (~100-1000 events). An all-time query scans the entire collection. With 433 jokes and growing user base, this collection grows unboundedly. Firestore aggregation queries timeout at 60 seconds for large datasets.

**Consequences:**
- Cloud Function returns empty rankings because query times out
- Function consumes maximum memory allocation trying to load all documents
- Billing spikes from scanning entire collection on every aggregation run
- At 50K+ rating events, the function becomes unreliable

**Warning signs:**
- `db.collection("rating_events").get()` with no filter or limit
- No index on `joke_id` or `rating` fields for the unfiltered query
- Function memory set at 256MiB (current setting) -- insufficient for large result sets
- No cursor-based pagination in aggregation logic

**Prevention:**
1. **Use write-time aggregation counters** instead of read-time scanning:
   - When a user rates: increment `hilarious_count` or `horrible_count` on the joke document
   - Leaderboard query becomes: `db.collection("jokes").orderBy("hilarious_count", "desc").limit(10)`
   - This is O(1) per rating event and O(log n) for leaderboard query
2. If keeping the current event-scanning approach:
   - Add composite index on `(rating, joke_id)` for efficient group counting
   - Use Firestore `count()` aggregation query per joke instead of loading all documents
   - Implement cursor-based pagination in the aggregation function
   - Increase function memory to 512MiB-1GiB
   - Set `timeoutSeconds: 300` to allow for large scans
3. **Recommended approach:** Maintain current rating_events for historical/audit trail, but add write-time counters on joke documents for leaderboard queries. This is the standard Firestore pattern.

**Which phase should address:** Phase 2 (Cloud Function / backend) -- must decide aggregation strategy before building leaderboard UI.

**Source:** [Summarize data with aggregation queries | Firestore](https://firebase.google.com/docs/firestore/query-data/aggregation-queries), [Write-time aggregations | Firestore](https://firebase.google.com/docs/firestore/solutions/aggregation), [Firestore Query Performance Best Practices](https://estuary.dev/blog/firestore-query-best-practices/)

---

## Moderate Pitfalls

Mistakes that cause degraded UX, technical debt, or implementation delays.

### Pitfall 6: Me Tab Rating Section Collapse During Migration

**What goes wrong:** After migration, the Me tab shows wrong groupings because it still filters by 5 rating levels (hilariousJokes, funnyJokes, mehJokes, groanJokes, horribleJokes) but all ratings are now binary.

**Why it happens:** `JokeViewModel` has 5 computed properties filtering by `userRating == 5`, `== 4`, `== 3`, `== 2`, `== 1`. After migration, jokes previously rated 4 map to 5 (hilarious) and jokes rated 2 map to 1 (horrible). But `MeView.swift` renders 5 separate sections. If migration maps 4 to 5 locally, the "Funny" section vanishes. If migration is incomplete, some jokes still have rating 2-4.

**Consequences:**
- Empty "Funny", "Meh", "Groan-Worthy" sections in Me tab
- Inconsistent state during rolling migration (some users migrated, some not)
- Section headers like "Funny (0)" with no jokes beneath
- Users confused about where their previously "Funny" jokes went

**Warning signs:**
- Changing UserDefaults values before updating MeView sections
- MeView still checking for 5 rating buckets after migration
- Not handling the case where `userRating` is 2, 3, or 4 post-migration

**Prevention:**
1. **Update MeView in the same release as the data migration** -- never ship one without the other
2. Replace 5 sections with 2 sections: "Hilarious" and "Horrible"
3. During the transition, handle legacy ratings gracefully:
   ```swift
   var filteredHilariousJokes: [Joke] {
       // Include both old (4-5) and new (5-only) hilarious ratings
       ratedJokes.filter { ($0.userRating ?? 0) >= 4 }
   }
   var filteredHorribleJokes: [Joke] {
       // Include both old (1-2) and new (1-only) horrible ratings
       ratedJokes.filter { ($0.userRating ?? 0) <= 2 && $0.userRating != nil }
   }
   // Gracefully handle orphaned "3" ratings: show in separate section or just display all rated
   ```
4. Clean up the 10 filtered computed properties in `JokeViewModel` (lines 99-176) -- reduce to 2

**Which phase should address:** Phase 3 (UI changes) -- must be synchronized with the data migration from Phase 1.

---

### Pitfall 7: Cross-ViewModel Rating Notification Schema Mismatch

**What goes wrong:** `CharacterDetailViewModel` posts `jokeRatingDidChange` notifications with the old integer rating (1-5 scale), but `JokeViewModel` expects the new binary format, or vice versa if one ViewModel is updated before the other.

**Why it happens:** Both ViewModels independently handle ratings and communicate via `NotificationCenter`. The notification payload includes `"rating": rating` as an Int. If `CharacterDetailViewModel.rateJoke()` still uses `min(max(rating, 1), 5)` clamping while `JokeViewModel.handleRatingNotification()` expects only 1 or 5, intermediate values cause bugs.

**Consequences:**
- Rating a joke in character view doesn't update Me tab correctly
- Or worse: rating in character view saves "3" which gets dropped/ignored in Me tab
- Duplicate rating logic (same code in both ViewModels) means double the places to update

**Warning signs:**
- Updating `rateJoke()` in one ViewModel but not the other
- Notification userInfo still passing old rating values
- `logRatingEvent` check `if clampedRating == 1 || clampedRating == 5` works correctly but `updateJokeRating` transaction still adds to `rating_sum` with old formula

**Prevention:**
1. **Extract shared rating logic** into a `RatingService` or extension that both ViewModels call
2. Update BOTH `rateJoke()` methods simultaneously:
   - `JokeViewModel.rateJoke()` (line 863)
   - `CharacterDetailViewModel.rateJoke()` (line 223)
3. Binary rating means `onRate` callback only receives 1 (horrible) or 5 (hilarious) -- validate at the call site
4. Ensure the `logRatingEvent` guard `if clampedRating == 1 || clampedRating == 5` still fires for ALL ratings (since all ratings are now 1 or 5)
5. Consider whether `updateJokeRating()` transaction (adding to `rating_sum`) still makes sense with binary values

**Which phase should address:** Phase 1 or 2 (wherever rating logic changes happen) -- both ViewModels must be updated in the same commit.

---

### Pitfall 8: Leaderboard Ranking Ties at Low Volume

**What goes wrong:** With 433 jokes and a small user base, many jokes end up tied with the same hilarious or horrible count (e.g., 1 vote each), making the "Top 10" meaningless or arbitrary.

**Why it happens:** The current `rankTopN()` function sorts by count and takes top 10. With sparse data, dozens of jokes may have count=1. The sort is unstable, so the Top 10 changes randomly between aggregation runs even when no new ratings arrive.

**Consequences:**
- Users see different Top 10 on each visit (confusing)
- Top 10 all show "1 rating" -- not compelling content
- Rankings appear broken or random

**Warning signs:**
- Many jokes with identical vote counts
- Leaderboard content changing between visits without new ratings
- No secondary sort criteria in `rankTopN()`

**Prevention:**
1. **Add tiebreaker sorting** -- when counts are equal, sort by `popularity_score` or `rating_avg` as secondary criterion:
   ```javascript
   .sort((a, b) => {
       if (b.count !== a.count) return b.count - a.count;
       return b.popularityScore - a.popularityScore; // tiebreaker
   })
   ```
2. **Set a minimum threshold** to appear in rankings (e.g., at least 3 votes):
   ```javascript
   const filtered = Object.entries(counts)
       .filter(([_, count]) => count >= 3);
   ```
3. Show "Not enough ratings yet" placeholder instead of a sparse leaderboard
4. Consider keeping a "weekly" or "monthly" view alongside all-time to give fresh content a chance

**Which phase should address:** Phase 2 (Cloud Function) -- include tiebreaker logic when updating aggregation.

---

### Pitfall 9: Scroll Position Reset on Me Tab Redesign

**What goes wrong:** Changing MeView from a 5-section `List` to a 2-section layout causes the scroll position to reset to top whenever ratings change, and tab switches lose scroll position.

**Why it happens:** SwiftUI `List` uses view identity for scroll position preservation. Changing section structure means SwiftUI considers it a new view hierarchy and resets scroll. The existing `ratedJokesList` uses `ForEach(jokes)` within sections -- changing the number of sections forces a full re-render.

**Consequences:**
- User rates a joke in the sheet, dismisses, and the Me tab scrolled back to top
- Switching between Home and Me tabs resets scroll position
- Removing/adding sections causes visible layout jump

**Warning signs:**
- Changing `Section` structure in the same view without using stable identifiers
- Using `withAnimation` on the `rateJoke` call that changes section membership
- Not testing the "rate joke from detail sheet then dismiss" flow

**Prevention:**
1. Use `scrollPosition(id:)` (iOS 17+) to preserve scroll position across re-renders
2. When changing from 5 sections to 2, ensure the `ForEach` identity (joke `id`) remains stable
3. Avoid `withAnimation` on rating changes that move jokes between sections -- the section change itself is jarring
4. Test the complete flow: tap joke -> rate in sheet -> dismiss -> verify scroll position maintained
5. Per existing CLAUDE.md convention: "Use `withAnimation` at the mutation site in the ViewModel. Never put `.animation()` on scroll containers."

**Which phase should address:** Phase 3 (UI redesign) -- test scroll behavior as acceptance criteria.

**Source:** [SwiftUI ScrollView reset position | Apple Developer Forums](https://developer.apple.com/forums/thread/127737), [TabView with ScrollView: scroll position | Apple Developer Forums](https://developer.apple.com/forums/thread/770039)

---

### Pitfall 10: Rating Event Deduplication Key Change

**What goes wrong:** The current `rating_events` document ID is `{deviceId}_{jokeId}_{weekId}`. Removing the week-based windowing means the deduplication key must change, but changing it means a single user can have both old (weekly) and new (all-time) events for the same joke.

**Why it happens:** The document ID format `deviceId_jokeId_weekId` allowed one rating per joke per week per device. For all-time, you want one rating per joke per device (no week). If you change the document ID to `{deviceId}_{jokeId}`, existing documents with the old key format are not overwritten -- they coexist.

**Consequences:**
- Same user's joke counted twice in all-time aggregation (once from old weekly key, once from new key)
- Inflated counts that can't be easily deduplicated
- If user re-rates a joke, new document created instead of updating old one

**Warning signs:**
- Changing `logRatingEvent()` document ID format without migration
- Cloud Function counting documents without deduplicating by `(device_id, joke_id)` pair
- `setData(eventData, merge: true)` no longer deduplicating because key format changed

**Prevention:**
1. **Change the Cloud Function aggregation to deduplicate at query time** rather than relying on document ID:
   ```javascript
   // Group by (device_id, joke_id), take the latest rating per group
   const latestByPair = {};
   for (const event of events) {
       const key = `${event.device_id}_${event.joke_id}`;
       if (!latestByPair[key] || event.timestamp > latestByPair[key].timestamp) {
           latestByPair[key] = event;
       }
   }
   ```
2. OR run a one-time migration script that consolidates old weekly events into new all-time format document IDs
3. **Recommended:** Keep the existing `logRatingEvent()` writing new format `{deviceId}_{jokeId}` for new events, and handle deduplication in the aggregation function that processes both old and new format events

**Which phase should address:** Phase 2 (Cloud Function) -- deduplication logic must be designed alongside all-time aggregation.

---

## Minor Pitfalls

Mistakes that cause annoyance or minor issues but are fixable.

### Pitfall 11: "Monthly Top 10" Naming Inconsistency After All-Time Switch

**What goes wrong:** The UI says "Monthly Top 10" but the data is now all-time. Confuses users and creates naming inconsistency across codebase.

**Why it happens:** `MonthlyTopTenCarouselView`, `MonthlyTopTenDetailView`, `MonthlyRankingsViewModel`, `MonthlyTop10Header`, and `MonthlyTopTenCard` all have "Monthly" in their names. The Firestore collection is still called `weekly_rankings`. Titles, headers, filenames, and collection names all reference the wrong time window.

**Prevention:**
1. Rename files and types to remove time-window references: `TopTenCarouselView`, `RankingsViewModel`, etc.
2. Update or create a new Firestore collection (e.g., `alltime_rankings`) rather than repurposing `weekly_rankings`
3. Update UI strings: "Monthly Top 10" -> "All-Time Top 10" or "Top 10"
4. Consider keeping the `weekly_rankings` collection for backward compatibility with old app versions

**Which phase should address:** Phase 3 (UI changes) -- rename alongside the visual redesign.

---

### Pitfall 12: Preview and Test Data Still Uses 5-Point Scale

**What goes wrong:** SwiftUI `#Preview` blocks and test data still use `userRating: 3` or `userRating: 4`, making it impossible to visually verify the new binary rating UI during development.

**Why it happens:** Multiple preview blocks across `JokeCardView`, `JokeDetailSheet`, `MeView`, and `GrainOMeterView` hardcode 5-point ratings. Developers don't update previews and then miss visual bugs.

**Prevention:**
1. Update all `#Preview` blocks to use only `userRating: 1` or `userRating: 5` (or `nil`)
2. Search codebase for all instances of `userRating:` in preview code
3. Update the `GroanOMeterView` preview to show new binary rating component
4. Remove the `CompactGroanOMeterView` preview showing all 5 emoji states

**Which phase should address:** Phase 3 (UI changes) -- update previews when updating views.

---

### Pitfall 13: Orphaned "Neutral" Ratings (Previously 3)

**What goes wrong:** Users who rated jokes as "3" (Meh) on the old system have their ratings dropped during migration, but the jokes remain visible as "rated" in the Me tab with no category.

**Why it happens:** The migration maps 4-5 -> Hilarious, 1-2 -> Horrible, and drops 3s. But if the `userRating` field is set to `nil` for dropped ratings, the joke disappears from Me tab. If it's left as `3`, the binary UI has no section for it.

**Prevention:**
1. **Explicitly convert 3s to nil** in the migration and remove from Me tab -- this is the cleanest approach
2. Show a one-time message: "We simplified ratings! Some neutral ratings were cleared."
3. Alternatively, prompt users to re-rate their "Meh" jokes on first launch after update
4. In `MeView`, add a fallback for any rating not matching 1 or 5: silently include in the "All Rated" view or ignore

**Which phase should address:** Phase 1 (Data Migration) -- decide on neutral rating strategy before building UI.

---

### Pitfall 14: EmptyStateView Text References Star Ratings

**What goes wrong:** The `EmptyStateView` in `MonthlyTopTenDetailView.swift` says "Jokes rated 5 stars will appear here" and "Jokes rated 1 star will appear here". After switching to binary, "5 stars" / "1 star" no longer matches the UI.

**Prevention:**
1. Update empty state text to reference new rating labels: "Jokes rated Hilarious will appear here"
2. Search entire codebase for "star" / "stars" references related to ratings
3. Check accessibility labels that might reference the 5-point scale

**Which phase should address:** Phase 3 (UI changes) -- text update alongside visual redesign.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Data Migration | UserDefaults type mismatch data loss (#1) | Keep `[String: Int]` format, map binary to 1/5 |
| Data Migration | Orphaned neutral ratings (#13) | Explicitly set to nil, communicate change to users |
| Data Migration | Cross-ViewModel notification mismatch (#7) | Update both ViewModels in same commit |
| Cloud Function / Backend | Mixed schema in rating_events (#2) | Keep 4-5/1-2 bucketing, backward compatible |
| Cloud Function / Backend | All-time query timeout (#5) | Use write-time counters on joke documents |
| Cloud Function / Backend | Deduplication key conflict (#10) | Deduplicate in aggregation logic, not document ID |
| Cloud Function / Backend | Document write limit during migration (#3) | Batch writes during low-traffic window |
| Cloud Function / Backend | Ranking ties at low volume (#8) | Add tiebreaker sort, minimum threshold |
| UI Redesign | GroanOMeter gesture regression (#4) | Build new component, update all display touchpoints |
| UI Redesign | Me Tab section collapse (#6) | Ship data migration and UI change together |
| UI Redesign | Scroll position reset (#9) | Stable ForEach identity, scoped animations |
| UI Redesign | Naming inconsistency (#11) | Rename files/types to remove time references |
| UI Redesign | Preview data outdated (#12) | Update all #Preview blocks |
| UI Redesign | Star rating text references (#14) | Search and update all copy |

---

## Integration-Specific Warnings for Existing Codebase

Based on detailed review of the current implementation:

### Touchpoints That Must Be Updated Atomically

The following files all reference the 5-point rating system and must be updated together to avoid inconsistency:

| File | What References 5-Point Scale |
|------|-------------------------------|
| `Joke.swift` | `ratingEmoji` (switch 1-5), `ratingEmojis` static array |
| `GrainOMeterView.swift` | `ratingOptions` 5-element array, `DragGesture` math, `CompactGroanOMeterView` 5-element array |
| `JokeDetailSheet.swift` | References `GroanOMeterView(currentRating:onRate:)` |
| `JokeCardView.swift` | Shows `CompactGroanOMeterView(rating:)` |
| `JokeViewModel.swift` | 5 filtered computed properties (`hilariousJokes` through `horribleJokes`), rating clamping `min(max(rating, 1), 5)`, rating event logging guard |
| `CharacterDetailViewModel.swift` | Same rating clamping and event logging |
| `MeView.swift` | 5 rating sections with emoji headers |
| `LocalStorageService.swift` | `saveRating` stores Int, `getRating` returns Int? |
| `FirestoreService.swift` | `updateJokeRating` transaction adds to `rating_sum`, `logRatingEvent` writes rating 1-5 |
| `functions/index.js` | `aggregateRatings` function bucketing logic |
| `FirestoreModels.swift` | `WeeklyRankings` struct, `RankingType` enum, `EmptyStateView` text |
| `MonthlyTopTenDetailView.swift` | "5 stars" / "1 star" text, "Monthly" naming |
| `MonthlyTopTenCarouselView.swift` | "Monthly Top 10" header text |
| `MonthlyRankingsViewModel.swift` | `fetchWeeklyRankings()` call |

### Current Architecture Strengths (Keep These)

1. **`firestoreId` as primary rating key** -- `LocalStorageService` already uses `firestoreId` for cross-view consistency. This survives the migration unchanged.
2. **Rating event deduplication via `setData(merge: true)`** -- existing pattern works. Just change the document ID format.
3. **Notification-based cross-ViewModel sync** -- `jokeRatingDidChange` pattern works for binary ratings too. Just ensure both VMs send consistent values.
4. **Session-rated visibility** -- `sessionRatedJokeIds` pattern in `JokeViewModel` works regardless of rating scale.
5. **Haptic feedback pattern** -- `HapticManager.shared.selection()` on rate will work with new UI.
6. **`withAnimation` at mutation site convention** -- already established per CLAUDE.md.

### Data Flow That Changes

```
OLD FLOW:
User taps emoji (1-5) -> GroanOMeterView.onRate(rating) -> ViewModel.rateJoke(joke, rating: 1-5)
  -> LocalStorage.saveRating(rating: 1-5)
  -> FirestoreService.updateJokeRating(adds to rating_sum)
  -> FirestoreService.logRatingEvent(only if rating==1 or rating==5)

NEW FLOW:
User taps Hilarious/Horrible -> BinaryRatingView.onRate(rating) -> ViewModel.rateJoke(joke, rating: 1 or 5)
  -> LocalStorage.saveRating(rating: 1 or 5)
  -> FirestoreService.updateJokeBinaryRating(increments hilarious_count or horrible_count)
  -> FirestoreService.logRatingEvent(always, since rating is always 1 or 5)
```

Key change: `logRatingEvent` will now fire for EVERY rating (currently only 1 or 5), because all ratings are now 1 or 5. This means the rating_events collection will grow faster. Plan for this in aggregation design.

---

## Validation Checklist Before Each Phase

### Phase 1: Data Migration
- [ ] Install current App Store version, rate 10+ jokes across all 5 levels
- [ ] Install development build over it (update scenario)
- [ ] Verify ALL previously rated jokes still appear in Me tab
- [ ] Verify ratings of 4-5 now show as Hilarious
- [ ] Verify ratings of 1-2 now show as Horrible
- [ ] Verify ratings of 3 are handled per chosen strategy (nil'd or bucketed)
- [ ] Verify `LocalStorageService` memory cache is invalidated after migration
- [ ] Verify both ViewModels use consistent rating values

### Phase 2: Cloud Function / Backend
- [ ] Run aggregation on existing rating_events data -- verify backward compatibility
- [ ] Verify no double-counting of events from same user+joke
- [ ] Test with 1000+ simulated events -- verify no timeout
- [ ] Verify tiebreaker sorting produces stable results
- [ ] Test write-time counters with concurrent rating writes
- [ ] Verify billing stays within expected range

### Phase 3: UI Redesign
- [ ] New rating component fires correct values (1 or 5, never 2-4)
- [ ] Compact rating view shows correct indicator for binary ratings
- [ ] Me tab shows exactly 2 sections (Hilarious, Horrible)
- [ ] All #Preview blocks use binary rating values
- [ ] Scroll position preserved when switching tabs
- [ ] Scroll position preserved when rating from detail sheet
- [ ] All "star" / "Monthly" text references updated
- [ ] Haptic feedback fires on both Hilarious and Horrible taps
- [ ] "Remove rating" swipe action still works in Me tab
- [ ] Verify no `.animation()` on scroll containers per CLAUDE.md convention

---

## Sources

### Official Documentation
- [Summarize data with aggregation queries | Firestore](https://firebase.google.com/docs/firestore/query-data/aggregation-queries)
- [Write-time aggregations | Firestore](https://firebase.google.com/docs/firestore/solutions/aggregation)
- [Understand reads and writes at scale | Firestore](https://firebase.google.com/docs/firestore/understand-reads-writes-scale)
- [Best practices for Cloud Firestore](https://firebase.google.com/docs/firestore/best-practices)
- [UserDefaults | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/userdefaults)

### Community Resources (MEDIUM confidence)
- [Beware UserDefaults: a tale of hard to find bugs, and lost data](https://christianselig.com/2024/10/beware-userdefaults/)
- [Managing Data Persistence with UserDefaults: Best Practices and Common Pitfalls](https://www.momentslog.com/development/ios/managing-data-persistence-with-userdefaults-best-practices-and-common-pitfalls)
- [How to handle Firebase Firestore data migration and schema evolution](https://bootstrapped.app/guide/how-to-handle-firebase-firestore-data-migration-and-schema-evolution)
- [Schema Versioning with Google Firestore](https://www.captaincodeman.com/schema-versioning-with-google-firestore)
- [Firestore Query Performance Best Practices for 2026](https://estuary.dev/blog/firestore-query-best-practices/)
- [SwiftUI ScrollView reset position | Apple Developer Forums](https://developer.apple.com/forums/thread/127737)
- [TabView with ScrollView: scroll position | Apple Developer Forums](https://developer.apple.com/forums/thread/770039)
- [How I Stopped Worrying and Learned to Love Firestore Migrations](https://medium.com/@ali.behsoodi/how-i-stopped-worrying-and-learned-to-love-firestore-migrations-b5ff975f7301)
- [Introducing COUNT, TTLs, and better scaling in Firestore](https://firebase.blog/posts/2022/12/introducing-firestore-count-ttl-scale/)

### Confidence Assessment

| Pitfall Category | Confidence | Notes |
|-----------------|------------|-------|
| UserDefaults data loss (#1) | HIGH | Verified against actual `LocalStorageService` code + community reports |
| Mixed Firestore schema (#2) | HIGH | Verified against actual `functions/index.js` and `FirestoreService.swift` |
| Write limit during migration (#3) | HIGH | Official Firestore documentation on write limits |
| GroanOMeter regression (#4) | HIGH | Direct code analysis of gesture handling in `GrainOMeterView.swift` |
| All-time query timeout (#5) | HIGH | Official Firestore aggregation documentation + 60s deadline |
| Me Tab section collapse (#6) | HIGH | Direct code analysis of `MeView.swift` and `JokeViewModel.swift` |
| Cross-ViewModel mismatch (#7) | HIGH | Direct code analysis of notification patterns |
| Ranking ties (#8) | MEDIUM | Logic analysis of `rankTopN()` function |
| Scroll position reset (#9) | MEDIUM | Known SwiftUI issue per Apple Developer Forums |
| Deduplication key conflict (#10) | HIGH | Direct analysis of document ID format |
| Naming inconsistency (#11) | HIGH | Direct file/type name analysis |
| Preview data (#12) | HIGH | Direct code analysis |
| Orphaned neutral ratings (#13) | HIGH | Direct analysis of migration mapping |
| Star rating text (#14) | HIGH | Direct code analysis of `EmptyStateView` |
