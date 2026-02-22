---
phase: 22-feed-refresh-behavior
plan: 02
subsystem: ui
tags: [swiftui, feed, sorting, impressions, freshness-tiering, pull-to-refresh]

# Dependency graph
requires:
  - phase: 22-feed-refresh-behavior
    plan: 01
    provides: "filteredJokes with rated-at-bottom pattern and sortJokesForFreshFeed"
  - phase: 08-feed-content-loading
    provides: "Impression tracking via LocalStorageService.markImpression and getImpressionIdsFast"
provides:
  - "Impression-tiered filteredJokes: unseen > seen-unrated > rated"
  - "Session-deferred rating reorder via sessionRatedJokeIds"
  - "Detail-sheet-open tracking via onView callback and markJokeViewed()"
  - "Feed freshness on pull-to-refresh with sessionRatedJokeIds clearing"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Impression-tiered filteredJokes: partition jokes into unseen/seen-unrated/rated tiers using storage.getImpressionIdsFast() and getRatedJokeIdsFast(), sort within each tier by popularityScore"
    - "Session-deferred reordering: sessionRatedJokeIds tracks in-session ratings so computed property treats them as pre-rating tier until refresh"
    - "onView callback pattern: JokeCardView fires onView() on detail sheet open, wired through JokeFeedView to viewModel.markJokeViewed()"

key-files:
  created: []
  modified:
    - "MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift"
    - "MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift"
    - "MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift"
    - "MrFunnyJokes/MrFunnyJokes/Views/SearchView.swift"

key-decisions:
  - "Re-added sessionRatedJokeIds (removed in 22-01) to defer rating reorder until pull-to-refresh"
  - "filteredJokes uses popularityScore as tiebreaker within tiers (not shuffled) to prevent scroll jumps on re-evaluation"
  - "markJokeViewed reuses existing markImpression system rather than separate viewed-joke tracking"
  - "onView fires on card tap (detail sheet open), not on scroll-viewport appearance"

patterns-established:
  - "Impression-tiered feed: unseen > seen-unrated > rated with popularityScore tiebreaker"
  - "Session-deferred reordering via Set<String> cleared on refresh"
  - "onView callback on JokeCardView for detail-sheet-open events"

# Metrics
duration: 4min
completed: 2026-02-22
---

# Phase 22 Plan 02: Gap Closure Summary

**Impression-tiered filteredJokes with session-deferred rating reorder and detail-sheet-open tracking via onView callback**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-22T05:32:13Z
- **Completed:** 2026-02-22T05:36:25Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- filteredJokes now tiers jokes by freshness: unseen > seen-unrated > rated, using impression data from LocalStorageService
- sessionRatedJokeIds defers rating reorder so rated jokes stay in place until pull-to-refresh or app restart
- JokeCardView fires onView() callback when detail sheet opens, wired to markJokeViewed() in JokeFeedView
- sortJokesForFreshFeed() preserved unchanged for initial load shuffling; filteredJokes uses deterministic popularityScore ordering

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite filteredJokes with impression-based tiering and session-deferred reordering** - `517320f` (feat)
2. **Task 2: Wire onView callback from JokeCardView through JokeFeedView to ViewModel** - `b605ef4` (feat)

## Files Created/Modified
- `MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` - Added sessionRatedJokeIds, rewrote filteredJokes with 3-tier impression ordering, added markJokeViewed(), updated rateJoke() and refresh()
- `MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift` - Added onView callback property, fires on detail sheet open
- `MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift` - Wired onView to viewModel.markJokeViewed(joke)
- `MrFunnyJokes/MrFunnyJokes/Views/SearchView.swift` - Added onView: {} no-op to JokeCardView call site

## Decisions Made
- Re-added sessionRatedJokeIds (previously removed in plan 22-01) because UAT revealed rated jokes still need to stay in place until refresh
- Used popularityScore as deterministic tiebreaker within tiers rather than shuffling, because filteredJokes is a computed property that re-evaluates on every access -- shuffling would cause unstable sort order and scroll jumps
- Reused existing markImpression system for markJokeViewed rather than introducing separate "viewed" storage, because detail-sheet-open is a superset of scroll-viewport-seen
- onView callback fires on card tap (when detail sheet opens), distinct from onAppear-based markJokeImpression which fires on scroll viewport entry

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All 3 UAT gaps closed: deferred rating reorder, viewed-joke demotion, feed freshness tiering
- No blockers or concerns
- Ready for UAT re-verification

## Self-Check: PASSED

- FOUND: `.planning/phases/22-feed-refresh-behavior/22-02-SUMMARY.md`
- FOUND: `MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift`
- FOUND: `MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift`
- FOUND: `MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift`
- FOUND: `MrFunnyJokes/MrFunnyJokes/Views/SearchView.swift`
- FOUND: `517320f` (Task 1 commit)
- FOUND: `b605ef4` (Task 2 commit)

---
*Phase: 22-feed-refresh-behavior*
*Completed: 2026-02-22*
