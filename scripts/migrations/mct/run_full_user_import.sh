#!/usr/bin/env bash
set -euo pipefail

# Run full MCT user import in batches

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="/var/migrations/mct/transformed/users.csv"
IMPORT_SCRIPT="$SCRIPT_DIR/openedx_bulk_import_mct.py"
STATE_FILE="/var/migrations/mct/user_import.state"
BATCH_SIZE="${BATCH_SIZE:-5000}"

echo "=========================================="
echo "MCT User Import - Full Run"
echo "=========================================="
echo "CSV: $CSV_FILE"
echo "Script: $IMPORT_SCRIPT"
echo "Batch size: $BATCH_SIZE"
echo "State file: $STATE_FILE"
echo ""

# Get total user count
TOTAL_USERS=$(wc -l < "$CSV_FILE")
TOTAL_USERS=$((TOTAL_USERS - 1))  # Subtract header
echo "Total users to import: $TOTAL_USERS"
echo ""

# Check if state file exists
START_OFFSET=0
if [[ -f "$STATE_FILE" ]]; then
  START_OFFSET=$(cat "$STATE_FILE")
  echo "Resuming from offset: $START_OFFSET"
else
  echo "Starting fresh import from offset 0"
fi

# Calculate batches
REMAINING=$((TOTAL_USERS - START_OFFSET))
BATCHES=$(( (REMAINING + BATCH_SIZE - 1) / BATCH_SIZE ))
echo "Batches to process: $BATCHES"
echo ""

# Run batches
CURRENT_OFFSET=$START_OFFSET
BATCH_NUM=1

while [[ $CURRENT_OFFSET -lt $TOTAL_USERS ]]; do
  echo "=========================================="
  echo "Batch $BATCH_NUM/$BATCHES"
  echo "Offset: $CURRENT_OFFSET"
  echo "Limit: $BATCH_SIZE"
  echo "=========================================="

  python3 "$IMPORT_SCRIPT" users \
    --csv "$CSV_FILE" \
    --offset "$CURRENT_OFFSET" \
    --limit "$BATCH_SIZE" \
    --state-file "$STATE_FILE"

  EXIT_CODE=$?

  if [[ $EXIT_CODE -ne 0 ]]; then
    echo "ERROR: Batch $BATCH_NUM failed with exit code $EXIT_CODE"
    echo "State saved at offset: $(cat "$STATE_FILE" 2>/dev/null || echo "unknown")"
    exit $EXIT_CODE
  fi

  # Update offset from state file
  CURRENT_OFFSET=$(cat "$STATE_FILE")
  BATCH_NUM=$((BATCH_NUM + 1))

  echo ""
  echo "Batch complete. Next offset: $CURRENT_OFFSET"
  echo ""

  # Short pause between batches
  sleep 2
done

echo "=========================================="
echo "IMPORT COMPLETE!"
echo "=========================================="
echo "Total users processed: $TOTAL_USERS"
echo "Final offset: $(cat "$STATE_FILE")"
echo ""
