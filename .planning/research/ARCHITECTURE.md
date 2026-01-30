# Architecture Research: v1.0.1 Content Freshness

**Project:** Mr. Funny Jokes iOS App
**Milestone:** v1.0.1 Content Freshness
**Researched:** 2026-01-30
**Confidence:** HIGH (verified with Apple documentation and existing codebase analysis)

## Executive Summary

The v1.0.1 milestone requires four architectural additions that integrate with the existing MVVM architecture:

1. **Background Widget Refresh** - New BGAppRefreshTask integration to update SharedStorageService
2. **Feed Prioritization** - Enhancement to JokeViewModel's sorting algorithm
3. **Background Joke Loading** - New background fetch mechanism in FirestoreService
4. **Cloud Functions** - New Firebase Cloud Functions to replace local aggregation script

All four features can be built incrementally without breaking changes to existing components.

## Current Architecture Overview

```
+------------------------------------------+
|              iOS App                      |
+------------------------------------------+
|  Views (SwiftUI)                         |
|    - JokeFeedView                        |
|    - JokeOfTheDayView                    |
|    - Widget Views (Extension)            |
+------------------------------------------+
|  ViewModels (@MainActor)                 |
|    - JokeViewModel (primary state)       |
|    - CharacterDetailViewModel            |
|    - MonthlyRankingsViewModel            |
+------------------------------------------+
|  Services (Singletons)                   |
|    - FirestoreService                    |
|    - LocalStorageService (UserDefaults)  |
|    - SharedStorageService (App Groups)   |
|    - NetworkMonitor                      |
|    - NotificationManager                 |
+------------------------------------------+
|  Widget Extension                        |
|    - JokeOfTheDayProvider               |
|    - Reads from SharedStorageService     |
+------------------------------------------+

           |
           v Firebase Firestore
+------------------------------------------+
|  Collections:                            |
|    - jokes                               |
|    - daily_jokes                         |
|    - rating_events                       |
|    - weekly_rankings                     |
+------------------------------------------+

           |
           v Local Scripts (Current)
+------------------------------------------+
|  scripts/aggregate-weekly-rankings.js    |
|    - Runs via local cron                 |
|    - Writes to weekly_rankings           |
+------------------------------------------+
```

## Feature 1: Background Widget Refresh

### Problem

Current widget update flow relies on the user opening the main app:

```
Current Flow:
App Launch -> JokeViewModel.fetchJokeOfTheDay() -> SharedStorageService.save() -> Widget Reads

Widget only gets new data when app is launched.
If user doesn't open app, widget shows stale joke for days.
```

### Solution Architecture

Use iOS `BGAppRefreshTask` to periodically update widget data without requiring app launch.

```
New Flow:
+------------------------------------------+
|  BGAppRefreshTask (System Scheduled)     |
|    - Registered at app launch            |
|    - System determines optimal run time  |
|    - 30 second execution limit           |
+------------------------------------------+
           |
           v
+------------------------------------------+
|  BackgroundRefreshService (NEW)          |
|    - Fetches daily_jokes from Firestore  |
|    - Updates SharedStorageService        |
|    - Reloads WidgetCenter timelines      |
|    - Reschedules next refresh task       |
+------------------------------------------+
           |
           v
+------------------------------------------+
|  SharedStorageService (EXISTING)         |
|    - saveJokeOfTheDay() called           |
|    - Widget reads fresh data             |
+------------------------------------------+
           |
           v
+------------------------------------------+
|  WidgetCenter.reloadTimelines()          |
|    - Forces widget to refresh            |
+------------------------------------------+
```

### Integration Points

| Existing Component | Modification Required |
|--------------------|----------------------|
| `MrFunnyJokesApp.swift` | Add background task registration in `init()` |
| `AppDelegate` | Add background task handler |
| `SharedStorageService` | No changes - already supports the operations |
| `FirestoreService` | No changes - `fetchJokeOfTheDay()` already exists |
| `Info.plist` | Add `BGTaskSchedulerPermittedIdentifiers` key |

### New Components

| Component | Purpose |
|-----------|---------|
| `BackgroundRefreshService.swift` | Orchestrates background refresh logic |

### Implementation Pattern (SwiftUI)

The SwiftUI `.backgroundTask` modifier provides a clean integration point:

```swift
// In MrFunnyJokesApp.swift
WindowGroup {
    RootView()
}
.backgroundTask(.appRefresh("com.bvanaski.mrfunnyjokes.widgetRefresh")) {
    await BackgroundRefreshService.shared.performRefresh()
}
```

### Key Constraints

- **30 second time limit** for BGAppRefreshTask execution
- **System determines scheduling** - cannot guarantee exact times
- **Battery optimization** - system may delay if device is low power
- **User can disable** - Background App Refresh toggle in iOS Settings

### Confidence: HIGH

Source: [Apple Developer Documentation - BGAppRefreshTask](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask)

---

## Feature 2: Feed Prioritization (Unrated Jokes First)

### Problem

Current feed sorting shows rated jokes prominently, causing users to see repetitive content.

### Current Implementation

```swift
// JokeViewModel.swift - sortJokesForFreshFeed()
// Already implements 3-tier sorting:
// 1. Unseen jokes (no impression)
// 2. Seen but unrated
// 3. Already rated
```

**Good news:** The existing `sortJokesForFreshFeed()` method already prioritizes unrated jokes. The issue is that it only runs on explicit refresh actions.

### Solution Architecture

Enhance the existing sorting to run automatically when returning to the feed:

```
+------------------------------------------+
|  JokeFeedView.onAppear                   |
|    - Triggers re-sort when tab selected  |
+------------------------------------------+
           |
           v
+------------------------------------------+
|  JokeViewModel                           |
|    - sortJokesForFreshFeed() (EXISTING)  |
|    - Add: resortFeedOnReturn() (NEW)     |
|    - Uses in-memory cache from           |
|      LocalStorageService                 |
+------------------------------------------+
           |
           v
+------------------------------------------+
|  LocalStorageService (EXISTING)          |
|    - getRatedJokeIdsFast() - already     |
|      provides cached rated joke IDs      |
|    - getImpressionIdsFast() - already    |
|      provides cached impression IDs      |
+------------------------------------------+
```

### Integration Points

| Existing Component | Modification Required |
|--------------------|----------------------|
| `JokeViewModel` | Add `resortFeedOnReturn()` method |
| `JokeFeedView` | Add `.onAppear` handler to call resort |
| `LocalStorageService` | No changes - memory cache already exists |

### No New Components Required

This feature is primarily a behavioral change to existing components.

### Confidence: HIGH

The existing infrastructure fully supports this. Implementation is straightforward.

---

## Feature 3: Background Joke Loading (Full Catalog)

### Problem

Users must manually tap "Load More" to fetch the full joke catalog. Many users miss content because they don't scroll far enough.

### Solution Architecture

Implement automatic background loading that fetches the complete catalog after initial display.

```
+------------------------------------------+
|  App Launch                              |
+------------------------------------------+
           |
           v
+------------------------------------------+
|  JokeViewModel.loadInitialContentAsync() |
|  (EXISTING - shows first batch quickly)  |
+------------------------------------------+
           |
           v (After initial batch displayed)
+------------------------------------------+
|  BackgroundCatalogLoader (NEW)           |
|    - Runs in background Task             |
|    - Fetches remaining jokes in batches  |
|    - Uses FirestoreService pagination    |
|    - Updates JokeViewModel.jokes[]       |
|    - Respects network conditions         |
+------------------------------------------+
           |
           v
+------------------------------------------+
|  FirestoreService (EXISTING)             |
|    - fetchMoreJokes() (existing)         |
|    - Pagination cursors work as-is       |
+------------------------------------------+
           |
           v
+------------------------------------------+
|  LocalStorageService (EXISTING)          |
|    - saveCachedJokes() for persistence   |
+------------------------------------------+
```

### Integration Points

| Existing Component | Modification Required |
|--------------------|----------------------|
| `JokeViewModel` | Add background loading task after initial load |
| `FirestoreService` | No changes - pagination already works |
| `LocalStorageService` | No changes - caching already works |
| `NetworkMonitor` | No changes - already provides connectivity status |

### Implementation Strategy

```swift
// In JokeViewModel.loadInitialContentAsync()
private func loadInitialContentAsync() async {
    // EXISTING: Load cached + first batch
    await existingLoadLogic()

    // NEW: Start background catalog load
    backgroundLoadTask = Task.detached(priority: .utility) {
        await self.loadRemainingCatalogInBackground()
    }
}

private func loadRemainingCatalogInBackground() async {
    while hasMoreJokes && !Task.isCancelled {
        // Respect network conditions
        guard networkMonitor.isConnected else {
            try? await Task.sleep(for: .seconds(30))
            continue
        }

        let newJokes = try? await firestoreService.fetchMoreJokes(limit: 50)
        // Process and add to jokes array
        // Small delay between batches to be gentle on resources
        try? await Task.sleep(for: .milliseconds(500))
    }
}
```

### Key Constraints

- Must not block main thread or impact UI responsiveness
- Should pause when app is backgrounded
- Should respect network conditions (pause on poor connectivity)
- Should use Firestore cache when available

### Confidence: HIGH

Existing pagination and caching infrastructure fully supports this pattern.

---

## Feature 4: Cloud Functions for Rankings

### Problem

Current rankings aggregation runs via local cron job (`scripts/aggregate-weekly-rankings.js`). This:
- Requires manual setup on developer machine
- Doesn't scale if multiple developers
- Won't run if machine is off

### Solution Architecture

Migrate aggregation logic to Firebase Cloud Functions with scheduled trigger.

```
+------------------------------------------+
|  Firebase Cloud Functions (2nd Gen)      |
+------------------------------------------+
|  functions/                              |
|    index.js                              |
|      - aggregateMonthlyRankings          |
|        (onSchedule trigger)              |
+------------------------------------------+
           |
           v (Scheduled: daily at 00:00 ET)
+------------------------------------------+
|  Cloud Scheduler Job                     |
|    - Created automatically by Firebase   |
|    - Triggers function on schedule       |
+------------------------------------------+
           |
           v
+------------------------------------------+
|  Function Logic                          |
|    - Query rating_events (30-day window) |
|    - Aggregate hilarious/horrible counts |
|    - Write to weekly_rankings collection |
+------------------------------------------+
```

### New Cloud Functions Project Structure

```
functions/
  package.json
  index.js
    - aggregateMonthlyRankings (scheduled function)
    - aggregateOnDemand (HTTP trigger for testing)
```

### Integration Points

| Existing Component | Modification Required |
|--------------------|----------------------|
| `scripts/aggregate-weekly-rankings.js` | Replace with Cloud Function (can keep as backup) |
| Firebase Project | Enable Cloud Functions, Cloud Scheduler APIs |
| `weekly_rankings` collection | No schema changes - same structure |
| `rating_events` collection | No schema changes - same structure |
| iOS App | No changes - reads from same collection |

### Implementation (Firebase Functions v2)

```javascript
// functions/index.js
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore } = require("firebase-admin/firestore");

// Run daily at midnight Eastern Time
exports.aggregateMonthlyRankings = onSchedule(
  {
    schedule: "0 0 * * *",
    timeZone: "America/New_York",
    retryCount: 3,
  },
  async (event) => {
    const db = getFirestore();

    // Get 30-day window
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Query rating_events from last 30 days
    const events = await db.collection("rating_events")
      .where("timestamp", ">=", thirtyDaysAgo)
      .get();

    // Aggregate hilarious (4-5) and horrible (1-2) counts
    // ... aggregation logic ...

    // Write to weekly_rankings
    const weekId = getCurrentWeekId();
    await db.collection("weekly_rankings")
      .doc(weekId)
      .set(rankings);
  }
);
```

### Deployment

```bash
# One-time setup
cd functions
npm install
firebase login
firebase init functions

# Deploy
firebase deploy --only functions
```

### Cost Considerations

- **Cloud Scheduler**: $0.10/month per job (first 3 free)
- **Cloud Functions**: Free tier covers most use cases (2M invocations/month)
- **Firestore reads**: Each aggregation reads rating_events (cost depends on volume)

### Confidence: HIGH

Source: [Firebase Cloud Functions - Schedule Functions](https://firebase.google.com/docs/functions/schedule-functions)

---

## Component Architecture Diagram (Post v1.0.1)

```
+====================================================+
|                    iOS App                          |
+====================================================+
|                                                    |
|  +----------------+    +------------------------+  |
|  |  App Launch    |    |  Background Tasks      |  |
|  |                |    |                        |  |
|  | MrFunnyJokesApp|--->| BackgroundRefreshSvc   |  |
|  | (register task)|    | (NEW - widget update)  |  |
|  +----------------+    +------------------------+  |
|                              |                     |
|  +----------------+          |                     |
|  |                |          |                     |
|  | JokeViewModel  |<---------+                     |
|  |                |                                |
|  | - Initial load |    +------------------------+  |
|  | - Background   |--->| BackgroundCatalogLoader|  |
|  |   catalog load |    | (NEW - full catalog)   |  |
|  | - Feed sorting |    +------------------------+  |
|  |   (ENHANCED)   |                                |
|  +----------------+                                |
|         |                                          |
|         v                                          |
|  +----------------+    +------------------------+  |
|  | FirestoreService    | LocalStorageService   |  |
|  | (UNCHANGED)    |    | (UNCHANGED)           |  |
|  +----------------+    +------------------------+  |
|         |                       |                  |
|         v                       v                  |
|  +----------------+    +------------------------+  |
|  |SharedStorageSvc|    | Widget Extension       |  |
|  | (UNCHANGED)    |--->| JokeOfTheDayProvider   |  |
|  +----------------+    | (UNCHANGED)            |  |
|                        +------------------------+  |
+====================================================+

             |
             v
+====================================================+
|              Firebase Backend                       |
+====================================================+
|                                                    |
|  +-----------------+    +------------------------+ |
|  | Firestore       |    | Cloud Functions (NEW)  | |
|  |                 |    |                        | |
|  | - jokes         |<---| aggregateMonthlyRankings|
|  | - daily_jokes   |    | (scheduled daily)      | |
|  | - rating_events |    +------------------------+ |
|  | - weekly_rankings                              | |
|  +-----------------+                              | |
|                                                    |
+====================================================+
```

---

## Build Order Recommendation

Based on dependencies and risk assessment:

### Phase 1: Cloud Functions (Backend First)
**Why first:** No iOS code changes, can test independently, replaces unreliable local cron.

1. Create `functions/` directory
2. Implement `aggregateMonthlyRankings` function
3. Test with dry-run/on-demand trigger
4. Deploy to production
5. Verify rankings update correctly
6. Disable local cron job

**Risk:** LOW - No impact on existing app

### Phase 2: Feed Prioritization
**Why second:** Small change, uses existing infrastructure, immediate UX improvement.

1. Add `resortFeedOnReturn()` to JokeViewModel
2. Add `.onAppear` handler to JokeFeedView
3. Test that rated jokes move to bottom on tab return
4. Verify performance (should be instant with memory cache)

**Risk:** LOW - Behavioral change only

### Phase 3: Background Joke Loading
**Why third:** Depends on existing pagination working correctly.

1. Add background task in JokeViewModel
2. Implement `loadRemainingCatalogInBackground()`
3. Add network condition checks
4. Test with different catalog sizes
5. Verify no memory issues with large catalogs

**Risk:** MEDIUM - Must verify memory usage with full catalog

### Phase 4: Background Widget Refresh
**Why last:** Most complex iOS integration, requires Info.plist changes.

1. Add `BGTaskSchedulerPermittedIdentifiers` to Info.plist
2. Create `BackgroundRefreshService`
3. Register task in MrFunnyJokesApp
4. Implement refresh logic
5. Test with simulated background launches
6. Verify widget updates without app launch

**Risk:** MEDIUM - Background task timing is unpredictable

---

## Testing Considerations

### Background Tasks (iOS)

Background tasks cannot be tested in Simulator. Must use:
- Physical device
- Xcode's "Simulate Background Fetch" (Debug menu)
- Console logs to verify execution

### Cloud Functions

- Use `firebase functions:shell` for local testing
- Deploy to staging project before production
- Monitor Cloud Functions logs in Firebase Console

---

## Sources

- [Apple Developer Documentation - BGAppRefreshTask](https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask)
- [Apple Developer Documentation - Background Tasks in SwiftUI](https://developer.apple.com/documentation/swiftui/backgroundtask/apprefresh(_:))
- [Apple WWDC 2022 - Efficiency awaits: Background tasks in SwiftUI](https://developer.apple.com/videos/play/wwdc2022/10142/)
- [Firebase Cloud Functions - Schedule Functions](https://firebase.google.com/docs/functions/schedule-functions)
- [Firebase Cloud Functions v2 Scheduler](https://firebase.google.com/docs/reference/functions/2nd-gen/node/firebase-functions.scheduler.scheduleoptions)
- [Apple Developer Forums - WidgetKit and Background App Refresh](https://developer.apple.com/forums/thread/659373)
- [Apple Developer Documentation - Making network requests in a widget extension](https://developer.apple.com/documentation/widgetkit/making-network-requests-in-a-widget-extension)
