---
phase: 07-cloud-functions-migration
plan: 01
subsystem: backend
tags: [firebase, cloud-functions, aggregation, serverless]

dependency-graph:
  requires: [scripts/aggregate-weekly-rankings.js]
  provides: [functions/, firebase.json, .firebaserc]
  affects: [07-02 deployment, weekly_rankings collection]

tech-stack:
  added: [firebase-functions@7.3.3, firebase-admin@13.3.1, firebase-tools@15.5.1]
  patterns: [scheduled-functions, http-triggers, shared-logic]

key-files:
  created: [functions/package.json, functions/index.js, functions/package-lock.json, firebase.json, .firebaserc]
  modified: [.gitignore]

decisions:
  - id: node20-runtime
    choice: Node.js 20 runtime for Cloud Functions
    reason: Required by firebase-functions v7; v18 deprecated

metrics:
  duration: 4m 6s
  completed: 2026-01-30
---

# Phase 7 Plan 01: Cloud Functions Infrastructure Summary

**One-liner:** Firebase Cloud Functions project structure with ported aggregation logic using onSchedule and onRequest triggers

## What Was Built

### Cloud Functions Project Structure

Created complete Firebase Cloud Functions infrastructure at `functions/`:

1. **functions/package.json**
   - Node.js 20 runtime (required for firebase-functions v7)
   - Dependencies: firebase-functions@^7.0.0, firebase-admin@^13.0.0
   - Scripts: serve (emulators), deploy (firebase deploy)

2. **functions/index.js**
   - `aggregateRankings`: Scheduled function (daily at midnight ET)
   - `triggerAggregation`: HTTP endpoint for manual triggering with optional `?week=YYYY-WNN` param
   - Shared `runAggregation()` function used by both triggers

3. **firebase.json** and **.firebaserc**
   - Project configuration pointing to functions/
   - Project alias: mr-funny-jokes

### Aggregation Logic Ported

Exact logic from `scripts/aggregate-weekly-rankings.js` preserved:
- Rating >= 4 = "hilarious"
- Rating <= 2 = "horrible"
- Rating == 3 = neutral (not counted)
- Outputs to `weekly_rankings` collection with same document structure

### Key Functions

| Function | Export | Trigger | Schedule |
|----------|--------|---------|----------|
| `aggregateRankings` | Yes | onSchedule | 0 0 * * * (daily midnight ET) |
| `triggerAggregation` | Yes | onRequest | On-demand HTTP |
| `runAggregation` | Internal | - | Shared core logic |

## Commits

| Hash | Type | Description |
|------|------|-------------|
| `037a513` | chore | Create Cloud Functions project structure |
| `621dea8` | feat | Port aggregation logic to Cloud Function |
| `27289f0` | chore | Add functions package-lock for reproducible builds |

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

1. **Node.js 20 runtime**: firebase-functions v7 requires Node.js 18+, and v18 is deprecated early 2025. Node.js 20 is the current LTS target.

2. **Shared runAggregation function**: Both scheduled and HTTP triggers share the same core logic, avoiding code duplication and ensuring consistent behavior.

3. **Module-scope Firestore initialization**: Initialized `db = getFirestore()` at module scope for better cold start performance, per Firebase best practices.

## Verification Results

- Firebase emulator started successfully
- Both functions loaded: `aggregateRankings`, `triggerAggregation`
- HTTP endpoint initialized at `http://127.0.0.1:5001/mr-funny-jokes/us-central1/triggerAggregation`
- No syntax or import errors
- Code syntax validated with `node -c index.js`

## Next Phase Readiness

**Ready for Plan 02:** Deployment and verification

**Pre-deployment checklist:**
- [ ] Ensure Cloud Scheduler API is enabled in Google Cloud Console
- [ ] Verify Firebase CLI authentication (`firebase login`)
- [ ] Deploy with `firebase deploy --only functions`
- [ ] Verify scheduled function appears in Firebase Console
- [ ] Test HTTP endpoint in production

**Known considerations:**
- Emulator timeout on HTTP endpoint is expected (no Firestore emulator running)
- First production run may have cold start latency (5-20 seconds)
- Monitor Cloud Functions logs after first scheduled execution
