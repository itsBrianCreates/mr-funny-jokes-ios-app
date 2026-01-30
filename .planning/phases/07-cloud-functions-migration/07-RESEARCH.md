# Phase 7: Cloud Functions Migration - Research

**Researched:** 2026-01-30
**Domain:** Firebase Cloud Functions v2, Scheduled Functions, Rankings Aggregation
**Confidence:** HIGH

## Summary

This research covers migrating the local `scripts/aggregate-weekly-rankings.js` cron job to Firebase Cloud Functions. The migration is straightforward because:

1. **Firebase Cloud Functions v2** provides `onSchedule` from `firebase-functions/v2/scheduler` that directly supports cron-based scheduling with timezone configuration
2. **The existing aggregation logic** can be ported nearly verbatim - same Firestore queries, same aggregation algorithm, same output format
3. **HTTP endpoint for manual triggering** uses `onRequest` from `firebase-functions/v2/https` - simple Node.js Express-like pattern

**Primary recommendation:** Use Firebase Cloud Functions v2 with `onSchedule` for the scheduled job and `onRequest` for manual HTTP triggering. Deploy to a new `functions/` directory at project root, separate from the existing `scripts/` directory.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `firebase-functions` | ^7.0.3 | Cloud Functions SDK | Official Firebase SDK, v7 is current major |
| `firebase-admin` | ^13.6.0 | Firestore access from functions | Official Firebase Admin SDK, required for server-side Firestore |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `firebase-tools` | latest | CLI for deployment | Required for `firebase deploy --only functions` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Cloud Functions | Cloud Run | More control but more complex setup; overkill for simple aggregation |
| `onSchedule` | External cron + HTTP endpoint | Already have this pattern locally; defeats purpose of migration |
| Firebase v2 | Firebase v1 | v1 is in maintenance mode; v2 has better cold start performance |

**Installation (in `functions/` directory):**
```bash
npm install firebase-functions@^7 firebase-admin@^13
```

## Architecture Patterns

### Recommended Project Structure
```
mr-funny-jokes-ios-app/
├── functions/              # NEW: Cloud Functions directory
│   ├── package.json        # Functions-specific dependencies
│   ├── index.js            # Function exports
│   └── .eslintrc.js        # Optional linting
├── firebase.json           # NEW: Firebase project config
├── .firebaserc             # NEW: Firebase project alias
├── scripts/                # EXISTING: Keep for now, archive later
│   ├── aggregate-weekly-rankings.js  # To be archived after migration verified
│   └── run-aggregation.sh            # To be archived after migration verified
└── ...
```

### Pattern 1: Scheduled Function with onSchedule
**What:** Cron-triggered function that runs at specified times
**When to use:** Recurring background jobs like rankings aggregation
**Example:**
```javascript
// Source: Firebase official docs - https://firebase.google.com/docs/functions/schedule-functions
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");

exports.aggregateRankings = onSchedule({
  schedule: "0 0 * * *",           // Daily at midnight
  timeZone: "America/New_York",    // Eastern Time per CONTEXT.md decision
  retryCount: 3,                   // Retry on failure
  memory: "256MiB",                // Sufficient for Firestore queries
}, async (event) => {
  logger.info("Starting rankings aggregation", { structuredData: true });
  // ... aggregation logic
  logger.info("Aggregation complete");
});
```

### Pattern 2: HTTP Endpoint with onRequest
**What:** HTTP endpoint for manual triggering
**When to use:** Testing, debugging, urgent manual runs
**Example:**
```javascript
// Source: Firebase official docs - https://firebase.google.com/docs/functions/http-events
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");

exports.triggerAggregation = onRequest(async (req, res) => {
  logger.info("Manual aggregation triggered");

  try {
    // Reuse same aggregation logic
    const result = await runAggregation();
    res.status(200).json({
      success: true,
      message: "Aggregation complete",
      result
    });
  } catch (error) {
    logger.error("Aggregation failed", { error: error.message });
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});
```

### Pattern 3: Shared Logic Between Triggers
**What:** Extract core aggregation into reusable function
**When to use:** When scheduled and HTTP endpoints share logic
**Example:**
```javascript
// Core aggregation logic - used by both triggers
async function runAggregation(weekId = null) {
  const targetWeek = weekId || getCurrentWeekId();
  const events = await fetchRatingEvents(targetWeek);
  const { hilariousCounts, horribleCounts, totalHilarious, totalHorrible } = aggregateRatings(events);
  const hilariousTop10 = rankTopN(hilariousCounts, 10);
  const horribleTop10 = rankTopN(horribleCounts, 10);
  await saveWeeklyRankings(targetWeek, { hilarious: hilariousTop10, horrible: horribleTop10, totalHilarious, totalHorrible });
  return { weekId: targetWeek, hilariousCount: hilariousTop10.length, horribleCount: horribleTop10.length };
}

// Scheduled trigger
exports.aggregateRankings = onSchedule({ schedule: "0 0 * * *", timeZone: "America/New_York" }, async () => {
  await runAggregation();
});

// HTTP trigger
exports.triggerAggregation = onRequest(async (req, res) => {
  const weekId = req.query.week || null;  // Optional week override
  const result = await runAggregation(weekId);
  res.json({ success: true, result });
});
```

### Anti-Patterns to Avoid
- **Initializing Firestore inside function handler:** Initialize at module scope for better cold start performance
- **Using `admin.firestore()` instead of `initializeFirestore()`:** The newer `initializeFirestore()` supports `preferRest: true` to reduce cold starts
- **Not handling errors:** Unhandled errors cause cold starts; always use try/catch
- **Oversized memory allocation:** 256MiB is sufficient for simple Firestore queries; don't over-provision

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cron scheduling | Custom scheduler logic | `onSchedule` with cron syntax | Cloud Scheduler handles reliability, retries, monitoring |
| Timezone handling | Manual date conversion | `timeZone` option in `onSchedule` | Firebase handles DST transitions automatically |
| Retry logic | Custom retry wrapper | `retryCount` option in `onSchedule` | Built-in exponential backoff |
| Error reporting | Console.log | `logger` from firebase-functions | Automatic Cloud Logging + Error Reporting integration |
| Manual triggering | Separate deployment | `onRequest` in same codebase | Shares code with scheduled function |

**Key insight:** Cloud Functions v2 options provide most operational concerns out-of-the-box. The `onSchedule` options handle scheduling, timezones, retries, and logging - focus only on business logic.

## Common Pitfalls

### Pitfall 1: Cold Start Latency with Firestore
**What goes wrong:** First invocation after idle period takes 5-20 seconds
**Why it happens:** gRPC library loading, Firestore client initialization
**How to avoid:** Use `initializeFirestore()` with `preferRest: true` option (HTTP/1.1 mode)
**Warning signs:** Logs showing long initialization times

```javascript
// Source: https://firebase.google.com/docs/functions/tips
const { initializeApp } = require("firebase-admin/app");
const { initializeFirestore } = require("firebase-admin/firestore");

initializeApp();
const db = initializeFirestore(admin.app(), { preferRest: true });
```

### Pitfall 2: Emulator Cannot Auto-Trigger Scheduled Functions
**What goes wrong:** `firebase emulators:start` doesn't auto-run scheduled functions
**Why it happens:** Emulator doesn't include Cloud Scheduler component
**How to avoid:** Manually trigger via Pub/Sub topic `firebase-schedule-<functionName>` or use curl to HTTP endpoint
**Warning signs:** Function works in production but never triggers locally

### Pitfall 3: Node.js Version Mismatch
**What goes wrong:** Deployment fails or runtime errors
**Why it happens:** Local Node.js version differs from Cloud Functions runtime
**How to avoid:** Specify `engines.node` in package.json matching deployment target; use Node.js 20 (18 deprecated in early 2025)
**Warning signs:** "Unexpected token" errors, missing API features

### Pitfall 4: firebase-functions v7 Breaking Changes
**What goes wrong:** Code from older tutorials doesn't work
**Why it happens:** v7 removed deprecated APIs
**How to avoid:**
- Don't use `functions.config()` - use `params` module instead
- Target Node.js 18+ (v7 dropped Node.js 16 support)
**Warning signs:** "functions.config is not a function" errors

### Pitfall 5: Forgetting to Enable Cloud Scheduler API
**What goes wrong:** Scheduled function deploys but never runs
**Why it happens:** Cloud Scheduler API not enabled for project
**How to avoid:** Verify in Google Cloud Console > APIs & Services > Cloud Scheduler API
**Warning signs:** Function deploys successfully but no logs at scheduled time

## Code Examples

Verified patterns from official sources:

### Complete index.js Template
```javascript
// Source: Firebase official docs, verified against STACK.md prior research
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

// Initialize at module scope (not inside handler)
initializeApp();
const db = getFirestore();

// Configuration constants (match existing script)
const RATING_EVENTS_COLLECTION = "rating_events";
const WEEKLY_RANKINGS_COLLECTION = "weekly_rankings";
const TOP_N = 10;

/**
 * Get current ISO week ID in Eastern Time (e.g., "2026-W04")
 * Ported from existing aggregate-weekly-rankings.js
 */
function getCurrentWeekId() {
  const now = new Date();
  const eastern = new Date(now.toLocaleString("en-US", { timeZone: "America/New_York" }));
  const startOfYear = new Date(eastern.getFullYear(), 0, 1);
  const days = Math.floor((eastern - startOfYear) / (24 * 60 * 60 * 1000));
  const weekNumber = Math.ceil((days + startOfYear.getDay() + 1) / 7);
  return `${eastern.getFullYear()}-W${String(weekNumber).padStart(2, "0")}`;
}

/**
 * Get week start and end dates for a given week ID
 */
function getWeekDateRange(weekId) {
  const [year, weekPart] = weekId.split("-W");
  const weekNum = parseInt(weekPart, 10);
  const jan4 = new Date(parseInt(year), 0, 4);
  const dayOfWeek = jan4.getDay() || 7;
  const week1Monday = new Date(jan4);
  week1Monday.setDate(jan4.getDate() - dayOfWeek + 1);
  const weekStart = new Date(week1Monday);
  weekStart.setDate(week1Monday.getDate() + (weekNum - 1) * 7);
  weekStart.setHours(0, 0, 0, 0);
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekStart.getDate() + 6);
  weekEnd.setHours(23, 59, 59, 999);
  return { weekStart, weekEnd };
}

/**
 * Fetch rating events for a week
 */
async function fetchRatingEvents(weekId) {
  const snapshot = await db.collection(RATING_EVENTS_COLLECTION)
    .where("week_id", "==", weekId)
    .get();
  return snapshot.docs.map(doc => doc.data());
}

/**
 * Aggregate ratings into hilarious/horrible counts
 */
function aggregateRatings(events) {
  const hilariousCounts = {};
  const horribleCounts = {};
  let totalHilarious = 0;
  let totalHorrible = 0;

  for (const event of events) {
    const { joke_id, rating } = event;
    if (rating >= 4) {
      hilariousCounts[joke_id] = (hilariousCounts[joke_id] || 0) + 1;
      totalHilarious++;
    } else if (rating <= 2) {
      horribleCounts[joke_id] = (horribleCounts[joke_id] || 0) + 1;
      totalHorrible++;
    }
  }
  return { hilariousCounts, horribleCounts, totalHilarious, totalHorrible };
}

/**
 * Rank top N jokes by count
 */
function rankTopN(counts, n = TOP_N) {
  return Object.entries(counts)
    .map(([jokeId, count]) => ({ joke_id: jokeId, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, n)
    .map((entry, index) => ({ ...entry, rank: index + 1 }));
}

/**
 * Save weekly rankings to Firestore
 */
async function saveWeeklyRankings(weekId, rankings) {
  const { weekStart, weekEnd } = getWeekDateRange(weekId);
  await db.collection(WEEKLY_RANKINGS_COLLECTION).doc(weekId).set({
    week_id: weekId,
    week_start: Timestamp.fromDate(weekStart),
    week_end: Timestamp.fromDate(weekEnd),
    hilarious: rankings.hilarious,
    horrible: rankings.horrible,
    total_hilarious_ratings: rankings.totalHilarious,
    total_horrible_ratings: rankings.totalHorrible,
    computed_at: FieldValue.serverTimestamp(),
  });
}

/**
 * Core aggregation logic - shared by scheduled and HTTP triggers
 */
async function runAggregation(weekId = null) {
  const targetWeek = weekId || getCurrentWeekId();
  logger.info(`Processing week: ${targetWeek}`);

  const events = await fetchRatingEvents(targetWeek);
  logger.info(`Found ${events.length} rating events`);

  if (events.length === 0) {
    logger.warn("No rating events found for this week");
  }

  const { hilariousCounts, horribleCounts, totalHilarious, totalHorrible } = aggregateRatings(events);
  const hilariousTop10 = rankTopN(hilariousCounts);
  const horribleTop10 = rankTopN(horribleCounts);

  logger.info(`Top 10 hilarious: ${hilariousTop10.length} jokes`);
  logger.info(`Top 10 horrible: ${horribleTop10.length} jokes`);

  await saveWeeklyRankings(targetWeek, {
    hilarious: hilariousTop10,
    horrible: horribleTop10,
    totalHilarious,
    totalHorrible,
  });

  return {
    weekId: targetWeek,
    eventsProcessed: events.length,
    hilariousTop10Count: hilariousTop10.length,
    horribleTop10Count: horribleTop10.length,
  };
}

// ============================================
// SCHEDULED FUNCTION: Daily at midnight ET
// ============================================
exports.aggregateRankings = onSchedule({
  schedule: "0 0 * * *",
  timeZone: "America/New_York",
  retryCount: 3,
  memory: "256MiB",
}, async (event) => {
  logger.info("Scheduled aggregation started");
  try {
    const result = await runAggregation();
    logger.info("Scheduled aggregation complete", result);
  } catch (error) {
    logger.error("Scheduled aggregation failed", { error: error.message, stack: error.stack });
    throw error; // Re-throw to trigger retry
  }
});

// ============================================
// HTTP FUNCTION: Manual trigger endpoint
// ============================================
exports.triggerAggregation = onRequest(async (req, res) => {
  logger.info("Manual aggregation triggered", {
    method: req.method,
    query: req.query
  });

  // Optional: Allow specifying a week via query param
  const weekId = req.query.week || null;

  try {
    const result = await runAggregation(weekId);
    res.status(200).json({
      success: true,
      message: "Aggregation complete",
      result,
    });
  } catch (error) {
    logger.error("Manual aggregation failed", { error: error.message });
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});
```

### package.json for functions/
```json
{
  "name": "mr-funny-jokes-functions",
  "description": "Cloud Functions for Mr. Funny Jokes rankings aggregation",
  "main": "index.js",
  "engines": {
    "node": "20"
  },
  "dependencies": {
    "firebase-admin": "^13.0.0",
    "firebase-functions": "^7.0.0"
  },
  "scripts": {
    "lint": "eslint .",
    "serve": "firebase emulators:start --only functions",
    "deploy": "firebase deploy --only functions"
  }
}
```

### firebase.json (project root)
```json
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs20"
  }
}
```

### .firebaserc (project root)
```json
{
  "projects": {
    "default": "mr-funny-jokes"
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| firebase-functions v1 | firebase-functions v2 | 2023 | Use `firebase-functions/v2/*` imports |
| `functions.config()` | `params` module | v7.0 (2025) | Environment variables now use params |
| Node.js 16 | Node.js 20/22 | v7.0 (2025) | Node 18 deprecated early 2025 |
| `admin.firestore()` | `initializeFirestore()` | firebase-admin v12+ | Supports `preferRest` for faster cold starts |

**Deprecated/outdated:**
- `functions.runWith()` for v1 options syntax - use options object in v2 handlers
- `functions.pubsub.schedule()` for v1 scheduled functions - use `onSchedule` in v2
- Node.js 16 runtime - deprecated, use 20 or 22

## Open Questions

Things that couldn't be fully resolved:

1. **Exact cold start time for this specific workload**
   - What we know: Cold starts typically 5-20 seconds; `preferRest: true` helps
   - What's unclear: Actual latency for this specific function (light Firestore queries)
   - Recommendation: Deploy, measure, optimize if needed with `minInstances: 1` ($~$5/month)

2. **Weekly vs Monthly aggregation terminology**
   - What we know: Context says "monthly" but existing script does weekly (`week_id`, `weekly_rankings`)
   - What's unclear: Whether to change to monthly or keep weekly
   - Recommendation: Keep existing weekly logic - matches current `rating_events.week_id` field and `weekly_rankings` collection

## Sources

### Primary (HIGH confidence)
- [Schedule functions | Cloud Functions for Firebase](https://firebase.google.com/docs/functions/schedule-functions) - onSchedule syntax, timezone config
- [Call functions via HTTP requests](https://firebase.google.com/docs/functions/http-events) - onRequest pattern
- [Manage functions | Cloud Functions for Firebase](https://firebase.google.com/docs/functions/manage-functions) - deployment, scaling
- [firebase-functions npm](https://www.npmjs.com/package/firebase-functions) - v7.0.3 current, breaking changes
- [firebase-admin npm](https://www.npmjs.com/package/firebase-admin) - v13.6.0 current
- [Tips & tricks | Cloud Functions for Firebase](https://firebase.google.com/docs/functions/tips) - cold start optimization

### Secondary (MEDIUM confidence)
- Prior research in `.planning/milestones/v1.0.1-research/STACK.md` - comprehensive Cloud Functions v2 patterns
- Existing `scripts/aggregate-weekly-rankings.js` - source logic to migrate

### Tertiary (LOW confidence)
- Community blog posts on cold start optimization - patterns may vary by workload

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Firebase documentation, npm package versions verified
- Architecture: HIGH - Patterns directly from Firebase docs + existing codebase analysis
- Pitfalls: MEDIUM - Based on official docs + community reports, some may not apply to this specific case

**Research date:** 2026-01-30
**Valid until:** 2026-03-30 (60 days - Firebase Functions v2 is stable)
