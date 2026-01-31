# Requirements: Mr. Funny Jokes v1.0.1

**Defined:** 2026-01-30
**Core Value:** Users can instantly get a laugh from character-delivered jokes and share them with friends

## v1.0.1 Requirements

Requirements for Content Freshness release. Each maps to roadmap phases.

### Widget Freshness

- [ ] **WIDGET-01**: All 6 widgets display today's joke without user opening the app
- [ ] **WIDGET-02**: Widget content updates daily even if app hasn't been opened in days
- [ ] **WIDGET-03**: Widget shows graceful fallback message when data is stale (>3 days)

### Feed Experience

- [ ] **FEED-01**: Joke feed loads next page automatically at scroll threshold (infinite scroll)
- [ ] **FEED-02**: "Load More" button removed from feed UI
- [ ] **FEED-03**: Full joke catalog loads in background after initial display (enables proper sorting)
- [ ] **FEED-04**: Feed re-sorts to prioritize unrated jokes after background catalog load completes

### Backend Reliability

- [x] **RANK-01**: Monthly rankings aggregation runs automatically via Firebase Cloud Functions
- [x] **RANK-02**: Cloud function runs daily at midnight ET
- [x] **RANK-03**: Local cron job retired after cloud deployment verified

## v2+ Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhanced Widget Features

- **WIDGET-10**: Widget push refresh via silent notifications
- **WIDGET-11**: Interactive widget buttons (reveal punchline without opening app)
- **WIDGET-12**: Control Center widget for quick joke access

### Real-Time Updates

- **RT-01**: Push notifications when new jokes added
- **RT-02**: Real-time rankings updates

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Aggressive background refresh (every 15 min) | Battery drain - previously removed for this reason |
| Firebase Firestore in widget extension | Known deadlock issue (GitHub #13070) - use App Groups |
| ML-based feed recommendations | Overkill for joke app, simple sorting sufficient |
| Background full catalog sync | Battery risk - defer catalog loading to app foreground |
| Real-time widget updates | iOS budget (40-70/day) makes this impractical |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| WIDGET-01 | Phase 9 | Pending |
| WIDGET-02 | Phase 9 | Pending |
| WIDGET-03 | Phase 9 | Pending |
| FEED-01 | Phase 8 | Pending |
| FEED-02 | Phase 8 | Pending |
| FEED-03 | Phase 8 | Pending |
| FEED-04 | Phase 8 | Pending |
| RANK-01 | Phase 7 | Complete |
| RANK-02 | Phase 7 | Complete |
| RANK-03 | Phase 7 | Complete |

**Coverage:**
- v1.0.1 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-01-30*
*Last updated: 2026-01-30 after Phase 7 complete (RANK-01, RANK-02, RANK-03 satisfied)*
