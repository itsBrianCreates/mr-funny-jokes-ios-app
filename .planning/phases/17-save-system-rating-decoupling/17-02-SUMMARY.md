---
phase: 17-save-system-rating-decoupling
plan: 02
subsystem: ui, viewmodel
tags: [SwiftUI, callback-closures, save-button, MeView, JokeDetailSheet]

# Dependency graph
requires:
  - phase: 17-01
    provides: Save persistence layer (saveJoke/unsaveJoke/savedJokes) in LocalStorageService, JokeViewModel, CharacterDetailViewModel
provides:
  - Save/Saved toggle button in JokeDetailSheet with person icon and haptic feedback
  - onSave callback wired through all 8 JokeDetailSheet call sites (6 functional + 2 preview)
  - onSave callback wired through JokeCardView, CharacterJokeCardView, JokeOfTheDayView, RankedJokeCard
  - MeView showing saved jokes instead of rated jokes with swipe-to-unsave
  - Dead ratedJokes/hilariousJokes/horribleJokes computed properties removed from JokeViewModel
affects: [18 (Me Tab redesign)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "onSave closure propagation mirroring existing onRate/onShare/onCopy callback pattern"
    - "Swipe-to-unsave uses dedicated unsaveJoke method (preserves rating)"

key-files:
  created: []
  modified:
    - MrFunnyJokes/MrFunnyJokes/Views/JokeDetailSheet.swift
    - MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift
    - MrFunnyJokes/MrFunnyJokes/Views/CharacterDetailView.swift
    - MrFunnyJokes/MrFunnyJokes/Views/MeView.swift
    - MrFunnyJokes/MrFunnyJokes/Views/JokeOfTheDayView.swift
    - MrFunnyJokes/MrFunnyJokes/Views/AllTimeTopTen/RankedJokeCard.swift
    - MrFunnyJokes/MrFunnyJokes/Views/AllTimeTopTen/AllTimeTopTenDetailView.swift
    - MrFunnyJokes/MrFunnyJokes/App/MrFunnyJokesApp.swift
    - MrFunnyJokes/MrFunnyJokes/Views/SearchView.swift
    - MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift
    - MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift

key-decisions:
  - "Save button placed between BinaryRatingView and Copy/Share Divider for visual grouping"
  - "onSave added to all intermediate views (JokeCardView, CharacterJokeCardView, JokeOfTheDayView, RankedJokeCard) to maintain callback pattern consistency"
  - "MeView uses flat List instead of segmented Picker since save has no sub-categories"

patterns-established:
  - "Save callback: onSave closure follows same propagation path as onRate/onShare/onCopy through view hierarchy"
  - "Unsave in MeView: swipe-to-delete calls viewModel.unsaveJoke() which preserves the user's rating"

# Metrics
duration: 22min
completed: 2026-02-21
---

# Phase 17 Plan 02: Save System UI Wiring Summary

**Save/Saved toggle button in JokeDetailSheet with onSave callbacks wired through all 10 view files, MeView rewired to display saved jokes with swipe-to-unsave**

## Performance

- **Duration:** 22 min
- **Started:** 2026-02-21T07:01:01Z
- **Completed:** 2026-02-21T09:23:53Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Save/Saved toggle button with person/person.fill icon, bordered button style, yellow/gray tint, and haptic feedback
- onSave callback wired through all 8 JokeDetailSheet call sites and all intermediate views (JokeCardView, CharacterJokeCardView, JokeOfTheDayView, RankedJokeCard)
- MeView completely rewritten: flat saved-jokes list, "No Saved Jokes Yet" empty state, swipe-to-unsave with person.badge.minus icon
- Dead code cleanup: removed ratedJokes, hilariousJokes, horribleJokes computed properties from JokeViewModel

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Save button to JokeDetailSheet and wire onSave through all call sites** - `cde9fc4` (feat)
2. **Task 2: Rewire MeView to show saved jokes and remove dead rated-joke code** - `634b5eb` (feat)

## Files Created/Modified
- `MrFunnyJokes/MrFunnyJokes/Views/JokeDetailSheet.swift` - Added onSave parameter and Save/Saved toggle button between rating and copy/share sections
- `MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift` - Added onSave closure parameter, passed through to JokeDetailSheet, updated 4 preview providers
- `MrFunnyJokes/MrFunnyJokes/Views/CharacterDetailView.swift` - Added onSave to CharacterJokeCardView struct and jokesList instantiation
- `MrFunnyJokes/MrFunnyJokes/Views/MeView.swift` - Complete rewrite: saved jokes list, new empty state, swipe-to-unsave
- `MrFunnyJokes/MrFunnyJokes/Views/JokeOfTheDayView.swift` - Added onSave parameter, passed through to JokeDetailSheet, updated 5 preview providers
- `MrFunnyJokes/MrFunnyJokes/Views/AllTimeTopTen/RankedJokeCard.swift` - Added onSave parameter, passed through to JokeDetailSheet, updated 4 preview providers
- `MrFunnyJokes/MrFunnyJokes/Views/AllTimeTopTen/AllTimeTopTenDetailView.swift` - Added onSave to RankedJokeCard instantiation with jokeViewModel.saveJoke
- `MrFunnyJokes/MrFunnyJokes/App/MrFunnyJokesApp.swift` - Added onSave to deep-link JOTD sheet JokeDetailSheet
- `MrFunnyJokes/MrFunnyJokes/Views/SearchView.swift` - Added onSave to JokeCardView instantiation
- `MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift` - Added onSave to JokeCardView and JokeOfTheDayView instantiations
- `MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` - Removed dead ratedJokes/hilariousJokes/horribleJokes computed properties

## Decisions Made
- Placed Save button between BinaryRatingView and the Divider before Copy/Share, giving it its own visual section
- Used flat List in MeView (no segmented control) since saved jokes have no sub-categories like the old rated system had
- Kept jokeCard helper function in MeView unchanged (visual design preserved)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Complete save system is now functional end-to-end (persistence + UI)
- Phase 18 (Me Tab redesign) can build on this foundation for rating indicators on saved joke cards (METB-03)
- No blockers or concerns

## Self-Check: PASSED

- FOUND: JokeDetailSheet.swift
- FOUND: MeView.swift
- FOUND: 17-02-SUMMARY.md
- FOUND: commit cde9fc4
- FOUND: commit 634b5eb

---
*Phase: 17-save-system-rating-decoupling*
*Completed: 2026-02-21*
