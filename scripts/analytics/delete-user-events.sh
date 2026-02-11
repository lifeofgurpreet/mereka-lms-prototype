#!/usr/bin/env bash
# @covers AC-008
# @spec: analytics-pipeline_spec.md
set -euo pipefail

# delete-user-events.sh - Delete user analytics events (GDPR right-to-be-forgotten)
#
# Usage:
#   scripts/analytics/delete-user-events.sh --user-id USER_ID --dry-run
#   scripts/analytics/delete-user-events.sh --user-id USER_ID
#
# Environment variables:
#   CLICKHOUSE_HOST: ClickHouse hostname (default: localhost)
#   CLICKHOUSE_PORT: ClickHouse port (default: 8123)
#   CLICKHOUSE_USER: ClickHouse username (default: default)
#   CLICKHOUSE_PASSWORD: ClickHouse password (required for real deletions)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source shared config if available
if [[ -f "$REPO_ROOT/scripts/shared/config.sh" ]]; then
  # Disable auto-validation for this script
  SKIP_CONFIG_VALIDATION=1 source "$REPO_ROOT/scripts/shared/config.sh"
fi

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
DRY_RUN=false

# Helper functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

log_dry_run() {
  echo -e "${YELLOW}[DRY-RUN]${NC} $*"
}

usage() {
  cat <<EOF
Usage: $0 --user-id USER_ID [--dry-run]

Delete all analytics events for a specific user (GDPR compliance).

Options:
  --user-id USER_ID    User identifier (Open edX user ID or hashed ID)
  --dry-run           Show what would be deleted without actually deleting

Environment variables:
  CLICKHOUSE_HOST     ClickHouse hostname (default: localhost)
  CLICKHOUSE_PORT     ClickHouse port (default: 8123)
  CLICKHOUSE_USER     ClickHouse username (default: default)
  CLICKHOUSE_PASSWORD ClickHouse password (required for real deletions)

Examples:
  # Dry-run to see what would be deleted
  $0 --user-id 12345 --dry-run

  # Actually delete user events
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
    --dry-run)
      DRY_RUN=true
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

# Validate user-id format (alphanumeric, underscore, hyphen)
if ! [[ "$USER_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  log_error "Invalid user-id format: $USER_ID"
  log_error "User ID must contain only alphanumeric characters, underscores, or hyphens"
  exit 1
fi

echo "=== User Event Deletion ==="
echo "User ID: $USER_ID"
echo "ClickHouse: $CLICKHOUSE_HOST:$CLICKHOUSE_PORT"
echo "Mode: $(if [[ "$DRY_RUN" == "true" ]]; then echo "DRY-RUN"; else echo "REAL DELETION"; fi)"
echo

# SQL queries for deletion
declare -a DELETION_QUERIES=(
  "DELETE FROM xapi_events_all WHERE actor_account_name = '${USER_ID}'"
  "DELETE FROM xapi_events_all WHERE actor_account_name LIKE '%${USER_ID}%'"
  "DELETE FROM learner_summary WHERE user_id = '${USER_ID}'"
  "DELETE FROM course_enrollment_events WHERE user_id = '${USER_ID}'"
)

# Tables that might contain user events
declare -a TABLES=(
  "xapi_events_all"
  "learner_summary"
  "course_enrollment_events"
  "problem_results"
  "video_engagement"
)

if [[ "$DRY_RUN" == "true" ]]; then
  log_dry_run "DRY-RUN MODE: Showing what would be deleted"
  echo

  log_dry_run "Would execute the following deletion queries:"
  for query in "${DELETION_QUERIES[@]}"; do
    echo "  - $query"
  done
  echo

  log_dry_run "Would search for user data in tables:"
  for table in "${TABLES[@]}"; do
    echo "  - $table"
  done
  echo

  log_dry_run "To perform actual deletion, run without --dry-run:"
  echo "  CLICKHOUSE_PASSWORD=your_password $0 --user-id $USER_ID"
  echo

  log_info "Dry-run complete. No data was deleted."
  exit 0
fi

# Real deletion mode
if [[ -z "$CLICKHOUSE_PASSWORD" ]]; then
  log_error "CLICKHOUSE_PASSWORD environment variable is required for real deletions"
  log_error "Aborting to prevent accidental deletions without proper authentication"
  exit 1
fi

log_warn "REAL DELETION MODE ACTIVE"
log_warn "This will permanently delete all events for user: $USER_ID"
echo

# Check if ClickHouse is accessible
log_info "Testing ClickHouse connection..."
if ! command -v curl &>/dev/null; then
  log_error "curl command not found. Install curl to connect to ClickHouse."
  exit 1
fi

# Simple ping test
if curl -s --max-time 5 \
  --user "$CLICKHOUSE_USER:$CLICKHOUSE_PASSWORD" \
  "http://$CLICKHOUSE_HOST:$CLICKHOUSE_PORT/ping" >/dev/null 2>&1; then
  log_info "ClickHouse is accessible"
else
  log_error "Cannot connect to ClickHouse at $CLICKHOUSE_HOST:$CLICKHOUSE_PORT"
  log_error "Check connection settings and ensure ClickHouse is running"
  exit 1
fi

# Log deletion operation
log_info "Starting deletion for user: $USER_ID"
log_info "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo

# Execute deletions
for query in "${DELETION_QUERIES[@]}"; do
  log_info "Executing: $query"

  # Execute query via ClickHouse HTTP interface
  response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    --user "$CLICKHOUSE_USER:$CLICKHOUSE_PASSWORD" \
    --data "$query" \
    "http://$CLICKHOUSE_HOST:$CLICKHOUSE_PORT" 2>&1)

  http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
  body=$(echo "$response" | grep -v "HTTP_CODE:")

  if [[ "$http_code" == "200" ]]; then
    log_info "✓ Query executed successfully"
  else
    log_error "✗ Query failed (HTTP $http_code)"
    log_error "Response: $body"
  fi
  echo
done

log_info "Deletion complete for user: $USER_ID"
log_info "Verify deletion with: verify-user-deletion.sh --user-id $USER_ID"

exit 0
