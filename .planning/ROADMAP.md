# Roadmap: Mr. Funny Jokes

## Milestones

- ✅ **v1.0 MVP** — Phases 1-6 (shipped 2026-01-25)
- ✅ **v1.0.1 Content Freshness** — Phases 7-9 (shipped 2026-01-31)
- ✅ **v1.0.2 Bug Fixes** — Phase 10 (shipped 2026-02-02)
- ✅ **v1.0.3 Seasonal Content & Scroll Fix** — Phases 11-12 (shipped 2026-02-15)
- ✅ **v1.1.0 Rating Simplification, Save & Me Tab Rework** — Phases 13-18 (shipped 2026-02-21)
- ✅ **v1.10 Firebase Analytics** — Phases 19-20 (shipped 2026-02-22)
- **v1.1.0 Bug Fixes** — Phases 21-22 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-6) — SHIPPED 2026-01-25</summary>

- [x] Phase 1: Foundation Cleanup (2/2 plans) — completed 2026-01-24
- [x] Phase 2: Lock Screen Widgets (2/2 plans) — completed 2026-01-24
- [x] Phase 3: Siri Integration (2/2 plans) — completed 2026-01-24
- [x] Phase 4: Home Screen Widget Polish (2/2 plans) — completed 2026-01-25
- [x] Phase 5: Rankings & Notifications (2/2 plans) — completed 2026-01-25
- [x] Phase 6: Content & Submission (1/1 plan) — completed 2026-01-25

</details>

<details>
<summary>✅ v1.0.1 Content Freshness (Phases 7-9) — SHIPPED 2026-01-31</summary>

- [x] Phase 7: Cloud Functions Migration (2/2 plans) — completed 2026-01-30
- [x] Phase 8: Feed Content Loading (2/2 plans) — completed 2026-01-31
- [x] Phase 9: Widget Background Refresh (2/2 plans) — completed 2026-01-31

</details>

<details>
<summary>✅ v1.0.2 Bug Fixes (Phase 10) — SHIPPED 2026-02-02</summary>

- [x] Phase 10: Bug Fixes & UX Polish (1/1 plan) — completed 2026-02-02

</details>

<details>
<summary>✅ v1.0.3 Seasonal Content & Scroll Fix (Phases 11-12) — SHIPPED 2026-02-15</summary>

- [x] Phase 11: Seasonal Content Ranking (1/1 plan) — completed 2026-02-15
- [x] Phase 12: Feed Scroll Stability (1/1 plan) — completed 2026-02-15

</details>

<details>
<summary>✅ v1.1.0 Rating Simplification, Save & Me Tab Rework (Phases 13-18) — SHIPPED 2026-02-21</summary>

- [x] Phase 13: Data Migration & Cloud Function (2/2 plans) — completed 2026-02-18
- [x] Phase 14: Binary Rating UI (2/2 plans) — completed 2026-02-18
- [x] Phase 15: Me Tab Redesign (1/1 plan) — completed 2026-02-18
- [x] Phase 16: All-Time Leaderboard UI (1/1 plan) — completed 2026-02-18
- [x] Phase 17: Save System & Rating Decoupling (2/2 plans) — completed 2026-02-20
- [x] Phase 18: Me Tab Saved Jokes (2/2 plans) — completed 2026-02-21

</details>

<details>
<summary>✅ v1.10 Firebase Analytics (Phases 19-20) — SHIPPED 2026-02-22</summary>

- [x] Phase 19: Analytics Foundation (1/1 plan) — completed 2026-02-21
- [x] Phase 20: Event Instrumentation (1/1 plan) — completed 2026-02-22

</details>

### v1.1.0 Bug Fixes (In Progress)

**Milestone Goal:** Fix app responsiveness on first launch, feed reordering after rating, and pull-to-refresh scroll behavior before App Store release.

- [ ] **Phase 21: First-Launch Responsiveness** — App responds immediately on cold start without force-quit workaround
- [ ] **Phase 22: Feed Refresh Behavior** — Pull-to-refresh reorders rated jokes and returns to top of feed

## Phase Details

### Phase 21: First-Launch Responsiveness
**Goal**: Users experience immediate responsiveness when tapping jokes, sharing, and navigating on the very first app launch
**Depends on**: Nothing (independent bug fix)
**Requirements**: PERF-01, PERF-02
**Success Criteria** (what must be TRUE):
  1. User can tap a joke card and see the detail sheet appear without perceptible delay on first launch
  2. User can tap Share/Copy in the detail sheet and get immediate response on first launch
  3. First launch and subsequent launches feel equally responsive — no force-quit needed to "wake up" the app
**Plans**: TBD

Plans:
- [ ] 21-01: TBD

### Phase 22: Feed Refresh Behavior
**Goal**: Pull-to-refresh correctly reorders the feed and scrolls to the top, with reordering persisting across app sessions
**Depends on**: Nothing (independent bug fix)
**Requirements**: FEED-01, FEED-02, FEED-03
**Success Criteria** (what must be TRUE):
  1. After rating a joke and pulling to refresh, rated jokes appear at the bottom of the feed and unrated jokes appear at the top
  2. After closing and reopening the app, previously rated jokes remain at the bottom of the feed (reordering persists)
  3. After pull-to-refresh completes, the feed scrolls back to the very top showing the first unrated joke
**Plans**: TBD

Plans:
- [ ] 22-01: TBD

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
| 12. Feed Scroll Stability | v1.0.3 | 1/1 | Complete | 2026-02-15 |
| 13. Data Migration & Cloud Function | v1.1.0 | 2/2 | Complete | 2026-02-18 |
| 14. Binary Rating UI | v1.1.0 | 2/2 | Complete | 2026-02-18 |
| 15. Me Tab Redesign | v1.1.0 | 1/1 | Complete | 2026-02-18 |
| 16. All-Time Leaderboard UI | v1.1.0 | 1/1 | Complete | 2026-02-18 |
| 17. Save System & Rating Decoupling | v1.1.0 | 2/2 | Complete | 2026-02-20 |
| 18. Me Tab Saved Jokes | v1.1.0 | 2/2 | Complete | 2026-02-21 |
| 19. Analytics Foundation | v1.10 | 1/1 | Complete | 2026-02-21 |
| 20. Event Instrumentation | v1.10 | 1/1 | Complete | 2026-02-22 |
| 21. First-Launch Responsiveness | v1.1.0 BF | 0/TBD | Not started | - |
| 22. Feed Refresh Behavior | v1.1.0 BF | 0/TBD | Not started | - |

---

*Roadmap created: 2026-01-24*
*Last updated: 2026-02-22 — v1.1.0 Bug Fixes milestone roadmap created*
