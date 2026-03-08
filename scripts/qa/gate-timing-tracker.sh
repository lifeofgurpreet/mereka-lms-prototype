#!/usr/bin/env bash
set -euo pipefail

# Gate Timing Tracker
# Wraps verification commands with timing capture and appends results to gate_timings.jsonl
#
# Usage: ./scripts/qa/gate-timing-tracker.sh <gate_name> <command...>
# Example: ./scripts/qa/gate-timing-tracker.sh spec_lint make check-specs
#
# Output: Appends JSON line to verification/manifests/gate_timings.jsonl

GATE_NAME="${1:?Usage: gate-timing-tracker.sh <gate_name> <command...>}"
shift
COMMAND="$*"
TIMINGS_FILE="verification/manifests/gate_timings.jsonl"
START_EPOCH=$(date +%s%N)

# Run the command, capture exit code
set +e
eval "$COMMAND" > /tmp/gate-output-$$ 2>&1
EXIT_CODE=$?
set -e

END_EPOCH=$(date +%s%N)
DURATION_MS=$(( (END_EPOCH - START_EPOCH) / 1000000 ))

# Append timing record
mkdir -p "$(dirname "$TIMINGS_FILE")"
printf '{"gate":"%s","command":"%s","duration_ms":%d,"exit_code":%d,"timestamp":"%s","host":"%s"}\n' \
  "$GATE_NAME" "$COMMAND" "$DURATION_MS" "$EXIT_CODE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname -s)" \
  >> "$TIMINGS_FILE"

# Print summary
if [ $EXIT_CODE -eq 0 ]; then
  echo "✓ $GATE_NAME passed in ${DURATION_MS}ms"
else
  echo "✗ $GATE_NAME failed (exit $EXIT_CODE) in ${DURATION_MS}ms"
fi

exit $EXIT_CODE
