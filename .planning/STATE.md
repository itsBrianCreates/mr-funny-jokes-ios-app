# Project State: Mr. Funny Jokes

## Current Position

**Milestone:** v1.0.3 — Seasonal Content & Scroll Fix
**Phase:** 12 of 12 (Feed Scroll Stability) -- COMPLETE
**Plan:** 1 of 1 complete
**Status:** All phases complete, milestone ready for completion

Last activity: 2026-02-15 — Phase 12 Plan 01 executed (feed scroll stability)

Progress: [██████████] 100%

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-15)

**Core value:** Users can instantly get a laugh from character-delivered jokes and share them with friends
**Current focus:** v1.0.3 — Seasonal content ranking and scroll stability

## Shipped Milestones

| Version | Name | Phases | Shipped |
|---------|------|--------|---------|
| v1.0 | MVP | 1-6 | 2026-01-25 |
| v1.0.1 | Content Freshness | 7-9 | 2026-01-31 |
| v1.0.2 | Bug Fixes & UX Polish | 10 | 2026-02-02 |

## Performance Metrics

**Velocity:**
- Total plans completed: 19
- Average duration: ~42 min
- Total execution time: ~13 hours

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 11 | 01 | 4min | 2 | 4 |
| 12 | 01 | 6min | 2 | 6 |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Recent decisions (full log in PROJECT.md):

- [v1.0.3-P12]: Move YouTube promo card outside ForEach as standalone LazyVStack item
- [v1.0.3-P12]: Use withAnimation at mutation sites instead of .animation() on scroll containers
- [v1.0.3-P12]: Pattern: scoped withAnimation over implicit .animation() for scroll stability
- [v1.0.3-P11]: Christmas season = Nov 1 through Dec 31 using device local calendar
- [v1.0.3-P11]: Only "christmas" tag triggers demotion -- "holidays" tag not affected
- [v1.0.3-P11]: Seasonal demotion at filteredJokes level, not in sortJokesForFreshFeed
- [v1.0.2]: Explicit rating re-application in loadInitialContentAsync — consistency with all other load paths
- [v1.0.2]: @AppStorage for promo dismissal — simple persistent state without extra infrastructure
- [v1.0.2]: Rating timestamps for Me tab sorting — most recently rated jokes appear first

### Codebase Notes (v1.0.3)

- Christmas jokes identified by `tags: ["christmas"]` -- demoted outside Nov 1 - Dec 31 via SeasonalHelper
- SeasonalHelper.swift provides isChristmasSeason() and Joke.isChristmasJoke
- Sorting by `popularityScore` descending in filteredJokes, with seasonal partition-and-append
- Client-side category filtering + seasonal demotion both applied in filteredJokes
- Feed uses ScrollView + LazyVStack with stable ForEach(feedJokes) identity
- Scoped withAnimation for isLoadingMore/isOffline transitions in ViewModels
- YouTube promo card is standalone LazyVStack item (not inside ForEach)
- Same scroll stability pattern applied to CharacterDetailView

### Open Items

- Remove local crontab entry (user action: `crontab -e` to remove aggregation line)
- Physical device overnight test for widget background refresh
- Consider automating daily_jokes population via Cloud Function

### Tech Debt

- Collection named "weekly_rankings" but UI shows "Monthly" (cosmetic)
- Firebase bundle ID warning in Xcode (informational only)

## Session Continuity

**Last session:** 2026-02-15
**Stopped at:** Completed 12-01-PLAN.md (Feed Scroll Stability)
**Resume file:** None

**Next steps:** `/gsd:complete-milestone` to wrap v1.0.3

---

*State initialized: 2026-01-24*
*Last updated: 2026-02-15 after Phase 12 Plan 01 complete*
