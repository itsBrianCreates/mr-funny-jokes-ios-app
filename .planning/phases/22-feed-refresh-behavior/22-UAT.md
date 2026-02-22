---
status: diagnosed
phase: 22-feed-refresh-behavior
source: 22-01-SUMMARY.md
started: 2026-02-21T12:00:00Z
updated: 2026-02-21T12:10:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Rated Jokes Move to Bottom After Pull-to-Refresh
expected: Rate a joke in the feed, then pull to refresh. The rated joke should now appear at the bottom of the feed, while unrated jokes remain at the top sorted by popularity.
result: issue
reported: "when I rate a joke it jumps to the bottom. I'm not sure this is a good UX because maybe I close the sheet and want to share the joke but it's gone. when I pull to refresh or close the app and come back that rated joke should move to the bottom of the list"
severity: major

### 2. Rated Jokes Stay Visible (Not Hidden)
expected: After rating a joke, it should still be visible in the feed — just moved to the bottom. It should NOT disappear from the feed entirely.
result: pass

### 3. Feed Ordering Persists Across App Restart
expected: Rate a joke, close the app completely, then reopen it. The previously rated joke should still appear at the bottom of the feed without needing to pull-to-refresh first.
result: pass

### 4. Scroll-to-Top After Pull-to-Refresh
expected: Scroll partway down the feed, then pull to refresh. The feed should scroll back to the very top, showing the first unrated joke.
result: pass

### 5. Viewed Jokes Demote on Refresh
expected: Open a joke's detail sheet (without rating), close it, then pull to refresh. The viewed joke should move toward the bottom of the feed.
result: issue
reported: "if I click to view a joke and then I refresh the feed, that joke should move to the bottom. that FAILED"
severity: major

### 6. Feed Freshness — Unseen Jokes Surface on Refresh
expected: After scrolling through several jokes, pull to refresh. Unseen jokes should appear at the top, and previously seen jokes should move down.
result: issue
reported: "the top view jokes don't ever change if I don't click on them, rate them, pull to refresh, close the app and come back. the content feels stale. we need a better way to surface jokes that I have not seen yet"
severity: major

## Summary

total: 6
passed: 3
issues: 3
pending: 0
skipped: 0

## Gaps

- truth: "Rated jokes should only move to bottom on pull-to-refresh or app restart, not immediately on rating"
  status: failed
  reason: "User reported: when I rate a joke it jumps to the bottom immediately. Should stay in place until pull-to-refresh or app restart so user can still find it to share."
  severity: major
  test: 1
  root_cause: "filteredJokes is a computed property that immediately re-evaluates when rateJoke() mutates jokes[index].userRating. The unrated/rated separation in filteredJokes fires instantly on every @Published jokes mutation, causing the rated joke to jump to the bottom of the ForEach immediately."
  artifacts:
    - path: "MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift"
      issue: "filteredJokes computed property (lines 53-83) separates unrated/rated on every evaluation; rateJoke() (lines 807-865) mutates jokes[index].userRating immediately"
  missing:
    - "Track session-rated joke IDs so filteredJokes treats them as unrated for sorting purposes"
    - "Clear session-rated IDs only on pull-to-refresh (viewModel.refresh()) or app restart"
  debug_session: ""

- truth: "Viewed (detail sheet opened) jokes should demote on refresh"
  status: failed
  reason: "User reported: clicking to view a joke and then refreshing the feed does not move it to the bottom"
  severity: major
  test: 5
  root_cause: "filteredJokes only separates rated vs unrated. Opening the detail sheet (JokeCardView.showingSheet) does not mark the joke as 'viewed' in any way that affects sort order. markJokeImpression fires on onAppear (scroll into viewport) but filteredJokes ignores impression data entirely — it sorts purely by popularityScore."
  artifacts:
    - path: "MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift"
      issue: "filteredJokes (lines 53-83) sorts by popularityScore only, ignores impression/viewed state"
    - path: "MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift"
      issue: "Detail sheet open (line 81) does not notify ViewModel of 'viewed' state"
  missing:
    - "Track 'viewed' jokes (detail sheet opened) via a callback or notification"
    - "filteredJokes should demote viewed jokes on refresh (similar to rated jokes)"
  debug_session: ""

- truth: "Feed should surface unseen jokes after pull-to-refresh, demoting previously seen jokes"
  status: failed
  reason: "User reported: top jokes never change unless rated. Content feels stale."
  severity: major
  test: 6
  root_cause: "filteredJokes sorts by popularityScore within unrated/rated groups, completely ignoring impression data. sortJokesForFreshFeed() exists and already tiers unseen > seen-unrated > rated, but it's only used when setting the jokes array on load — filteredJokes re-sorts everything by popularityScore, defeating the freshness ordering."
  artifacts:
    - path: "MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift"
      issue: "filteredJokes (lines 67-69) sorts by popularityScore, overriding freshness tiers from sortJokesForFreshFeed"
    - path: "MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift"
      issue: "sortJokesForFreshFeed (line 260) has correct tiering but its order is destroyed by filteredJokes"
  missing:
    - "filteredJokes should tier by: unseen > seen-unrated > viewed/rated, with popularityScore as tiebreaker within each tier"
  debug_session: ""
