# Phase 7: Cloud Functions Migration - Context

**Gathered:** 2026-01-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Rankings aggregation runs automatically in Firebase Cloud Functions, eliminating the manual local cron job. The cloud function aggregates monthly joke ratings data and updates Firestore rankings documents. No iOS app changes required.

</domain>

<decisions>
## Implementation Decisions

### Scheduling & Triggers
- Scheduled Cloud Function runs at midnight America/New_York (ET)
- HTTP endpoint available for manual triggering (testing, urgent updates)
- HTTP endpoint is public (no authentication required) — simplicity over protection for this low-risk operation

### Claude's Discretion
- Exact run frequency (daily vs twice daily) based on data patterns and cost
- Logging verbosity and format
- Error handling and retry logic
- Data validation approach

</decisions>

<specifics>
## Specific Ideas

- Current cron script is in `scripts/` directory — migrate that logic to Cloud Function
- Must match existing aggregation logic exactly before retiring local script

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-cloud-functions-migration*
*Context gathered: 2026-01-30*
