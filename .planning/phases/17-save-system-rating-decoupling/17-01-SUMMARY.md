---
phase: 17-save-system-rating-decoupling
plan: 01
subsystem: persistence, viewmodel
tags: [UserDefaults, SwiftUI, Combine, NotificationCenter, data-migration]

# Dependency graph
requires:
  - phase: 13-14 (rating system)
    provides: Rating persistence patterns in LocalStorageService, rating notification sync between ViewModels
provides:
  - LocalStorageService save/unsave/isJokeSaved/getSavedTimestamp methods
  - Joke.isSaved property with backward-compatible Codable support
  - migrateRatedToSavedIfNeeded one-time migration
  - JokeViewModel.saveJoke/unsaveJoke methods with notification sync
  - JokeViewModel.savedJokes computed property (sorted by save timestamp)
  - CharacterDetailViewModel.saveJoke toggle method with notification posting
  - .jokeSaveDidChange notification for cross-ViewModel sync
  - Save state applied in all joke loading paths (9 in JokeViewModel, 3 in CharacterDetailViewModel)
affects: [17-02 (UI wiring), 18 (Me Tab redesign)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Save persistence parallel to rating persistence in LocalStorageService"
    - "isSaved property applied in every load path, mirroring userRating pattern"
    - ".jokeSaveDidChange notification mirroring .jokeRatingDidChange pattern"

key-files:
  created: []
  modified:
    - MrFunnyJokes/MrFunnyJokes/Services/LocalStorageService.swift
    - MrFunnyJokes/MrFunnyJokes/Models/Joke.swift
    - MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift
    - MrFunnyJokes/MrFunnyJokes/ViewModels/CharacterDetailViewModel.swift

key-decisions:
  - "Save storage uses UserDefaults with Set<String> for IDs and [String: TimeInterval] for timestamps, matching rating persistence pattern exactly"
  - "Migration preserves rating timestamps as save timestamps for continuity"
  - "unsaveJoke is a dedicated method (not a toggle) for clean swipe-to-delete in MeView"
  - "withAnimation used at mutation site in ViewModel per CLAUDE.md animation patterns"

patterns-established:
  - "Save persistence: savedJokeIds (Set<String>) + savedJokeTimestamps ([String: TimeInterval]) in UserDefaults"
  - "Save state application: storage.isJokeSaved() called alongside storage.getRating() in every load path"
  - "Save notification: .jokeSaveDidChange with jokeId, firestoreId, isSaved, jokeData userInfo"

# Metrics
duration: 57min
completed: 2026-02-21
---

# Phase 17 Plan 01: Save System Data Layer Summary

**Save persistence layer with UserDefaults, Joke.isSaved property, rated-to-saved migration, and cross-ViewModel notification sync across all load paths**

## Performance

- **Duration:** 57 min
- **Started:** 2026-02-21T05:16:27Z
- **Completed:** 2026-02-21T06:14:01Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Complete save CRUD in LocalStorageService (save, unsave, isJokeSaved, getSavedTimestamp) with thread-safe queue access and memory cache
- One-time rated-to-saved migration that copies all rated joke IDs into saved collection, preserving timestamps
- Save state applied in every joke loading code path (9 locations in JokeViewModel, 3 in CharacterDetailViewModel)
- Cross-ViewModel save synchronization via .jokeSaveDidChange notification using established Combine pattern
- savedJokes computed property returning saved jokes sorted by most recently saved

## Task Commits

Each task was committed atomically:

1. **Task 1: Add save persistence to LocalStorageService, isSaved to Joke model, and rated-to-saved migration** - `4388465` (feat)
2. **Task 2: Wire save logic into both ViewModels with notification sync, migration trigger, and save state application** - `ad0936f` (feat)

## Files Created/Modified
- `MrFunnyJokes/MrFunnyJokes/Services/LocalStorageService.swift` - Save/unsave/isJokeSaved/getSavedTimestamp methods, migrateRatedToSavedIfNeeded migration, cachedSavedIds memory cache
- `MrFunnyJokes/MrFunnyJokes/Models/Joke.swift` - Added isSaved: Bool property with backward-compatible Codable support
- `MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` - saveJoke/unsaveJoke methods, savedJokes computed property, handleSaveNotification, migration trigger, save state in all load paths
- `MrFunnyJokes/MrFunnyJokes/ViewModels/CharacterDetailViewModel.swift` - .jokeSaveDidChange notification name, saveJoke toggle method, save state in loadJokes/loadMoreJokes

## Decisions Made
- Used dedicated `unsaveJoke` method rather than toggling via `saveJoke` for clean swipe-to-delete semantics in MeView
- Placed migration call at PHASE 0 in `loadInitialContentAsync` alongside existing binary rating migration, before memory cache preload
- Added `cachedSavedIds` to memory cache preload for fast startup access

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Xcode build required GoogleService-Info.plist at project root level (pre-existing config issue, not caused by this plan). Resolved by copying plist to expected location.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Complete data and logic layer for saving jokes is ready for Plan 02 (UI wiring)
- Plan 02 can wire Save button to JokeDetailSheet, rewire MeView from ratedJokes to savedJokes, and pass onSave callbacks through all entry points
- No blockers or concerns

---
*Phase: 17-save-system-rating-decoupling*
*Completed: 2026-02-21*
