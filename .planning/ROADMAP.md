# Roadmap: Mr. Funny Jokes

## Milestones

- ✅ **v1.0 MVP** — Phases 1-6 (shipped 2026-01-25)
- ✅ **v1.0.1 Content Freshness** — Phases 7-9 (shipped 2026-01-31)
- 📋 **v1.1 TBD** — Phases 10+ (planned)

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

### 📋 v1.1 TBD (Planned)

Define next milestone with `/gsd:new-milestone`

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

---

*Roadmap created: 2026-01-24*
*Last updated: 2026-01-31 — v1.0.1 milestone archived*
