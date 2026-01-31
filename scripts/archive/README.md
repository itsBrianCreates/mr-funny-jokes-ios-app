# Archived Scripts

These scripts were replaced by Firebase Cloud Functions on 2026-01-30.

## Archived Files

- **aggregate-weekly-rankings.js** - Now handled by `aggregateRankings` Cloud Function
- **run-aggregation.sh** - No longer needed (Cloud Scheduler triggers function)

## Cloud Functions Location

The replacement functions are in `functions/index.js`:
- `aggregateRankings` - Scheduled function (daily at midnight ET)
- `triggerAggregation` - HTTP endpoint for manual triggering

## Rollback

If Cloud Functions need to be disabled, these scripts can be restored:
```bash
mv scripts/archive/aggregate-weekly-rankings.js scripts/
mv scripts/archive/run-aggregation.sh scripts/
```

Then set up local cron job as before.
