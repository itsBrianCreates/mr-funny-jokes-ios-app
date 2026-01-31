# Phase 9: Widget Background Refresh - Context

**Gathered:** 2026-01-30
**Status:** Ready for planning

<domain>
## Phase Boundary

All 6 widgets (home screen: small, medium, large; lock screen: circular, rectangular, inline) display fresh Joke of the Day without requiring app launch. Widgets update daily even if app hasn't been opened in 3+ days.

</domain>

<decisions>
## Implementation Decisions

### Refresh Timing
- Widgets refresh at midnight ET to align with JOTD cycle
- If midnight refresh fails, retry on next WidgetKit timeline reload
- Stick to scheduled refresh — no aggressive refresh on device unlock even if stale
- All widgets (home screen and lock screen) refresh identically

### Stale Data Handling
- When data is stale (>3 days), show a random joke from local cache
- Local cache size: small (10-20 jokes) — enough for variety without storage overhead
- If cache is empty (fresh install, never opened app), show placeholder: "Open Mr. Funny Jokes to get started!"

### Widget Content Source
- All 6 widgets show the same JOTD — consistent experience
- JOTD is the top-rated joke of the day, regardless of which character delivered it
- This provides natural variety: some days Mr. Love, some days Mr. Bad, Mr. Sad, Mr. Funny, etc.
- Keep current widget design — no changes to character display

### Update Indicators
- No visual indicators when content updates — silent, clean changes
- No visual difference between fresh and stale content
- Keep current tap behavior (whatever widgets do now)

### Claude's Discretion
- Whether to use BGAppRefreshTask + WidgetKit or WidgetKit alone (pick based on iOS best practices)
- Whether cached fallback jokes rotate daily or stay static until fresh data arrives
- Technical implementation of timeline scheduling

</decisions>

<specifics>
## Specific Ideas

- "We want to see variety here!" — Character variety should emerge naturally from top-rated joke selection
- Current widget design is satisfactory — focus on data freshness, not visual changes

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-widget-background-refresh*
*Context gathered: 2026-01-30*
