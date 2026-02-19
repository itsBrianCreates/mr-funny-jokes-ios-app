---
phase: 13-data-migration-cloud-function
plan: 01
subsystem: database
tags: [firestore, firebase-admin, cloud-functions, migration, ratings]

# Dependency graph
requires: []
provides:
  - "Firestore rating_events migration script (5-point to binary)"
  - "All-time rankings Cloud Function (weekly_rankings/all_time)"
  - "Feature branch v1.1.0 for milestone work"
affects: [13-02, 14-rating-ui, 15-me-tab, 16-top10-rankings]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Firestore migration script pattern (ES module, dry-run, batch 500)"]

key-files:
  created:
    - scripts/migrate-rating-events.js
  modified:
    - scripts/package.json
    - functions/index.js

key-decisions:
  - "Exit 0 (not 1) when no rating events found -- empty collection is valid state, not error"
  - "Combined updates and deletes into single batch loop for efficiency"

patterns-established:
  - "Rating migration pattern: migrateRating() returns {action, newRating} object for batch processing"

# Metrics
duration: 2min
completed: 2026-02-18
---

# Phase 13 Plan 01: Data Migration & Cloud Function Summary

**Firestore rating_events migration script (5-point to binary) and Cloud Function updated to aggregate all-time rankings into weekly_rankings/all_time**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-18T16:29:10Z
- **Completed:** 2026-02-18T16:31:37Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created `scripts/migrate-rating-events.js` following established migration pattern (ES modules, dry-run, batch 500)
- Migration script remaps rating 4/5->5, 1/2->1, and deletes rating 3 documents using batch.update() and batch.delete()
- Updated `functions/index.js` to aggregate ALL rating_events (no week_id filter) and write to weekly_rankings/all_time document
- Feature branch `v1.1.0` created and all commits land on it

## Task Commits

Each task was committed atomically:

1. **Task 1: Create feature branch and Firestore migration script** - `5aaf9f2` (feat)
2. **Task 2: Update Cloud Function for all-time aggregation** - `7e23b4f` (feat)

## Files Created/Modified
- `scripts/migrate-rating-events.js` - One-time Firestore migration script to convert rating_events from 5-point to binary format
- `scripts/package.json` - Added migrate-ratings and migrate-ratings:dry-run npm scripts
- `functions/index.js` - Modified to aggregate all rating events into all_time document instead of weekly

## Decisions Made
- Exit with code 0 when no rating events found (empty collection is a valid state, not an error condition)
- Combined update and delete operations into a single batch processing loop rather than separate passes

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Migration script ready to run: `cd scripts && npm run migrate-ratings:dry-run` then `npm run migrate-ratings`
- Cloud Function ready to deploy: `cd functions && firebase deploy --only functions`
- Plan 02 (local UserDefaults migration) can proceed on the v1.1.0 branch

## Self-Check: PASSED

All files verified present. All commits verified in git log.

---
*Phase: 13-data-migration-cloud-function*
*Completed: 2026-02-18*
