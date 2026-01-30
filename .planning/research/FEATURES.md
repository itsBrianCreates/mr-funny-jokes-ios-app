# Feature Landscape: Content Freshness (v1.0.1)

**Domain:** iOS content app with widgets
**Researched:** 2026-01-30
**Confidence:** HIGH (based on Apple documentation and established patterns)

---

## Context

This research focuses on content freshness features for an iOS joke app that already has:
- 6 widget types (3 home screen, 3 lock screen) showing Joke of the Day
- Joke feed with infinite scroll pagination (manual "Load More")
- User rating system with local persistence
- Monthly rankings (aggregated via local cron job)

**Problem:** Users see stale/repetitive content because updates require manual actions.

---

## Table Stakes

Features users expect from a content-focused iOS app. Missing any of these = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Existing? | Notes |
|---------|--------------|------------|-----------|-------|
| **Widget shows current content** | Widgets that show yesterday's joke feel broken | Medium | Partial | Currently requires app launch to update |
| **New content surfaced first** | Users expect to see things they haven't seen | Low | YES | `sortJokesForFreshFeed()` already implements unseen > seen unrated > rated |
| **Offline access to cached content** | iOS users expect apps to work offline | Low | YES | Firestore cache + LocalStorageService |
| **Content loads without friction** | Infinite scroll is standard in feed-based apps | Medium | Partial | Manual "Load More" button exists |

### Feature: Widget Background Refresh

**What:** Widgets display fresh Joke of the Day without requiring user to open the main app.

**Expected behavior:**
- Widget updates daily with new joke content
- User should see new joke each morning without any action
- Works even if user hasn't opened app in days

**Technical approach (from research):**

1. **WidgetKit Timeline with Network Fetch**
   - `getTimeline()` can make URLSession requests directly
   - Fetch new joke from Firebase, populate timeline entry
   - Use `.after(midnight)` policy for daily refresh

2. **Budget constraints:**
   - ~40-70 widget refreshes per day budget (system-managed)
   - Daily refresh only needs 1 refresh/day (well within budget)
   - Refresh not guaranteed at exact time; system schedules based on battery/network

3. **Implementation pattern:**
   ```swift
   func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
       Task {
           let joke = await fetchJokeOfTheDayFromServer() ?? loadCachedJoke()
           let entry = JokeEntry(date: Date(), joke: joke)
           let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
           let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
           completion(timeline)
       }
   }
   ```

**Complexity:** Medium
- Requires adding network fetch capability to widget extension
- Need to handle failure gracefully (fall back to cached)
- Shared storage already exists via App Groups

**Dependencies:**
- SharedStorageService (exists)
- App Group container (configured)
- Network reachability handling

**Source:** [Apple Developer Documentation - Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date), [Swift Senpai - Refreshing Widget](https://swiftsenpai.com/development/refreshing-widget/)

---

### Feature: Feed Content Prioritization

**What:** Feed automatically shows unrated jokes before already-rated ones.

**Expected behavior:**
- Fresh content appears at top of feed
- Content user has already rated pushed down
- Seen-but-unrated content in middle tier

**Current state:** Already implemented in `JokeViewModel.sortJokesForFreshFeed()`:
```swift
// Existing 3-tier prioritization:
// 1. Unseen jokes (no impression)
// 2. Seen but unrated jokes
// 3. Already rated jokes
// Shuffled within each tier for variety
```

**Complexity:** LOW (already done)

**Note:** This feature is table stakes but already complete. No additional work needed.

---

### Feature: Automatic Content Loading

**What:** Full joke catalog loads automatically without manual "Load More" taps.

**Expected behavior:**
- Feed scrolls infinitely without interruption
- Content preloads as user approaches end
- No visible loading spinners during normal scrolling

**Technical approaches:**

1. **Prefetching (recommended)**
   - Load next batch when user reaches threshold (e.g., 3 items from end)
   - Current implementation has `loadMoreIfNeeded(currentItem:)` but requires explicit trigger
   - Enhancement: Make it truly automatic

2. **Background preload on app launch**
   - Fetch all jokes (or large batch) during initial load
   - Cache locally for instant access
   - Trade-off: Higher initial bandwidth, but smoother UX

**Current state:** Manual "Load More" button exists. Need to:
- Convert to automatic preload trigger
- Remove visible button
- Ensure smooth UX with proper loading states

**Complexity:** Low
- Infrastructure exists (`loadMoreIfNeeded`)
- Remove button, trigger automatically on scroll threshold

**Dependencies:**
- Existing `JokeViewModel.loadMore()` method
- `FirestoreService.fetchMoreJokes()` pagination

---

## Differentiators

Features that go beyond expectations. Not missing = not broken, but having them = competitive advantage.

| Feature | Value Proposition | Complexity | Priority | Notes |
|---------|-------------------|------------|----------|-------|
| **Instant offline-first experience** | App feels fast even on slow networks | Medium | Should have | Cache-first pattern already exists |
| **Smart notification timing** | Daily notification with that day's actual joke | Low | Could have | Already implemented in NotificationManager |
| **Background data sync** | Catalog stays fresh without user action | High | Defer | iOS restrictions make this unreliable |
| **Cloud-based aggregation** | Rankings update automatically, no local cron | Medium | Must have | Firebase Cloud Functions |

### Feature: Cloud-Based Rankings Aggregation

**What:** Monthly rankings calculated automatically in the cloud, not via local cron job.

**Value proposition:**
- Runs reliably regardless of whether developer's machine is on
- Scales with user base
- Professional backend architecture

**Technical approach (Firebase Cloud Functions):**

1. **Scheduled function using `onSchedule`**
   ```javascript
   const { onSchedule } = require("firebase-functions/v2/scheduler");

   exports.aggregateMonthlyRankings = onSchedule("0 0 * * *", async (event) => {
     // Aggregate rating_events from past 30 days
     // Calculate top jokes by rating_sum / rating_count
     // Write to monthly_rankings collection
   });
   ```

2. **Cron syntax:** `0 0 * * *` = midnight daily (runs every day, aggregates rolling 30-day window)

3. **Pricing:**
   - Cloud Scheduler: $0.10/month per job (3 free per Google account)
   - Cloud Functions: Billed per invocation (minimal for daily job)
   - Firestore reads/writes for aggregation

**Complexity:** Medium
- Requires Firebase Cloud Functions setup (if not already)
- Migration from local cron job
- Testing scheduled function behavior

**Dependencies:**
- Firebase project on Blaze plan (pay-as-you-go)
- `rating_events` collection (exists)
- `weekly_rankings` collection (exists, possibly rename to `monthly_rankings`)

**Source:** [Firebase Cloud Functions Schedule Functions](https://firebase.google.com/docs/functions/schedule-functions)

---

### Feature: Widget Push Refresh (Silent Notifications)

**What:** Server can trigger widget refresh via silent push notification.

**Value proposition:**
- Immediate widget update when new Joke of the Day is published
- More control than relying on system-scheduled refreshes

**Technical approach:**
1. Send silent push notification with `"content-available": 1`
2. App receives notification in background
3. App calls `WidgetCenter.shared.reloadAllTimelines()`

**Complexity:** High
- Requires push notification infrastructure
- APNs certificate/key management
- Server-side push sending capability
- Not guaranteed to work (iOS may throttle)

**Priority:** Defer to v2
- Current daily refresh via timeline is sufficient
- Silent push adds complexity without proportional benefit

---

## Anti-Features

Features to explicitly NOT build. These are common mistakes in this domain.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Real-time widget updates** | iOS doesn't support it; budget would be exhausted in minutes | Daily refresh is sufficient for joke content |
| **Force-refresh on every app open** | Wastes battery, bandwidth, user patience | Cache-first, background refresh |
| **Complex feed algorithms** | Overkill for joke app; users don't need ML recommendations | Simple 3-tier prioritization (already implemented) |
| **Sync all content at launch** | Slow first launch, excessive bandwidth | Paginated fetch with local cache |
| **Interactive widget buttons for rating** | iOS 17+ required, adds complexity, not needed for 4.2.2 | Tap widget to open app for rating |
| **Background fetch every 15 minutes** | Battery drain, iOS will throttle app | Daily widget refresh sufficient |
| **Server-driven feed ordering** | Requires backend changes, latency | Client-side sorting from local data |

### Anti-Feature Detail: Aggressive Background Refresh

**What not to do:** Schedule BGAppRefreshTask to fetch new jokes every 15 minutes.

**Why it fails:**
- iOS 17+ aggressively limits background refresh
- If user doesn't open app regularly, iOS deprioritizes background tasks
- Low Power Mode disables background refresh entirely
- App can be flagged as "battery drainer" and restricted

**What to do instead:**
- Use WidgetKit timeline with daily refresh policy
- Rely on Firestore offline cache for feed content
- Accept that some staleness is okay for joke content

**Source:** [Apple Developer - Using background tasks to update your app](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app)

---

## Feature Dependencies

```
Widget Background Refresh
    |
    +---> SharedStorageService (exists)
    +---> App Groups container (configured)
    +---> Network fetch in widget extension (NEW)

Automatic Content Loading
    |
    +---> loadMoreIfNeeded (exists)
    +---> FirestoreService pagination (exists)
    +---> UI change: remove button (NEW)

Cloud Rankings Aggregation
    |
    +---> Firebase Blaze plan
    +---> Cloud Functions setup (NEW)
    +---> rating_events collection (exists)
```

---

## MVP Recommendation

For v1.0.1 milestone, prioritize:

### Must Have (Table Stakes)
1. **Widget Background Refresh** - Core complaint: widgets show stale jokes
   - Add network fetch to widget's `getTimeline()`
   - Daily refresh policy
   - Fallback to cached joke on network failure

2. **Automatic Feed Loading** - Remove manual "Load More" friction
   - Trigger automatic load at scroll threshold
   - Hide loading indicator in normal flow

### Should Have (Addresses Project Goals)
3. **Cloud Rankings Aggregation** - Remove dependency on local cron job
   - Firebase Cloud Function with daily schedule
   - Migrate from local script

### Defer to v1.1 or Later
- Widget push refresh (silent notifications)
- Background app refresh for feed content
- Any ML/recommendation features

---

## Implementation Complexity Summary

| Feature | Complexity | Effort Estimate | Risk |
|---------|------------|-----------------|------|
| Widget Background Refresh | Medium | 4-8 hours | Low - patterns well-documented |
| Automatic Feed Loading | Low | 2-4 hours | Very Low - infrastructure exists |
| Cloud Rankings Aggregation | Medium | 4-6 hours | Medium - Firebase Functions setup |

**Total estimated effort:** 10-18 hours for all v1.0.1 content freshness features.

---

## Sources

### Apple Documentation
- [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) - Official WidgetKit refresh guidance
- [TimelineReloadPolicy](https://developer.apple.com/documentation/widgetkit/timelinereloadpolicy) - `.after`, `.atEnd`, `.never` policies
- [Using background tasks to update your app](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app) - Background fetch limitations

### Firebase Documentation
- [Schedule functions](https://firebase.google.com/docs/functions/schedule-functions) - Cloud Functions cron jobs

### Community Resources
- [Swift Senpai - How to Update or Refresh a Widget](https://swiftsenpai.com/development/refreshing-widget/) - Practical refresh patterns
- [Swift Senpai - How to Fetch and Show Remote Data on a Widget](https://swiftsenpai.com/development/widget-load-remote-data/) - URLSession in widgets
- [Medium - Understanding the Limitations of Widgets Runtime](https://medium.com/@telawittig/understanding-the-limitations-of-widgets-runtime-in-ios-app-development-and-strategies-for-managing-a3bb018b9f5a) - Widget constraints
- [NN/g - Infinite Scrolling: When to Use It](https://www.nngroup.com/articles/infinite-scrolling-tips/) - UX best practices

---

*Researched: 2026-01-30 | Confidence: HIGH | Ready for requirements definition*
