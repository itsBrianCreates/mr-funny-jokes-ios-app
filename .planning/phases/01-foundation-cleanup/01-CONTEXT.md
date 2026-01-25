# Phase 1: Foundation & Cleanup - Context

**Gathered:** 2026-01-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove iPad support, update rankings from weekly to monthly, and simplify notification UI. These are platform/configuration changes to prepare the codebase for native feature development in later phases.

</domain>

<decisions>
## Implementation Decisions

### Ranking Transition
- Start fresh with monthly rankings — reset all scores to 0
- No transition messaging to users — switch silently
- Section header: "Monthly Top 10"
- If fewer than 10 jokes qualify, show whatever exists (no placeholder, no hiding)

### Notification Removal UX
- Replace time picker with helper text AND deep-link button
- Keep simple on/off toggle, remove time picker only
- Friendly tone for helper text (e.g., "Want to adjust when you get jokes? Head to Settings!")
- Keep notification section in current position within Settings screen
- Button opens iOS Settings directly to app notification preferences

### iPad Removal
- Full removal: remove deployment target AND delete iPad-specific code/assets
- No existing iPad users to consider
- Remove iPad from all targets (main app + widget extensions)
- iPad support noted as potential future addition (not permanent exclusion)

### Claude's Discretion
- Exact helper text wording
- Code cleanup approach for iPad-specific assets
- SwiftUI patterns for new/modified views

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

- iPad support — potential future version (post-v1.0)

</deferred>

---

*Phase: 01-foundation-cleanup*
*Context gathered: 2026-01-24*
