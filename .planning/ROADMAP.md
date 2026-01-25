# Roadmap: Mr. Funny Jokes v1.0

**Created:** 2026-01-24
**Phases:** 6
**Requirements:** 18 mapped

## Phase Overview

| # | Phase | Goal | Requirements | Status |
|---|-------|------|--------------|--------|
| 1 | Foundation & Cleanup | Platform changes and UI cleanup to prepare for native features | PLAT-01, PLAT-02, RANK-01, RANK-02, NOTIF-01, NOTIF-02 | Complete |
| 2 | Lock Screen Widgets | Add lock screen widgets for Joke of the Day display | WIDGET-01, WIDGET-02, WIDGET-03, WIDGET-04 | Complete |
| 3 | Siri Integration | Voice-activated joke delivery via App Intents | SIRI-01, SIRI-02, SIRI-03, SIRI-04 | Pending |
| 4 | Widget Polish | Verify and polish all home screen widget sizes | WIDGET-05, WIDGET-06, WIDGET-07 | Pending |
| 5 | Testing & Bug Fixes | Comprehensive testing and bug resolution | — | Pending |
| 6 | Content & Submission | User-provided jokes + App Store submission | CONT-01 | Pending |

## Phase Details

### Phase 1: Foundation & Cleanup

**Goal:** Remove iPad support, update rankings from weekly to monthly, simplify notification UI, and establish native SwiftUI patterns for all new development.

**Requirements:** PLAT-01, PLAT-02, RANK-01, RANK-02, NOTIF-01, NOTIF-02

**Plans:** 3 plans (Wave 1 - all parallel)

Plans:
- [x] 01-01-PLAN.md — Verify iPhone-only deployment and clean up iPad remnants
- [x] 01-02-PLAN.md — Rename Weekly rankings to Monthly throughout codebase
- [x] 01-03-PLAN.md — Simplify notification settings (remove time picker, add Settings deep link)

**Success Criteria:**
1. App runs only on iPhone - iPad deployment target removed from Xcode project
2. Rankings section displays "Monthly Top 10" with 30-day calculation window
3. Settings screen no longer shows in-app notification time picker
4. Settings screen includes helper text guiding users to iOS Settings for notification management

**Notes:**
- These are lower-risk changes that clean up the codebase before adding new native features
- Removing iPad simplifies testing matrix for v1.0
- Monthly rankings ensures leaderboard feels populated with low initial user base
- Notification simplification follows native iOS patterns (less custom UI = better 4.2.2 optics)

---

### Phase 2: Lock Screen Widgets

**Goal:** Add lock screen widget support for all three accessory families, displaying Joke of the Day content.

**Requirements:** WIDGET-01, WIDGET-02, WIDGET-03, WIDGET-04

**Plans:** 2 plans (Wave 1 implementation, Wave 2 verification)

Plans:
- [x] 02-01-PLAN.md — Implement lock screen widget views and configuration
- [x] 02-02-PLAN.md — Verify widgets on physical device

**Success Criteria:**
1. Users can add a circular lock screen widget showing character avatar or abbreviated joke
2. Users can add a rectangular lock screen widget showing joke setup text
3. Users can add an inline lock screen widget showing joke text
4. All lock screen widgets render correctly in vibrant mode (desaturated appearance)

**Notes:**
- Uses existing JokeOfTheDayWidget extension - add accessory families to configuration
- Must handle `.widgetRenderingMode` environment value for vibrant vs fullColor
- Lock screen widgets share timeline provider with home screen widgets
- Test on actual lock screen - simulator may not reflect vibrant mode accurately
- Critical for 4.2.2 compliance: demonstrates native iOS integration beyond basic APIs

---

### Phase 3: Siri Integration

**Goal:** Enable users to request jokes via Siri voice commands, with spoken responses that work offline.

**Requirements:** SIRI-01, SIRI-02, SIRI-03, SIRI-04

**Plans:** (created by /gsd:plan-phase)

**Success Criteria:**
1. Saying "Hey Siri, tell me a joke from Mr. Funny Jokes" triggers the app intent
2. Siri audibly speaks the joke setup and punchline without opening the app
3. Siri command works when device has no internet connection (uses cached jokes)
4. App Shortcut appears automatically in the Shortcuts app after installation

**Notes:**
- Use App Intents framework (not deprecated SiriKit Intent Definition files)
- Phrases MUST include `.applicationName` placeholder for Siri to recognize
- Intent reads from SharedStorageService (App Groups) for offline support
- Create TellJokeIntent with IntentDialog response for spoken output
- Add MrFunnyShortcutsProvider (AppShortcutsProvider) for auto-registration
- Character-specific parameter ("Tell me a Mr. Potty joke") deferred to v2 per requirements

---

### Phase 4: Widget Polish

**Goal:** Verify and polish all existing home screen widget sizes to ensure consistent, high-quality appearance.

**Requirements:** WIDGET-05, WIDGET-06, WIDGET-07

**Plans:** (created by /gsd:plan-phase)

**Success Criteria:**
1. Small widget displays joke of the day with readable text and proper character branding
2. Medium widget displays joke of the day with full setup/punchline visible
3. Large widget displays joke of the day with enhanced visual presentation
4. All widgets handle dark mode and light mode correctly

**Notes:**
- Home screen widgets already exist - this phase is verification and polish
- Check text truncation on all device sizes
- Verify deep-link tap action opens correct joke in app
- Test widget refresh behavior (budget ~40-70 refreshes/day in production)
- Screenshots of all widget sizes needed for App Store submission

---

### Phase 5: Testing & Bug Fixes

**Goal:** Comprehensive testing of all new features, bug identification and resolution before content and submission.

**Requirements:** —

**Plans:** (created by /gsd:plan-phase)

**Success Criteria:**
1. All Siri commands tested on real device (not just simulator)
2. All widget sizes tested on multiple iPhone models
3. Lock screen widgets tested in actual lock screen context
4. Offline mode verified for Siri intent
5. No critical bugs remaining

**Notes:**
- Test on real device (simulator may not reflect Siri/widget behavior accurately)
- Test widget refresh behavior over multiple days
- Verify App Groups data sharing between main app and extensions
- Document any issues found for resolution
- User will manually test and report bugs

---

### Phase 6: Content & Submission

**Goal:** User manually provides and reviews 500 jokes, then prepare App Store submission materials.

**Requirements:** CONT-01

**Plans:** (created by /gsd:plan-phase)

**Success Criteria:**
1. Firebase contains 500 jokes distributed across all 5 characters
2. Each character has meaningful joke coverage (no character feels empty)
3. App Review Notes document all native features with step-by-step testing instructions

**Notes:**
- **User provides jokes manually** - not automated content generation
- Use existing `scripts/add-jokes.js` for batch insertion after user review
- Follow CLAUDE.md joke processing workflow for categorization
- App Review Notes template provided in research summary - customize for submission
- Include demo video showing Siri integration and widget functionality
- This phase starts AFTER all technical phases and testing are complete

---

## Dependencies

```
Phase 1 (Foundation)
    |
    v
Phase 2 (Lock Screen Widgets) ----+
    |                              |
    v                              v
Phase 3 (Siri)                Phase 4 (Widget Polish)
    |                              |
    +----------+-------------------+
               |
               v
         Phase 5 (Testing & Bug Fixes)
               |
               v
         Phase 6 (Content & Submission)
```

**Parallelization opportunities:**
- Phases 2/3 can run in parallel (both depend on Phase 1 but not each other)
- Phase 4 can run in parallel with Phase 3 once Phase 2 is complete
- Phase 5 requires all technical phases (1-4) complete
- Phase 6 (content) happens only after all testing is done — user manually provides jokes

---

## Estimated Effort

| Phase | Estimated Hours | Risk |
|-------|-----------------|------|
| Phase 1: Foundation | 2-4 hours | Low |
| Phase 2: Lock Screen Widgets | 4-6 hours | Low |
| Phase 3: Siri Integration | 4-6 hours | Low |
| Phase 4: Widget Polish | 2-3 hours | Low |
| Phase 5: Testing & Bug Fixes | 2-4 hours | Low |
| Phase 6: Content & Submission | User-driven | Low |
| **Total (technical)** | **14-23 hours** | **Low** |

---

*Roadmap created: 2026-01-24*
*Based on research: .planning/research/SUMMARY.md*
