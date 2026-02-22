# Requirements: Mr. Funny Jokes

**Defined:** 2026-02-22
**Core Value:** Users can instantly get a laugh from character-delivered jokes and share them with friends

## v1.1.0 Requirements

Requirements for bug fixes before App Store release. Each maps to roadmap phases.

### Performance

- [ ] **PERF-01**: App responds to taps (joke detail, share) within normal speed on first launch — no force-quit required
- [ ] **PERF-02**: First-launch experience feels as responsive as subsequent launches

### Feed

- [ ] **FEED-01**: After pull-to-refresh, rated jokes move to the bottom and unrated jokes appear at the top
- [ ] **FEED-02**: Feed reordering works consistently after app close and reopen
- [ ] **FEED-03**: Pull-to-refresh scrolls the feed back to the top after refreshing

## Future Requirements

### Extended Analytics

- **EANL-01**: Track search queries and results count
- **EANL-02**: Track joke save/unsave actions
- **EANL-03**: Track widget taps and deep link opens
- **EANL-04**: Track Siri intent usage
- **EANL-05**: Firebase Analytics dashboard with custom events in Firebase Console

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full performance profiling/optimization | Only fixing first-launch lag — broader optimization is future work |
| Feed algorithm redesign | Only fixing existing reordering behavior, not adding new logic |
| New features | Bug fix milestone only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PERF-01 | Phase 21 | Pending |
| PERF-02 | Phase 21 | Pending |
| FEED-01 | Phase 22 | Pending |
| FEED-02 | Phase 22 | Pending |
| FEED-03 | Phase 22 | Pending |

**Coverage:**
- v1.1.0 requirements: 5 total
- Mapped to phases: 5
- Unmapped: 0

---
*Requirements defined: 2026-02-22*
*Last updated: 2026-02-22 — traceability updated with phase mappings*
