---
phase: 09-widget-background-refresh
plan: 01
subsystem: widget
tags: [widget, firestore, rest-api, caching, ios]
completed: 2026-01-31
duration: ~5 min

dependency_graph:
  requires: []
  provides:
    - "WidgetDataFetcher: Firestore REST API fetch for widgets"
    - "SharedStorageService: Fallback jokes cache"
    - "SharedJokeOfTheDay: Updated placeholder message"
  affects:
    - "09-02-PLAN.md: Uses WidgetDataFetcher in JokeOfTheDayProvider"

tech_stack:
  added: []
  patterns:
    - "URLSession async/await for REST API"
    - "Firestore REST API (no SDK in widgets)"
    - "ET timezone consistency"

key_files:
  created:
    - MrFunnyJokes/JokeOfTheDayWidget/WidgetDataFetcher.swift
  modified:
    - MrFunnyJokes/Shared/SharedStorageService.swift
    - MrFunnyJokes/Shared/SharedJokeOfTheDay.swift
    - MrFunnyJokes/MrFunnyJokes.xcodeproj/project.pbxproj

decisions:
  - key: "firestore-rest-api"
    choice: "Use Firestore REST API with URLSession"
    why: "Avoids Firebase SDK deadlock issues in widget extensions (known issue #13070)"
  - key: "et-timezone"
    choice: "Use America/New_York timezone for date calculation"
    why: "Consistency with Cloud Functions JOTD selection"
  - key: "fallback-cache-size"
    choice: "Max 20 fallback jokes"
    why: "Balance between offline availability and storage"

metrics:
  tasks_completed: 3
  tasks_total: 3
  commits: 3
---

# Phase 09 Plan 01: Widget Data Infrastructure Summary

**One-liner:** URLSession-based Firestore REST fetcher + fallback cache for offline widget graceful degradation

## What Was Built

### 1. WidgetDataFetcher.swift (146 lines)
New file for widget extension that fetches JOTD directly from Firestore REST API:
- `fetchJokeOfTheDay()` async function returning `SharedJokeOfTheDay?`
- Two-step fetch: `daily_jokes/{date}` -> `jokes/{id}`
- Uses ET timezone for date calculation (consistent with Cloud Functions)
- Parses Firestore REST response format
- Splits joke text into setup/punchline using delimiters
- Graceful error handling (returns nil, never crashes)

**Key pattern:** No Firebase SDK imports - uses only Foundation and URLSession to avoid widget deadlock issues.

### 2. SharedStorageService Fallback Cache
Enhanced with new cache methods for widget offline fallback:
- `saveFallbackJokes(_ jokes:)` - Cache up to 20 JOTD entries
- `getRandomFallbackJoke()` - Get random joke when network unavailable
- `getFallbackJokeCount()` - Diagnostics for cache size

Separate from Siri cache to serve different purposes.

### 3. Updated Placeholder Message
Changed placeholder from "Loading jokes..." to "Open Mr. Funny Jokes to get started!" with empty punchline for clean single-line display.

Shown only when:
1. JOTD is stale (>24 hours old)
2. Network fetch fails
3. Fallback cache is empty (fresh install)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | d82788e | Add WidgetDataFetcher with Firestore REST API |
| 2 | 3366d2d | Add fallback jokes cache to SharedStorageService |
| 3 | b700657 | Update widget placeholder message |

## Verification Results

- Widget target: BUILD SUCCEEDED
- Main app target: BUILD SUCCEEDED
- WidgetDataFetcher contains: `firestore.googleapis.com`, `America/New_York`
- WidgetDataFetcher does NOT contain: `import FirebaseFirestore`
- SharedStorageService has: `fallbackJokesCache`, `saveFallbackJokes`, `getRandomFallbackJoke`
- SharedJokeOfTheDay has: "Open Mr. Funny Jokes to get started!"

## Deviations from Plan

None - plan executed exactly as written.

## Next Steps

Plan 09-02 will:
1. Update JokeOfTheDayProvider to use WidgetDataFetcher
2. Implement stale detection with ET timezone
3. Add fallback joke retrieval flow
4. Populate fallback cache from main app
5. Checkpoint for human verification of widget behavior
