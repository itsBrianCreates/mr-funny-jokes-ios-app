# Requirements: Mr. Funny Jokes v1.0

**Defined:** 2025-01-24
**Core Value:** Users can instantly get a laugh from character-delivered jokes and share them with friends.

## v1 Requirements

Requirements for v1.0 release. Each maps to roadmap phases.

### Siri Integration

- [ ] **SIRI-01**: User can say "Hey Siri, tell me a joke" to trigger the app
- [ ] **SIRI-02**: Siri speaks both setup and punchline aloud
- [ ] **SIRI-03**: Siri intent works offline using cached jokes
- [ ] **SIRI-04**: App Shortcut auto-registers in Shortcuts app

### Lock Screen Widgets

- [x] **WIDGET-01**: Accessory Circular widget displays joke of the day
- [x] **WIDGET-02**: Accessory Rectangular widget displays joke of the day
- [x] **WIDGET-03**: Accessory Inline widget displays joke text
- [x] **WIDGET-04**: All lock screen widgets handle vibrant rendering mode correctly

### Home Screen Widget Polish

- [ ] **WIDGET-05**: Small widget displays joke of the day correctly
- [ ] **WIDGET-06**: Medium widget displays joke of the day correctly
- [ ] **WIDGET-07**: Large widget displays joke of the day correctly

### Rankings

- [x] **RANK-01**: Rankings use monthly period instead of weekly
- [x] **RANK-02**: UI labels updated to "Monthly Top 10"

### Notifications

- [x] **NOTIF-01**: In-app notification time picker removed
- [x] **NOTIF-02**: Settings shows helper text for iOS Settings notification management

### Content

- [ ] **CONT-01**: 500 jokes in Firebase across all 5 characters

### Platform

- [x] **PLAT-01**: Remove iPad support (iPhone only)
- [x] **PLAT-02**: All new UI uses native SwiftUI components

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Siri Enhancements

- **SIRI-05**: Character-specific Siri command ("Tell me a Mr. Potty joke")
- **SIRI-06**: SiriTipView in app for feature discoverability

### Widget Enhancements

- **WIDGET-08**: Interactive rating button in home screen widgets (iOS 17+)
- **WIDGET-09**: Control Center widget (iOS 18+)

### Character Chat (Backup Plan)

- **CHAT-01**: Full character chat feature (see PRD at ~/Desktop/PRD Character Chat Feature.md)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Character-specific Siri | Adds complexity, defer to v2 if v1 passes review |
| Interactive widget buttons | Not needed for 4.2.2 compliance |
| Control Center widget | iOS 18+ only, defer to v2 |
| Apple Intelligence integration | Too new, insufficient community data |
| iPad support | Simplify testing and UI, iPhone-only for v1.0 |
| Live Activities | High complexity, not needed for 4.2.2 |
| Custom notification scheduling | Using iOS Settings instead |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLAT-01 | Phase 1: Foundation & Cleanup | Complete |
| PLAT-02 | Phase 1: Foundation & Cleanup | Complete |
| RANK-01 | Phase 1: Foundation & Cleanup | Complete |
| RANK-02 | Phase 1: Foundation & Cleanup | Complete |
| NOTIF-01 | Phase 1: Foundation & Cleanup | Complete |
| NOTIF-02 | Phase 1: Foundation & Cleanup | Complete |
| WIDGET-01 | Phase 2: Lock Screen Widgets | Complete |
| WIDGET-02 | Phase 2: Lock Screen Widgets | Complete |
| WIDGET-03 | Phase 2: Lock Screen Widgets | Complete |
| WIDGET-04 | Phase 2: Lock Screen Widgets | Complete |
| SIRI-01 | Phase 3: Siri Integration | Pending |
| SIRI-02 | Phase 3: Siri Integration | Pending |
| SIRI-03 | Phase 3: Siri Integration | Pending |
| SIRI-04 | Phase 3: Siri Integration | Pending |
| WIDGET-05 | Phase 4: Widget Polish | Pending |
| WIDGET-06 | Phase 4: Widget Polish | Pending |
| WIDGET-07 | Phase 4: Widget Polish | Pending |
| CONT-01 | Phase 6: Content & Submission | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2025-01-24*
*Last updated: 2026-01-24 after roadmap creation*
