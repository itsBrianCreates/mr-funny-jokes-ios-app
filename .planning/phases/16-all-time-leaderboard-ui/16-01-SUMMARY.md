---
phase: 16-all-time-leaderboard-ui
plan: 01
subsystem: ui
tags: [swiftui, firestore, rankings, leaderboard, refactor]

# Dependency graph
requires:
  - phase: 13-cloud-function-rankings
    provides: all_time document in weekly_rankings collection
provides:
  - All-Time Top 10 UI reading from weekly_rankings/all_time Firestore document
  - AllTimeRankingsViewModel with no date range dependencies
  - AllTimeTopTen views (carousel + detail) with "All-Time Top 10" labels
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Optional date fields in Codable structs for backwards-compatible Firestore decoding"

key-files:
  created: []
  modified:
    - MrFunnyJokes/MrFunnyJokes/Models/FirestoreModels.swift
    - MrFunnyJokes/MrFunnyJokes/Services/FirestoreService.swift
    - MrFunnyJokes/MrFunnyJokes/ViewModels/AllTimeRankingsViewModel.swift
    - MrFunnyJokes/MrFunnyJokes/Views/AllTimeTopTen/AllTimeTopTenCarouselView.swift
    - MrFunnyJokes/MrFunnyJokes/Views/AllTimeTopTen/AllTimeTopTenDetailView.swift
    - MrFunnyJokes/MrFunnyJokes/Views/AllTimeTopTen/RankedJokeCard.swift
    - MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift
    - MrFunnyJokes/MrFunnyJokes.xcodeproj/project.pbxproj

key-decisions:
  - "Kept WeeklyRankings struct name unchanged to match Firestore collection name (accepted tech debt)"
  - "Made weekStart/weekEnd optional rather than removing them for backwards compatibility"
  - "Removed date range subtitle entirely from detail view (no date concept for all-time)"

patterns-established:
  - "All-Time naming convention: AllTimeRankingsViewModel, AllTimeTopTenCarouselView, AllTimeTopTenDetailView"

# Metrics
duration: 4min
completed: 2026-02-18
---

# Phase 16 Plan 01: All-Time Leaderboard UI Summary

**Rewired leaderboard UI from defunct weekly/monthly rankings to all-time document, renamed all Monthly references to All-Time across 8 files**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-18T19:03:30Z
- **Completed:** 2026-02-18T19:08:09Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- WeeklyRankings model now decodes all_time documents with optional weekStart/weekEnd fields
- FirestoreService.fetchAllTimeRankings() reads from hardcoded "all_time" document ID
- All UI labels, struct names, file names, and folder names use AllTime naming convention
- Zero "Monthly" references remain in any Swift source file or pbxproj
- EmptyStateView preserved and accessible for MeView dependency
- getCurrentWeekId() preserved for logRatingEvent() functionality

## Task Commits

Each task was committed atomically:

1. **Task 1: Data layer changes, filesystem renames, and pbxproj updates** - `517c869` (feat)
2. **Task 2: Rename all Monthly references in Swift source to All-Time** - `1757474` (feat)

## Files Created/Modified
- `MrFunnyJokes/MrFunnyJokes/Models/FirestoreModels.swift` - Made weekStart/weekEnd optional in WeeklyRankings struct, updated doc comments
- `MrFunnyJokes/MrFunnyJokes/Services/FirestoreService.swift` - Renamed fetchWeeklyRankings to fetchAllTimeRankings, reads from "all_time" document, removed getCurrentWeekDateRange()
- `MrFunnyJokes/MrFunnyJokes/ViewModels/AllTimeRankingsViewModel.swift` - Renamed class, removed monthDateRange property and formatDateRange method
- `MrFunnyJokes/MrFunnyJokes/Views/AllTimeTopTen/AllTimeTopTenCarouselView.swift` - Renamed all structs from MonthlyTopTen to AllTimeTopTen, updated header text
- `MrFunnyJokes/MrFunnyJokes/Views/AllTimeTopTen/AllTimeTopTenDetailView.swift` - Renamed struct, removed date range subtitle, updated nav title
- `MrFunnyJokes/MrFunnyJokes/Views/AllTimeTopTen/RankedJokeCard.swift` - Updated doc comment from Monthly to All-Time
- `MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift` - Updated all references to use AllTime naming
- `MrFunnyJokes/MrFunnyJokes.xcodeproj/project.pbxproj` - Updated all file references and group names

## Decisions Made
- Kept WeeklyRankings struct name matching Firestore collection name (accepted tech debt per prior decision)
- Made weekStart/weekEnd optional (Date?) rather than removing to maintain Codable compatibility
- Removed date range subtitle entirely from detail view since all-time rankings have no date concept
- Removed getCurrentWeekDateRange() as it had no callers after the rewire
- Preserved getCurrentWeekId() which is still used by logRatingEvent()

## Deviations from Plan

None - plan executed exactly as written.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All-Time Top 10 UI is fully connected to the all_time Firestore document
- v1.1.0 milestone feature set is complete
- Ready for final testing and release

## Self-Check: PASSED

- All 8 modified files verified present on disk
- Commit 517c869 (Task 1) verified in git log
- Commit 1757474 (Task 2) verified in git log
- Zero "Monthly" references in Swift source (grep verified)
- All 9 phase-level verification checks passed

---
*Phase: 16-all-time-leaderboard-ui*
*Completed: 2026-02-18*
