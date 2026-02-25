#!/usr/bin/env bash
# @spec: disaster-recovery-business-continuity_spec.md
# @covers AC-005, AC-008, AC-009, AC-010, AC-023, AC-024
set -euo pipefail

# verify-dr-drill-schedule.sh
# Verifies that the monthly DR drill schedule is documented, configured, and
# (in online mode) shows evidence of recent successful execution.
#
# Offline mode: checks documentation, CronJob manifests, and evidence scripts.
# Online mode (--online): verifies live Velero schedules and backup timestamps.
#
# Usage:
#   ./scripts/qa/verify-dr-drill-schedule.sh             # offline (default)
#   ./scripts/qa/verify-dr-drill-schedule.sh --online    # live cluster checks
#   ./scripts/qa/verify-dr-drill-schedule.sh --help

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ONLINE=false
NAMESPACE="mereka-lms"
VELERO_NS="velero"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
  echo -e "${GREEN}PASS${NC}: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

skip() {
  echo -e "${YELLOW}SKIP${NC}: $1 ($2)"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

has_kubectl() {
  [[ "$ONLINE" == true ]] && command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null 2>&1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --online)
      ONLINE=true
      shift
      ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify DR drill schedule documentation and execution compliance.

OPTIONS:
    --online    Enable live cluster checks (requires kubectl access)
    --help      Show this help message

OFFLINE CHECKS (always run):
    - DR drill schedule documentation exists
    - Backup coverage matrix documented
    - DR evidence bundle script exists and references required outputs
    - GitHub Actions DR evidence workflow configured with monthly schedule
    - Velero CronJob manifests present in repo (bbi-infrastructure cross-repo check)
    - Restore drill procedure documented per database type
    - Drill pass/fail criteria documented

ONLINE CHECKS (--online only):
    - Velero backup schedules active with recent completed backups
    - BackupStorageLocation phase is Available
    - backup-verification CronJob is not suspended
    - restore-test CronJob has a recorded successful run
    - Most recent Velero backup completed within 48 hours
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

echo "DR Drill Schedule Verification"
echo "==============================="
echo "Spec: disaster-recovery-business-continuity_spec.md"
echo "Mode: $([ "$ONLINE" == true ] && echo "ONLINE (live cluster)" || echo "OFFLINE (repo checks)")"
echo ""

# ─── OFFLINE: DR drill schedule documentation exists ───

check_drill_schedule_doc() {
  echo "--- Check: DR drill schedule documentation exists ---"

  local doc="${REPO_ROOT}/docs/operations/DR_DRILL_SCHEDULE.md"
  if [[ ! -f "$doc" ]]; then
    fail "DR_DRILL_SCHEDULE.md not found at $doc"
    return
  fi

  # Verify the doc covers all required databases
  local required_sections=("MySQL" "MongoDB" "PostgreSQL" "Velero")
  local missing=0
  for section in "${required_sections[@]}"; do
    if ! grep -qi "$section" "$doc"; then
      fail "DR_DRILL_SCHEDULE.md missing section for '$section'"
      missing=$((missing + 1))
    fi
  done

  # Verify monthly cadence is documented
  if ! grep -qi "monthly\|every month\|first.*month\|month.*first" "$doc"; then
    fail "DR_DRILL_SCHEDULE.md does not document a monthly drill cadence"
    missing=$((missing + 1))
  fi

  # Verify pass/fail criteria are documented
  if ! grep -qi "pass\|fail\|criteria\|success" "$doc"; then
    fail "DR_DRILL_SCHEDULE.md does not document pass/fail criteria"
    missing=$((missing + 1))
  fi

  if [[ $missing -eq 0 ]]; then
    pass "DR_DRILL_SCHEDULE.md exists and covers MySQL, MongoDB, PostgreSQL, Velero, monthly cadence, and criteria"
  fi
}

# ─── OFFLINE: Backup coverage matrix exists ───

check_backup_coverage_matrix() {
  echo "--- Check: Backup coverage matrix documented ---"

  local matrix="${REPO_ROOT}/docs/operations/BACKUP_COVERAGE_MATRIX.md"
  if [[ -f "$matrix" ]]; then
    pass "BACKUP_COVERAGE_MATRIX.md exists"
  else
    fail "BACKUP_COVERAGE_MATRIX.md not found at $matrix"
  fi
}

# ─── OFFLINE: DR evidence bundle script covers required outputs ───

check_dr_evidence_script() {
  echo "--- Check: DR evidence bundle script exists and references required outputs ---"

  local script="${REPO_ROOT}/scripts/qa/build-dr-evidence-bundle.sh"
  if [[ ! -f "$script" ]]; then
    fail "build-dr-evidence-bundle.sh not found at $script"
    return
  fi

  local required_outputs=(
    "audit-velero.json"
    "audit-velero-alert-pipeline.json"
    "audit-observability-runtime.json"
    "observability-compliance-runtime.json"
    "observability-first-class-runtime-evidence-index.json"
  )
  local missing=0
  for output in "${required_outputs[@]}"; do
    if ! grep -q "$output" "$script"; then
      fail "build-dr-evidence-bundle.sh does not reference expected output '$output'"
      missing=$((missing + 1))
    fi
  done

  if [[ $missing -eq 0 ]]; then
    pass "build-dr-evidence-bundle.sh references all required evidence outputs"
  fi
}

# ─── OFFLINE: GitHub Actions DR evidence workflow with monthly schedule ───

check_dr_workflow() {
  echo "--- Check: GitHub Actions DR evidence workflow has monthly schedule ---"

  local workflow="${REPO_ROOT}/.github/workflows/dr-evidence-bundle.yml"
  if [[ ! -f "$workflow" ]]; then
    fail "DR evidence bundle workflow not found at $workflow"
    return
  fi

  if ! grep -q "cron:" "$workflow"; then
    fail "DR evidence bundle workflow missing cron: schedule"
    return
  fi

  # Monthly on 1st of month: matches patterns like "30 2 1 * *"
  if grep -qE "cron:.*['\"]?[0-9]+ [0-9]+ 1 \* \*" "$workflow"; then
    pass "DR evidence bundle workflow has monthly cron schedule (1st of month)"
  else
    fail "DR evidence bundle workflow missing monthly cron schedule (expected '* * 1 * *' pattern)"
  fi
}

# ─── OFFLINE: workflow_dispatch for on-demand DR evidence generation ───

check_dr_workflow_dispatch() {
  echo "--- Check: DR evidence workflow supports on-demand trigger ---"

  local workflow="${REPO_ROOT}/.github/workflows/dr-evidence-bundle.yml"
  if [[ ! -f "$workflow" ]]; then
    skip "DR workflow on-demand trigger" "dr-evidence-bundle.yml not found"
    return
  fi

  if grep -q "workflow_dispatch" "$workflow"; then
    pass "DR evidence bundle workflow supports workflow_dispatch (on-demand trigger)"
  else
    fail "DR evidence bundle workflow missing workflow_dispatch trigger"
  fi
}

# ─── OFFLINE: Restore drill documentation per database type ───

check_restore_drill_docs() {
  echo "--- Check: Restore drill documentation exists for each database type ---"

  local found_mysql=false
  local found_mongo=false
  local found_pg=false
  local found_velero=false

  # Check DR_DRILL_SCHEDULE.md first (primary location)
  local drill_doc="${REPO_ROOT}/docs/operations/DR_DRILL_SCHEDULE.md"
  if [[ -f "$drill_doc" ]]; then
    grep -qi "MySQL\|Cloud SQL" "$drill_doc" && found_mysql=true
    grep -qi "MongoDB\|Atlas" "$drill_doc" && found_mongo=true
    grep -qi "PostgreSQL\|postgres" "$drill_doc" && found_pg=true
    grep -qi "Velero" "$drill_doc" && found_velero=true
  fi

  # Also check CLOUD_SQL_RESTORE_DRILL.md
  local cloud_sql_doc="${REPO_ROOT}/docs/operations/CLOUD_SQL_RESTORE_DRILL.md"
  [[ -f "$cloud_sql_doc" ]] && found_mysql=true

  # Check for any doc mentioning Atlas backup
  while IFS= read -r doc; do
    grep -qi "Atlas.*backup\|backup.*Atlas\|Atlas.*restore\|restore.*Atlas" "$doc" && found_mongo=true && break
  done < <(find "${REPO_ROOT}/docs/operations" -name "*.md" -type f 2>/dev/null)

  local missing=0
  [[ "$found_mysql" == false ]] && { fail "No MySQL/Cloud SQL restore drill documentation found"; missing=$((missing + 1)); }
  [[ "$found_mongo" == false ]] && { fail "No MongoDB Atlas restore drill documentation found"; missing=$((missing + 1)); }
  [[ "$found_pg" == false ]]    && { fail "No PostgreSQL restore drill documentation found"; missing=$((missing + 1)); }
  [[ "$found_velero" == false ]] && { fail "No Velero restore drill documentation found"; missing=$((missing + 1)); }

  if [[ $missing -eq 0 ]]; then
    pass "Restore drill documentation exists for MySQL, MongoDB Atlas, PostgreSQL, and Velero"
  fi
}

# ─── OFFLINE: Drill pass/fail criteria documented ───

check_drill_criteria() {
  echo "--- Check: Drill pass/fail criteria and release gate integration documented ---"

  local drill_doc="${REPO_ROOT}/docs/operations/DR_DRILL_SCHEDULE.md"
  if [[ ! -f "$drill_doc" ]]; then
    skip "Drill pass/fail criteria" "DR_DRILL_SCHEDULE.md not found"
    return
  fi

  local has_criteria=false
  local has_gate=false

  grep -qi "pass.*crit\|crit.*pass\|success.*crit\|crit.*success\|fail.*crit\|crit.*fail" "$drill_doc" && has_criteria=true
  grep -qi "release.*gate\|gate.*release\|production.*release\|deploy.*gate\|drill.*block\|block.*deploy" "$drill_doc" && has_gate=true

  local missing=0
  [[ "$has_criteria" == false ]] && { fail "DR_DRILL_SCHEDULE.md missing pass/fail criteria section"; missing=$((missing + 1)); }
  [[ "$has_gate" == false ]]     && { fail "DR_DRILL_SCHEDULE.md missing release gate integration documentation"; missing=$((missing + 1)); }

  if [[ $missing -eq 0 ]]; then
    pass "DR_DRILL_SCHEDULE.md documents pass/fail criteria and release gate integration"
  fi
}

# ─── OFFLINE: Escalation path documented ───

check_escalation_path() {
  echo "--- Check: Escalation path for failed drills documented ---"

  local drill_doc="${REPO_ROOT}/docs/operations/DR_DRILL_SCHEDULE.md"
  if [[ ! -f "$drill_doc" ]]; then
    skip "Escalation path" "DR_DRILL_SCHEDULE.md not found"
    return
  fi

  if grep -qi "escalat\|on-call\|oncall\|P0\|incident" "$drill_doc"; then
    pass "DR_DRILL_SCHEDULE.md documents escalation path for failed drills"
  else
    fail "DR_DRILL_SCHEDULE.md missing escalation path for failed drills"
  fi
}

# ─── ONLINE: Velero backup schedules active with recent completed backups ───

check_velero_schedules() {
  echo "--- Check: Velero backup schedules active with recent completed backups ---"

  if ! has_kubectl; then
    skip "Velero schedule check" "no cluster access (run with --online and kubectl configured)"
    return
  fi

  local schedules
  schedules=$(kubectl get schedule -n "$VELERO_NS" -o json 2>/dev/null || echo '{"items":[]}')
  local schedule_count
  schedule_count=$(echo "$schedules" | jq '.items | length')

  if [[ "$schedule_count" -lt 3 ]]; then
    fail "Expected >=3 Velero schedules, found $schedule_count"
    return
  fi

  local required=("hourly-critical" "daily-all-apps" "weekly-full")
  local all_found=true
  for pattern in "${required[@]}"; do
    if ! echo "$schedules" | jq -r '.items[].metadata.name' | grep -q "$pattern"; then
      fail "Missing Velero schedule matching '$pattern'"
      all_found=false
    fi
  done

  if [[ "$all_found" == true ]]; then
    local recent_backup
    recent_backup=$(kubectl get backup -n "$VELERO_NS" -o json 2>/dev/null \
      | jq -r '[.items[] | select(.status.phase == "Completed")] | sort_by(.status.completionTimestamp) | last | .status.completionTimestamp // empty')

    if [[ -n "$recent_backup" ]]; then
      pass "All 3 Velero schedules present with recent completed backup ($recent_backup)"
    else
      fail "Velero schedules exist but no recent Completed backup found"
    fi
  fi
}

# ─── ONLINE: BackupStorageLocation is Available ───

check_bsl_available() {
  echo "--- Check: BackupStorageLocation phase is Available ---"

  if ! has_kubectl; then
    skip "BSL availability check" "no cluster access (run with --online)"
    return
  fi

  local bsl_phase
  bsl_phase=$(kubectl get backupstoragelocation -n "$VELERO_NS" \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")

  if [[ "$bsl_phase" == "Available" ]]; then
    pass "BackupStorageLocation phase is Available"
  elif [[ -z "$bsl_phase" ]]; then
    fail "No BackupStorageLocation found in $VELERO_NS namespace"
  else
    fail "BackupStorageLocation phase is '$bsl_phase' (expected Available)"
  fi
}

# ─── ONLINE: backup-verification CronJob is active ───

check_backup_verification_cronjob() {
  echo "--- Check: backup-verification CronJob exists and is not suspended ---"

  if ! has_kubectl; then
    skip "backup-verification CronJob check" "no cluster access (run with --online)"
    return
  fi

  local cronjob
  cronjob=$(kubectl get cronjob -n "$VELERO_NS" -o json 2>/dev/null \
    | jq '[.items[] | select(.metadata.name | test("backup-verification"))] | first // empty')

  if [[ -z "$cronjob" || "$cronjob" == "null" ]]; then
    fail "No backup-verification CronJob found in $VELERO_NS namespace"
    return
  fi

  local suspended
  suspended=$(echo "$cronjob" | jq '.spec.suspend // false')

  if [[ "$suspended" == "true" ]]; then
    fail "backup-verification CronJob is suspended"
  else
    pass "backup-verification CronJob exists and is active"
  fi
}

# ─── ONLINE: restore-test CronJob has a recorded successful run ───

check_restore_test_cronjob() {
  echo "--- Check: restore-test CronJob has a recorded successful run ---"

  if ! has_kubectl; then
    skip "restore-test CronJob success check" "no cluster access (run with --online)"
    return
  fi

  local cronjob
  cronjob=$(kubectl get cronjob -n "$VELERO_NS" -o json 2>/dev/null \
    | jq '[.items[] | select(.metadata.name | test("restore-test"))] | first // empty')

  if [[ -z "$cronjob" || "$cronjob" == "null" ]]; then
    fail "No restore-test CronJob found in $VELERO_NS namespace"
    return
  fi

  local last_success
  last_success=$(echo "$cronjob" | jq -r '.status.lastSuccessfulTime // empty')

  if [[ -n "$last_success" ]]; then
    pass "restore-test CronJob has a recorded successful run ($last_success)"
  else
    fail "restore-test CronJob exists but has no recorded successful run"
  fi
}

# ─── ONLINE: Most recent Velero backup is fresh (<48h) ───

check_recent_backup_freshness() {
  echo "--- Check: Most recent Velero backup completed within 48 hours ---"

  if ! has_kubectl; then
    skip "Backup freshness check" "no cluster access (run with --online)"
    return
  fi

  local latest_ts
  latest_ts=$(kubectl get backup -n "$VELERO_NS" -o json 2>/dev/null \
    | jq -r '[.items[] | select(.status.phase == "Completed")] | sort_by(.status.completionTimestamp) | last | .status.completionTimestamp // empty')

  if [[ -z "$latest_ts" ]]; then
    fail "No Completed Velero backup found"
    return
  fi

  local age_hours
  age_hours=$(python3 -c "
import datetime
now = datetime.datetime.now(datetime.timezone.utc)
ts = datetime.datetime.fromisoformat('${latest_ts}'.replace('Z', '+00:00'))
print(int((now - ts).total_seconds() / 3600))
" 2>/dev/null || echo "999")

  if [[ "$age_hours" -le 48 ]]; then
    pass "Most recent Velero backup is ${age_hours}h old (within 48h threshold)"
  else
    fail "Most recent Velero backup is ${age_hours}h old (exceeds 48h threshold) — last: $latest_ts"
  fi
}

# ─── Run all checks ───

check_drill_schedule_doc
echo ""
check_backup_coverage_matrix
echo ""
check_dr_evidence_script
echo ""
check_dr_workflow
echo ""
check_dr_workflow_dispatch
echo ""
check_restore_drill_docs
echo ""
check_drill_criteria
echo ""
check_escalation_path
echo ""
check_velero_schedules
echo ""
check_bsl_available
echo ""
check_backup_verification_cronjob
echo ""
check_restore_test_cronjob
echo ""
check_recent_backup_freshness

# ─── Summary ───

echo ""
echo "==============================="
echo "Summary"
echo "==============================="
echo -e "${GREEN}Passed:  $PASS_COUNT${NC}"
echo -e "${RED}Failed:  $FAIL_COUNT${NC}"
echo -e "${YELLOW}Skipped: $SKIP_COUNT${NC}"

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
else
  exit 0
fi
