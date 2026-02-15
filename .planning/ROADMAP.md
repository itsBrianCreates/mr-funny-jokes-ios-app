# Roadmap: Mr. Funny Jokes

## Milestones

- ✅ **v1.0 MVP** — Phases 1-6 (shipped 2026-01-25)
- ✅ **v1.0.1 Content Freshness** — Phases 7-9 (shipped 2026-01-31)
- ✅ **v1.0.2 Bug Fixes** — Phase 10 (shipped 2026-02-02)
- 🚧 **v1.0.3 Seasonal Content & Scroll Fix** — Phases 11-12 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-6) — SHIPPED 2026-01-25</summary>

### Phase 1: Foundation Cleanup
**Goal**: Clean existing codebase and establish baseline for native iOS integration
**Plans**: 2 plans

Plans:
- [x] 01-01: Codebase assessment and cleanup
- [x] 01-02: Widget architecture foundation

### Phase 2: Lock Screen Widgets
**Goal**: Add lock screen widget support for iOS 16+ compliance
**Plans**: 2 plans

Plans:
- [x] 02-01: Lock screen widget implementation
- [x] 02-02: Vibrant mode and circular widget fixes

### Phase 3: Siri Integration
**Goal**: Users can ask Siri for jokes via App Intents
**Plans**: 2 plans

Plans:
- [x] 03-01: App Intents implementation
- [x] 03-02: Siri visual snippets and offline caching

### Phase 4: Home Screen Widget Polish
**Goal**: All home screen widgets match native iOS spacing and styling
**Plans**: 2 plans

Plans:
- [x] 04-01: Widget spacing audit and fixes
- [x] 04-02: Widget content and typography polish

### Phase 5: Rankings & Notifications
**Goal**: Monthly rankings work correctly and notifications use native iOS patterns
**Plans**: 2 plans

Plans:
- [x] 05-01: Weekly to monthly rankings migration
- [x] 05-02: iOS Settings notification integration

### Phase 6: Content & Submission
**Goal**: App Store submission materials complete and app ready for review
**Plans**: 1 plan

Plans:
- [x] 06-01: App Store submission materials

</details>

<details>
<summary>✅ v1.0.1 Content Freshness (Phases 7-9) — SHIPPED 2026-01-31</summary>

### Phase 7: Cloud Functions Migration
**Goal**: Rankings aggregation runs automatically in cloud, eliminating manual cron dependency
**Plans**: 2 plans

Plans:
- [x] 07-01: Create Cloud Functions infrastructure and port aggregation logic
- [x] 07-02: Deploy to Firebase, verify execution, archive local scripts

### Phase 8: Feed Content Loading
**Goal**: Full joke catalog loads automatically in background, feed shows unrated jokes first
**Plans**: 2 plans

Plans:
- [x] 08-01: Infinite scroll infrastructure and remove Load More button
- [x] 08-02: Background catalog loading and unrated-only filtering

### Phase 9: Widget Background Refresh
**Goal**: All 6 widgets display fresh Joke of the Day without requiring app launch
**Plans**: 2 plans

Plans:
- [x] 09-01: Widget infrastructure (WidgetDataFetcher + fallback cache)
- [x] 09-02: Provider enhancement + main app wiring + verification

</details>

<details>
<summary>✅ v1.0.2 Bug Fixes (Phase 10) — SHIPPED 2026-02-02</summary>

### Phase 10: Bug Fixes & UX Polish
**Goal**: Fix Me tab persistence bug and add YouTube promo dismissal
**Requirements**: ME-01, ME-02, PROMO-01, PROMO-02, PROMO-03
**Plans**: 1 plan

Plans:
- [x] 10-01: Me tab rating persistence fix and YouTube promo dismissal

**Success Criteria:** All 5 verified

**Bonus fixes:** Me tab shows most recently rated first, PTR bounce-back fix

**Full details:** [milestones/v1.0.2-ROADMAP.md](milestones/v1.0.2-ROADMAP.md)

</details>

### 🚧 v1.0.3 Seasonal Content & Scroll Fix (In Progress)

**Milestone Goal:** Demote Christmas jokes outside their season and fix iOS 18 scrolling glitches.

- [x] **Phase 11: Seasonal Content Ranking** - Holiday jokes demoted to bottom of all feeds outside Nov 1 - Dec 31
- [ ] **Phase 12: Feed Scroll Stability** - Smooth, glitch-free scrolling in feed on iOS 18+

## Phase Details

### Phase 11: Seasonal Content Ranking
**Goal**: Holiday jokes appear at the bottom of feeds outside their season and rank normally during their season
**Depends on**: Nothing (independent of Phase 12)
**Requirements**: SEASON-01, SEASON-02, SEASON-03
**Success Criteria** (what must be TRUE):
  1. User scrolling the main feed in February sees Christmas/holiday jokes at the bottom, not mixed in with top-rated jokes
  2. User scrolling the main feed in December sees Christmas/holiday jokes ranked by popularity alongside all other jokes
  3. User browsing a character feed (e.g., Mr. Funny) in February sees holiday jokes demoted to the bottom
  4. User applying a category filter still sees seasonal demotion in effect outside the holiday window
**Plans**: 1 plan

Plans:
- [x] 11-01-PLAN.md — Seasonal helper utility and feed demotion logic

### Phase 12: Feed Scroll Stability
**Goal**: Feed scrolling is smooth and stable regardless of content loading or conditional UI elements
**Depends on**: Nothing (independent of Phase 11)
**Requirements**: SCROLL-01, SCROLL-02, SCROLL-03
**Success Criteria** (what must be TRUE):
  1. User can scroll upward from the bottom of a long feed without visible jumps or position glitches on iOS 18
  2. Feed scroll position remains stable when background content loading completes while user is mid-scroll
  3. Scrolling past conditional content (character carousel, JOTD card, promo card) produces no anchor shifts or stuttering
**Plans**: TBD

Plans:
- [ ] 12-01: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation Cleanup | v1.0 | 2/2 | Complete | 2026-01-24 |
| 2. Lock Screen Widgets | v1.0 | 2/2 | Complete | 2026-01-24 |
| 3. Siri Integration | v1.0 | 2/2 | Complete | 2026-01-24 |
| 4. Home Screen Widget Polish | v1.0 | 2/2 | Complete | 2026-01-25 |
| 5. Rankings & Notifications | v1.0 | 2/2 | Complete | 2026-01-25 |
| 6. Content & Submission | v1.0 | 1/1 | Complete | 2026-01-25 |
| 7. Cloud Functions Migration | v1.0.1 | 2/2 | Complete | 2026-01-30 |
| 8. Feed Content Loading | v1.0.1 | 2/2 | Complete | 2026-01-31 |
| 9. Widget Background Refresh | v1.0.1 | 2/2 | Complete | 2026-01-31 |
| 10. Bug Fixes & UX Polish | v1.0.2 | 1/1 | Complete | 2026-02-02 |
| 11. Seasonal Content Ranking | v1.0.3 | 1/1 | Complete | 2026-02-15 |
| 12. Feed Scroll Stability | v1.0.3 | 0/? | Not started | - |

---

*Roadmap created: 2026-01-24*
*Last updated: 2026-02-15 — Phase 11 complete*
