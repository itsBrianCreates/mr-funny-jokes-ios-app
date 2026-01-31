#!/bin/bash
# Weekly rankings aggregation cron script
# Runs the Node.js aggregation script and logs output

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/aggregation.log"

echo "========================================" >> "$LOG_FILE"
echo "$(date): Starting aggregation" >> "$LOG_FILE"

cd "$SCRIPT_DIR"
/usr/local/bin/node aggregate-weekly-rankings.js >> "$LOG_FILE" 2>&1

echo "$(date): Aggregation complete" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
