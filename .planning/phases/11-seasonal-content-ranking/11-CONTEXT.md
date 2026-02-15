# Phase 11: Seasonal Content Ranking - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Holiday jokes appear at the bottom of feeds outside their season and rank normally during their season. Affects main feed, character feeds, and category-filtered feeds. No new UI elements — purely a sorting/ranking change.

</domain>

<decisions>
## Implementation Decisions

### Holiday content identification
- Filter on the `christmas` tag in the joke's tags array
- If a joke has `christmas` in its tags, it is subject to seasonal ranking rules
- The `holidays` tag is NOT used for detection — some jokes have it, some don't, but `christmas` is the canonical tag
- Other holiday tags (halloween, thanksgiving) are not affected by this phase

### Season window
- Christmas jokes rank normally (by popularity) during Nov 1 - Dec 31
- Christmas jokes are demoted to the bottom of all feeds outside Nov 1 - Dec 31
- Window is inclusive: Nov 1 00:00 through Dec 31 23:59

### Affected feeds
- Main feed (all jokes)
- Character feeds (e.g., Mr. Funny's jokes)
- Category-filtered feeds
- Demotion applies consistently across all feed views

### Claude's Discretion
- Timezone handling (device local vs UTC)
- Exact sort position within the demoted group (by popularity among demoted, or arbitrary)
- Implementation approach (client-side sort modifier vs query-level)

</decisions>

<specifics>
## Specific Ideas

- "We're just going to look for anything that has Christmas and filter that to the bottom and rise it to the top in our window"
- Christmas-only for now — other holidays can get their own seasonal treatment in a future phase

</specifics>

<deferred>
## Deferred Ideas

- Per-holiday seasonal windows (Halloween in October, Thanksgiving in November) — future phase
- Migrating mixed `holidays` tags to specific holiday tags — cleanup task

</deferred>

---

*Phase: 11-seasonal-content-ranking*
*Context gathered: 2026-02-15*
