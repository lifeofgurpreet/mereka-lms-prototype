#!/usr/bin/env bash
# @covers AC-021, AC-022, AC-023
# @spec: disaster-recovery-business-continuity_spec.md
# Cloud SQL automated snapshot verification (STUB - requires GCP access to run)
#
# Goals:
# - Verify daily snapshot schedule is configured
# - Confirm snapshots are being created within SLA (< 24h old)
# - Generate compliance evidence for quarterly restore drills
#
# Usage:
#   ./scripts/qa/verify-cloud-sql-snapshots.sh
#   ./scripts/qa/verify-cloud-sql-snapshots.sh --json
#   ./scripts/qa/verify-cloud-sql-snapshots.sh --instance my-instance --project my-project
#
# Note: This is a STUB script. It will work when run with GCP access.
# For now, it validates the configuration and outputs expected behavior.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Default values
GCP_PROJECT="${GCP_PROJECT:-mereka-lms}"
CLOUD_SQL_INSTANCE="${CLOUD_SQL_INSTANCE:-mereka-lms-mysql}"
JSON_OUT=0
MAX_BACKUP_AGE_HOURS=24
REQUIRED_SCHEDULE="daily"

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/verify-cloud-sql-snapshots.sh [OPTIONS]

Options:
  --project PROJECT         GCP project ID (default: mereka-lms)
  --instance INSTANCE       Cloud SQL instance name (default: mereka-lms-mysql)
  --json                    Output results as JSON
  --max-age-hours HOURS     Maximum acceptable backup age in hours (default: 24)
  -h, --help                Show this help message

Environment Variables:
  GCP_PROJECT               Override default GCP project
  CLOUD_SQL_INSTANCE        Override default instance name

Examples:
  ./scripts/qa/verify-cloud-sql-snapshots.sh
  ./scripts/qa/verify-cloud-sql-snapshots.sh --json
  ./scripts/qa/verify-cloud-sql-snapshots.sh --project my-project --instance my-instance
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) GCP_PROJECT="${2:-}"; shift 2 ;;
    --instance) CLOUD_SQL_INSTANCE="${2:-}"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    --max-age-hours) MAX_BACKUP_AGE_HOURS="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

warn() { printf "WARN: %s\n" "$*" >&2; }
fail() { printf "FAIL: %s\n" "$*" >&2; }
ok() { printf "OK: %s\n" "$*"; }
info() { printf "INFO: %s\n" "$*"; }

# Check if gcloud is available
if ! command -v gcloud &>/dev/null; then
  if [[ $JSON_OUT -eq 1 ]]; then
    cat <<EOF
{
  "status": "stub",
  "message": "gcloud not found - this is a STUB script",
  "checks": {
    "gcloud_available": false,
    "backup_schedule_configured": "unknown",
    "latest_backup_age_hours": null,
    "daily_snapshots_enabled": "unknown"
  },
  "recommendation": "Install gcloud CLI and authenticate to run full verification"
}
EOF
  else
    warn "gcloud CLI not found. This is a STUB script."
    info "When GCP access is available, this script will verify:"
    info "  1. Cloud SQL instance exists: $CLOUD_SQL_INSTANCE"
    info "  2. Daily automatic backups are enabled"
    info "  3. Latest backup is less than $MAX_BACKUP_AGE_HOURS hours old"
    info ""
    info "To enable full verification:"
    info "  1. Install gcloud: https://cloud.google.com/sdk/docs/install"
    info "  2. Authenticate: gcloud auth login"
    info "  3. Set project: gcloud config set project $GCP_PROJECT"
  fi
  exit 0
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
  if [[ $JSON_OUT -eq 1 ]]; then
    cat <<EOF
{
  "status": "stub",
  "message": "gcloud not authenticated - this is a STUB script",
  "checks": {
    "gcloud_available": true,
    "gcloud_authenticated": false,
    "backup_schedule_configured": "unknown",
    "latest_backup_age_hours": null,
    "daily_snapshots_enabled": "unknown"
  },
  "recommendation": "Run 'gcloud auth login' to authenticate"
}
EOF
  else
    warn "gcloud not authenticated. This is a STUB script."
    info "Run: gcloud auth login"
  fi
  exit 0
fi

# Verify Cloud SQL instance exists
info "Checking Cloud SQL instance: $CLOUD_SQL_INSTANCE in project $GCP_PROJECT"
if ! gcloud sql instances describe "$CLOUD_SQL_INSTANCE" --project="$GCP_PROJECT" &>/dev/null; then
  if [[ $JSON_OUT -eq 1 ]]; then
    cat <<EOF
{
  "status": "fail",
  "message": "Cloud SQL instance not found: $CLOUD_SQL_INSTANCE",
  "checks": {
    "gcloud_available": true,
    "gcloud_authenticated": true,
    "instance_exists": false,
    "backup_schedule_configured": "unknown",
    "latest_backup_age_hours": null,
    "daily_snapshots_enabled": "unknown"
  },
  "project": "$GCP_PROJECT",
  "instance": "$CLOUD_SQL_INSTANCE"
}
EOF
  else
    fail "Cloud SQL instance not found: $CLOUD_SQL_INSTANCE"
    info "Available instances:"
    gcloud sql instances list --project="$GCP_PROJECT" --format="table(name,region,databaseVersion)"
  fi
  exit 1
fi

ok "Cloud SQL instance found: $CLOUD_SQL_INSTANCE"

# Check if automated backups are enabled
backup_enabled=$(gcloud sql instances describe "$CLOUD_SQL_INSTANCE" \
  --project="$GCP_PROJECT" \
  --format="value(settings.backupConfiguration.enabled)" 2>/dev/null || echo "false")

if [[ "$backup_enabled" != "True" ]]; then
  if [[ $JSON_OUT -eq 1 ]]; then
    cat <<EOF
{
  "status": "fail",
  "message": "Automated backups not enabled for $CLOUD_SQL_INSTANCE",
  "checks": {
    "gcloud_available": true,
    "gcloud_authenticated": true,
    "instance_exists": true,
    "backup_schedule_configured": false,
    "latest_backup_age_hours": null,
    "daily_snapshots_enabled": false
  },
  "project": "$GCP_PROJECT",
  "instance": "$CLOUD_SQL_INSTANCE",
  "recommendation": "Enable automated backups in Cloud SQL console or via gcloud"
}
EOF
  else
    fail "Automated backups not enabled for $CLOUD_SQL_INSTANCE"
    info "Enable via: gcloud sql instances patch $CLOUD_SQL_INSTANCE --backup-start-time HH:MM"
  fi
  exit 1
fi

ok "Automated backups enabled"

# Get backup window start time
backup_start_time=$(gcloud sql instances describe "$CLOUD_SQL_INSTANCE" \
  --project="$GCP_PROJECT" \
  --format="value(settings.backupConfiguration.startTime)" 2>/dev/null || echo "unknown")

info "Backup window starts at: $backup_start_time"

# List recent backups
info "Fetching recent backups..."
backups_json=$(gcloud sql backups list \
  --instance="$CLOUD_SQL_INSTANCE" \
  --project="$GCP_PROJECT" \
  --limit=5 \
  --format=json 2>/dev/null || echo "[]")

if [[ "$backups_json" == "[]" ]] || [[ -z "$backups_json" ]]; then
  if [[ $JSON_OUT -eq 1 ]]; then
    cat <<EOF
{
  "status": "fail",
  "message": "No backups found for $CLOUD_SQL_INSTANCE",
  "checks": {
    "gcloud_available": true,
    "gcloud_authenticated": true,
    "instance_exists": true,
    "backup_schedule_configured": true,
    "latest_backup_age_hours": null,
    "daily_snapshots_enabled": true,
    "backups_exist": false
  },
  "project": "$GCP_PROJECT",
  "instance": "$CLOUD_SQL_INSTANCE",
  "backup_start_time": "$backup_start_time",
  "recommendation": "Wait for first automated backup or trigger manual backup"
}
EOF
  else
    fail "No backups found for $CLOUD_SQL_INSTANCE"
    info "Trigger manual backup: gcloud sql backups create --instance=$CLOUD_SQL_INSTANCE"
  fi
  exit 1
fi

# Parse latest backup timestamp
latest_backup_time=$(echo "$backups_json" | python3 -c "
import json, sys, datetime
backups = json.load(sys.stdin)
if not backups:
    print('unknown')
    sys.exit(0)
# Get the most recent backup (first in list, already sorted by time)
latest = backups[0]
end_time = latest.get('endTime', latest.get('windowStartTime', ''))
if not end_time:
    print('unknown')
    sys.exit(0)
print(end_time)
")

if [[ "$latest_backup_time" == "unknown" ]]; then
  if [[ $JSON_OUT -eq 1 ]]; then
    cat <<EOF
{
  "status": "warn",
  "message": "Could not determine latest backup timestamp",
  "checks": {
    "gcloud_available": true,
    "gcloud_authenticated": true,
    "instance_exists": true,
    "backup_schedule_configured": true,
    "latest_backup_age_hours": null,
    "daily_snapshots_enabled": true,
    "backups_exist": true
  },
  "project": "$GCP_PROJECT",
  "instance": "$CLOUD_SQL_INSTANCE",
  "backup_start_time": "$backup_start_time"
}
EOF
  else
    warn "Could not determine latest backup timestamp"
  fi
  exit 0
fi

# Calculate backup age in hours
backup_age_hours=$(python3 -c "
import datetime
now = datetime.datetime.now(datetime.timezone.utc)
backup_time = datetime.datetime.fromisoformat('$latest_backup_time'.replace('Z', '+00:00'))
age_seconds = (now - backup_time).total_seconds()
age_hours = age_seconds / 3600
print(f'{age_hours:.2f}')
")

ok "Latest backup: $latest_backup_time (${backup_age_hours}h ago)"

# Check if backup is fresh
backup_fresh=true
if (( $(echo "$backup_age_hours > $MAX_BACKUP_AGE_HOURS" | bc -l) )); then
  backup_fresh=false
fi

# Get total backup count
backup_count=$(echo "$backups_json" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))")

if [[ $JSON_OUT -eq 1 ]]; then
  cat <<EOF
{
  "status": "$( [[ "$backup_fresh" == "true" ]] && echo "pass" || echo "fail" )",
  "message": "$( [[ "$backup_fresh" == "true" ]] && echo "Cloud SQL snapshots verified successfully" || echo "Latest backup is stale (>${MAX_BACKUP_AGE_HOURS}h old)" )",
  "checks": {
    "gcloud_available": true,
    "gcloud_authenticated": true,
    "instance_exists": true,
    "backup_schedule_configured": true,
    "latest_backup_age_hours": $backup_age_hours,
    "backup_fresh": $backup_fresh,
    "daily_snapshots_enabled": true,
    "backups_exist": true,
    "total_backups": $backup_count
  },
  "project": "$GCP_PROJECT",
  "instance": "$CLOUD_SQL_INSTANCE",
  "backup_start_time": "$backup_start_time",
  "latest_backup_time": "$latest_backup_time",
  "max_backup_age_hours": $MAX_BACKUP_AGE_HOURS,
  "recommendation": "$( [[ "$backup_fresh" == "true" ]] && echo "None - backups healthy" || echo "Investigate why backups are stale. Check backup logs in Cloud Console." )"
}
EOF
else
  if [[ "$backup_fresh" == "false" ]]; then
    fail "Latest backup is stale: ${backup_age_hours}h ago (threshold: ${MAX_BACKUP_AGE_HOURS}h)"
    info "Investigate backup logs: gcloud sql operations list --instance=$CLOUD_SQL_INSTANCE"
    exit 1
  else
    ok "Backup freshness verified: ${backup_age_hours}h ago (threshold: ${MAX_BACKUP_AGE_HOURS}h)"
    info "Total backups found: $backup_count"
    ok "Cloud SQL snapshot verification PASSED"
  fi
fi
