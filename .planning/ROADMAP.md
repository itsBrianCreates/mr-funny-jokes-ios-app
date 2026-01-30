# Roadmap: Mr. Funny Jokes

## Milestones

- ✅ **v1.0 MVP** - Phases 1-6 (shipped 2026-01-25)
- 🚧 **v1.0.1 Content Freshness** - Phases 7-9 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 1-6) - SHIPPED 2026-01-25</summary>

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

### 🚧 v1.0.1 Content Freshness (In Progress)

**Milestone Goal:** Widgets stay fresh without app launch, feed prioritizes unrated jokes, backend runs in cloud.

#### Phase 7: Cloud Functions Migration
**Goal**: Rankings aggregation runs automatically in cloud, eliminating manual cron dependency
**Depends on**: Nothing (backend-only, no iOS changes)
**Requirements**: RANK-01, RANK-02, RANK-03
**Success Criteria** (what must be TRUE):
  1. Monthly rankings aggregation runs daily at midnight ET without manual intervention
  2. Cloud function logs visible in Firebase Console showing successful runs
  3. Local cron job script retired (moved to archive or deleted)
  4. Rankings data in Firestore matches expected aggregation logic
**Plans**: 2 plans

Plans:
- [ ] 07-01-PLAN.md — Create Cloud Functions infrastructure and port aggregation logic
- [ ] 07-02-PLAN.md — Deploy to Firebase, verify execution, archive local scripts

#### Phase 8: Feed Content Loading
**Goal**: Full joke catalog loads automatically in background, feed shows unrated jokes first
**Depends on**: Nothing (independent of Phase 7)
**Requirements**: FEED-01, FEED-02, FEED-03, FEED-04
**Success Criteria** (what must be TRUE):
  1. User scrolling feed reaches next page automatically at threshold (no tap required)
  2. "Load More" button no longer appears in feed UI
  3. Full joke catalog available for sorting after background load completes
  4. When returning to feed tab, unrated jokes appear before already-rated jokes
**Plans**: TBD

Plans:
- [ ] 08-01: TBD

#### Phase 9: Widget Background Refresh
**Goal**: All 6 widgets display fresh Joke of the Day without requiring app launch
**Depends on**: Phase 8 (validates background operation patterns)
**Requirements**: WIDGET-01, WIDGET-02, WIDGET-03
**Success Criteria** (what must be TRUE):
  1. Home screen widgets (small, medium, large) show today's joke after overnight period without app launch
  2. Lock screen widgets (circular, rectangular, inline) show today's joke after overnight period without app launch
  3. Widgets update daily even if app hasn't been opened in 3+ days
  4. When data is stale (>3 days), widget shows graceful fallback message
**Plans**: TBD

Plans:
- [ ] 09-01: TBD

## Progress

**Execution Order:**
Phases 7 and 8 can run in parallel. Phase 9 should follow Phase 8.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation Cleanup | v1.0 | 2/2 | Complete | 2026-01-24 |
| 2. Lock Screen Widgets | v1.0 | 2/2 | Complete | 2026-01-24 |
| 3. Siri Integration | v1.0 | 2/2 | Complete | 2026-01-24 |
| 4. Home Screen Widget Polish | v1.0 | 2/2 | Complete | 2026-01-25 |
| 5. Rankings & Notifications | v1.0 | 2/2 | Complete | 2026-01-25 |
| 6. Content & Submission | v1.0 | 1/1 | Complete | 2026-01-25 |
| 7. Cloud Functions Migration | v1.0.1 | 0/2 | Ready | - |
| 8. Feed Content Loading | v1.0.1 | 0/? | Not started | - |
| 9. Widget Background Refresh | v1.0.1 | 0/? | Not started | - |

---

*Roadmap created: 2026-01-24*
*Last updated: 2026-01-30 after Phase 7 planning complete*
