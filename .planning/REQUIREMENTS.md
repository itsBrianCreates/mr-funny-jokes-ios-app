# Requirements: Mr. Funny Jokes

**Defined:** 2026-02-15
**Core Value:** Users can instantly get a laugh from character-delivered jokes and share them with friends

## v1.0.3 Requirements

Requirements for v1.0.3 Seasonal Content & Scroll Fix. Each maps to roadmap phases.

### Seasonal Content

- [ ] **SEASON-01**: Christmas/holiday-tagged jokes are pushed to the bottom of the feed when the current date is outside Nov 1 - Dec 31
- [ ] **SEASON-02**: Christmas/holiday-tagged jokes rank normally (by popularity score) when the current date is within Nov 1 - Dec 31
- [ ] **SEASON-03**: Seasonal demotion applies to all feed contexts (main feed, character feeds, category-filtered feeds)

### Scroll Stability

- [ ] **SCROLL-01**: User can scroll up from the bottom of the feed without visual glitches or position jumps on iOS 18+
- [ ] **SCROLL-02**: Feed maintains stable scroll position when background content loading completes
- [ ] **SCROLL-03**: Conditional content (character carousel, JOTD, promo card) does not destabilize scroll anchors during scrolling

## Future Requirements

### Seasonal Content (v2)

- **SEASON-04**: Seasonal system supports multiple holidays (Valentine's, Halloween, etc.) with configurable date windows
- **SEASON-05**: Admin can configure seasonal windows remotely via Firebase

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-holiday seasonal system | Just Christmas for now; extend later if needed |
| Server-side seasonal ranking | Client-side sort modification is simpler and sufficient |
| Hiding seasonal jokes entirely | User prefers push-to-bottom over hiding |
| Complete feed architecture rewrite | Targeted scroll fixes only, not a rewrite |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SEASON-01 | Phase 11 | Pending |
| SEASON-02 | Phase 11 | Pending |
| SEASON-03 | Phase 11 | Pending |
| SCROLL-01 | Phase 12 | Pending |
| SCROLL-02 | Phase 12 | Pending |
| SCROLL-03 | Phase 12 | Pending |

**Coverage:**
- v1.0.3 requirements: 6 total
- Mapped to phases: 6
- Unmapped: 0

---
*Requirements defined: 2026-02-15*
*Last updated: 2026-02-15 after roadmap created (traceability updated)*
