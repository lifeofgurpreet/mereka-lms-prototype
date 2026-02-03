#!/usr/bin/env bash
set -euo pipefail

# Test MCT user import with a small batch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="/var/migrations/mct/transformed/users.csv"
IMPORT_SCRIPT="$SCRIPT_DIR/openedx_bulk_import_mct.py"
STATE_FILE="/tmp/mct_user_import_test.state"

echo "Testing MCT user import with first 100 users..."
echo "CSV: $CSV_FILE"
echo "Script: $IMPORT_SCRIPT"
echo ""

# Run test import
python3 "$IMPORT_SCRIPT" users \
  --csv "$CSV_FILE" \
  --offset 0 \
  --limit 100 \
  --state-file "$STATE_FILE"

echo ""
echo "Test complete! Check results above."
echo "State file: $STATE_FILE"
if [[ -f "$STATE_FILE" ]]; then
  echo "Last offset: $(cat "$STATE_FILE")"
fi
