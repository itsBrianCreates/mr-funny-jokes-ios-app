# Requirements: Mr. Funny Jokes

**Defined:** 2026-02-21
**Core Value:** Users can instantly get a laugh from character-delivered jokes and share them with friends

## v1.10 Requirements

Requirements for Firebase Analytics integration. Each maps to roadmap phases.

### Setup

- [ ] **SETUP-01**: FirebaseAnalytics SPM package product added to app target
- [ ] **SETUP-02**: GoogleService-Info.plist updated with IS_ANALYTICS_ENABLED = true
- [ ] **SETUP-03**: Analytics auto-initializes via existing FirebaseApp.configure() call (no extra code needed)

### Events

- [ ] **EVNT-01**: Joke rated event logged with joke ID, character, and rating (hilarious/horrible)
- [ ] **EVNT-02**: Joke shared/copied event logged with joke ID
- [ ] **EVNT-03**: Character selected event logged with character ID

### Service

- [ ] **SRVC-01**: AnalyticsService singleton created following existing service/singleton pattern
- [ ] **SRVC-02**: Analytics.logEvent() used with descriptive event names and minimal parameters

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
| Analytics in widget extension | Firebase SDK causes deadlock issue #13070 |
| Custom Analytics dashboard UI in-app | Unnecessary — Firebase Console provides this |
| User properties / audience segmentation | No auth system, anonymous users only |
| Crashlytics integration | Separate concern, not part of this milestone |
| Performance monitoring | Separate concern, defer to future milestone |
| A/B testing via Remote Config | No need yet — not enough users for meaningful experiments |
| Over-instrumentation of every UI interaction | Keep lightweight — only key user actions |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SETUP-01 | — | Pending |
| SETUP-02 | — | Pending |
| SETUP-03 | — | Pending |
| EVNT-01 | — | Pending |
| EVNT-02 | — | Pending |
| EVNT-03 | — | Pending |
| SRVC-01 | — | Pending |
| SRVC-02 | — | Pending |

**Coverage:**
- v1.10 requirements: 8 total
- Mapped to phases: 0
- Unmapped: 8 (will be mapped during roadmap creation)

---
*Requirements defined: 2026-02-21*
*Last updated: 2026-02-21 after initial definition*
