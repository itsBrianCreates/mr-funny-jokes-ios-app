# Phase 4: Widget Polish - Context

**Gathered:** 2026-01-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Verify and polish all existing home screen widget sizes (small, medium, large) for consistent, high-quality appearance. Widgets already exist — this phase is about visual refinement and verification, not adding new widget types.

</domain>

<decisions>
## Implementation Decisions

### Text Layout
- Truncating setup text is acceptable — users tap widget to see full joke with punchline
- Reduce internal padding to match native iOS system widgets (Weather, Calendar, etc.)
- Fixed font sizes per widget: Small, Medium, Large each have their own size (not dynamic)
- Character name always visible on all widget sizes — reinforces persona branding

### Claude's Discretion
- Exact font point sizes for each widget size
- Visual branding treatment (colors, gradients)
- Tap behavior and deep link destination
- Empty/error state presentation
- Dark mode adaptation approach

</decisions>

<specifics>
## Specific Ideas

- Current widgets have excessive internal padding that limits text display
- Native iOS widget padding should be the reference point for spacing

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-widget-polish*
*Context gathered: 2026-01-25*
