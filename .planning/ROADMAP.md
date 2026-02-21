# Roadmap: Mr. Funny Jokes

## Milestones

- ✅ **v1.0 MVP** — Phases 1-6 (shipped 2026-01-25)
- ✅ **v1.0.1 Content Freshness** — Phases 7-9 (shipped 2026-01-31)
- ✅ **v1.0.2 Bug Fixes** — Phase 10 (shipped 2026-02-02)
- ✅ **v1.0.3 Seasonal Content & Scroll Fix** — Phases 11-12 (shipped 2026-02-15)
- ✅ **v1.1.0 Rating Simplification, Save & Me Tab Rework** — Phases 13-18 (shipped 2026-02-21)

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

### 🚧 v1.1.0 Rating Simplification, Save & Me Tab Rework

**Milestone Goal:** Simplify rating to binary, introduce all-time rankings, decouple saving from rating, and redesign Me tab around saved jokes.

<details>
<summary>✅ Phases 13-16 (Rating & Top 10) — SHIPPED 2026-02-18</summary>

- [x] Phase 13: Data Migration & Cloud Function (2/2 plans) — completed 2026-02-18
- [x] Phase 14: Binary Rating UI (2/2 plans) — completed 2026-02-18
- [x] Phase 15: Me Tab Redesign (1/1 plan) — completed 2026-02-18
- [x] Phase 16: All-Time Leaderboard UI (1/1 plan) — completed 2026-02-18

</details>

#### Phase 17: Save System & Rating Decoupling — completed 2026-02-20
**Goal**: Users can save jokes independently of rating, and rating no longer drives the Me tab
**Depends on**: Phase 16 (binary rating system must exist)
**Requirements**: SAVE-01, SAVE-02, SAVE-03, SAVE-04, SAVE-05, RATE-01, RATE-02, RATE-03, MIGR-01
**Success Criteria** (what must be TRUE):
  1. ✓ User can tap a Save button in the joke detail sheet to save a joke without rating it
  2. ✓ Save button toggles between Save and Saved states, and saved state persists after closing and reopening the app
  3. ✓ Rating a joke does NOT cause it to appear in the Me tab -- only saving does
  4. ✓ Rating icon on joke cards still works, and the joke sheet still displays the user's existing rating
  5. ✓ All previously rated jokes appear as saved jokes after the first launch with the update (migration)
**Plans:** 2 plans

Plans:
- [x] 17-01-PLAN.md — Save persistence layer, Joke model extension, ViewModel save logic, migration
- [x] 17-02-PLAN.md — Save button in JokeDetailSheet, all call sites, MeView rewiring

#### Phase 18: Me Tab Saved Jokes — completed 2026-02-21
**Goal**: Me tab displays the user's saved joke collection with rating indicators
**Depends on**: Phase 17 (save storage and migration must exist)
**Requirements**: METB-01, METB-02, METB-03, METB-04
**Success Criteria** (what must be TRUE):
  1. ✓ Me tab shows saved jokes instead of rated jokes
  2. ✓ Saved jokes appear in newest-first order (most recently saved at top)
  3. ✓ Each saved joke row displays a Hilarious or Horrible indicator if the user rated that joke
  4. ✓ The Hilarious/Horrible segmented control is gone from the Me tab
**Plans:** 2 plans

Plans:
- [x] 18-01-PLAN.md — Add CompactRatingView rating indicator to MeView saved joke cards
- [x] 18-02-PLAN.md — Move Save button below divider, group with Copy/Share, apply blue tint (gap closure)

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

---

*Roadmap created: 2026-01-24*
*Last updated: 2026-02-21 — Phase 18 complete (all plans executed, verification passed)*
