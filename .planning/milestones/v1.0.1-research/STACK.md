# Technology Stack: v1.0.1 Content Freshness

**Project:** Mr. Funny Jokes - Content Freshness Milestone
**Researched:** 2026-01-30
**Overall Confidence:** HIGH (verified against Apple Developer Documentation and Firebase official docs)

---

## Executive Summary

For v1.0.1 content freshness features, the stack additions are:

1. **Widget Background Refresh:** Use `BGTaskScheduler` with `BGAppRefreshTaskRequest` to wake the app periodically and update widget data via App Groups. The widget's `TimelineProvider` already handles display updates; we just need the app to push fresh data.

2. **Background Joke Loading:** Same `BGAppRefreshTask` fetches full joke catalog on app backgrounding. Firestore's existing 50MB cache handles storage.

3. **Feed Prioritization:** No stack additions needed. Client-side logic in existing `FirestoreService` and `JokeViewModel`.

4. **Cloud Rankings Aggregation:** Firebase Cloud Functions (v2) with `onSchedule` replaces the local cron job. Requires Blaze plan but cost is negligible ($0.10/month per scheduler job + free tier invocations).

**Key insight:** iOS background refresh is "best effort" - the system decides when to run tasks based on user behavior, battery, and network. For guaranteed daily updates, combine widget timeline reload policies with background fetch. Widgets can also fetch directly in their `TimelineProvider` if the main app hasn't run recently.

---

## Stack Additions Required

### 1. BackgroundTasks Framework (iOS Native)

| Component | iOS Requirement | Purpose | Confidence |
|-----------|-----------------|---------|------------|
| `BGTaskScheduler` | iOS 13+ | Register and schedule background tasks | HIGH |
| `BGAppRefreshTaskRequest` | iOS 13+ | Short-lived refresh task (30 sec max) | HIGH |
| `backgroundTask(_:action:)` modifier | iOS 16+ SwiftUI | SwiftUI scene modifier for handling tasks | HIGH |

**Why BGAppRefreshTask (not BGProcessingTask):**
- Widget data refresh is lightweight (single Firestore query)
- BGProcessingTask is for long operations (ML, heavy computation)
- BGAppRefreshTask has better scheduling priority for frequently-used apps

**Critical Limitations:**
- **30 second maximum runtime** - sufficient for a single Firestore fetch
- **System-controlled scheduling** - not guaranteed to run at specific times
- **User behavior dependent** - apps users engage with get more refresh opportunities
- iOS provides ~40-70 refresh opportunities per day for frequently-viewed widgets

### 2. Firebase Cloud Functions v2

| Component | Purpose | Confidence |
|-----------|---------|------------|
| `firebase-functions/v2/scheduler` | Scheduled function triggers | HIGH |
| `onSchedule` handler | Cron-based invocation | HIGH |
| `firebase-admin` | Firestore access from function | HIGH |

**Why Cloud Functions v2 (not v1):**
- Active development; v1 is in maintenance mode
- Better cold start performance
- Improved concurrency controls
- Same scheduling syntax available

**Pricing (Blaze Plan Required):**
- Cloud Scheduler: $0.10/month per job (first 3 free)
- Function invocations: 2M/month free, then $0.40/million
- For daily aggregation: ~30 invocations/month = well within free tier

### 3. No New Stack for Feed Prioritization

Existing stack handles this:
- `LocalStorageService` already tracks rated joke IDs
- `FirestoreService.fetchInitialJokes()` can be modified to accept exclusion list
- Client-side sorting/filtering in `JokeViewModel`

### 4. No New Stack for Widget Direct Fetch (Already Supported)

The existing `TimelineProvider` can make network requests:
- WidgetKit allows network calls in `getTimeline()`
- App Groups share Firestore configuration
- Already using `SharedStorageService` for data sharing

---

## Implementation Architecture

### Background Refresh Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    User Opens App                            │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  1. Fetch Joke of the Day from Firestore            │    │
│  │  2. Save to SharedStorageService (App Group)        │    │
│  │  3. Call WidgetCenter.shared.reloadAllTimelines()   │    │
│  │  4. Schedule BGAppRefreshTask for background        │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  App Goes to Background                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  BGTaskScheduler determines when to wake app         │    │
│  │  (Based on user patterns, battery, network)          │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼ (iOS decides timing)
┌─────────────────────────────────────────────────────────────┐
│                BGAppRefreshTask Executes                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  1. Fetch tomorrow's Joke of the Day                 │    │
│  │  2. Fetch full joke catalog (background load)        │    │
│  │  3. Save to SharedStorageService                     │    │
│  │  4. Call WidgetCenter.shared.reloadAllTimelines()   │    │
│  │  5. Schedule next BGAppRefreshTask                   │    │
│  │  6. Call task.setTaskCompleted(success: true)        │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Widget Timeline Provider Runs                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Reads fresh data from SharedStorageService          │    │
│  │  Returns timeline entries for next 24+ hours         │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Cloud Functions Aggregation Flow

```
┌─────────────────────────────────────────────────────────────┐
│            Cloud Scheduler (configured in Firebase)          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Cron: "0 0 * * *" (daily at midnight UTC)           │    │
│  │  Or: "every day 00:00" (App Engine syntax)           │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              onSchedule Cloud Function                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  1. Query rating_events for current period           │    │
│  │  2. Aggregate hilarious (4-5) and horrible (1-2)     │    │
│  │  3. Rank top 10 for each category                    │    │
│  │  4. Write to weekly_rankings collection              │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Code Structure: Background Tasks

### Info.plist Configuration (Required)

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.bvanaski.MrFunnyJokes.refresh</string>
</array>
```

### Capability Configuration (Required)

Enable "Background Modes" capability with "Background fetch" checked.

### SwiftUI App Integration

```swift
@main
struct MrFunnyJokesApp: App {
    init() {
        FirebaseApp.configure()
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .backgroundTask(.appRefresh("com.bvanaski.MrFunnyJokes.refresh")) {
            await handleAppRefresh()
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.bvanaski.MrFunnyJokes.refresh",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleRefreshTask(refreshTask)
        }
    }

    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            do {
                // Fetch and cache joke of the day
                let joke = try await FirestoreService.shared.fetchJokeOfTheDay()
                if let joke = joke {
                    SharedStorageService.shared.saveJokeOfTheDay(joke.toShared())
                }

                // Trigger widget update
                WidgetCenter.shared.reloadAllTimelines()

                // Schedule next refresh
                scheduleAppRefresh()

                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(
            identifier: "com.bvanaski.MrFunnyJokes.refresh"
        )
        // Request refresh no earlier than 4 hours from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
}
```

---

## Code Structure: Cloud Functions

### Directory Setup

```
functions/
├── package.json
├── index.js
└── .eslintrc.js
```

### package.json

```json
{
  "name": "mr-funny-jokes-functions",
  "main": "index.js",
  "engines": {
    "node": "20"
  },
  "dependencies": {
    "firebase-admin": "^13.0.0",
    "firebase-functions": "^6.0.0"
  }
}
```

### index.js (Scheduled Aggregation)

```javascript
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Aggregates rating events into monthly rankings
 * Runs daily at midnight Eastern Time
 */
exports.aggregateRankings = onSchedule({
  schedule: "0 0 * * *",  // Daily at midnight UTC
  timeZone: "America/New_York",
  retryCount: 3,
}, async (event) => {
  logger.info("Starting rankings aggregation");

  const monthId = getCurrentMonthId();
  const events = await fetchRatingEvents(monthId);

  if (events.length === 0) {
    logger.info("No rating events for this period");
    return;
  }

  const { hilariousCounts, horribleCounts } = aggregateRatings(events);
  const hilariousTop10 = rankTopN(hilariousCounts, 10);
  const horribleTop10 = rankTopN(horribleCounts, 10);

  await saveRankings(monthId, hilariousTop10, horribleTop10);

  logger.info(`Aggregation complete: ${hilariousTop10.length} hilarious, ${horribleTop10.length} horrible`);
});

function getCurrentMonthId() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

async function fetchRatingEvents(monthId) {
  // Query events for the current month
  const snapshot = await db.collection("rating_events")
    .where("month_id", "==", monthId)
    .get();

  return snapshot.docs.map(doc => doc.data());
}

function aggregateRatings(events) {
  const hilariousCounts = {};
  const horribleCounts = {};

  for (const event of events) {
    const { joke_id, rating } = event;

    if (rating >= 4) {
      hilariousCounts[joke_id] = (hilariousCounts[joke_id] || 0) + 1;
    } else if (rating <= 2) {
      horribleCounts[joke_id] = (horribleCounts[joke_id] || 0) + 1;
    }
  }

  return { hilariousCounts, horribleCounts };
}

function rankTopN(counts, n) {
  return Object.entries(counts)
    .map(([jokeId, count]) => ({ joke_id: jokeId, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, n)
    .map((entry, index) => ({ ...entry, rank: index + 1 }));
}

async function saveRankings(monthId, hilarious, horrible) {
  await db.collection("weekly_rankings").doc(monthId).set({
    month_id: monthId,
    hilarious,
    horrible,
    computed_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}
```

---

## What NOT to Add

| Approach | Why Avoid |
|----------|-----------|
| **Push notifications for widget refresh** | Widgets cannot receive push notifications; overkill for daily jokes |
| **URLSession background downloads** | Designed for large file downloads, not small Firestore queries |
| **BGProcessingTask** | For CPU-intensive tasks; joke fetch is too lightweight |
| **Third-party scheduling libraries** | Native BGTaskScheduler is sufficient and better integrated |
| **Firebase Extensions for aggregation** | Custom logic needed; Cloud Functions more flexible |
| **Real-time listeners in widget** | Widgets can't maintain persistent connections |

---

## Alternatives Considered

### Widget Direct Network Fetch vs. App Background Refresh

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Widget fetches directly** | Works even if app never opens; simpler | Widget has limited runtime; can't access full FirestoreService | Use as fallback |
| **App background refresh** | Full app context; can update Siri cache too | Requires app to have run at least once | Primary approach |
| **Hybrid** | Best of both worlds | Slightly more complexity | **Recommended** |

**Recommendation:** Implement hybrid approach:
1. App background refresh as primary mechanism
2. Widget `TimelineProvider` falls back to direct fetch if shared data is stale (>24 hours)

### Cloud Functions vs. Firebase Scheduled Extensions

| Approach | Pros | Cons |
|----------|------|------|
| **Cloud Functions** | Full control; can customize aggregation logic | Requires Blaze plan; must maintain code |
| **Firebase Extensions** | No-code setup | Limited to predefined use cases; none fit rankings |

**Recommendation:** Cloud Functions - the aggregation logic is custom (hilarious/horrible categorization) and cannot be replicated with extensions.

---

## Migration Path from Local Cron

Current state: `scripts/aggregate-weekly-rankings.js` runs via manual cron

Migration steps:
1. Create `functions/` directory with Cloud Function
2. Deploy with `firebase deploy --only functions`
3. Verify function runs at scheduled time via Firebase Console
4. Remove local cron job and script from workflow

The existing script logic maps directly to the Cloud Function - same aggregation algorithm, same Firestore collections, same output format.

---

## Testing Strategy

### Background Task Testing

1. **Simulator debugging:**
   ```
   e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.bvanaski.MrFunnyJokes.refresh"]
   ```

2. **Device testing:**
   - Set `earliestBeginDate` to 1 minute for testing
   - Put app in background, wait
   - Check Console.app for task execution logs

### Cloud Function Testing

1. **Local emulator:**
   ```bash
   firebase emulators:start --only functions
   ```

2. **Manual trigger (Firebase Console):**
   - Functions > aggregateRankings > Test Function

3. **Verify Firestore:**
   - Check `weekly_rankings` collection for new document

---

## Sources

### Official Documentation (HIGH confidence)
- [Using background tasks to update your app](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app) - Apple Developer
- [Refreshing and Maintaining Your App Using Background Tasks](https://developer.apple.com/documentation/BackgroundTasks/refreshing-and-maintaining-your-app-using-background-tasks) - Apple Developer
- [Schedule functions | Cloud Functions for Firebase](https://firebase.google.com/docs/functions/schedule-functions) - Firebase
- [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) - Apple Developer
- [WidgetCenter](https://developer.apple.com/documentation/widgetkit/widgetcenter) - Apple Developer

### WWDC Sessions (HIGH confidence)
- [Efficiency awaits: Background tasks in SwiftUI - WWDC22](https://developer.apple.com/videos/play/wwdc2022/10142/)

### Technical Articles (MEDIUM confidence, verified against official docs)
- [Background tasks in SwiftUI | Swift with Majid](https://swiftwithmajid.com/2022/07/06/background-tasks-in-swiftui/)
- [How to Update or Refresh a Widget? - Swift Senpai](https://swiftsenpai.com/development/refreshing-widget/)
- [Don't rely on BGAppRefreshTask for your app's business logic](https://mertbulan.com/programming/dont-rely-on-bgapprefreshtask-for-your-apps-business-logic/)

### Firebase Documentation (HIGH confidence)
- [Firebase Pricing](https://firebase.google.com/pricing)
- [scheduler namespace | Cloud Functions for Firebase](https://firebase.google.com/docs/reference/functions/2nd-gen/node/firebase-functions.scheduler)

---

## Quality Gate Verification

- [x] Versions are current (BGTaskScheduler iOS 13+, Firebase Functions v2 latest)
- [x] Rationale explains WHY, not just WHAT
- [x] Integration with existing stack considered (App Groups, SharedStorageService, Firestore cache)
- [x] What NOT to add documented with reasons
- [x] Migration path from current state documented
- [x] Testing strategy included
- [x] Pricing implications noted (Blaze plan required, but minimal cost)

---

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| BGTaskScheduler | HIGH | Mature API (iOS 13+), well-documented, verified with Apple Developer docs |
| Widget refresh patterns | HIGH | Existing codebase uses TimelineProvider; patterns well-established |
| Firebase Cloud Functions v2 | HIGH | Official Firebase documentation, simple migration from existing script |
| Feed prioritization | HIGH | No stack changes; pure client-side logic with existing services |
| Background refresh reliability | MEDIUM | iOS system controls timing; cannot guarantee exact refresh times |

---

## Roadmap Implications

Based on this research, suggested phase structure for v1.0.1:

1. **Phase 1: Background Infrastructure**
   - Add BGTaskScheduler registration
   - Configure Info.plist and capabilities
   - Implement basic background refresh task
   - Test widget data update flow

2. **Phase 2: Widget Direct Fetch Fallback**
   - Add network fetch to TimelineProvider
   - Handle stale data detection (>24 hours)
   - Test offline/online scenarios

3. **Phase 3: Feed Prioritization**
   - Modify FirestoreService to accept exclusion list
   - Update JokeViewModel to filter rated jokes
   - Ensure full catalog background loading works

4. **Phase 4: Cloud Functions Deployment**
   - Set up functions/ directory
   - Deploy scheduled aggregation function
   - Verify execution in Firebase Console
   - Retire local cron job

**Phase ordering rationale:**
- Background infrastructure first: foundation for everything else
- Widget fallback second: ensures daily updates even without app usage
- Feed prioritization third: depends on background catalog loading
- Cloud functions last: independent of app code, can deploy anytime
