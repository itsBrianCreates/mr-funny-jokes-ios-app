---
phase: 12-feed-scroll-stability
plan: 01
subsystem: ui
tags: [swiftui, scrollview, animation, ios18, lazyvstack]

requires:
  - phase: 11-seasonal-content-ranking
    provides: filteredJokes with seasonal demotion logic (sorting unchanged)
provides:
  - Stable ForEach identity using Joke.id directly (no enumerated wrapper)
  - Scoped withAnimation for isLoadingMore and isOffline state changes
  - YouTube promo card as standalone LazyVStack item outside ForEach
  - Matching scroll stability fixes in CharacterDetailView
affects: []

tech-stack:
  added: []
  patterns: [scoped-withAnimation-over-implicit-animation, stable-foreach-identity]

key-files:
  created: []
  modified:
    - MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift
    - MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift
    - MrFunnyJokes/MrFunnyJokes/Views/CharacterDetailView.swift
    - MrFunnyJokes/MrFunnyJokes/ViewModels/CharacterDetailViewModel.swift
    - MrFunnyJokes/JokeOfTheDayWidget/WidgetDataFetcher.swift
    - MrFunnyJokes/MrFunnyJokes.xcodeproj/project.pbxproj

key-decisions:
  - "Move YouTube promo card outside ForEach as standalone LazyVStack item rather than conditional insertion by index"
  - "Use withAnimation at mutation sites in ViewModels instead of implicit .animation() on ScrollView"
  - "Fix var→let warning in WidgetDataFetcher and sync widget bundle version to 7"

patterns-established:
  - "Scoped withAnimation: Always animate state changes at the mutation site (withAnimation { self.prop = val }) instead of applying .animation() modifiers to scroll containers"
  - "Stable ForEach identity: Use ForEach(collection) with Identifiable conformance, never ForEach(Array(collection.enumerated()))"

duration: 6min
completed: 2026-02-15
---

# Phase 12 Plan 01: Feed Scroll Stability Summary

**Stable feed scrolling via ForEach identity fix, scoped withAnimation replacements, and YouTube promo card extraction from joke loop**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-15
- **Completed:** 2026-02-15
- **Tasks:** 2 (1 auto + 1 human verification)
- **Files modified:** 6

## Accomplishments
- Replaced unstable `ForEach(Array(feedJokes.enumerated()))` with `ForEach(feedJokes)` using native Identifiable conformance — eliminates upward scroll jumps (SCROLL-01)
- Removed implicit `.animation()` modifiers from ScrollView containers in both JokeFeedView and CharacterDetailView — prevents background loading from disrupting scroll position (SCROLL-02)
- Moved YouTube promo card from conditional index-based insertion inside ForEach to standalone LazyVStack item — eliminates anchor shifts from conditional content (SCROLL-03)
- Scoped animations via `withAnimation` at mutation sites in JokeViewModel and CharacterDetailViewModel for isLoadingMore and isOffline

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix feed item identity and remove scroll-disrupting animations** - `fec50e5` (feat)
2. **Build fixes: punchline let warning + widget bundle version** - `1bd4b19` (fix)
3. **Task 2: Human verification of scroll stability** - approved by user (no commit needed)

## Files Created/Modified
- `MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift` - Stable ForEach, extracted YouTube promo, removed .animation() modifiers
- `MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` - Scoped withAnimation for isLoadingMore and isOffline
- `MrFunnyJokes/MrFunnyJokes/Views/CharacterDetailView.swift` - Removed .animation() from jokesList
- `MrFunnyJokes/MrFunnyJokes/ViewModels/CharacterDetailViewModel.swift` - Scoped withAnimation for isLoadingMore
- `MrFunnyJokes/JokeOfTheDayWidget/WidgetDataFetcher.swift` - var punchline → let punchline
- `MrFunnyJokes/MrFunnyJokes.xcodeproj/project.pbxproj` - Widget bundle version 6 → 7

## Decisions Made
- Moved YouTube promo card outside ForEach as standalone LazyVStack item rather than trying to fix the index-based insertion
- Used withAnimation at mutation sites instead of finding alternative implicit animation approaches
- Fixed pre-existing build warning (punchline let) and version mismatch discovered during verification

## Deviations from Plan

### Auto-fixed Issues

**1. [Build fix] var punchline → let in WidgetDataFetcher.swift**
- **Found during:** Build verification
- **Issue:** `var punchline` never mutated, causing compiler warning treated as error
- **Fix:** Changed to `let punchline`
- **Committed in:** `1bd4b19`

**2. [Build fix] Widget extension bundle version mismatch**
- **Found during:** Build verification
- **Issue:** Widget CURRENT_PROJECT_VERSION was 6, parent app was 7
- **Fix:** Updated both Debug and Release widget configs to version 7
- **Committed in:** `1bd4b19`

---

**Total deviations:** 2 auto-fixed (both build fixes)
**Impact on plan:** Both necessary for clean build. No scope creep.

## Issues Encountered
- iPhone 16 simulator unavailable (iOS 26.2 environment) — used iPhone 17 Pro instead

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 12 is the final phase of v1.0.3 milestone
- All scroll stability requirements (SCROLL-01, SCROLL-02, SCROLL-03) verified
- Milestone ready for completion

---
*Phase: 12-feed-scroll-stability*
*Completed: 2026-02-15*
