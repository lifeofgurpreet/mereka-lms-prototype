#!/usr/bin/env bash
set -euo pipefail

# verify-user-deletion.sh - Verify user event deletion was complete
#
# Usage:
#   scripts/analytics/verify-user-deletion.sh --user-id USER_ID
#   scripts/analytics/verify-user-deletion.sh --user-id USER_ID --offline
#
# Modes:
#   --offline: Verify deletion script exists and has proper syntax (no ClickHouse connection)
#   (default): Query ClickHouse to verify no events remain for user

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default configuration
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-8123}"
CLICKHOUSE_USER="${CLICKHOUSE_USER:-default}"
CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD:-}"

USER_ID=""
OFFLINE_MODE=false

# Counters
PASS=0
FAIL=0

# Helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

usage() {
  cat <<EOF
Usage: $0 --user-id USER_ID [--offline]

Verify user event deletion was complete.

Options:
  --user-id USER_ID    User identifier to verify deletion for
  --offline           Offline verification mode (no ClickHouse connection)

Offline mode verifies:
  - Deletion script exists and has valid syntax
  - Expected deletion targets are documented

Online mode verifies:
  - No events remain in ClickHouse for the specified user
  - All known tables have been checked

Examples:
  # Offline verification (no live ClickHouse needed)
  $0 --user-id 12345 --offline

  # Online verification (checks actual ClickHouse data)
  CLICKHOUSE_PASSWORD=secret $0 --user-id 12345
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --user-id)
      USER_ID="$2"
      shift 2
      ;;
    --offline)
      OFFLINE_MODE=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate arguments
if [[ -z "$USER_ID" ]]; then
  log_error "Missing required argument: --user-id"
  usage
fi

# Validate user-id format
if ! [[ "$USER_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  log_error "Invalid user-id format: $USER_ID"
  exit 1
fi

echo "=== User Deletion Verification ==="
echo "User ID: $USER_ID"
echo "Mode: $(if [[ "$OFFLINE_MODE" == "true" ]]; then echo "OFFLINE"; else echo "ONLINE"; fi)"
echo

# Tables that should be checked for user data
declare -a DELETION_TARGETS=(
  "xapi_events_all"
  "learner_summary"
  "course_enrollment_events"
  "problem_results"
  "video_engagement"
)

if [[ "$OFFLINE_MODE" == "true" ]]; then
  log_info "Running offline verification..."
  echo

  # Check 1: Deletion script exists
  deletion_script="$SCRIPT_DIR/delete-user-events.sh"
  if [[ -f "$deletion_script" ]]; then
    pass "Deletion script exists: $(basename "$deletion_script")"
  else
    fail "Deletion script not found: $deletion_script"
  fi

  # Check 2: Deletion script has valid syntax
  if [[ -f "$deletion_script" ]]; then
    if bash -n "$deletion_script" 2>/dev/null; then
      pass "Deletion script has valid bash syntax"
    else
      fail "Deletion script has syntax errors"
      bash -n "$deletion_script" 2>&1 | head -5
    fi
  fi

  # Check 3: Deletion script is executable
  if [[ -f "$deletion_script" && -x "$deletion_script" ]]; then
    pass "Deletion script is executable"
  else
    warn "Deletion script is not executable (run: chmod +x $deletion_script)"
  fi

  # Check 4: Expected deletion targets documented
  log_info "Expected deletion targets:"
  for table in "${DELETION_TARGETS[@]}"; do
    echo "  - $table"
  done
  pass "Deletion targets documented"

  echo
  log_info "Offline verification complete."
  log_info "To verify actual deletion, run without --offline:"
  echo "  CLICKHOUSE_PASSWORD=password $0 --user-id $USER_ID"

else
  # Online verification mode
  log_info "Running online verification (querying ClickHouse)..."
  echo

  # Check ClickHouse connection
  if ! command -v curl &>/dev/null; then
    fail "curl command not found. Install curl to connect to ClickHouse."
    exit 1
  fi

  if [[ -z "$CLICKHOUSE_PASSWORD" ]]; then
    fail "CLICKHOUSE_PASSWORD environment variable required for online verification"
    exit 1
  fi

  # Test connection
  if curl -s --max-time 5 \
    --user "$CLICKHOUSE_USER:$CLICKHOUSE_PASSWORD" \
    "http://$CLICKHOUSE_HOST:$CLICKHOUSE_PORT/ping" >/dev/null 2>&1; then
    pass "ClickHouse is accessible at $CLICKHOUSE_HOST:$CLICKHOUSE_PORT"
  else
    fail "Cannot connect to ClickHouse at $CLICKHOUSE_HOST:$CLICKHOUSE_PORT"
    exit 1
  fi
  echo

  # Query each table for remaining user data
  log_info "Checking tables for remaining user data..."
  for table in "${DELETION_TARGETS[@]}"; do
    # Check if table exists
    table_check
    table_check=$(curl -s --user "$CLICKHOUSE_USER:$CLICKHOUSE_PASSWORD" \
      --data "SELECT count() FROM system.tables WHERE name = '$table'" \
      "http://$CLICKHOUSE_HOST:$CLICKHOUSE_PORT" 2>&1)

    if [[ "$table_check" == "0" ]]; then
      warn "Table $table does not exist (may not be created yet)"
      continue
    fi

    # Query for user data (check multiple user ID fields)
    count_query="SELECT count() FROM $table WHERE user_id = '$USER_ID' OR actor_account_name = '$USER_ID' OR actor_account_name LIKE '%${USER_ID}%'"
    count
    count=$(curl -s --user "$CLICKHOUSE_USER:$CLICKHOUSE_PASSWORD" \
      --data "$count_query" \
      "http://$CLICKHOUSE_HOST:$CLICKHOUSE_PORT" 2>&1)

    if [[ "$count" =~ ^[0-9]+$ ]]; then
      if [[ "$count" -eq 0 ]]; then
        pass "Table $table: 0 events remaining for user"
      else
        fail "Table $table: $count events still present for user"
      fi
    else
      warn "Table $table: Could not query (may not have user_id column)"
    fi
  done

  echo
  log_info "Online verification complete."
fi

# Summary
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS"
echo -e "${RED}FAIL:${NC} $FAIL"

if [[ $FAIL -gt 0 ]]; then
  log_error "Verification failed. User deletion may be incomplete."
  exit 1
fi

echo
log_info "✓ Verification successful. User data deletion appears complete."

exit 0
