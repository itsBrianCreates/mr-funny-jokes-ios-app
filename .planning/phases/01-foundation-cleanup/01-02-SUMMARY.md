---
phase: 01-foundation-cleanup
plan: 02
subsystem: ui
tags: [swiftui, rankings, branding, rename]

# Dependency graph
requires:
  - phase: none
    provides: Existing Weekly rankings feature
provides:
  - Monthly Top 10 branding throughout UI
  - MonthlyRankingsViewModel
  - MonthlyTopTenCarouselView
  - MonthlyTopTenDetailView
affects: [02-widgets, 04-widget-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - UI-only naming changes (backend collection names unchanged)

key-files:
  created: []
  modified:
    - MrFunnyJokes/MrFunnyJokes/ViewModels/MonthlyRankingsViewModel.swift
    - MrFunnyJokes/MrFunnyJokes/Views/MonthlyTopTen/MonthlyTopTenCarouselView.swift
    - MrFunnyJokes/MrFunnyJokes/Views/MonthlyTopTen/MonthlyTopTenDetailView.swift
    - MrFunnyJokes/MrFunnyJokes/Views/MonthlyTopTen/RankedJokeCard.swift
    - MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift
    - MrFunnyJokes/MrFunnyJokes.xcodeproj/project.pbxproj

key-decisions:
  - "Keep backend collection name as weekly_rankings to avoid Firestore migration"
  - "All user-facing text changed from Weekly to Monthly"

patterns-established:
  - "UI branding can differ from backend naming when collections are established"

# Metrics
duration: 15min
completed: 2026-01-24
---

# Phase 01 Plan 02: Rename Weekly to Monthly Summary

**All user-facing Weekly Top 10 references renamed to Monthly Top 10 across ViewModel, Views, and JokeFeedView**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-01-24T16:30:00Z
- **Completed:** 2026-01-24T16:45:00Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- Renamed WeeklyRankingsViewModel to MonthlyRankingsViewModel with property updates
- Renamed WeeklyTopTen folder and all files to MonthlyTopTen
- Updated all struct names, comments, and user-facing text
- Updated JokeFeedView to use Monthly components
- Fixed Xcode project file to reference new file paths

## Task Commits

Each task was committed atomically:

1. **Task 1: Rename ViewModel and update date formatting** - `4f08d3d` (refactor)
2. **Task 2: Rename Views folder and update all Weekly -> Monthly text** - `6e6b8e3` (refactor)
3. **Task 3: Update JokeFeedView references** - `06c7e3f` (refactor)
4. **Deviation fix: Update Xcode project file** - `69f6ef8` (fix)

## Files Created/Modified
- `ViewModels/MonthlyRankingsViewModel.swift` - Renamed from WeeklyRankingsViewModel, updated property and comments
- `Views/MonthlyTopTen/MonthlyTopTenCarouselView.swift` - Renamed structs and text to Monthly
- `Views/MonthlyTopTen/MonthlyTopTenDetailView.swift` - Updated navigation title, empty state text
- `Views/MonthlyTopTen/RankedJokeCard.swift` - Updated comment from Weekly to Monthly
- `Views/JokeFeedView.swift` - Updated all references to Monthly components
- `MrFunnyJokes.xcodeproj/project.pbxproj` - Updated file references for renamed files

## Decisions Made
- Keep `fetchWeeklyRankings()` call in ViewModel - backend collection name stays as `weekly_rankings` to avoid Firestore schema changes
- All user-facing text changed to "Monthly Top 10"
- Empty state text changed from "this week" to "this month"

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated Xcode project file for renamed files**
- **Found during:** Verification (build test after Task 3)
- **Issue:** Build failed because project.pbxproj still referenced old file paths (WeeklyRankingsViewModel.swift, WeeklyTopTen/*.swift)
- **Fix:** Updated all file references in project.pbxproj to point to renamed files and folder
- **Files modified:** MrFunnyJokes.xcodeproj/project.pbxproj
- **Verification:** `xcodebuild build` succeeds
- **Committed in:** `69f6ef8`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Auto-fix necessary for project to compile. No scope creep.

## Issues Encountered
None beyond the blocking deviation handled above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All Monthly Top 10 branding complete
- Backend collection name unchanged (weekly_rankings)
- App compiles and builds successfully
- Ready for Phase 2 (Lock Screen Widgets)

---
*Phase: 01-foundation-cleanup*
*Completed: 2026-01-24*
