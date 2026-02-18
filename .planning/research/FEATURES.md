# Feature Landscape: Binary Rating System & All-Time Top 10 (v1.1.0)

**Domain:** iOS content app with binary rating, leaderboard, and personal history
**Researched:** 2026-02-17
**Confidence:** HIGH (based on established UX patterns, codebase analysis, and platform precedent)

---

## Context

This research focuses on the v1.1.0 milestone for Mr. Funny Jokes, which changes three interconnected systems:

1. **Rating system** -- Replace 5-emoji scale (1-5) with binary Hilarious/Horrible
2. **Leaderboard** -- Replace Monthly Top 10 with All-Time Top 10
3. **Me tab** -- Redesign from 5 list sections to segmented control with 2 tabs

**Existing infrastructure being modified:**
- `Joke.userRating: Int?` (currently 1-5, will become 1 or 5)
- `GroanOMeterView` (5-emoji slider, will be replaced)
- `CompactGroanOMeterView` (single emoji indicator, will be simplified)
- `MeView` with 5 sections (Hilarious/Funny/Meh/Groan-worthy/Horrible)
- `MonthlyRankingsViewModel` fetching weekly_rankings by week_id
- Cloud Function aggregating rating_events with week_id filter
- `LocalStorageService` rating persistence (UserDefaults keyed by firestoreId)
- `rating_events` collection (documents keyed as `deviceId_jokeId_weekId`)
- `weekly_rankings` collection (documents keyed as `2026-W04`)

---

## Table Stakes

Features users expect when interacting with binary rating systems. Missing any = UX feels broken or confusing.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Two-option rating UI** | Binary choice must be immediately obvious and tappable | Low | Replace 5-emoji slider with Hilarious/Horrible buttons |
| **Instant visual feedback on rate** | User must see their choice confirmed immediately | Low | Already exists via `@Published userRating` reactivity |
| **Ability to change rating** | Users expect to re-rate; binary makes this even more expected | Low | Already works -- tap other option to switch |
| **Ability to remove rating** | Swipe-to-delete in Me tab already exists | Low | Keep existing pattern (rating = 0 removes) |
| **Rating persists across sessions** | Users return expecting their votes to still be there | Low | Already works via LocalStorageService |
| **Rating syncs to backend** | Votes must count toward leaderboard | Low | Already works via logRatingEvent |
| **Leaderboard shows top content** | All-time list with ranked jokes | Medium | Modify Cloud Function to aggregate all events, not just current week |
| **Personal history with binary filter** | Me tab must let users see their Hilarious vs Horrible votes | Medium | Replace 5-section List with segmented Picker |
| **Rated indicator on cards** | Feed cards must show if/how user rated | Low | CompactGroanOMeterView simplified to single emoji |
| **Migration of existing ratings** | 433 jokes with existing ratings must not disappear | Medium | Map 4-5 to Hilarious, 1-2 to Horrible, drop 3s |

---

### Feature: Binary Rating UI (Replace GroanOMeterView)

**What:** Two large, tappable buttons -- Hilarious (thumbs up / laughing emoji) and Horrible (thumbs down / melting emoji) -- replace the 5-emoji drag slider.

**Why binary works for this app:**
- Netflix saw 200% more ratings after switching from 5-star to binary (per Netflix VP Todd Yellin)
- YouTube found that when they had a 5-star system, the overwhelmingly most common rating was 5-stars, next was 1-star; 2-4 were rarely used
- A joke is either funny or not -- there is no meaningful "3 out of 5" for comedy
- Lower cognitive load means faster rating, more data, better leaderboard accuracy

**Expected UX behavior:**
- Unrated state: Both buttons visible, neither highlighted
- Rated state: Selected button highlighted with filled style, other dimmed
- Tapping the already-selected button could either (a) deselect or (b) do nothing -- recommendation: do nothing (deselection via swipe-to-delete in Me tab is cleaner)
- Tapping the other button switches the rating immediately
- Haptic feedback on selection (already pattern: `HapticManager.shared.selection()`)

**Implementation approach:**
- Two side-by-side buttons or a segmented Picker in the JokeDetailSheet
- On JokeCardView, CompactGroanOMeterView shows single emoji for the user's rating
- `onRate` callback stays as `(Int) -> Void` but only receives 1 (Horrible) or 5 (Hilarious)
- Clamp logic in `rateJoke()` changes from `min(max(rating, 1), 5)` to only accepting 1 or 5

**Complexity:** Low
- GroanOMeterView replacement is straightforward -- simpler UI, fewer states
- CompactGroanOMeterView simplifies from 5 cases to 2

**Dependencies:**
- `Joke.userRating` field (no schema change needed, values just restricted to 1 or 5)
- `JokeDetailSheet.onRate` callback (no signature change)
- `JokeCardView.onRate` callback (no signature change)

---

### Feature: Rating Data Migration (Existing 1-5 to Binary)

**What:** Convert existing locally stored ratings from 5-point scale to binary.

**Migration mapping:**
- Rating 4 or 5 --> 5 (Hilarious)
- Rating 1 or 2 --> 1 (Horrible)
- Rating 3 --> removed (neutral; dropped)

**Why this mapping:**
- The existing Cloud Function already treats 4-5 as "hilarious" and 1-2 as "horrible"
- Rating 3 is already excluded from ranking events (neutral, not counted)
- This mapping preserves the intent behind existing votes

**Expected behavior:**
- Migration runs once on first launch after update
- User sees their previously rated jokes under the correct binary category
- No visible migration process -- it should be seamless
- Dropped "3" ratings mean some jokes disappear from Me tab -- this is acceptable since "meh" has no binary equivalent

**Implementation approach:**
- On app launch, check for migration flag in UserDefaults
- If not migrated: iterate all stored ratings, apply mapping, save back
- Set migration flag to prevent re-running
- Also update in-memory `jokes` array ratings to match

**Complexity:** Medium
- Local migration is straightforward (iterate UserDefaults dictionary)
- Must also handle rating_events in Firestore -- but existing events with rating 4 already work since Cloud Function already maps 4-5 to hilarious
- The tricky part: ensuring the migration runs before any UI renders rated jokes

**Dependencies:**
- `LocalStorageService.loadRatingsSync()` -- reads all ratings
- `LocalStorageService.saveRatingsSync()` -- writes migrated ratings
- App launch sequence (MrFunnyJokesApp or JokeViewModel init)

**Risk:** LOW -- Netflix kept old star data but did not expose it. This app has a small user base (early stage), so migration complexity is minimal.

---

### Feature: All-Time Top 10 Leaderboard

**What:** Replace monthly rolling window with cumulative all-time ranking.

**Why all-time over monthly:**
- Not enough users for meaningful monthly rankings (app is early stage, 433 jokes)
- All-time accumulates value -- early ratings are not lost
- Simpler mental model for users ("the best jokes ever" vs "the best jokes this month")
- Eliminates "empty leaderboard" problem at start of each month

**Expected UX behavior:**
- Same visual layout as current Monthly Top 10 (carousel preview + detail view)
- Segmented control: Hilarious / Horrible (already exists as RankingType enum)
- Ranked joke cards with position badges (already exists as RankedJokeCard)
- Title changes from "Monthly Top 10" to "All-Time Top 10"
- Date range subtitle removed (or changed to "Since launch" / total rating count)
- Total ratings count shown on carousel cards (already shown)

**Technical approach -- Cloud Function changes:**
- Remove week_id filter from rating_events query -- aggregate ALL events
- Change document ID from `2026-W04` to `all-time` (single document, overwritten daily)
- Remove week_start/week_end fields (or repurpose as first_event/last_event dates)
- Keep the same ranking algorithm (count per joke, sort descending, top 10)

**Technical approach -- Client changes:**
- `MonthlyRankingsViewModel` renamed to `AllTimeRankingsViewModel`
- `fetchWeeklyRankings()` fetches document `all-time` instead of computed week ID
- Remove `monthDateRange` property, add total count or "Since [date]" display
- Update UI labels: "Monthly Top 10" --> "All-Time Top 10" throughout

**Complexity:** Medium
- Cloud Function change is simple (remove `where("week_id", "==", weekId)`)
- Client changes are mostly renaming and removing week-specific logic
- Need to handle one-time recomputation of all-time rankings from all existing events

**Dependencies:**
- `rating_events` collection (existing, no schema change needed)
- `weekly_rankings` collection (rename to `all_time_rankings` or keep name, change doc ID)
- Cloud Function deployment
- `FirestoreService.fetchWeeklyRankings()` (rename and update query)
- All views referencing "Monthly" (carousel, detail view, headers)

**Firestore cost note:** Aggregating ALL rating_events on every daily run grows linearly with total events. At 433 jokes and early user base, this is negligible. If the app scales significantly, a write-time aggregation pattern (increment counters on each rating event) would be more efficient. For now, the scheduled batch approach is appropriate.

---

### Feature: Me Tab Redesign (Segmented Binary View)

**What:** Replace 5-section grouped List with a segmented control (Hilarious / Horrible) filtering a flat list.

**Current Me tab structure:**
```
Hilarious (5-star) section
Funny (4-star) section
Meh (3-star) section
Groan-worthy (2-star) section
Horrible (1-star) section
```

**New Me tab structure:**
```
[Segmented Control: Hilarious | Horrible]
[Flat list of jokes matching selected segment]
```

**Why this redesign:**
- Matches the Top 10 detail view layout (segmented control with same categories)
- UI consistency across app -- both Me tab and Top 10 use same Hilarious/Horrible toggle
- Simpler to scan -- no 5 collapsible sections, just one flat list
- Binary naturally maps to 2-tab segmented control

**Expected UX behavior:**
- Default to "Hilarious" tab on first visit (positive-first)
- Segmented control at top, joke list below
- Each joke row shows: setup text, character indicator, category, tap to open detail sheet
- Swipe-to-delete removes rating (existing pattern, keep it)
- Empty state per segment: "No Hilarious jokes rated yet" / "No Horrible jokes rated yet"
- Count badge in segment label or below: "Hilarious (12)" and "Horrible (5)"
- Category filter (selectedMeCategory) can remain as additional filter within each segment
- Sorted by most recently rated (existing sortByRatingTimestamp behavior)

**Implementation approach:**
- Add `@State var selectedMeSegment: RankingType = .hilarious` to MeView
- Use existing `Picker("Category", selection: $selectedMeSegment).pickerStyle(.segmented)`
- Reuse existing `JokeRowView` for list items
- ViewModel changes: collapse `filteredHilariousJokes` + `filteredFunnyJokes` into single `filteredHilariousJokes` (rating 5 only), collapse `filteredHorribleJokes` + `filteredGroanJokes` into single `filteredHorribleJokes` (rating 1 only)
- Remove `filteredFunnyJokes`, `filteredMehJokes`, `filteredGroanJokes` computed properties

**Complexity:** Medium
- View restructuring is straightforward
- ViewModel simplification removes code (net negative lines)
- Must ensure empty states work per segment

**Dependencies:**
- `RankingType` enum (exists, has .hilarious and .horrible cases)
- `JokeRowView` (exists, reusable)
- `JokeViewModel.filteredHilariousJokes` and `filteredHorribleJokes` (exist, need value remapping)
- Rating migration must complete before Me tab renders (avoids showing stale 5-tier data)

---

### Feature: Updated Compact Rating Indicator

**What:** Feed cards show a small emoji indicating the user's binary rating.

**Current:** `CompactGroanOMeterView` maps rating 1-5 to one of five emojis.

**New:** Only two possible states:
- Hilarious: Show laughing emoji (or thumbs up)
- Horrible: Show melting emoji (or thumbs down)

**Complexity:** Low -- simplify existing `CompactGroanOMeterView` from 5 cases to 2.

---

## Differentiators

Features that go beyond basic expectations. Not missing = not broken, but having them = polish.

| Feature | Value Proposition | Complexity | Priority | Notes |
|---------|-------------------|------------|----------|-------|
| **Animated rating transition** | Satisfying micro-interaction when rating | Low | Should have | Spring animation on button select |
| **Rating count on leaderboard cards** | Shows joke popularity at a glance | Low | Already exists | `rankedJoke.count` display |
| **"Your vote counted" toast** | Confirms rating synced to backend | Low | Could have | Optional -- current haptic may suffice |
| **Undo rating in feed** | Quick undo without navigating to Me tab | Medium | Defer | Adds complexity; swipe-to-delete in Me tab covers the use case |
| **Streak indicator** | Show how many jokes rated in a row | Medium | Defer | Engagement gamification, not core for v1.1 |
| **Joke count per segment in Me tab** | Badge showing "(12)" next to "Hilarious" in picker | Low | Should have | Provides context before tapping |

### Feature: Animated Rating Transition

**What:** When user taps Hilarious or Horrible, the button scales up with a spring animation and the emoji bounces.

**Why it matters:** Rating is the core interaction. Making it feel good encourages more ratings, which improves the leaderboard. Netflix's 200% increase in ratings was partly attributed to making the thumbs interaction more satisfying than clicking stars.

**Implementation:** Use SwiftUI `.scaleEffect` with `.spring()` animation on selection state change. Already a pattern used in `GroanOMeterView` (.scaleEffect(displayIndex == index ? 1.15 : 1.0)).

**Complexity:** Low -- leverage existing animation patterns.

---

### Feature: Segment Count Badges

**What:** Me tab segmented control shows count: "Hilarious (12) | Horrible (5)"

**Why it matters:** Users want to know at a glance how many jokes they have in each category without tapping. Provides information scent.

**Implementation:**
```swift
Picker("Category", selection: $selectedSegment) {
    Text("\(RankingType.hilarious.emoji) Hilarious (\(viewModel.filteredHilariousJokes.count))")
        .tag(RankingType.hilarious)
    Text("\(RankingType.horrible.emoji) Horrible (\(viewModel.filteredHorribleJokes.count))")
        .tag(RankingType.horrible)
}
.pickerStyle(.segmented)
```

**Complexity:** Low -- computed property already provides count.

---

## Anti-Features

Features to explicitly NOT build. Common mistakes when implementing binary rating systems.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **"Meh" / neutral third option** | Defeats purpose of binary; re-introduces the ambiguity being eliminated | Two options only. Unrated = neutral by absence |
| **Star rating display anywhere** | Confusing to show stars alongside binary UI; mixed signals | Remove all star/emoji scale references |
| **Average rating display** | Binary ratings don't produce meaningful averages (e.g., 3.2 stars) | Show vote counts or Hilarious/Horrible ratio |
| **Real-time leaderboard updates** | Overkill for daily joke app; WebSocket infra not justified | Daily scheduled Cloud Function is sufficient |
| **Undo toast/snackbar on every rate** | Clutters UI; rating is low-stakes and easily changeable | Haptic feedback is sufficient confirmation |
| **Netflix-style "double thumbs up"** | Three-tier (great/good/bad) reintroduces complexity being removed | Stay purely binary |
| **Percentage match scores** | Requires recommendation engine; this is a browse-and-rate app, not a personalization platform | Show raw counts instead |
| **Force re-rate migrated jokes** | Asking users to re-rate all their old jokes is hostile | Silent migration with sensible defaults |
| **Confirmaton dialog before rating** | Binary rating should be one-tap, zero-friction | Immediate apply with haptic |
| **Separate "unrate" button** | Extra UI element with low utility in binary system | Swipe-to-delete in Me tab (existing) |

### Anti-Feature Detail: Neutral / "Meh" Third Option

**Why it keeps coming up:** The current 5-point scale has a prominent "Meh" (3-star) category, and developers instinctively feel something is lost without it.

**Why it is wrong for this app:**
- The entire point of moving to binary is to force a choice. "Was it funny or not?"
- YouTube's data showed that when granularity was available, users overwhelmingly chose extremes anyway
- A neutral option reduces signal quality for the leaderboard (neither positive nor negative data)
- Users who feel "meh" simply will not rate -- and that absence of a rating IS the neutral signal

**What happens to "3" ratings during migration:** They are dropped. The joke returns to unrated state. If the user encounters it again, they must make a binary choice. This is by design.

### Anti-Feature Detail: Average Rating Display

**Why it is wrong for binary:**
- An average of binary votes (e.g., 73% Hilarious) requires enough votes to be statistically meaningful
- With 433 jokes and a small user base, most jokes will have 0-3 votes -- making percentages misleading
- The leaderboard (Top 10 by count) is the correct way to surface popularity
- Showing "1 out of 1 voted Hilarious (100%)" on a joke card is meaningless noise

---

## Feature Dependencies

```
Rating Migration (must run first)
    |
    +--> LocalStorageService ratings dictionary
    +--> App launch sequence (before UI renders)
    +--> Modifies: all stored rating values from 1-5 to 1 or 5

Binary Rating UI
    |
    +--> New GroanOMeterView (or rename to BinaryRatingView)
    +--> Updated CompactGroanOMeterView (2 cases instead of 5)
    +--> JokeDetailSheet (uses new rating view)
    +--> JokeCardView (uses updated compact view)
    +--> CharacterDetailView (uses updated compact view)
    +--> JokeOfTheDayView (uses new rating view)
    +--> SearchView (uses updated compact view)
    +--> rateJoke() validation (accept only 1 or 5)

All-Time Top 10
    |
    +--> Cloud Function update (remove week_id filter)
    +--> One-time full aggregation of all existing rating_events
    +--> FirestoreService.fetchWeeklyRankings() --> fetchAllTimeRankings()
    +--> MonthlyRankingsViewModel --> AllTimeRankingsViewModel
    +--> MonthlyTopTenCarouselView --> AllTimeTopTenCarouselView
    +--> MonthlyTopTenDetailView --> AllTimeTopTenDetailView
    +--> MonthlyTop10Header --> AllTimeTop10Header

Me Tab Redesign
    |
    +--> Rating migration complete (so jokes are in binary categories)
    +--> RankingType enum (existing, provides .hilarious / .horrible)
    +--> Remove: filteredFunnyJokes, filteredMehJokes, filteredGroanJokes
    +--> Update: hilariousJokes filter (was ==5, stays ==5)
    +--> Update: horribleJokes filter (was ==1, stays ==1)
    +--> MeView restructured with segmented Picker
    +--> Remove 5-section List layout

Rating Event Changes
    |
    +--> logRatingEvent currently only fires for rating 1 or 5 (already correct)
    +--> Document ID format change: remove weekId from composite key
    |    Current: "{deviceId}_{jokeId}_{weekId}"
    |    New: "{deviceId}_{jokeId}" (all-time, deduplicated per device per joke)
    +--> Cloud Function aggregation query: remove week_id filter
```

**Critical ordering:**
1. Rating migration MUST happen before Me tab redesign (stale 3-star ratings would show nowhere)
2. Cloud Function update MUST happen before All-Time Top 10 UI (client needs data to display)
3. Binary rating UI can happen in parallel with leaderboard changes (independent code paths)
4. Rating event document ID change should happen alongside Cloud Function update

---

## MVP Recommendation

For v1.1.0 milestone, all four features are required (they are interconnected):

### Phase 1: Data Layer Changes
1. **Rating migration logic** -- Run on first launch, convert 1-5 to binary
2. **Cloud Function update** -- Remove week filter, aggregate all-time, new document format
3. **Rating event deduplication change** -- Remove weekId from composite document ID
4. **Firestore client updates** -- Fetch all-time document, rename ViewModel

**Rationale:** Data layer must be correct before UI changes. Migration must run before Me tab can display binary data correctly. Cloud Function must produce all-time rankings before leaderboard UI can show them.

### Phase 2: UI Changes
5. **Binary rating UI** -- Replace GroanOMeterView with two-button layout
6. **Me tab redesign** -- Segmented control with Hilarious/Horrible tabs
7. **All-Time Top 10 UI** -- Rename labels, remove date range, update headers
8. **Compact rating indicator** -- Simplify to 2-emoji display

**Rationale:** All UI changes can happen together once data layer is settled. They are mostly independent view files.

### Phase 3: Polish
9. **Rating animation** -- Spring bounce on button select
10. **Segment count badges** -- Show joke counts in Me tab picker
11. **Empty state messaging** -- Update all empty states for binary context

### Defer to Later
- Undo rating in feed (swipe-to-delete in Me tab covers this)
- Streak indicators (engagement gamification, not core)
- "Your vote counted" toast (haptic is sufficient)
- Netflix-style double thumbs up (complexity for marginal value)

---

## Implementation Complexity Summary

| Feature | Complexity | Effort Estimate | Risk |
|---------|------------|-----------------|------|
| Rating migration | Medium | 2-3 hours | Low -- straightforward dictionary mapping |
| Binary rating UI | Low | 2-4 hours | Low -- simpler than current 5-emoji slider |
| All-Time Cloud Function | Medium | 2-3 hours | Low -- removing filter is simpler than adding |
| All-Time client changes | Medium | 3-4 hours | Low -- mostly renaming and removing week logic |
| Me tab redesign | Medium | 3-4 hours | Low -- removing sections, adding segmented control |
| Compact rating update | Low | 1 hour | Very Low -- fewer cases |
| Rating event dedup change | Low | 1-2 hours | Medium -- must not break existing events |
| Polish (animations, counts, empty states) | Low | 2-3 hours | Very Low |

**Total estimated effort:** 16-24 hours for entire v1.1.0 milestone.

---

## Key Decisions for Roadmap

### 1. Rating Value Encoding: Keep 1 and 5 or Use New Values?

**Recommendation: Keep 1 (Horrible) and 5 (Hilarious).**
- Cloud Function already maps 4-5 to hilarious, 1-2 to horrible
- Existing rating_events in Firestore use these values
- No schema migration needed on the backend
- LocalStorageService stores Int values -- 1 and 5 work fine
- Migration just narrows the range, does not change the encoding

### 2. What Happens to the "weekly_rankings" Collection Name?

**Recommendation: Keep the collection name "weekly_rankings" but use document ID "all-time".**
- Renaming a Firestore collection requires creating a new collection and migrating all documents
- The collection name is internal (users never see it)
- Just change the document ID from `2026-W04` to `all-time`
- Add a code comment explaining the naming debt
- This mirrors the existing pattern (collection already named "weekly" while showing "Monthly")

### 3. Should "Meh" (3-star) Users Be Notified?

**Recommendation: No.**
- The app has no user accounts or communication channel
- Ratings are anonymous/device-local
- Dropped 3-star ratings are a minor data loss for a small user base
- The alternative (keeping 3s in some limbo state) adds complexity with zero benefit

### 4. Should We Support Both Rating Scales During Transition?

**Recommendation: No. Hard cutover.**
- Binary and 5-point cannot coexist in the same UI
- Migration happens at app launch before any UI renders
- There is no server-side user state to migrate (ratings are device-local + anonymous events)
- App Store update naturally gates the transition

---

## Sources

### Binary Rating UX Research
- [Appcues: 5 Stars vs Thumbs Up/Down](https://www.appcues.com/blog/rating-system-ux-star-thumbs) -- Netflix/YouTube case studies, engagement data
- [UX Planet: How to Design User Rating and Reviews](https://uxplanet.org/how-to-design-user-rating-and-reviews-1b26c0208d3a) -- Rating system design patterns
- [Prototypr: 5-Star vs Thumbs-Up](https://prototypr.io/news/5-star-vs-thumbs-up-when-to-use-which-rating-system) -- When to use which system
- [Yale Insights: Thumbs Up/Down Eliminates Bias](https://insights.som.yale.edu/insights/simple-thumbs-up-or-down-eliminates-racial-bias-in-online-ratings) -- Binary reduces rating bias

### Leaderboard Design
- [UI Patterns: Leaderboard Design Pattern](https://ui-patterns.com/patterns/leaderboard) -- UX patterns for leaderboards
- [System Design One: Leaderboard System Design](https://systemdesign.one/leaderboard-system-design/) -- Technical architecture patterns
- [Firebase: Build Leaderboards with Firestore](https://firebase.google.com/codelabs/build-leaderboards-with-firestore) -- Official Firebase leaderboard codelab
- [Firebase: Write-time Aggregations](https://firebase.google.com/docs/firestore/solutions/aggregation) -- Aggregation strategies

### SwiftUI Implementation
- [Hacking with Swift: Segmented Control](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-segmented-control-and-read-values-from-it) -- Native Picker with .segmented style
- [Apple: SegmentedPickerStyle](https://developer.apple.com/documentation/swiftui/segmentedpickerstyle) -- Official documentation

---

*Researched: 2026-02-17 | Confidence: HIGH | Ready for roadmap creation*
