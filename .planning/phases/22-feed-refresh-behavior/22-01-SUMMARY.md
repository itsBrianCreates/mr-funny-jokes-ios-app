---
phase: 22-feed-refresh-behavior
plan: 01
subsystem: ui
tags: [swiftui, feed, sorting, pull-to-refresh, scroll]

# Dependency graph
requires:
  - phase: 08-feed-content-loading
    provides: "filteredJokes computed property and sessionRatedJokeIds tracking"
provides:
  - "filteredJokes keeps rated jokes visible at bottom instead of hiding them"
  - "Feed ordering persists across app sessions via LocalStorageService ratings"
  - "Scroll-to-top after pull-to-refresh verified working"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Rated-at-bottom pattern: unrated jokes first by popularity, rated jokes at bottom by popularity"

key-files:
  created: []
  modified:
    - "MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift"

key-decisions:
  - "Removed sessionRatedJokeIds entirely since rated jokes now stay visible at bottom"
  - "Ordering persists across sessions without additional persistence work -- userRating from LocalStorageService is sufficient"

patterns-established:
  - "Rated-at-bottom feed: filteredJokes separates unrated/rated, sorts each by popularity, concatenates"

# Metrics
duration: 3min
completed: 2026-02-22
---

# Phase 22 Plan 01: Feed Refresh Behavior Summary

**filteredJokes reordered to keep rated jokes at bottom instead of hiding them, with sessionRatedJokeIds tracking removed and scroll-to-top after refresh verified**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-22T04:56:37Z
- **Completed:** 2026-02-22T04:59:44Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- filteredJokes now includes all jokes: unrated sorted by popularity first, rated sorted by popularity at bottom
- Removed sessionRatedJokeIds tracking mechanism (no longer needed since rated jokes stay visible)
- Verified scroll-to-top after pull-to-refresh works correctly with topAnchorID anchor
- Ordering persists across app close/reopen because it derives from LocalStorageService UserDefaults ratings

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix filteredJokes to keep rated jokes at bottom instead of hiding them** - `bf74fcf` (fix)
2. **Task 2: Verify and harden scroll-to-top after pull-to-refresh** - No commit (verification-only, no code changes needed)

## Files Created/Modified
- `MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` - Changed filteredJokes to separate unrated/rated groups instead of excluding rated; removed sessionRatedJokeIds property, refresh clear, and rateJoke insert

## Decisions Made
- Removed sessionRatedJokeIds entirely -- rated jokes now stay visible at the bottom of the feed, so session-level tracking of which jokes to keep visible is unnecessary
- No changes needed to JokeFeedView.swift -- the existing scroll-to-top implementation (topAnchorID + 100ms delay + proxy.scrollTo) works correctly with the new filteredJokes behavior

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Feed refresh behavior complete -- all three success criteria satisfied (FEED-01, FEED-02, FEED-03)
- No blockers or concerns

## Self-Check: PASSED

- FOUND: `.planning/phases/22-feed-refresh-behavior/22-01-SUMMARY.md`
- FOUND: `bf74fcf` (Task 1 commit)
- Task 2: No commit expected (verification-only)

---
*Phase: 22-feed-refresh-behavior*
*Completed: 2026-02-22*
