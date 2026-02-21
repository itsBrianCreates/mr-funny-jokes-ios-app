# Roadmap: Mr. Funny Jokes

## Milestones

- ✅ **v1.0 MVP** — Phases 1-6 (shipped 2026-01-25)
- ✅ **v1.0.1 Content Freshness** — Phases 7-9 (shipped 2026-01-31)
- ✅ **v1.0.2 Bug Fixes** — Phase 10 (shipped 2026-02-02)
- ✅ **v1.0.3 Seasonal Content & Scroll Fix** — Phases 11-12 (shipped 2026-02-15)
- ✅ **v1.1.0 Rating Simplification, Save & Me Tab Rework** — Phases 13-18 (shipped 2026-02-21)
- 🚧 **v1.10 Firebase Analytics** — Phases 19-20 (in progress)

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

### 🚧 v1.10 Firebase Analytics (In Progress)

**Milestone Goal:** Integrate Firebase Analytics to track key user actions with lightweight instrumentation of core interactions.

- [x] **Phase 19: Analytics Foundation** — Firebase Analytics dependency, configuration, and AnalyticsService singleton — completed 2026-02-21
- [ ] **Phase 20: Event Instrumentation** — Wire analytics events into joke rating, sharing, and character selection flows

## Phase Details

### Phase 19: Analytics Foundation
**Goal**: App initializes Firebase Analytics on launch with a service layer ready to log events
**Depends on**: Nothing (first phase of milestone)
**Requirements**: SETUP-01, SETUP-02, SETUP-03, SRVC-01, SRVC-02
**Success Criteria** (what must be TRUE):
  1. App builds and runs with FirebaseAnalytics SPM product linked to the app target
  2. Firebase Analytics auto-initializes on app launch via existing FirebaseApp.configure() — no additional setup code required
  3. AnalyticsService.shared singleton exists following the same pattern as FirestoreService.shared and other existing services
  4. AnalyticsService exposes methods that call Analytics.logEvent() with descriptive event names and minimal parameters
**Plans**: 1 plan

Plans:
- [x] 19-01-PLAN.md — Add FirebaseAnalytics SPM dependency, enable analytics in plist, create AnalyticsService singleton — completed 2026-02-21

### Phase 20: Event Instrumentation
**Goal**: Key user actions (rating, sharing, character selection) produce analytics events visible in Firebase
**Depends on**: Phase 19
**Requirements**: EVNT-01, EVNT-02, EVNT-03
**Success Criteria** (what must be TRUE):
  1. Rating a joke as Hilarious or Horrible logs an event with the joke ID, character name, and rating value
  2. Copying or sharing a joke logs an event with the joke ID
  3. Selecting a character from the home screen logs an event with the character ID
  4. Events appear in Firebase Analytics Debug View when running with the -FIRAnalyticsDebugEnabled launch argument
**Plans**: TBD

Plans:
- [ ] 20-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 19 → 20

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
| 20. Event Instrumentation | v1.10 | 0/TBD | Not started | - |

---

*Roadmap created: 2026-01-24*
*Last updated: 2026-02-21 — Phase 19 (Analytics Foundation) complete*
