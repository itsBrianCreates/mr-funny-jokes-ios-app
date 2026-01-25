# Phase 5: Testing & Bug Fixes - Context

**Gathered:** 2026-01-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Comprehensive testing of all new features (Siri, widgets, lock screen widgets) and resolution of any bugs found before content and submission. User performs manual testing and reports bugs; Claude fixes them.

</domain>

<decisions>
## Implementation Decisions

### Testing scope
- Full re-test of all features from scratch (don't rely on prior verification)
- Basic usage patterns only — no stress testing required for v1.0
- Claude determines logical testing order
- Claude determines best offline testing scenario for Siri

### Siri voice commands
- **Confirmed working:** "Tell me a joke from Mr. Funny Jokes" voice command now works
- User enabled via Settings page in app
- Both Shortcuts app AND voice commands must be tested
- This is a critical v1.0 feature for App Review (4.2.2 compliance)

### Bug handling
- User reports bugs directly in chat — Claude fixes immediately
- Blocking severity: crashes AND broken features (cosmetic issues can ship)
- If a bug can't be fixed quickly: take the time to fix it properly, don't disable features
- Minor cosmetic issues: track as backlog for v1.1

### Test documentation
- Markdown checklist in .planning/ — check off as testing progresses
- Claude generates checklist based on Phases 1-4 features
- Single device testing is fine — no need to track device/iOS version per test
- User will capture App Store screenshots separately

### Claude's Discretion
- Testing order priority
- Specific offline testing scenario (airplane mode vs WiFi-off)
- Checklist detail level and organization

</decisions>

<specifics>
## Specific Ideas

- Siri voice command now confirmed working — must ensure this is prominently tested and documented for App Review
- User turned on Siri in Settings page to enable voice commands

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-testing-bug-fixes*
*Context gathered: 2026-01-25*
