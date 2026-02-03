#!/usr/bin/env bash
set -euo pipefail

# Run MCT user import in K8s pod in batches

NAMESPACE="mereka-lms"
POD_NAME="lms-75c446d865-c77cn"
CSV_FILE="/tmp/mct_import/users.csv"
IMPORT_SCRIPT="/tmp/mct_import/openedx_bulk_import_mct.py"
STATE_FILE="/tmp/mct_import/user_import.state"
BATCH_SIZE="${BATCH_SIZE:-5000}"

echo "=========================================="
echo "MCT User Import - K8s Pod Execution"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo "Pod: $POD_NAME"
echo "CSV: $CSV_FILE"
echo "Batch size: $BATCH_SIZE"
echo ""

# Get total user count
TOTAL_USERS=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- sh -c "wc -l < $CSV_FILE")
TOTAL_USERS=$((TOTAL_USERS - 1))  # Subtract header
echo "Total users to import: $TOTAL_USERS"
echo ""

# Check if state file exists
START_OFFSET=0
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- test -f "$STATE_FILE" 2>/dev/null; then
  START_OFFSET=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- cat "$STATE_FILE")
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
  echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "=========================================="

  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    python3 "$IMPORT_SCRIPT" users \
      --csv "$CSV_FILE" \
      --offset "$CURRENT_OFFSET" \
      --limit "$BATCH_SIZE" \
      --state-file "$STATE_FILE"

  EXIT_CODE=$?

  if [[ $EXIT_CODE -ne 0 ]]; then
    echo "ERROR: Batch $BATCH_NUM failed with exit code $EXIT_CODE"
    SAVED_OFFSET=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- cat "$STATE_FILE" 2>/dev/null || echo "unknown")
    echo "State saved at offset: $SAVED_OFFSET"
    exit $EXIT_CODE
  fi

  # Update offset from state file
  CURRENT_OFFSET=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- cat "$STATE_FILE")
  BATCH_NUM=$((BATCH_NUM + 1))

  echo ""
  echo "Batch complete. Next offset: $CURRENT_OFFSET"
  echo "Progress: $CURRENT_OFFSET/$TOTAL_USERS ($(( CURRENT_OFFSET * 100 / TOTAL_USERS ))%)"
  echo ""

  # Short pause between batches
  sleep 2
done

echo "=========================================="
echo "IMPORT COMPLETE!"
echo "=========================================="
echo "Total users processed: $TOTAL_USERS"
FINAL_OFFSET=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- cat "$STATE_FILE")
echo "Final offset: $FINAL_OFFSET"
echo "Completed at: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
