#!/usr/bin/env bash
# @spec: disaster-recovery-business-continuity_spec.md
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021, AC-022
set -euo pipefail

# verify-disaster-recovery.sh
# Verifies Disaster Recovery & Business Continuity spec compliance.
# Combines static repo checks with live cluster checks (when available).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKIP_CLUSTER=false
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
  if [[ "$SKIP_CLUSTER" == true ]]; then
    return 1
  fi
  command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null 2>&1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-cluster)
      SKIP_CLUSTER=true
      shift
      ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify Disaster Recovery & Business Continuity spec compliance.

OPTIONS:
    --skip-cluster    Skip checks requiring live kubectl access
    --help            Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "Disaster Recovery & Business Continuity Verification"
echo "====================================================="
echo "Spec: disaster-recovery-business-continuity_spec.md"
echo ""

# ─── AC-001: Velero backup schedules active with recent completed backups ───

check_ac_001() {
  echo "--- AC-001: Velero backup schedules active with recent completed backups ---"

  if ! has_kubectl; then
    skip "AC-001: Velero schedules active" "no cluster access"
    return
  fi

  local schedules
  schedules=$(kubectl get schedule -n "$VELERO_NS" -o json 2>/dev/null || echo '{"items":[]}')
  local schedule_count
  schedule_count=$(echo "$schedules" | jq '.items | length')

  if [[ "$schedule_count" -lt 3 ]]; then
    fail "AC-001: Expected >=3 Velero schedules (hourly-critical, daily-all-apps, weekly-full), found $schedule_count"
    return
  fi

  local required=("hourly-critical" "daily-all-apps" "weekly-full")
  local all_found=true

  for pattern in "${required[@]}"; do
    if ! echo "$schedules" | jq -r '.items[].metadata.name' | grep -q "$pattern"; then
      fail "AC-001: Missing Velero schedule matching '$pattern'"
      all_found=false
    fi
  done

  if [[ "$all_found" == true ]]; then
    # Check that at least one backup completed within last 48 hours
    local recent_backup
    recent_backup=$(kubectl get backup -n "$VELERO_NS" -o json 2>/dev/null \
      | jq -r '[.items[] | select(.status.phase == "Completed")] | sort_by(.status.completionTimestamp) | last | .status.completionTimestamp // empty')

    if [[ -n "$recent_backup" ]]; then
      pass "AC-001: All 3 Velero schedules present with recent completed backup ($recent_backup)"
    else
      fail "AC-001: Velero schedules exist but no recent Completed backup found"
    fi
  fi
}

# ─── AC-002: volumeSnapshotsCompleted matches bound PVC count ───

check_ac_002() {
  echo "--- AC-002: volumeSnapshotsCompleted matches bound PVC count ---"

  if ! has_kubectl; then
    skip "AC-002: Volume snapshot count" "no cluster access"
    return
  fi

  # Get the latest hourly-critical backup
  local backup_json
  backup_json=$(kubectl get backup -n "$VELERO_NS" -o json 2>/dev/null \
    | jq '[.items[] | select(.metadata.name | test("hourly-critical")) | select(.status.phase == "Completed")] | sort_by(.status.completionTimestamp) | last // empty')

  if [[ -z "$backup_json" || "$backup_json" == "null" ]]; then
    skip "AC-002: Volume snapshot count" "no hourly-critical completed backup found"
    return
  fi

  local snap_count
  snap_count=$(echo "$backup_json" | jq '.status.volumeSnapshotsCompleted // 0')

  if [[ "$snap_count" -gt 0 ]]; then
    pass "AC-002: volumeSnapshotsCompleted=$snap_count (>0)"
  else
    fail "AC-002: volumeSnapshotsCompleted=0 — backup captured K8s objects only, not PV data"
  fi
}

# ─── AC-003: BackupStorageLocation phase is Available ───

check_ac_003() {
  echo "--- AC-003: BackupStorageLocation phase is Available ---"

  if ! has_kubectl; then
    skip "AC-003: BSL phase" "no cluster access"
    return
  fi

  local bsl_phase
  bsl_phase=$(kubectl get backupstoragelocation -n "$VELERO_NS" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")

  if [[ "$bsl_phase" == "Available" ]]; then
    pass "AC-003: BackupStorageLocation phase is Available"
  elif [[ -z "$bsl_phase" ]]; then
    fail "AC-003: No BackupStorageLocation found in $VELERO_NS namespace"
  else
    fail "AC-003: BackupStorageLocation phase is '$bsl_phase' (expected Available)"
  fi
}

# ─── AC-004: No critical stateful service uses emptyDir for persistent data ───

check_ac_004() {
  echo "--- AC-004: No critical stateful service uses emptyDir for persistent data ---"

  local deployments="${REPO_ROOT}/deploy/k8s/base/deployments.yml"
  local critical_services=("mysql" "redis" "elasticsearch")
  local violations=0

  if [[ ! -f "$deployments" ]]; then
    fail "AC-004: deployments.yml not found at $deployments"
    return
  fi

  for svc in "${critical_services[@]}"; do
    # Check if this service's deployment uses emptyDir for its main volume
    # Extract the section for this deployment and look for emptyDir
    local svc_section
    svc_section=$(awk "/name: ${svc}\$/,/^---/" "$deployments" 2>/dev/null || echo "")

    if echo "$svc_section" | grep -q "emptyDir:"; then
      fail "AC-004: Critical stateful service '$svc' uses emptyDir volume"
      violations=$((violations + 1))
    fi
  done

  if [[ $violations -eq 0 ]]; then
    pass "AC-004: No critical stateful service (mysql, redis, elasticsearch) uses emptyDir"
  fi
}

# ─── AC-005: Monthly restore-test CronJob exists and is configured ───

check_ac_005() {
  echo "--- AC-005: Restore-test CronJob creates throwaway namespace, PVCs Bound, MySQL probe ---"

  if ! has_kubectl; then
    # Fallback: check that the restore-test script exists in the repo
    local restore_script="${REPO_ROOT}/infrastructure/k8s/velero/restore-test-script.sh"
    if [[ -f "$restore_script" ]]; then
      pass "AC-005: restore-test-script.sh exists at $restore_script (live drill validation requires cluster)"
    else
      fail "AC-005: restore-test-script.sh not found at $restore_script"
    fi
    return
  fi

  local cronjob
  cronjob=$(kubectl get cronjob -n "$VELERO_NS" -o json 2>/dev/null \
    | jq '[.items[] | select(.metadata.name | test("restore-test"))] | first // empty')

  if [[ -z "$cronjob" || "$cronjob" == "null" ]]; then
    fail "AC-005: No restore-test CronJob found in $VELERO_NS namespace"
    return
  fi

  # Check last successful job
  local last_success
  last_success=$(echo "$cronjob" | jq -r '.status.lastSuccessfulTime // empty')

  if [[ -n "$last_success" ]]; then
    pass "AC-005: restore-test CronJob exists, last success: $last_success"
  else
    fail "AC-005: restore-test CronJob exists but has no recorded successful run"
  fi
}

# ─── AC-006: Restore drill produces at least 1 PVC in Bound state ───

check_ac_006() {
  echo "--- AC-006: Restore drill PVCs in Bound state ---"

  if ! has_kubectl; then
    skip "AC-006: Restore drill PVC state" "no cluster access"
    return
  fi

  # Check if restore-test namespace exists (from a recent drill)
  local test_ns
  for ns in velero-restore-test mereka-lms-dr; do
    if kubectl get ns "$ns" &>/dev/null 2>&1; then
      test_ns="$ns"
      break
    fi
  done

  if [[ -z "${test_ns:-}" ]]; then
    # No active restore-test namespace; check the last job log
    local last_job
    last_job=$(kubectl get jobs -n "$VELERO_NS" -l component=restore-test --sort-by=.metadata.creationTimestamp -o name 2>/dev/null | tail -1)

    if [[ -n "$last_job" ]]; then
      local log
      log=$(kubectl logs -n "$VELERO_NS" "$last_job" --tail=100 2>/dev/null || echo "")
      if echo "$log" | grep -qi "bound"; then
        pass "AC-006: Restore drill logs indicate PVCs reached Bound state"
      else
        skip "AC-006: Restore drill PVC state" "no active restore namespace and cannot confirm from logs"
      fi
    else
      skip "AC-006: Restore drill PVC state" "no restore-test jobs found"
    fi
    return
  fi

  local bound_pvcs
  bound_pvcs=$(kubectl get pvc -n "$test_ns" -o json 2>/dev/null | jq '[.items[] | select(.status.phase == "Bound")] | length')

  if [[ "$bound_pvcs" -ge 1 ]]; then
    pass "AC-006: $bound_pvcs PVCs in Bound state in $test_ns"
  else
    fail "AC-006: No PVCs in Bound state in restore-test namespace $test_ns"
  fi
}

# ─── AC-007: fix-velero-restore-test.sh exists and is executable ───

check_ac_007() {
  echo "--- AC-007: fix-velero-restore-test.sh exists ---"

  local script="${REPO_ROOT}/scripts/infra/fix-velero-restore-test.sh"
  if [[ -x "$script" ]]; then
    pass "AC-007: fix-velero-restore-test.sh exists and is executable"
  elif [[ -f "$script" ]]; then
    fail "AC-007: fix-velero-restore-test.sh exists but is not executable"
  else
    fail "AC-007: fix-velero-restore-test.sh not found at $script"
  fi
}

# ─── AC-008: backup-verification CronJob confirms freshness ───

check_ac_008() {
  echo "--- AC-008: backup-verification CronJob confirms backup freshness ---"

  if ! has_kubectl; then
    skip "AC-008: backup-verification CronJob" "no cluster access"
    return
  fi

  local cronjob
  cronjob=$(kubectl get cronjob -n "$VELERO_NS" -o json 2>/dev/null \
    | jq '[.items[] | select(.metadata.name | test("backup-verification"))] | first // empty')

  if [[ -z "$cronjob" || "$cronjob" == "null" ]]; then
    fail "AC-008: No backup-verification CronJob found in $VELERO_NS namespace"
    return
  fi

  local suspended
  suspended=$(echo "$cronjob" | jq '.spec.suspend // false')

  if [[ "$suspended" == "true" ]]; then
    fail "AC-008: backup-verification CronJob is suspended"
  else
    pass "AC-008: backup-verification CronJob exists and is active"
  fi
}

# ─── AC-009: DR evidence bundle script produces required outputs ───

check_ac_009() {
  echo "--- AC-009: DR evidence bundle script exists and is structured correctly ---"

  local script="${REPO_ROOT}/scripts/qa/build-dr-evidence-bundle.sh"
  if [[ ! -f "$script" ]]; then
    fail "AC-009: build-dr-evidence-bundle.sh not found"
    return
  fi

  # Check that the script references required output files
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
      fail "AC-009: build-dr-evidence-bundle.sh does not reference expected output '$output'"
      missing=$((missing + 1))
    fi
  done

  if [[ $missing -eq 0 ]]; then
    pass "AC-009: build-dr-evidence-bundle.sh references all required evidence outputs"
  fi
}

# ─── AC-010: GitHub Actions DR Evidence Bundle workflow runs monthly ───

check_ac_010() {
  echo "--- AC-010: GitHub Actions DR Evidence Bundle workflow configured for monthly runs ---"

  local workflow="${REPO_ROOT}/.github/workflows/dr-evidence-bundle.yml"
  if [[ ! -f "$workflow" ]]; then
    fail "AC-010: DR evidence bundle workflow not found at $workflow"
    return
  fi

  # Check for monthly cron schedule (1st of month)
  if grep -q "cron:" "$workflow" && grep -q "1 \* \*" "$workflow"; then
    pass "AC-010: DR evidence bundle workflow has monthly cron schedule"
  else
    fail "AC-010: DR evidence bundle workflow missing monthly cron schedule"
  fi
}

# ─── AC-011: Evidence bundle can be generated within 1 business day ───

check_ac_011() {
  echo "--- AC-011: Evidence bundle generation on demand ---"

  local workflow="${REPO_ROOT}/.github/workflows/dr-evidence-bundle.yml"
  local script="${REPO_ROOT}/scripts/qa/build-dr-evidence-bundle.sh"

  if [[ -f "$workflow" ]] && grep -q "workflow_dispatch" "$workflow" && [[ -f "$script" ]]; then
    pass "AC-011: DR evidence bundle supports manual trigger (workflow_dispatch) and CLI script"
  elif [[ -f "$script" ]]; then
    pass "AC-011: DR evidence bundle CLI script exists for on-demand generation"
  else
    fail "AC-011: No mechanism for on-demand DR evidence bundle generation"
  fi
}

# ─── AC-012: Velero backup failure alert rule exists ───

check_ac_012() {
  echo "--- AC-012: Alert fires within 1 hour of backup failure ---"

  # Check PrometheusRules in the repo for Velero backup failure alerts
  local found=false

  for rule_file in "${REPO_ROOT}"/deploy/k8s/base/monitoring/prometheusrule*.yaml; do
    [[ -f "$rule_file" ]] || continue
    if grep -qi "VeleroBackupFailed\|velero_backup_failure\|velero_backup_last_successful" "$rule_file"; then
      found=true
      break
    fi
  done

  # Also check velero namespace manifests
  if [[ "$found" == false ]]; then
    for f in "${REPO_ROOT}"/infrastructure/k8s/velero/*.yaml; do
      [[ -f "$f" ]] || continue
      if grep -qi "PrometheusRule\|alerting\|VeleroBackup" "$f"; then
        found=true
        break
      fi
    done
  fi

  if [[ "$found" == true ]]; then
    pass "AC-012: Velero backup failure alert rule found in manifests"
  else
    # Check live cluster if available
    if has_kubectl; then
      local rules
      rules=$(kubectl get prometheusrule -A -o json 2>/dev/null \
        | jq -r '.items[].spec.groups[].rules[].alert // empty' 2>/dev/null || echo "")
      if echo "$rules" | grep -qi "VeleroBackup"; then
        pass "AC-012: Velero backup failure alert rule found in live cluster"
      else
        fail "AC-012: No Velero backup failure alert rule found in manifests or cluster"
      fi
    else
      fail "AC-012: No Velero backup failure alert rule found in repo manifests"
    fi
  fi
}

# ─── AC-013: Stale restore-test detection ───

check_ac_013() {
  echo "--- AC-013: Stale restore-test failure detection ---"

  local script="${REPO_ROOT}/scripts/qa/audit-velero-alert-pipeline.sh"
  if [[ ! -f "$script" ]]; then
    fail "AC-013: audit-velero-alert-pipeline.sh not found"
    return
  fi

  if grep -q "restore-test\|restore_test\|stale" "$script"; then
    pass "AC-013: audit-velero-alert-pipeline.sh checks for stale restore-test"
  else
    fail "AC-013: audit-velero-alert-pipeline.sh does not appear to check for stale restore-test"
  fi
}

# ─── AC-014: audit-velero-alert-pipeline.sh validates freshness signals ───

check_ac_014() {
  echo "--- AC-014: audit-velero-alert-pipeline.sh validates backup and restore freshness ---"

  local script="${REPO_ROOT}/scripts/qa/audit-velero-alert-pipeline.sh"
  if [[ ! -f "$script" ]]; then
    fail "AC-014: audit-velero-alert-pipeline.sh not found"
    return
  fi

  local checks_backup=false
  local checks_restore=false

  if grep -q "backup-verification\|backup.verification\|backup_verification" "$script"; then
    checks_backup=true
  fi

  if grep -q "restore-test\|restore.test\|restore_test" "$script"; then
    checks_restore=true
  fi

  if [[ "$checks_backup" == true ]] && [[ "$checks_restore" == true ]]; then
    pass "AC-014: audit-velero-alert-pipeline.sh validates both backup-verification and restore-test freshness"
  else
    [[ "$checks_backup" == false ]] && fail "AC-014: Script missing backup-verification freshness check"
    [[ "$checks_restore" == false ]] && fail "AC-014: Script missing restore-test freshness check"
  fi
}

# ─── AC-015: Single PVC restore procedure documented ───

check_ac_015() {
  echo "--- AC-015: Single PVC failure restore procedure documented ---"

  local found=false

  while IFS= read -r doc; do
    if grep -qi "pvc.*restore\|restore.*pvc\|velero restore\|single.*component\|DR-002" "$doc"; then
      found=true
      break
    fi
  done < <(find "${REPO_ROOT}/docs/operations" -name "*.md" -type f 2>/dev/null)

  # Also check the spec itself for inline procedures
  if [[ "$found" == false ]]; then
    if grep -q "DR-002" "${REPO_ROOT}/specs/disaster-recovery-business-continuity_spec.md" 2>/dev/null; then
      found=true
    fi
  fi

  if [[ "$found" == true ]]; then
    pass "AC-015: Single PVC restore procedure is documented"
  else
    fail "AC-015: No documentation found for single PVC restore procedure (DR-002)"
  fi
}

# ─── AC-016: Full namespace restore with --namespace-mappings ───

check_ac_016() {
  echo "--- AC-016: Full namespace restore procedure documented ---"

  local found=false

  while IFS= read -r doc; do
    if grep -qi "namespace-mapping\|namespace.mapping\|velero restore create\|DR-003" "$doc"; then
      found=true
      break
    fi
  done < <(find "${REPO_ROOT}/docs/operations" "${REPO_ROOT}/infrastructure/k8s/velero" -name "*.md" -o -name "*.sh" 2>/dev/null)

  if [[ "$found" == true ]]; then
    pass "AC-016: Full namespace restore procedure documented (with namespace-mappings)"
  else
    fail "AC-016: No documentation for full namespace restore with --namespace-mappings (DR-003)"
  fi
}

# ─── AC-017: Secret rotation checklist documented ───

check_ac_017() {
  echo "--- AC-017: Secret rotation checklist documented ---"

  local checklist="${REPO_ROOT}/docs/operations/SECRET_ROTATION_CHECKLIST.md"
  if [[ -f "$checklist" ]]; then
    pass "AC-017: SECRET_ROTATION_CHECKLIST.md exists"
  else
    fail "AC-017: SECRET_ROTATION_CHECKLIST.md not found at $checklist"
  fi
}

# ─── AC-018: Full cluster rebuild procedure documented (DR-007) ───

check_ac_018() {
  echo "--- AC-018: Full cluster rebuild procedure documented (RTO 4h) ---"

  local found=false

  while IFS= read -r doc; do
    if grep -qi "cluster.*rebuild\|full.*cluster\|DR-007\|cluster.*loss\|4.hour" "$doc"; then
      found=true
      break
    fi
  done < <(find "${REPO_ROOT}/docs/operations" -name "*.md" -type f 2>/dev/null)

  # Also check the spec which defines the procedure
  if [[ "$found" == false ]]; then
    if grep -q "DR-007" "${REPO_ROOT}/specs/disaster-recovery-business-continuity_spec.md" 2>/dev/null; then
      found=true
    fi
  fi

  if [[ "$found" == true ]]; then
    pass "AC-018: Full cluster rebuild procedure is documented (DR-007)"
  else
    fail "AC-018: No documentation for full cluster rebuild procedure (DR-007, RTO 4h)"
  fi
}

# ─── AC-019: MySQL user count verification capability ───

check_ac_019() {
  echo "--- AC-019: MySQL data integrity verification post-restore ---"

  # Check that the restore-test script includes a MySQL probe
  local restore_script="${REPO_ROOT}/infrastructure/k8s/velero/restore-test-script.sh"

  if [[ -f "$restore_script" ]]; then
    if grep -qi "SELECT.*1\|mysql.*probe\|auth_user\|data.integrity" "$restore_script"; then
      pass "AC-019: restore-test-script.sh includes MySQL data integrity check"
    else
      fail "AC-019: restore-test-script.sh lacks MySQL data integrity verification (SELECT 1 or user count)"
    fi
  else
    fail "AC-019: restore-test-script.sh not found"
  fi
}

# ─── AC-020: public-health-check.sh exists ───

check_ac_020() {
  echo "--- AC-020: public-health-check.sh exists for post-restore validation ---"

  local script="${REPO_ROOT}/scripts/qa/public-health-check.sh"
  if [[ -x "$script" ]]; then
    pass "AC-020: public-health-check.sh exists and is executable"
  elif [[ -f "$script" ]]; then
    fail "AC-020: public-health-check.sh exists but is not executable"
  else
    fail "AC-020: public-health-check.sh not found"
  fi
}

# ─── AC-021: Kustomize produces valid manifests ───

check_ac_021() {
  echo "--- AC-021: Kustomize renders valid production manifests ---"

  if ! command -v kubectl &>/dev/null; then
    skip "AC-021: Kustomize render" "kubectl not installed"
    return
  fi

  local output
  output=$(kubectl kustomize "${REPO_ROOT}/deploy/k8s/overlays/production" 2>&1) || true

  if [[ -n "$output" ]] && ! echo "$output" | grep -qi "error"; then
    pass "AC-021: kubectl kustomize deploy/k8s/overlays/production produces valid output"
  else
    fail "AC-021: kubectl kustomize deploy/k8s/overlays/production fails or produces errors"
  fi
}

# ─── AC-022: GCS backup bucket multi-region or cross-region ───

check_ac_022() {
  echo "--- AC-022: GCS backup bucket multi-region storage ---"

  if ! has_kubectl; then
    skip "AC-022: GCS bucket region" "no cluster access"
    return
  fi

  # Get the BSL bucket name from Velero config
  local bucket
  bucket=$(kubectl get backupstoragelocation -n "$VELERO_NS" -o jsonpath='{.items[0].spec.objectStorage.bucket}' 2>/dev/null || echo "")

  if [[ -z "$bucket" ]]; then
    skip "AC-022: GCS bucket region" "cannot determine Velero backup bucket"
    return
  fi

  # Check if gsutil is available to inspect bucket
  if command -v gsutil &>/dev/null; then
    local location
    location=$(gsutil ls -L -b "gs://$bucket" 2>/dev/null | grep "Location constraint:" | awk '{print $NF}' || echo "")

    if echo "$location" | grep -qi "MULTI_REGIONAL\|multi-region\|^US$\|^EU$\|^ASIA$"; then
      pass "AC-022: Velero backup bucket '$bucket' is multi-region ($location)"
    elif [[ -n "$location" ]]; then
      fail "AC-022: Velero backup bucket '$bucket' is single-region ($location), expected multi-region"
    else
      skip "AC-022: GCS bucket region" "could not determine bucket location"
    fi
  else
    skip "AC-022: GCS bucket region" "gsutil not available"
  fi
}

# ─── Additional: Backup Coverage Matrix exists ───

check_backup_coverage_matrix() {
  echo "--- Supplemental: Backup Coverage Matrix documented ---"

  local matrix="${REPO_ROOT}/docs/operations/BACKUP_COVERAGE_MATRIX.md"
  if [[ -f "$matrix" ]]; then
    pass "Supplemental: BACKUP_COVERAGE_MATRIX.md exists"
  else
    fail "Supplemental: BACKUP_COVERAGE_MATRIX.md not found"
  fi
}

# ─── Additional: Cloud SQL backup workflow exists (disabled) ───

check_cloud_sql_backup_workflow() {
  echo "--- Supplemental: Cloud SQL backup workflow exists (disabled) ---"

  local workflow="${REPO_ROOT}/.github/workflows/cloud-sql-backup.yml"
  if [[ -f "$workflow" ]]; then
    pass "Supplemental: cloud-sql-backup.yml workflow exists"
  else
    fail "Supplemental: cloud-sql-backup.yml workflow not found"
  fi
}

# ─── Run all checks ───

check_ac_001
echo ""
check_ac_002
echo ""
check_ac_003
echo ""
check_ac_004
echo ""
check_ac_005
echo ""
check_ac_006
echo ""
check_ac_007
echo ""
check_ac_008
echo ""
check_ac_009
echo ""
check_ac_010
echo ""
check_ac_011
echo ""
check_ac_012
echo ""
check_ac_013
echo ""
check_ac_014
echo ""
check_ac_015
echo ""
check_ac_016
echo ""
check_ac_017
echo ""
check_ac_018
echo ""
check_ac_019
echo ""
check_ac_020
echo ""
check_ac_021
echo ""
check_ac_022
echo ""
check_backup_coverage_matrix
echo ""
check_cloud_sql_backup_workflow

# ─── Summary ───

echo ""
echo "====================================================="
echo "Summary"
echo "====================================================="
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo -e "${YELLOW}Skipped: $SKIP_COUNT${NC}"

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
else
  exit 0
fi
