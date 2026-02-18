# Phase 13: Data Migration & Cloud Function - Research

**Researched:** 2026-02-17
**Domain:** Firestore data migration, Cloud Functions v2 scheduled functions, iOS UserDefaults migration
**Confidence:** HIGH

## Summary

Phase 13 is a pure backend/data phase with no UI changes. It requires three parallel workstreams: (1) creating the `v1.1.0` feature branch, (2) migrating existing data from 5-point to binary format in both Firestore `rating_events` and local `UserDefaults`, and (3) modifying the existing Cloud Function to aggregate all-time rankings instead of weekly ones. The codebase already has well-established patterns for all three concerns -- existing migration scripts in `scripts/`, a deployed Cloud Function in `functions/index.js`, and local rating storage in `LocalStorageService.swift`.

The migration is straightforward because the prior decision to keep Int type for ratings (1 = Horrible, 5 = Hilarious) means the data format does not change -- only the values need remapping. The Cloud Function modification is a simplification: remove the `week_id` filter to aggregate all events, and write to a fixed `all_time` document ID instead of a weekly one.

**Primary recommendation:** Execute the three workstreams in order: branch creation, Firestore migration script (run once), Cloud Function update + deploy, then local rating migration code (runs at app launch). The Firestore migration is irreversible so it must use dry-run first.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| firebase-admin | ^12.0.0 | Firestore Admin SDK for migration scripts | Already in `scripts/package.json` |
| firebase-admin | ^13.0.0 | Firestore Admin SDK for Cloud Functions | Already in `functions/package.json` |
| firebase-functions | ^7.0.0 | Cloud Functions v2 (scheduler, HTTP) | Already deployed, Node.js 20 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift UserDefaults | Native | Local rating storage migration | App launch one-time migration |
| Git branching | N/A | Feature branch management | INFRA-01 requirement |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Migration script | Cloud Function trigger | Script is simpler, runs once, has dry-run; Cloud Function would add deployment complexity for a one-time operation |
| UserDefaults migration at launch | Migration on first rating | Launch migration is simpler to reason about, guarantees consistency before any user interaction |

## Architecture Patterns

### Existing Migration Script Pattern

The codebase has two established migration scripts that follow an identical pattern. **The new Firestore migration script MUST follow this exact same structure.**

**Location:** `scripts/migrate-joke-ids.js`, `scripts/migrate-holiday-tags.js`

**Pattern:**
```
scripts/
├── migrate-rating-events.js    # New migration script (follows existing pattern)
├── serviceAccountKey.json      # Already in .gitignore
├── package.json                # Add new npm script entry
└── ...existing scripts...
```

**Established script conventions (from codebase):**
1. ES module syntax (`import` statements, `"type": "module"` in package.json)
2. Firebase Admin SDK initialized from `serviceAccountKey.json`
3. `--dry-run` flag for simulation mode
4. Logging with `[INFO]`, `[WARN]`, `[ERROR]`, `[SUCCESS]` prefixes and timestamps
5. Batch operations with `BATCH_SIZE = 500`
6. Summary report at the end
7. Migration log file saved to disk

### Existing Cloud Function Pattern

**Location:** `functions/index.js`

**Current function exports:**
- `aggregateRankings` -- scheduled daily at midnight ET via `onSchedule`
- `triggerAggregation` -- HTTP endpoint for manual triggering

**Current aggregation logic (must be modified):**
- Filters `rating_events` by `week_id` field
- Groups ratings: 4-5 = hilarious, 1-2 = horrible, 3 = neutral
- Writes top 10 to `weekly_rankings/{weekId}`
- Uses CommonJS (`require` statements)

**Target: All-time aggregation:**
- Remove `week_id` filter -- aggregate ALL events
- Write to `weekly_rankings/all_time` (fixed document ID per decision)
- Keep the same ranking logic (count-based top 10)
- Keep scheduled + HTTP trigger pattern
- Keep existing field names in the output document (hilarious, horrible, rank, count, etc.)

### Local Rating Migration Pattern

**Location:** `LocalStorageService.swift`

**Current local storage format:**
- `jokeRatings` key: `[String: Int]` dictionary mapping `firestoreId` -> rating (1-5)
- `jokeRatingTimestamps` key: `[String: TimeInterval]` dictionary mapping `firestoreId` -> timestamp

**Migration rules (from requirements):**
- Rating 4 or 5 -> becomes 5 (Hilarious)
- Rating 1 or 2 -> becomes 1 (Horrible)
- Rating 3 -> removed entirely (key deleted from dictionary)

**Migration must also:**
- Remove corresponding timestamps for dropped rating 3 jokes
- Run exactly once (use a `hasMigratedRatingsToBinary` UserDefaults flag)
- Run before any other rating operations (early in app launch)
- Be added to `LocalStorageService.swift` (where rating data lives)

### Existing Firestore Schema for rating_events

```
Document ID: {deviceId}_{jokeId}_{weekId}
Fields:
  - joke_id: string
  - rating: integer (currently 1-5, target: only 1 or 5)
  - device_id: string
  - week_id: string (e.g., "2024-W03")
  - timestamp: Firestore server timestamp
```

### Target Firestore Schema for weekly_rankings (all_time document)

```
Document ID: "all_time"
Collection: "weekly_rankings"
Fields:
  - week_id: "all_time"             # Changed from weekly ID
  - week_start: timestamp           # Earliest rating event timestamp
  - week_end: timestamp             # Latest rating event timestamp
  - hilarious: [{joke_id, count, rank}]
  - horrible: [{joke_id, count, rank}]
  - total_hilarious_ratings: integer
  - total_horrible_ratings: integer
  - computed_at: server timestamp
```

### Anti-Patterns to Avoid

- **Running migration without dry-run first:** Every existing script supports `--dry-run`. The new one must too. Firestore deletes are irreversible.
- **Migrating local ratings in a ViewModel:** The migration belongs in `LocalStorageService` (where the data lives), not in a ViewModel. ViewModels should just see the already-migrated data.
- **Deleting rating_events with rating 3:** The Cloud Function aggregation already ignores rating 3 (line 111 of `functions/index.js`). Deleting them is optional cleanup, not required. The all-time aggregation can simply skip them. However, for requirement TOP-03, ratings 2-4 should be remapped or removed.
- **Breaking the existing weekly rankings document:** The `MonthlyRankingsViewModel` currently reads from `weekly_rankings/{currentWeekId}`. The all-time document uses ID `all_time`, so the old documents are left undisturbed during migration. The ViewModel change to read `all_time` happens in Phase 16.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Firestore batch writes | Manual loop with individual writes | `db.batch()` with 500-doc limit | Already used in existing scripts; handles atomicity |
| Week ID calculation | Custom date math | Copy from existing `getCurrentWeekId()` or remove entirely | Existing Cloud Function has this; for all-time we don't need it |
| Migration idempotency | Complex state tracking | Simple boolean UserDefaults flag | `@AppStorage` or `UserDefaults.standard.bool(forKey:)` pattern already used in codebase |
| Cloud Function scheduling | Custom cron via crontab | `onSchedule` from firebase-functions v2 | Already deployed and working |

**Key insight:** Every component needed for this phase already exists in the codebase in some form. The migration script follows existing scripts. The Cloud Function modification simplifies existing code. The local migration extends an existing service. No new dependencies are needed.

## Common Pitfalls

### Pitfall 1: Firestore Migration Script Modifying Documents It Shouldn't

**What goes wrong:** Script processes all `rating_events` documents but accidentally modifies non-rating fields or creates malformed documents.
**Why it happens:** Copy-paste from existing migration scripts without adjusting field mappings.
**How to avoid:** The script should ONLY modify the `rating` field on each document. Use `db.collection('rating_events').doc(id).update({ rating: newRating })` -- NOT `set()` which would overwrite the entire document.
**Warning signs:** Documents losing their `joke_id`, `device_id`, or `timestamp` fields after migration.

### Pitfall 2: Local Migration Running Multiple Times

**What goes wrong:** Ratings get double-remapped (e.g., a 2 that was already migrated to 1 stays 1, but a 4 that became 5 could be mistakenly processed again).
**Why it happens:** Migration flag not checked, or flag not persisted before migration runs.
**How to avoid:** Set the migration flag AFTER successful completion. Check it BEFORE starting. Use `UserDefaults.standard.bool(forKey: "hasMigratedRatingsToBinary")`.
**Warning signs:** Users reporting lost ratings after multiple app launches.

### Pitfall 3: Cloud Function Deploy Breaking Current Rankings

**What goes wrong:** Deploying the updated Cloud Function while the iOS app still reads from the weekly document breaks the Top 10 screen.
**Why it happens:** The Cloud Function now writes to `all_time` document instead of the weekly one, but the app still queries the weekly one.
**How to avoid:** The Cloud Function should write to BOTH the current weekly document AND the `all_time` document during the transition period. Alternatively, since Phase 16 updates the client to read `all_time`, deploy the Cloud Function change only when Phase 16 is also ready. **Recommendation:** Write to `all_time` only; the weekly document data stays frozen from the last run. The app will show stale weekly data until Phase 16 updates the client, which is acceptable since the milestone ships all phases together.
**Warning signs:** Top 10 screen showing "No data" after Cloud Function deploy.

### Pitfall 4: Rating Event Document IDs Include week_id

**What goes wrong:** The document ID format is `{deviceId}_{jokeId}_{weekId}`. When migrating rating values from 2/3/4 to 1/5/removed, the document ID still contains the old week_id. This is fine for migration but means the all-time aggregation must NOT rely on document ID parsing.
**Why it happens:** Assumption that document IDs would be clean after migration.
**How to avoid:** The all-time aggregation reads `rating` and `joke_id` fields from document data, never from the document ID. This is already the pattern in the existing Cloud Function.
**Warning signs:** None -- the existing code already reads from fields, not IDs.

### Pitfall 5: Migrating rating_events with values 2, 3, 4

**What goes wrong:** The requirement says existing 2-4 values should be "cleaned or handled." But the existing Cloud Function already handles this: ratings 4-5 = hilarious, 1-2 = horrible, 3 = ignored. After migration, all events will be 1 or 5.
**Why it happens:** Confusion about whether to remap in-place (2->1, 4->5) or just delete.
**How to avoid:** The migration script should remap: 4->5, 2->1, and DELETE documents with rating 3. This ensures the data is fully binary-compatible AND the all-time aggregation counts are accurate (no ambiguity about whether a "2" should count as horrible).
**Warning signs:** All-time counts being lower than expected because 2s and 4s were deleted instead of remapped.

### Pitfall 6: Feature Branch Workflow

**What goes wrong:** Creating the feature branch but then making commits on `main` accidentally.
**Why it happens:** Forgetting to switch branches, or using the wrong branch for commits.
**How to avoid:** Create branch as the very first step. All subsequent phase work happens on this branch. Verify with `git branch` before each commit.
**Warning signs:** Commits appearing on `main` that should be on `v1.1.0`.

## Code Examples

Verified patterns from the existing codebase:

### Firestore Migration Script Structure (from existing scripts)

```javascript
// Source: scripts/migrate-holiday-tags.js (established pattern)
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const BATCH_SIZE = 500;
const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');

// Standard logging (same as all other scripts)
const log = {
  info: (msg) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
  warn: (msg) => console.log(`[WARN] ${new Date().toISOString()} - ${msg}`),
  error: (msg) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
  success: (msg) => console.log(`[SUCCESS] ${new Date().toISOString()} - ${msg}`),
  divider: () => console.log('='.repeat(70))
};
```

### Cloud Function All-Time Aggregation (modified from functions/index.js)

```javascript
// Source: functions/index.js lines 80-91 (current aggregation logic)
// Current: filters by week_id
// Target: remove week_id filter, aggregate ALL events

// CURRENT (weekly):
async function fetchRatingEvents(weekId) {
  const snapshot = await db.collection(RATING_EVENTS_COLLECTION)
    .where("week_id", "==", weekId)
    .get();
  return snapshot.docs.map(doc => doc.data());
}

// TARGET (all-time):
async function fetchAllRatingEvents() {
  const snapshot = await db.collection(RATING_EVENTS_COLLECTION).get();
  return snapshot.docs.map(doc => doc.data());
}

// Save to fixed "all_time" document instead of weekly
async function saveAllTimeRankings(rankings) {
  const document = {
    week_id: "all_time",
    // ... same structure, just "all_time" as ID
  };
  await db.collection(WEEKLY_RANKINGS_COLLECTION).doc("all_time").set(document);
}
```

### Local Rating Migration (following LocalStorageService.swift patterns)

```swift
// Source: LocalStorageService.swift (established patterns)
// Migration method following existing service patterns

private let migrationKey = "hasMigratedRatingsToBinary"

func migrateRatingsToBinaryIfNeeded() {
    // Check if already migrated
    guard !userDefaults.bool(forKey: migrationKey) else { return }

    queue.sync {
        var ratings = self.loadRatingsSync()       // [String: Int]
        var timestamps = self.loadRatingTimestampsSync()  // [String: TimeInterval]
        var changed = false
        var keysToRemove: [String] = []

        for (key, rating) in ratings {
            switch rating {
            case 4, 5:
                ratings[key] = 5  // -> Hilarious
                changed = true
            case 1, 2:
                ratings[key] = 1  // -> Horrible
                changed = true
            case 3:
                keysToRemove.append(key)  // Drop neutral ratings
                changed = true
            default:
                break  // Already 1 or 5, or unexpected value
            }
        }

        // Remove dropped ratings and their timestamps
        for key in keysToRemove {
            ratings.removeValue(forKey: key)
            timestamps.removeValue(forKey: key)
        }

        if changed {
            self.saveRatingsSync(ratings)
            self.saveRatingTimestampsSync(timestamps)
        }

        // Mark migration as complete
        userDefaults.set(true, forKey: migrationKey)
    }
}
```

### Rating Event Migration Logic (for Firestore script)

```javascript
// Migration rules for rating_events collection:
function migrateRating(currentRating) {
  if (currentRating >= 4) return 5;       // 4,5 -> Hilarious (5)
  if (currentRating <= 2) return 1;       // 1,2 -> Horrible (1)
  if (currentRating === 3) return null;   // 3 -> DELETE document
  return currentRating;                    // Unexpected value, keep as-is
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Weekly ranking aggregation | All-time ranking aggregation | v1.1.0 (this phase) | Cloud Function simplifies by removing time window |
| 5-point rating scale | Binary (Hilarious/Horrible) | v1.1.0 (this phase) | Simpler data model, cleaner aggregation |
| `weekly_rankings/{weekId}` | `weekly_rankings/all_time` | v1.1.0 (this phase) | Fixed document ID, no weekly rotation |

**Deprecated/outdated:**
- Weekly aggregation pattern: Replaced by all-time. The `getCurrentWeekId()` function in the Cloud Function becomes unnecessary for all-time mode.
- Rating values 2, 3, 4: No longer valid after migration. Only 1 (Horrible) and 5 (Hilarious) are stored.

## Codebase Inventory: Files That Must Change

### Files to CREATE (new)

| File | Purpose |
|------|---------|
| `scripts/migrate-rating-events.js` | One-time Firestore migration script for `rating_events` collection |

### Files to MODIFY

| File | What Changes | Why |
|------|-------------|-----|
| `scripts/package.json` | Add `migrate-ratings` and `migrate-ratings:dry-run` npm scripts | Follows existing script registration pattern |
| `functions/index.js` | Modify `runAggregation()` to aggregate all events, write to `all_time` doc | TOP-02: All-time aggregation |
| `MrFunnyJokes/Services/LocalStorageService.swift` | Add `migrateRatingsToBinaryIfNeeded()` method | RATE-05: Local rating migration |
| `MrFunnyJokes/ViewModels/JokeViewModel.swift` | Call migration method early in `init()` or `loadInitialContentAsync()` | Trigger migration at app launch |

### Files that do NOT change in this phase

| File | Why Not |
|------|---------|
| `Joke.swift` | Model stays the same -- `userRating: Int?` already supports 1 and 5 |
| `FirestoreModels.swift` | `WeeklyRankings` struct already has the right shape for all-time data |
| `MonthlyRankingsViewModel.swift` | Still reads from `fetchWeeklyRankings()` -- changed in Phase 16 |
| `FirestoreService.swift` | `fetchWeeklyRankings()` and `logRatingEvent()` stay the same for now |
| `GrainOMeterView.swift` | UI changes happen in Phase 14 |
| `MeView.swift` | UI changes happen in Phase 15 |

## Open Questions

1. **Firestore rating_events volume**
   - What we know: 433 jokes in the database, anonymous device-based rating. Document ID format: `{deviceId}_{jokeId}_{weekId}`
   - What's unclear: How many total rating_events documents exist? This affects migration script run time and Cloud Function memory/execution time for all-time aggregation
   - Recommendation: The migration script should log the total count. For all-time aggregation, 256MiB memory (current setting) should be sufficient for thousands of events. If it exceeds ~50k events, consider pagination in the Cloud Function

2. **Cloud Function deployment timing**
   - What we know: The Cloud Function deploys independently from the iOS app. The app currently reads weekly rankings via `fetchWeeklyRankings()` which uses `getCurrentWeekId()`
   - What's unclear: Should the Cloud Function be deployed before or after the iOS app update? The v1.1.0 milestone ships all phases together, but Cloud Function deploys happen immediately while iOS app updates go through App Store review
   - Recommendation: Deploy the Cloud Function as part of Phase 13 work. The existing weekly data stays frozen (no longer updated), and the `all_time` document is created. Phase 16 updates the iOS client to read from `all_time`. Between deployment and app update, users see stale but functional weekly data. This is acceptable for a low-user-count app.

3. **Should existing weekly ranking documents be deleted?**
   - What we know: The decision says "Keep `weekly_rankings` collection name, use `all_time` document ID." Old weekly documents will remain but never update.
   - What's unclear: Whether to clean up old weekly documents
   - Recommendation: Leave them. They're harmless, and deleting them adds risk for zero benefit. The collection name stays the same per the decision.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis** -- All findings verified by reading source files directly:
  - `functions/index.js` -- Current Cloud Function aggregation logic
  - `functions/package.json` -- firebase-functions v7, firebase-admin v13, Node.js 20
  - `scripts/migrate-joke-ids.js` -- Established migration script pattern
  - `scripts/migrate-holiday-tags.js` -- Established migration script pattern
  - `scripts/package.json` -- ES modules, firebase-admin v12
  - `MrFunnyJokes/Services/LocalStorageService.swift` -- Local rating storage (UserDefaults)
  - `MrFunnyJokes/Services/FirestoreService.swift` -- Firestore interaction patterns
  - `MrFunnyJokes/ViewModels/JokeViewModel.swift` -- Rating flow, app launch sequence
  - `MrFunnyJokes/Models/Joke.swift` -- Data model (userRating: Int?)
  - `MrFunnyJokes/Models/FirestoreModels.swift` -- WeeklyRankings struct
  - `MrFunnyJokes/App/MrFunnyJokesApp.swift` -- App launch lifecycle
  - `firebase.json` -- Functions deployment config (Node.js 20)
  - `.firebaserc` -- Project ID: mr-funny-jokes

### Secondary (MEDIUM confidence)
- Firebase Cloud Functions v2 scheduler API -- Based on existing deployed code patterns
- Firestore batch write limits (500 documents) -- Established in existing migration scripts

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All libraries already in use, no new dependencies
- Architecture: HIGH -- All patterns directly observed in existing codebase
- Pitfalls: HIGH -- Based on actual code analysis and established migration patterns
- Code examples: HIGH -- Adapted from existing codebase files with line references

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable -- no external dependency changes expected)
