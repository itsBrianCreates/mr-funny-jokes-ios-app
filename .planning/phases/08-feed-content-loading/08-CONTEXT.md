# Phase 8: Feed Content Loading - Context

**Gathered:** 2026-01-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Full joke catalog loads automatically in background as user scrolls, with feed showing only unrated jokes (sorted by popularity). The existing "Load More" button is removed in favor of infinite scroll. Rated jokes are accessed via the "Me" tab, not the feed.

</domain>

<decisions>
## Implementation Decisions

### Infinite scroll behavior
- Trigger threshold: Claude's discretion (standard iOS patterns)
- Batch size: Claude's discretion (balance between frequency and efficiency)
- On load failure: Show inline retry button (reuse existing "Load More Jokes" button styling)
- Pull-to-refresh: Full reset — reload from page 1, scroll to top

### Unrated-first sorting
- Feed shows ONLY unrated jokes — rated jokes are removed from feed entirely
- Users find their rated jokes in the "Me" tab
- Unrated jokes ordered by popularity score (trending/popular first)
- When user rates a joke: stays visible for current session, removed on next refresh

### Background loading
- Trigger: Start background loading when user scrolls (not on app launch)
- Progress visibility: Completely silent — no UI indicator
- Catalog size: Design for 500-2000 jokes
- Background/tab switch: Claude's discretion (follow iOS guidelines)

### Loading states
- Initial load: Skeleton cards (gray placeholder cards mimicking joke layout)
- Scroll threshold loading: Skeleton card(s) at bottom of list
- Empty state: Use existing empty state (no changes needed)
- Retry on failure: Reuse existing "Load More Jokes" button styling

### Claude's Discretion
- Exact scroll threshold percentage for triggering next page
- Batch size per page load
- Background loading behavior when app backgrounded or tab switched
- Skeleton card animation and design details

</decisions>

<specifics>
## Specific Ideas

- Rated jokes don't clutter the feed — they live in the "Me" tab
- Reuse existing "Load More Jokes" button for retry styling — keeps UI consistent
- Skeleton cards match the joke card layout

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-feed-content-loading*
*Context gathered: 2026-01-30*
