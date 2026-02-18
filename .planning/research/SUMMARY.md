# Project Research Summary

**Project:** Mr. Funny Jokes v1.1.0
**Domain:** iOS rating system migration and leaderboard redesign
**Researched:** 2026-02-17
**Confidence:** HIGH

## Executive Summary

The v1.1.0 milestone simplifies the joke rating system from 5-point (1-5) to binary (Hilarious/Horrible) and replaces monthly rankings with all-time Top 10. This change touches every layer of the app: UI components, ViewModels, local storage, Firestore schema, and Cloud Functions. The good news: this is a **simplification**, not a feature addition. The existing architecture is well-structured for this change — MVVM boundaries are clean, the rating pipeline is centralized, and most work involves removing complexity rather than building new systems.

The research reveals that **zero new dependencies are required**. Every capability needed — binary rating UI, data migration, all-time aggregation — is achievable with the existing SwiftUI, Firebase Firestore, and Cloud Functions stack. The codebase already contains the exact patterns needed: a segmented Picker exists in MonthlyTopTenDetailView, rating events are already filtered to values 1 and 5, and batch migration scripts are an established pattern. The primary risk is **data migration timing** — existing users' ratings must be preserved and properly migrated, and the changes to local storage, Cloud Functions, and UI must be coordinated to avoid inconsistent states.

The recommended approach is a phased rollout: migrate data first (both local UserDefaults and establish the all-time Cloud Function), then update the rating UI, then redesign the Me tab, and finally rename the leaderboard. This order minimizes risk of data loss and ensures users always see consistent state. The critical pitfall to avoid is changing the UserDefaults storage format — keeping ratings as `[String: Int]` with values constrained to 1 or 5 preserves all existing data while enabling binary semantics.

## Key Findings

### Recommended Stack

The milestone requires **no new dependencies or libraries**. All changes use the existing stack with refactored logic:

**Core technologies (unchanged):**
- **SwiftUI** with native `Picker(.segmented)` — already used in MonthlyTopTenDetailView for the Hilarious/Horrible toggle, proven pattern for binary choices
- **Firebase Firestore iOS SDK** — rating sync continues to use existing transaction-based `updateJokeRating()`, no schema changes to jokes collection
- **Cloud Functions (Node.js 20)** — same runtime and dependencies, logic simplified by removing time-windowed queries
- **UserDefaults** for local ratings — keep `[String: Int]` type, map binary ratings to 1 (Horrible) and 5 (Hilarious) to preserve existing data
- **Combine** for cross-ViewModel sync — notification pattern unchanged

**Key implementation decisions:**
- Rating values stay as Int (1 or 5) rather than introducing a new enum — minimizes cascading type changes across storage, notifications, and Firestore
- Segmented control replaces drag slider — simpler interaction, better accessibility, follows existing codebase pattern
- All-time rankings stored in existing `weekly_rankings` collection with document ID "all_time" — pragmatic to avoid collection migration

### Expected Features

**Must have (table stakes):**
- **Binary rating UI** with immediate visual feedback — two large, tappable options (Hilarious/Horrible) replacing 5-emoji slider
- **Rating persistence** across sessions and to backend — UserDefaults + Firestore sync unchanged
- **All-time Top 10 leaderboard** replacing monthly — Cloud Function aggregates all rating_events without week filter
- **Me tab binary filter** with segmented control — Hilarious/Horrible tabs instead of 5 collapsible sections
- **Rating data migration** — map 4-5 to Hilarious, 1-2 to Horrible, drop 3s (neutral)
- **Rated indicator on cards** — CompactGroanOMeterView simplified to 2 emoji states

**Should have (polish):**
- **Animated rating transition** — spring animation on button select (existing pattern from GroanOMeterView)
- **Segment count badges** — "Hilarious (12) | Horrible (5)" in Me tab picker
- **Tiebreaker sorting** in rankings — when vote counts are equal, sort by popularity_score as secondary criterion

**Defer (v2+):**
- Undo rating in feed (swipe-to-delete in Me tab covers this use case)
- Streak indicators for engagement gamification
- "Your vote counted" toast (haptic feedback is sufficient)
- Netflix-style "double thumbs up" (reintroduces complexity being eliminated)

### Architecture Approach

The binary rating change is a **narrowing** of the existing pipeline, not a new system. The rating flow from user tap → local storage → Firestore → Cloud Function aggregation → leaderboard display remains intact. The key architectural insight: most components shrink or simplify rather than grow.

**Major components:**

1. **Rating UI layer** — Replace `GroanOMeterView` (5-emoji drag slider) with `BinaryRatingView` (segmented Picker). Simplify `CompactGroanOMeterView` from 5 cases to 2. Update `Joke.ratingEmoji` computed property.

2. **ViewModel layer** — Remove `funnyJokes`, `mehJokes`, `groanJokes` computed properties from JokeViewModel. Simplify `rateJoke()` to only accept 1 or 5. Always log rating events (existing guard `if rating == 1 || rating == 5` becomes redundant since all ratings are now 1 or 5).

3. **Local storage layer** — One-time migration in `LocalStorageService` to remap 4→5, 2→1, remove 3s. Keep `[String: Int]` type for backward compatibility. Migration gated by UserDefaults flag, runs once on first launch.

4. **Firestore layer** — No schema changes to `jokes` collection. Cloud Function removes week_id filter from rating_events query and writes to single `all_time` document. Document ID format changes from `{deviceId}_{jokeId}_{weekId}` to `{deviceId}_{jokeId}` for new events; aggregation deduplicates at query time.

5. **Leaderboard layer** — Rename `MonthlyRankingsViewModel` to `AllTimeRankingsViewModel`. Update `fetchWeeklyRankings()` to read `all_time` doc. Update UI strings and headers.

**Integration points preserved:**
- Cross-ViewModel notification via `jokeRatingDidChange` (works with any Int rating value)
- Session-rated visibility tracking (unchanged)
- Haptic feedback on rate (`HapticManager.shared.selection()`)
- `withAnimation` at mutation site in ViewModel (never on scroll containers per CLAUDE.md convention)

### Critical Pitfalls

1. **UserDefaults rating data loss during type migration** — Changing the storage value type from Int silently wipes all existing ratings. **Prevention:** Keep `[String: Int]` type, map binary to 1/5 values. Create migration script that reads old values, remaps in-place, writes back. Test update scenario (install current version, rate jokes, update to new version).

2. **Firestore rating_events mixed schema breaks aggregation** — Old events have rating values 2-4 which new binary logic might exclude. **Prevention:** Keep aggregation logic as `rating >= 4` for hilarious and `rating <= 2` for horrible to handle both old and new data. Do NOT narrow to only `rating == 1` or `rating == 5`.

3. **All-time aggregation query timeout on large collection** — Switching from week-filtered query to full collection scan causes Cloud Function timeouts as rating_events grows. **Prevention:** For v1.1 with 433 jokes and low traffic, full scan is acceptable. Plan for write-time counters (`hilarious_count`, `horrible_count` on joke documents) if collection exceeds 10K events.

4. **GroanOMeter gesture handling regression** — Reusing the 5-emoji drag slider code for 2 buttons produces incorrect ratings or layout bugs. **Prevention:** Build new `BinaryRatingView` component. Do NOT modify GroanOMeterView. Update all touchpoints: `Joke.ratingEmoji`, `CompactGroanOMeterView`, card display logic.

5. **Cross-ViewModel rating notification mismatch** — If one ViewModel is updated to binary before the other, rating sync breaks. **Prevention:** Update both `JokeViewModel.rateJoke()` and `CharacterDetailViewModel.rateJoke()` in same commit. Extract shared logic if possible.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Data Layer & Migration
**Rationale:** Data integrity is the foundation. All UI depends on correctly migrated ratings. Cloud Function must produce all-time data before leaderboard UI can display it.

**Delivers:**
- Local rating migration (UserDefaults 1-5 to binary)
- Updated Cloud Function (removes week filter, writes all_time doc)
- Initial all-time rankings data populated
- Firestore migration script for rating_events (optional — Cloud Function handles mixed data)

**Key files:**
- `LocalStorageService.swift` — add `migrateRatingsToBinary()` method
- `functions/index.js` — remove week_id filter, aggregate all events, write to `all_time` doc
- `scripts/migrate-ratings.js` — NEW (optional batch script for cleaning rating_events)

**Avoids:** Pitfall #1 (data loss), Pitfall #2 (mixed schema)

**Research flag:** LOW — established patterns (existing migration scripts, Cloud Function aggregation logic)

---

### Phase 2: Binary Rating UI
**Rationale:** Core interaction change. Once data layer is stable, replacing the rating UI is highest impact. This phase delivers immediate UX improvement.

**Delivers:**
- New `BinaryRatingView` component (segmented control replacing GroanOMeterView)
- Updated `CompactBinaryRatingView` for card indicators
- Simplified `rateJoke()` in both ViewModels
- Updated `Joke.ratingEmoji` computed property

**Key files:**
- `Views/BinaryRatingView.swift` — NEW (segmented Picker for rating selection)
- `Views/GrainOMeterView.swift` — MODIFY (update CompactGroanOMeterView to binary)
- `ViewModels/JokeViewModel.swift` — MODIFY (simplify rateJoke, always log events)
- `ViewModels/CharacterDetailViewModel.swift` — MODIFY (same rateJoke simplification)
- `Models/Joke.swift` — MODIFY (binary ratingEmoji logic)
- `Views/JokeDetailSheet.swift` — MODIFY (swap GroanOMeterView for BinaryRatingView)
- `Views/JokeCardView.swift` — MODIFY (updated compact view)

**Avoids:** Pitfall #4 (gesture regression), Pitfall #5 (cross-ViewModel mismatch)

**Research flag:** LOW — native SwiftUI Picker pattern already in codebase

---

### Phase 3: Me Tab Redesign
**Rationale:** Depends on both data migration (Phase 1) and binary rating UI (Phase 2). Simplifies from 5 sections to 2-tab segmented control.

**Delivers:**
- Me tab with Hilarious/Horrible segmented control
- Removed funnyJokes/mehJokes/groanJokes computed properties
- Updated empty states for binary context
- Segment count badges

**Key files:**
- `Views/MeView.swift` — MAJOR REDESIGN (segmented control + 2 lists)
- `ViewModels/JokeViewModel.swift` — MODIFY (remove 3 filtered computed properties)

**Avoids:** Pitfall #6 (section collapse during migration), Pitfall #9 (scroll position reset)

**Research flag:** LOW — follows existing MonthlyTopTenDetailView segmented control pattern

---

### Phase 4: All-Time Leaderboard UI
**Rationale:** Depends on Cloud Function (Phase 1) having populated all_time data. This is display-only, doesn't block rating flow, can come last.

**Delivers:**
- All-time Top 10 views and ViewModel
- Updated UI strings ("Monthly" → "All-Time")
- Removed date range display
- Deleted old MonthlyTopTen files

**Key files:**
- `ViewModels/AllTimeRankingsViewModel.swift` — NEW (renamed from Monthly, fetches all_time doc)
- `Views/AllTimeTopTen/AllTimeTopTenCarouselView.swift` — NEW (renamed)
- `Views/AllTimeTopTen/AllTimeTopTenDetailView.swift` — NEW (renamed, removed date range)
- `Services/FirestoreService.swift` — MODIFY (add fetchAllTimeRankings method)
- `Models/FirestoreModels.swift` — MODIFY (make weekStart/weekEnd optional)
- `Views/JokeFeedView.swift` — MODIFY (references to AllTime instead of Monthly)
- DELETE: `ViewModels/MonthlyRankingsViewModel.swift`, `Views/MonthlyTopTen/` directory

**Avoids:** Pitfall #11 (naming inconsistency)

**Research flag:** LOW — mostly renaming and cosmetic changes

---

### Phase Ordering Rationale

**Why this order:**
1. **Data first** — Migration must complete before UI shows binary ratings. Cloud Function must populate data before leaderboard renders it.
2. **Core interaction second** — Binary rating UI is the most-used feature, highest UX impact.
3. **Me tab third** — Depends on both migration and new rating UI being stable.
4. **Leaderboard last** — Display-only, no data dependencies on other phases after Cloud Function deploys.

**Why these groupings:**
- Phase 1 and 2 can overlap slightly (Cloud Function deploys while rating UI is in development), but Phase 1 must finish first
- Phase 3 and 4 are independent of each other (can be built in parallel after Phases 1-2 complete)
- All four phases together complete the milestone — none can be deferred

**How this avoids pitfalls:**
- Data migration runs before any UI changes ship (avoids showing inconsistent state)
- Both ViewModels updated in same phase (avoids notification mismatch)
- Cloud Function tested with existing data before UI consumes it (avoids empty leaderboards)
- GroanOMeterView fully replaced, not modified (avoids gesture regression)

### Research Flags

**Phases with standard patterns (skip research-phase):**
- **Phase 1:** Migration scripts follow `migrate-holiday-tags.js` pattern exactly
- **Phase 2:** Native SwiftUI Picker already in codebase at MonthlyTopTenDetailView.swift:54-58
- **Phase 3:** Segmented control pattern established, just removing sections
- **Phase 4:** Renaming and cosmetic changes only

**No phases require additional research.** All patterns are either established in the codebase or documented in official Apple/Firebase sources.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Zero new dependencies; all changes use existing SwiftUI, Firebase, UserDefaults patterns verified in codebase |
| Features | HIGH | Binary rating patterns validated against Netflix/YouTube case studies; all features map to existing capabilities |
| Architecture | HIGH | Full codebase analysis completed; all affected files identified; MVVM boundaries remain clean |
| Pitfalls | HIGH | Verified against actual code (LocalStorageService, JokeViewModel, functions/index.js); UserDefaults migration is critical path |

**Overall confidence:** HIGH

### Gaps to Address

**Minor gaps (handle during implementation):**
- **Collection naming debt:** Keeping `weekly_rankings` collection name while using `all_time` document ID is pragmatic but cosmetically misleading. Add code comment. Can rename collection in future release.
- **Rating average semantics:** The `rating_avg` field on jokes becomes less meaningful with binary values (trends toward extremes). Consider whether to display it or deprecate. Not blocking — can decide during UI phase.
- **Scalability threshold:** Full collection scan for all-time aggregation is safe at current scale (433 jokes, low traffic). If rating_events exceeds 10K documents, plan migration to write-time counters. Monitor during beta.

**No blocking gaps.** Research is complete and actionable for roadmap creation.

## Sources

### Primary (HIGH confidence)

**Verified against existing codebase:**
- `MrFunnyJokes/ViewModels/JokeViewModel.swift` (lines 863-908) — rating logic, filtered computed properties
- `MrFunnyJokes/ViewModels/CharacterDetailViewModel.swift` (line 223) — duplicate rating logic
- `MrFunnyJokes/Views/MonthlyTopTen/MonthlyTopTenDetailView.swift` (lines 54-58) — existing segmented Picker pattern
- `MrFunnyJokes/Services/LocalStorageService.swift` — UserDefaults `[String: Int]` rating storage
- `MrFunnyJokes/Models/FirestoreModels.swift` (lines 196-222) — `RankingType` enum with Hilarious/Horrible
- `scripts/migrate-holiday-tags.js` — established migration script pattern
- `functions/index.js` — Cloud Function aggregation logic

**Official documentation:**
- [Apple: SegmentedPickerStyle](https://developer.apple.com/documentation/swiftui/segmentedpickerstyle) — native SwiftUI component
- [Firebase: Transactions and Batched Writes](https://firebase.google.com/docs/firestore/manage-data/transactions) — 500 operation batch limit
- [Firebase: Write-time Aggregations](https://firebase.google.com/docs/firestore/solutions/aggregation) — aggregation patterns
- [Firebase: Summarize Data with Aggregation Queries](https://firebase.google.com/docs/firestore/query-data/aggregation-queries) — count() and query optimization

### Secondary (MEDIUM confidence)

**Binary rating UX research:**
- [Appcues: 5 Stars vs Thumbs Up/Down](https://www.appcues.com/blog/rating-system-ux-star-thumbs) — Netflix 200% engagement increase case study
- [Yale Insights: Thumbs Up/Down Eliminates Bias](https://insights.som.yale.edu/insights/simple-thumbs-up-or-down-eliminates-racial-bias-in-online-ratings)

**Data migration patterns:**
- [Beware UserDefaults: A Tale of Hard to Find Bugs](https://christianselig.com/2024/10/beware-userdefaults/) — real-world migration pitfalls
- [How to Handle Firebase Firestore Data Migration](https://bootstrapped.app/guide/how-to-handle-firebase-firestore-data-migration-and-schema-evolution)

**Community resources:**
- [Hacking with Swift: Segmented Control](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-segmented-control-and-read-values-from-it)
- [Firestore Query Performance Best Practices](https://estuary.dev/blog/firestore-query-best-practices/)

---

*Research completed: 2026-02-17*
*Ready for roadmap: yes*
