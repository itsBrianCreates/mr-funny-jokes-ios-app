---
phase: 22-feed-refresh-behavior
plan: 02
verified: 2026-02-22T05:49:42Z
status: passed
score: 6/6 must-haves verified
re_verification:
  previous_status: passed
  previous_score: 3/3
  previous_plan: 22-01
  gaps_closed:
    - "Rated jokes stay in position until pull-to-refresh (session-deferred reorder via sessionRatedJokeIds)"
    - "Viewed jokes (detail sheet opened) demote on next refresh via markJokeViewed() and impression tracking"
    - "Feed surfaces unseen jokes at top using impression-tiered filteredJokes (unseen > seen-unrated > rated)"
  gaps_remaining: []
  regressions: []
---

# Phase 22 Plan 02: Feed Refresh Behavior Verification Report

**Phase Goal:** Pull-to-refresh correctly reorders the feed and scrolls to the top, with rated jokes staying in place until refresh
**Plan:** 22-02 (gap closure — impression-tiered feed, session-deferred reordering, onView callback)
**Verified:** 2026-02-22T05:49:42Z
**Status:** PASSED
**Re-verification:** Yes — closes 3 UAT gaps from 22-01

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | After rating a joke, it stays in its current position in the feed until pull-to-refresh or app restart | VERIFIED | `sessionRatedJokeIds.insert(sessionKey)` at line 877 of JokeViewModel.swift. `filteredJokes` (line 78) checks `sessionRatedJokeIds.contains(key)` and sets `effectivelyRated = joke.userRating != nil && !isSessionRated`, so session-rated jokes bypass the `rated` tier and remain in their current tier (unseen or seen-unrated). |
| 2 | After pull-to-refresh, session-rated jokes move to the bottom of the feed | VERIFIED | `refresh()` at line 612 calls `sessionRatedJokeIds.removeAll()`. On next `filteredJokes` evaluation, those jokes have `userRating != nil` and `isSessionRated = false`, so `effectivelyRated = true` and they drop to the `rated` tier. |
| 3 | After app restart, previously-rated jokes appear at bottom via persisted ratings | VERIFIED | `sessionRatedJokeIds` is an in-memory `Set<String>` (line 50), cleared on init. `filteredJokes` uses `ratedIds = cachedRatedIds ?? storage.getRatedJokeIdsFast()` (line 70) for persisted-rating lookup. On app restart, `isSessionRated = false` for all jokes, so `persistedRated = ratedIds.contains(key)` correctly places them in the `rated` tier from the start. |
| 4 | Opening a joke detail sheet and then pulling to refresh demotes that joke below unseen jokes | VERIFIED | `JokeCardView` fires `onView()` on button tap (line 47). `JokeFeedView` wires `onView: { viewModel.markJokeViewed(joke) }` (line 113). `markJokeViewed()` at line 340-343 calls `storage.markImpression(firestoreId: joke.firestoreId)` and `invalidateSortCache()`. On next `filteredJokes` evaluation after refresh, `hasImpression = true` for the viewed joke, so it moves to `seenUnrated` tier (below unseen jokes). |
| 5 | After pull-to-refresh, unseen jokes appear at the top of the feed and previously seen jokes move down | VERIFIED | `filteredJokes` tiers: unseen (`!hasImpression`) → `sortedUnseen`, seen-unrated (`hasImpression && !effectivelyRated && !persistedRated`) → `sortedSeenUnrated`, rated → `sortedRated`. Combined as `sortedUnseen + sortedSeenUnrated + sortedRated` (line 102). Impression data from `storage.getImpressionIdsFast()` persists across sessions, so scroll-viewport-seen jokes are correctly tiered below unseen ones after any refresh. |
| 6 | Within each freshness tier, jokes are sorted by popularityScore (not randomly shuffled) | VERIFIED | Lines 97-99: `unseen.sorted { $0.popularityScore > $1.popularityScore }`, `seenUnrated.sorted { ... }`, `rated.sorted { ... }`. No shuffle in `filteredJokes`. `sortJokesForFreshFeed()` (used for initial load array assignment) is unchanged and still shuffles, but that does not affect `filteredJokes` ordering. |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` | Impression-tiered filteredJokes with sessionRatedJokeIds and viewed-joke tracking | VERIFIED | `sessionRatedJokeIds` at line 50; `filteredJokes` rewrite at lines 57-113; `markJokeViewed()` at lines 338-343; `rateJoke()` inserts/removes session key at lines 864-877; `refresh()` clears at line 612. |
| `MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift` | onView callback triggered when detail sheet opens | VERIFIED | `let onView: () -> Void` at line 10. Button action at lines 44-48: `showingSheet = true` then `onView()`. All 4 preview instances include `onView: {}`. |
| `MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift` | onView wired to viewModel.markJokeViewed | VERIFIED | Line 113: `onView: { viewModel.markJokeViewed(joke) }` inside `ForEach(feedJokes)` JokeCardView initializer. |
| `MrFunnyJokes/MrFunnyJokes/Views/SearchView.swift` | onView no-op closure to satisfy new JokeCardView parameter | VERIFIED | Line 139: `onView: {}` in the SearchView JokeCardView initializer. Search results correctly exclude from freshness tracking. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `filteredJokes` | `storage.getImpressionIdsFast()` | `impressionIds = cachedImpressionIds ?? storage.getImpressionIdsFast()` at line 69 | WIRED | Confirmed at line 69. `cachedImpressionIds` is invalidated by `invalidateSortCache()` (called from `markJokeImpression`, `markJokeViewed`, `rateJoke`, `handleRatingNotification`). `LocalStorageService.getImpressionIdsFast()` confirmed to exist at line 450 of LocalStorageService.swift. |
| `filteredJokes` | `sessionRatedJokeIds` | `sessionRatedJokeIds.contains(key)` at line 78 | WIRED | Confirmed at line 78. Session-rated jokes have `effectivelyRated = false`, keeping them in unseen or seenUnrated tier until refresh. |
| `rateJoke()` | `sessionRatedJokeIds` | `sessionRatedJokeIds.insert(sessionKey)` on non-zero rating | WIRED | Confirmed at line 877 (insert on rating), line 865 (remove on un-rating). |
| `refresh()` | `sessionRatedJokeIds` | `sessionRatedJokeIds.removeAll()` | WIRED | Confirmed at line 612. Runs before Firestore fetch, ensuring next `filteredJokes` evaluation reorders all rated jokes. |
| `JokeCardView.showingSheet` | `onView` callback | Button action at lines 44-48: `showingSheet = true; onView()` | WIRED | Confirmed at lines 46-47 of JokeCardView.swift. `onView()` fires immediately when detail sheet is triggered. |
| `JokeFeedView ForEach` | `viewModel.markJokeViewed` | `onView: { viewModel.markJokeViewed(joke) }` passed to JokeCardView | WIRED | Confirmed at line 113 of JokeFeedView.swift. |

### Commit Verification

| Commit | Description | Status |
|--------|-------------|--------|
| `517320f` | `feat(22-02): rewrite filteredJokes with impression-based tiering and session-deferred reordering` | VALID — 1 file changed, 52 insertions, 8 deletions in JokeViewModel.swift |
| `b605ef4` | `feat(22-02): wire onView callback from JokeCardView through JokeFeedView to ViewModel` | VALID — 3 files changed, 14 insertions, 6 deletions |

### Requirements Coverage

| Requirement | Status | Notes |
|-------------|--------|-------|
| After rating a joke and pulling to refresh, rated jokes appear at the bottom and unrated at the top | SATISFIED | Deferred via sessionRatedJokeIds; cleared on refresh(); filteredJokes places rated tier at bottom |
| After closing and reopening the app, previously rated jokes remain at the bottom | SATISFIED | sessionRatedJokeIds is in-memory (empty on restart); persisted ratings from getRatedJokeIdsFast() handle rehydration |
| After pull-to-refresh, the feed scrolls to the very top | SATISFIED | Preserved from 22-01: JokeFeedView .refreshable block calls proxy.scrollTo(topAnchorID, anchor: .top) after refresh |
| Rated jokes stay in their current feed position until pull-to-refresh or app restart | SATISFIED | Core mechanic of 22-02: sessionRatedJokeIds.contains() in filteredJokes prevents immediate reorder |
| Viewed jokes (detail sheet opened) demote below unseen jokes on next refresh | SATISFIED | markJokeViewed() -> storage.markImpression() marks joke as seen; filteredJokes tiers by impression data |
| Feed surfaces unseen jokes at top after pull-to-refresh | SATISFIED | filteredJokes 3-tier system: unseen (no impression) at top, seen-unrated in middle, rated at bottom |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | — |

No TODOs, FIXMEs, placeholder implementations, empty handlers, or stub returns detected in any of the 4 modified files.

### Notable Design Correctness Check

One subtle correctness risk: `invalidateSortCache()` is called at the top of `rateJoke()` (line 851), BEFORE `sessionRatedJokeIds.insert(sessionKey)` at line 877. This means when `filteredJokes` next evaluates, `cachedRatedIds` is nil, so it re-reads `getRatedJokeIdsFast()` from storage — which will include the newly-persisted rating (line 875 saves it to storage). However, because `sessionRatedJokeIds.insert(sessionKey)` runs at line 877 (as part of the same synchronous `rateJoke()` call, before any UI re-render), by the time SwiftUI re-evaluates `filteredJokes` in response to the `@Published jokes` mutation, `sessionRatedJokeIds` already contains the key. The session guard correctly overrides the persisted rating lookup. The ordering is safe.

### Human Verification Required

The following behaviors cannot be verified programmatically and require human testing:

#### 1. Deferred reorder — rated joke stays in place during session

**Test:** Rate a joke (1 or 5 stars). Without pulling to refresh, observe its position in the feed.
**Expected:** The rated joke remains at its current scroll position. It does NOT jump to the bottom.
**Why human:** Requires observing runtime UI state; `filteredJokes` re-evaluation timing cannot be asserted statically.

#### 2. Reorder on pull-to-refresh

**Test:** Rate a joke, note its position, then pull to refresh.
**Expected:** After the refresh spinner dismisses, the previously-rated joke now appears at the very bottom of the feed, and the feed scrolls to the top.
**Why human:** Requires observing actual UI transition at runtime.

#### 3. Viewed-joke demotion on refresh

**Test:** Tap a joke card to open its detail sheet (without rating it). Close the sheet. Pull to refresh.
**Expected:** The viewed joke appears below unviewed jokes that have similar popularityScores. It is not at the absolute top.
**Why human:** Requires runtime observation of impression-based reordering. The "below unseen" behavior depends on how many unseen jokes exist in the local cache.

#### 4. Feed freshness — unseen jokes surface

**Test:** Scroll through 10+ jokes (triggering onAppear impressions), then pull to refresh.
**Expected:** The jokes that appeared in the viewport during scrolling move to the middle tier (seen-unrated), and any jokes not yet scrolled into view rise to the top.
**Why human:** Requires runtime observation of viewport-tracking impressions and feed reorder.

#### 5. App restart persistence

**Test:** Rate a joke, force-quit the app, reopen it.
**Expected:** The rated joke appears at the bottom of the feed from the very first load (no refresh needed).
**Why human:** Requires observing actual app lifecycle behavior.

### Gaps Summary

No gaps. All 6 observable truths from the 22-02 plan are verified against actual code. The 3 UAT gaps identified in 22-UAT.md (immediate rating jump, viewed-joke demotion, feed staleness) are addressed by substantive, wired implementations:

- Gap 1 (immediate jump): closed by `sessionRatedJokeIds` in `filteredJokes` and `rateJoke()`
- Gap 2 (viewed-joke demotion): closed by `markJokeViewed()` + `onView` callback chain through JokeCardView and JokeFeedView
- Gap 3 (feed staleness): closed by impression-tiered `filteredJokes` (unseen > seen-unrated > rated)

All 4 modified files compile (both task commits exist and are valid). No regressions detected in category filtering (Step 1 of filteredJokes), seasonal demotion (Step 5), infinite scroll (onAppear/loadMoreIfNeeded unchanged), or scroll-to-top (JokeFeedView .refreshable block preserved from 22-01).

---

_Verified: 2026-02-22T05:49:42Z_
_Verifier: Claude (gsd-verifier)_
