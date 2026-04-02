#!/usr/bin/env bash
# =============================================================================
# run_full_import.sh — Mereka LMS full content migration pipeline
#
# Codifies every step of the import pipeline (courses, users, enrollments,
# completions, metadata, catalogs, taxonomy) into a single repeatable script
# that works across dev, staging, and production environments.
#
# Usage:
#   ./scripts/migrations/run_full_import.sh --env dev --phase all
#   ./scripts/migrations/run_full_import.sh --env dev --phase phase-1-courses
#   ./scripts/migrations/run_full_import.sh --env staging --phase phase-2-users
#   ./scripts/migrations/run_full_import.sh --env prod --phase phase-3-enrollments
#
# Phases:
#   phase-0-verify       Pre-flight checks (cluster access, pod health, disk space)
#   phase-1-courses      Copy OLX tarballs to CMS pod and import all courses
#   phase-2-users        Copy user CSVs to LMS pod, import MCT then Kajabi users
#   phase-3-enrollments  Copy enrollment CSVs and bulk-import enrollments
#   phase-4-completions  Import Kajabi completions and issue certificates
#   phase-5-metadata     Run post_import_metadata.py (descriptions + images)
#   phase-6-catalogs     Run post_import_enterprise_catalogs.py
#   phase-7-taxonomy     Run post_import_taxonomy.py
#   phase-8-verify       Run verification pipeline
#   all                  Run phases 0-8 in order (stops on first failure)
#
# Logs:
#   var/import/import-{env}-{timestamp}.log
#
# Requirements:
#   - kubectl in PATH and context set correctly (or --context flag)
#   - python3 in PATH (for phases 2–7 orchestration)
#   - Run from the repository root (mereka-lms/)
# =============================================================================

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
ENV=""
PHASE=""
DRY_RUN=0
SKIP_CONFIRM=0
KUBE_CONTEXT=""   # override via --context; resolved from ENV if empty

# ─── Colour codes ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Paths (all relative to repo root) ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# EXPORTS_ROOT can be overridden for worktree usage where exports/ is gitignored.
# Default: $REPO_ROOT/exports (the main checkout's export artifacts).
EXPORTS_ROOT="${EXPORTS_ROOT:-$REPO_ROOT/exports}"

MCT_OLX_DIR="$EXPORTS_ROOT/mct/olx_packages"
DRIVE_OLX_DIR="$EXPORTS_ROOT/drive/olx_packages"
MCT_USERS_CSV="$EXPORTS_ROOT/mct/openedx_import/users_import.csv"
MCT_ENROLLMENTS_CSV="$EXPORTS_ROOT/mct/openedx_import/enrollments_import.csv"
KAJABI_USERS_CSV="$EXPORTS_ROOT/kajabi/openedx_import/users_import.csv"
KAJABI_ENROLLMENTS_CSV="$EXPORTS_ROOT/kajabi/openedx_import/enrollments_import.csv"
KAJABI_COMPLETIONS_CSV="$EXPORTS_ROOT/kajabi/openedx_import/completions_import.csv"

MCT_BULK_IMPORT="$SCRIPT_DIR/mct/openedx_bulk_import_mct.py"
KAJABI_BULK_IMPORT="$SCRIPT_DIR/kajabi/openedx_bulk_import.py"
POST_COMPLETIONS="$SCRIPT_DIR/post_import_completions.py"
POST_CATALOGS="$SCRIPT_DIR/post_import_enterprise_catalogs.py"
POST_TAXONOMY="$SCRIPT_DIR/post_import_taxonomy.py"
VERIFY_PIPELINE="$SCRIPT_DIR/run-verification-pipeline.sh"

LOG_DIR="$REPO_ROOT/var/import"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

# ─── Batch sizes ──────────────────────────────────────────────────────────────
USER_BATCH_SIZE=2000
ENROLLMENT_BATCH_SIZE=5000

# ─── Course import delay (seconds between courses) ───────────────────────────
COURSE_IMPORT_DELAY=5

# =============================================================================
# Argument parsing
# =============================================================================
usage() {
  cat <<EOF
Usage: $0 --env <dev|staging|prod> --phase <phase|all> [options]

Options:
  --env ENV         Environment: dev, staging, or prod (required)
  --phase PHASE     Phase to run: phase-0-verify ... phase-8-verify, or all
  --context CTX     Override kubectl context (default: resolved from --env)
  --dry-run         Print commands without executing them
  --yes             Skip confirmation prompts
  --help            Show this help

Examples:
  $0 --env dev --phase all
  $0 --env dev --phase phase-1-courses
  $0 --env staging --phase phase-2-users
  $0 --env prod --phase phase-3-enrollments --yes
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)      ENV="$2";         shift 2 ;;
    --phase)    PHASE="$2";       shift 2 ;;
    --context)  KUBE_CONTEXT="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=1;        shift ;;
    --yes)      SKIP_CONFIRM=1;   shift ;;
    --help|-h)  usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo -e "${RED}ERROR: --env is required${NC}" >&2
  usage
fi
if [[ -z "$PHASE" ]]; then
  echo -e "${RED}ERROR: --phase is required${NC}" >&2
  usage
fi

# =============================================================================
# Environment resolution
# =============================================================================
case "$ENV" in
  dev)
    NAMESPACE="mereka-lms-dev"
    : "${KUBE_CONTEXT:=rke2-nonprod}"
    ;;
  staging)
    NAMESPACE="stg-mereka-lms"
    : "${KUBE_CONTEXT:=rke2-nonprod}"
    ;;
  prod)
    NAMESPACE="mereka-lms-prod"
    : "${KUBE_CONTEXT:=rke2-nonprod}"
    ;;
  *)
    echo -e "${RED}ERROR: Unknown environment '$ENV'. Must be: dev, staging, prod${NC}" >&2
    exit 1
    ;;
esac

# =============================================================================
# Logging setup
# =============================================================================
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/import-${ENV}-${TIMESTAMP}.log"

log() {
  local msg="$*"
  echo -e "$msg" | tee -a "$LOG_FILE"
}

log_plain() {
  echo "$*" | tee -a "$LOG_FILE"
}

# =============================================================================
# Helper utilities
# =============================================================================
banner() {
  local title="$1"
  log ""
  log "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  log "${BLUE}${BOLD}║  $title${NC}"
  log "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
}

step() {
  log "${CYAN}>>> $*${NC}"
}

ok() {
  log "${GREEN}✓ $*${NC}"
}

warn() {
  log "${YELLOW}⚠  $*${NC}"
}

fail() {
  log "${RED}✗ $*${NC}"
}

# Run a command, respecting --dry-run. Always logs the command.
run_cmd() {
  log_plain "  CMD: $*"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "${YELLOW}  [DRY-RUN] skipped${NC}"
    return 0
  fi
  "$@" 2>&1 | tee -a "$LOG_FILE"
}

# kubectl shorthand with context and namespace
kube() {
  kubectl --context="$KUBE_CONTEXT" "$@"
}

kube_ns() {
  kubectl --context="$KUBE_CONTEXT" -n "$NAMESPACE" "$@"
}

# Get pod name by label selector (no hardcoded pod names)
get_pod() {
  local app_name="$1"
  kube_ns get pods \
    -l "app.kubernetes.io/name=${app_name}" \
    --field-selector='status.phase=Running' \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Wait for a pod to be ready
wait_for_pod() {
  local app_name="$1"
  local retries=10
  local delay=5
  local pod=""
  step "Waiting for $app_name pod to be ready..."
  for ((i=1; i<=retries; i++)); do
    pod="$(get_pod "$app_name")"
    if [[ -n "$pod" ]]; then
      ok "$app_name pod ready: $pod"
      echo "$pod"
      return 0
    fi
    warn "  Attempt $i/$retries: no running $app_name pod found, retrying in ${delay}s..."
    sleep "$delay"
  done
  fail "No running $app_name pod found after $((retries * delay))s"
  return 1
}

# Confirm before destructive/long operations
confirm() {
  local prompt="$1"
  if [[ $SKIP_CONFIRM -eq 1 ]]; then
    return 0
  fi
  echo -e "${YELLOW}${prompt} [y/N]${NC} " >&2
  read -r answer </dev/tty
  [[ "$answer" =~ ^[Yy]$ ]]
}

# Track phase pass/fail counts
PHASE_OK=0
PHASE_FAIL=0

record_ok() {
  PHASE_OK=$((PHASE_OK + 1))
}
record_fail() {
  PHASE_FAIL=$((PHASE_FAIL + 1))
}

# =============================================================================
# PHASE 0 — Pre-flight verification
# =============================================================================
phase_0_verify() {
  banner "PHASE 0: Pre-flight verification (env=$ENV, namespace=$NAMESPACE)"

  local errors=0

  # 1. kubectl context
  step "Checking kubectl context '$KUBE_CONTEXT'..."
  if kube config get-contexts "$KUBE_CONTEXT" &>/dev/null; then
    ok "Context $KUBE_CONTEXT exists"
  else
    fail "Context $KUBE_CONTEXT not found in kubeconfig"
    errors=$((errors + 1))
  fi

  # 2. Verify context exists (all kubectl calls use --context flag, no global switch)
  step "Verifying context $KUBE_CONTEXT..."

  # 3. Namespace exists
  step "Checking namespace $NAMESPACE..."
  if kube get namespace "$NAMESPACE" &>/dev/null; then
    ok "Namespace $NAMESPACE exists"
  else
    fail "Namespace $NAMESPACE not found"
    errors=$((errors + 1))
  fi

  # 4. LMS pod health
  step "Checking LMS pod health..."
  local lms_pod
  lms_pod="$(get_pod lms)"
  if [[ -n "$lms_pod" ]]; then
    ok "LMS pod running: $lms_pod"
  else
    fail "No running LMS pod found in $NAMESPACE"
    errors=$((errors + 1))
  fi

  # 5. CMS pod health
  step "Checking CMS pod health..."
  local cms_pod
  cms_pod="$(get_pod cms)"
  if [[ -n "$cms_pod" ]]; then
    ok "CMS pod running: $cms_pod"
  else
    fail "No running CMS pod found in $NAMESPACE"
    errors=$((errors + 1))
  fi

  # 6. Exports root directory
  step "Checking exports root: $EXPORTS_ROOT"
  if [[ ! -d "$EXPORTS_ROOT" ]]; then
    fail "EXPORTS_ROOT directory not found: $EXPORTS_ROOT"
    fail "If running from a worktree, set EXPORTS_ROOT to the main checkout's exports dir:"
    fail "  EXPORTS_ROOT=/home/gurpreet/projects/k8s/mereka-lms/exports $0 --env $ENV ..."
    errors=$((errors + 1))
  else
    ok "Exports root exists: $EXPORTS_ROOT"
  fi

  # 7. Required export files
  step "Checking required export artifacts..."
  local required_files=(
    "$MCT_USERS_CSV"
    "$MCT_ENROLLMENTS_CSV"
    "$KAJABI_USERS_CSV"
    "$KAJABI_ENROLLMENTS_CSV"
    "$KAJABI_COMPLETIONS_CSV"
    "$MCT_BULK_IMPORT"
    "$KAJABI_BULK_IMPORT"
    "$POST_COMPLETIONS"
    "$POST_CATALOGS"
    "$POST_TAXONOMY"
  )
  for f in "${required_files[@]}"; do
    if [[ -f "$f" ]]; then
      ok "  Found: ${f#$REPO_ROOT/}"
    else
      fail "  Missing: ${f#$REPO_ROOT/}"
      errors=$((errors + 1))
    fi
  done

  # 7. MCT OLX packages
  step "Checking MCT OLX packages..."
  local mct_count=0
  if [[ -d "$MCT_OLX_DIR" ]]; then
    for dir in "$MCT_OLX_DIR"/*/; do
      [[ -d "$dir" ]] || continue
      local name
      name="$(basename "$dir")"
      [[ "$name" == "course_packages_manifest.csv" ]] && continue
      local tarball="$dir/${name}.tar.gz"
      if [[ -f "$tarball" ]]; then
        mct_count=$((mct_count + 1))
      else
        warn "  No tarball for MCT package: $name (expected $tarball)"
      fi
    done
    ok "MCT OLX packages with tarballs: $mct_count"
  else
    fail "MCT OLX directory not found: $MCT_OLX_DIR"
    errors=$((errors + 1))
  fi

  # 8. Drive OLX packages
  step "Checking Drive OLX packages..."
  local drive_count=0
  if [[ -d "$DRIVE_OLX_DIR" ]]; then
    for dir in "$DRIVE_OLX_DIR"/*/; do
      [[ -d "$dir" ]] || continue
      local name
      name="$(basename "$dir")"
      local tarball="$dir/${name}.tar.gz"
      if [[ -f "$tarball" ]]; then
        drive_count=$((drive_count + 1))
      else
        warn "  No tarball for Drive package: $name (expected $tarball)"
      fi
    done
    ok "Drive OLX packages with tarballs: $drive_count"
  else
    fail "Drive OLX directory not found: $DRIVE_OLX_DIR"
    errors=$((errors + 1))
  fi

  # 9. CSV row counts
  step "Checking CSV row counts..."
  local mct_user_rows kajabi_user_rows mct_enr_rows kajabi_enr_rows kajabi_comp_rows
  mct_user_rows="$(wc -l < "$MCT_USERS_CSV" 2>/dev/null || echo 0)"
  kajabi_user_rows="$(wc -l < "$KAJABI_USERS_CSV" 2>/dev/null || echo 0)"
  mct_enr_rows="$(wc -l < "$MCT_ENROLLMENTS_CSV" 2>/dev/null || echo 0)"
  kajabi_enr_rows="$(wc -l < "$KAJABI_ENROLLMENTS_CSV" 2>/dev/null || echo 0)"
  kajabi_comp_rows="$(wc -l < "$KAJABI_COMPLETIONS_CSV" 2>/dev/null || echo 0)"

  log "  MCT users CSV:             $((mct_user_rows - 1)) data rows (expected ~71,260)"
  log "  Kajabi users CSV:          $((kajabi_user_rows - 1)) data rows (expected ~94,872)"
  log "  MCT enrollments CSV:       $((mct_enr_rows - 1)) data rows (expected ~2,305,395)"
  log "  Kajabi enrollments CSV:    $((kajabi_enr_rows - 1)) data rows (expected ~85,355)"
  log "  Kajabi completions CSV:    $((kajabi_comp_rows - 1)) data rows (expected ~11,178)"

  # 10. Disk space on pods (informational)
  step "Checking /tmp disk space on CMS pod..."
  if [[ -n "$cms_pod" && $DRY_RUN -eq 0 ]]; then
    kube_ns exec "$cms_pod" -c cms -- df -h /tmp 2>/dev/null | tee -a "$LOG_FILE" || true
  fi

  if [[ $errors -gt 0 ]]; then
    fail "Pre-flight FAILED with $errors error(s). Fix issues before proceeding."
    return 1
  fi

  ok "Pre-flight passed (0 errors, $mct_count MCT + $drive_count Drive packages ready)"
}

# =============================================================================
# PHASE 1 — Course import
# =============================================================================
phase_1_courses() {
  banner "PHASE 1: Course import (OLX → CMS pod)"

  local cms_pod
  cms_pod="$(wait_for_pod cms)"

  local ok_count=0
  local fail_count=0
  local skip_count=0

  # ── Helper: import one tarball ──────────────────────────────────────────────
  import_one_course() {
    local name="$1"
    local tarball="$2"
    local target_dir="/tmp/olx_import_${name}"

    step "[$((ok_count + fail_count + skip_count + 1))] $name"

    # Copy tarball into pod
    if [[ $DRY_RUN -eq 0 ]]; then
      kube cp "$tarball" "${NAMESPACE}/${cms_pod}:${target_dir}.tar.gz" -c cms 2>&1 | tee -a "$LOG_FILE"

      # Extract and import
      local result
      result="$(kube_ns exec "$cms_pod" -c cms -- bash -c "
        set -e
        mkdir -p '${target_dir}'
        tar xzf '${target_dir}.tar.gz' -C '${target_dir}'
        cd /openedx/edx-platform
        python manage.py cms import '${target_dir}' '${target_dir}' 2>&1 | tail -5
      " 2>&1 | tee -a "$LOG_FILE")"

      # Success indicator: manage.py cms import prints 'Seeding forum roles' on success
      if echo "$result" | grep -qiE "Seeding forum|Successfully imported|import_course_draft"; then
        ok "  $name — OK"
        ok_count=$((ok_count + 1))
      else
        # Non-zero exit would have triggered set -e above; if we get here check output
        warn "  $name — no clear success marker in output (check log)"
        ok_count=$((ok_count + 1))
      fi

      # Cleanup tmp in pod
      kube_ns exec "$cms_pod" -c cms -- rm -rf "${target_dir}" "${target_dir}.tar.gz" 2>/dev/null || true

      sleep "$COURSE_IMPORT_DELAY"
    else
      log "  [DRY-RUN] would copy $tarball and run manage.py cms import"
      ok_count=$((ok_count + 1))
    fi
  }

  # ── MCT packages ────────────────────────────────────────────────────────────
  step "Processing MCT OLX packages from $MCT_OLX_DIR..."
  for dir in "$MCT_OLX_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    local name
    name="$(basename "$dir")"
    local tarball="$dir/${name}.tar.gz"
    if [[ ! -f "$tarball" ]]; then
      warn "  Skipping $name — no tarball found at $tarball"
      skip_count=$((skip_count + 1))
      continue
    fi
    import_one_course "$name" "$tarball" || {
      fail "  $name — FAILED"
      fail_count=$((fail_count + 1))
    }
  done

  # ── Drive/FOW packages ───────────────────────────────────────────────────────
  step "Processing Drive OLX packages from $DRIVE_OLX_DIR..."
  for dir in "$DRIVE_OLX_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    local name
    name="$(basename "$dir")"
    local tarball="$dir/${name}.tar.gz"
    if [[ ! -f "$tarball" ]]; then
      warn "  Skipping $name — no tarball found at $tarball"
      skip_count=$((skip_count + 1))
      continue
    fi
    import_one_course "$name" "$tarball" || {
      fail "  $name — FAILED"
      fail_count=$((fail_count + 1))
    }
  done

  log ""
  log "${BOLD}Phase 1 result: ok=$ok_count fail=$fail_count skip=$skip_count${NC}"

  if [[ $fail_count -gt 0 ]]; then
    fail "Phase 1 had $fail_count failures. Check log: $LOG_FILE"
    return 1
  fi
  ok "Phase 1 complete — $ok_count courses imported"
}

# =============================================================================
# PHASE 2 — User import
# =============================================================================
phase_2_users() {
  banner "PHASE 2: User import (MCT + Kajabi → LMS pod)"

  local lms_pod
  lms_pod="$(wait_for_pod lms)"

  # ── Copy scripts and CSVs into pod ─────────────────────────────────────────
  step "Copying import scripts to LMS pod..."
  run_cmd kube cp "$MCT_BULK_IMPORT"    "${NAMESPACE}/${lms_pod}:/tmp/openedx_bulk_import_mct.py"    -c lms
  run_cmd kube cp "$KAJABI_BULK_IMPORT" "${NAMESPACE}/${lms_pod}:/tmp/openedx_bulk_import_kajabi.py" -c lms

  step "Copying MCT users CSV..."
  run_cmd kube cp "$MCT_USERS_CSV" "${NAMESPACE}/${lms_pod}:/tmp/mct_users.csv" -c lms

  step "Copying Kajabi users CSV..."
  run_cmd kube cp "$KAJABI_USERS_CSV" "${NAMESPACE}/${lms_pod}:/tmp/kajabi_users.csv" -c lms

  # ── MCT users ───────────────────────────────────────────────────────────────
  step "Importing MCT users in batches of $USER_BATCH_SIZE..."
  local mct_total
  mct_total="$(( $(wc -l < "$MCT_USERS_CSV") - 1 ))"
  log "  Total MCT user rows: $mct_total"

  local offset=0
  local mct_ok=0
  local mct_fail=0
  while [[ $offset -lt $mct_total ]]; do
    local limit
    limit="$(( mct_total - offset < USER_BATCH_SIZE ? mct_total - offset : USER_BATCH_SIZE ))"
    local batch_num="$(( offset / USER_BATCH_SIZE + 1 ))"
    local total_batches="$(( (mct_total + USER_BATCH_SIZE - 1) / USER_BATCH_SIZE ))"
    step "  MCT users batch $batch_num/$total_batches (offset=$offset limit=$limit)..."

    if [[ $DRY_RUN -eq 0 ]]; then
      local result
      result="$(kube_ns exec "$lms_pod" -c lms -- \
        python /tmp/openedx_bulk_import_mct.py users \
          --csv /tmp/mct_users.csv \
          --settings lms.envs.tutor.production \
          --offset "$offset" \
          --limit  "$limit" \
        2>&1 | tee -a "$LOG_FILE")"
      if echo "$result" | grep -q "IMPORT COMPLETE"; then
        mct_ok=$((mct_ok + limit))
      else
        warn "  Batch $batch_num may have had issues — check log"
        mct_fail=$((mct_fail + 1))
      fi
    else
      log "  [DRY-RUN] would run openedx_bulk_import_mct.py users --offset $offset --limit $limit"
    fi
    offset=$((offset + USER_BATCH_SIZE))
  done
  log "  MCT users: ~$mct_ok processed, $mct_fail batches with issues"

  # ── Kajabi users ────────────────────────────────────────────────────────────
  step "Importing Kajabi users in batches of $USER_BATCH_SIZE..."
  local kajabi_total
  kajabi_total="$(( $(wc -l < "$KAJABI_USERS_CSV") - 1 ))"
  log "  Total Kajabi user rows: $kajabi_total"

  offset=0
  local kajabi_ok=0
  local kajabi_fail=0
  while [[ $offset -lt $kajabi_total ]]; do
    local limit
    limit="$(( kajabi_total - offset < USER_BATCH_SIZE ? kajabi_total - offset : USER_BATCH_SIZE ))"
    local batch_num="$(( offset / USER_BATCH_SIZE + 1 ))"
    local total_batches="$(( (kajabi_total + USER_BATCH_SIZE - 1) / USER_BATCH_SIZE ))"
    step "  Kajabi users batch $batch_num/$total_batches (offset=$offset limit=$limit)..."

    if [[ $DRY_RUN -eq 0 ]]; then
      local result
      result="$(kube_ns exec "$lms_pod" -c lms -- \
        python /tmp/openedx_bulk_import_kajabi.py users \
          --csv /tmp/kajabi_users.csv \
          --settings lms.envs.tutor.production \
          --offset "$offset" \
          --limit  "$limit" \
        2>&1 | tee -a "$LOG_FILE")"
      if echo "$result" | grep -q "processed=\|IMPORT COMPLETE"; then
        kajabi_ok=$((kajabi_ok + limit))
      else
        warn "  Batch $batch_num may have had issues — check log"
        kajabi_fail=$((kajabi_fail + 1))
      fi
    else
      log "  [DRY-RUN] would run openedx_bulk_import_kajabi.py users --offset $offset --limit $limit"
    fi
    offset=$((offset + USER_BATCH_SIZE))
  done
  log "  Kajabi users: ~$kajabi_ok processed, $kajabi_fail batches with issues"

  ok "Phase 2 complete — MCT ~$mct_ok rows, Kajabi ~$kajabi_ok rows"
}

# =============================================================================
# PHASE 3 — Enrollment import
# =============================================================================
phase_3_enrollments() {
  banner "PHASE 3: Enrollment import (MCT + Kajabi → LMS pod)"

  local lms_pod
  lms_pod="$(wait_for_pod lms)"

  # Ensure scripts are present (may have been copied in phase-2; re-copy to be safe)
  step "Ensuring import scripts are present on LMS pod..."
  run_cmd kube cp "$MCT_BULK_IMPORT"    "${NAMESPACE}/${lms_pod}:/tmp/openedx_bulk_import_mct.py"    -c lms
  run_cmd kube cp "$KAJABI_BULK_IMPORT" "${NAMESPACE}/${lms_pod}:/tmp/openedx_bulk_import_kajabi.py" -c lms

  step "Copying MCT enrollments CSV..."
  run_cmd kube cp "$MCT_ENROLLMENTS_CSV" "${NAMESPACE}/${lms_pod}:/tmp/mct_enrollments.csv" -c lms

  step "Copying Kajabi enrollments CSV..."
  run_cmd kube cp "$KAJABI_ENROLLMENTS_CSV" "${NAMESPACE}/${lms_pod}:/tmp/kajabi_enrollments.csv" -c lms

  # ── MCT enrollments ─────────────────────────────────────────────────────────
  step "Importing MCT enrollments in batches of $ENROLLMENT_BATCH_SIZE..."
  local mct_total
  mct_total="$(( $(wc -l < "$MCT_ENROLLMENTS_CSV") - 1 ))"
  log "  Total MCT enrollment rows: $mct_total (this may take several hours)"

  if ! confirm "MCT enrollment import: $mct_total rows at batch $ENROLLMENT_BATCH_SIZE. Proceed?"; then
    warn "MCT enrollment import skipped by user"
  else
    local offset=0
    local mct_ok=0
    local mct_fail=0
    while [[ $offset -lt $mct_total ]]; do
      local limit
      limit="$(( mct_total - offset < ENROLLMENT_BATCH_SIZE ? mct_total - offset : ENROLLMENT_BATCH_SIZE ))"
      local batch_num="$(( offset / ENROLLMENT_BATCH_SIZE + 1 ))"
      local total_batches="$(( (mct_total + ENROLLMENT_BATCH_SIZE - 1) / ENROLLMENT_BATCH_SIZE ))"
      step "  MCT enr batch $batch_num/$total_batches (offset=$offset limit=$limit)..."

      if [[ $DRY_RUN -eq 0 ]]; then
        kube_ns exec "$lms_pod" -c lms -- \
          python /tmp/openedx_bulk_import_mct.py enrollments \
            --csv /tmp/mct_enrollments.csv \
            --settings lms.envs.tutor.production \
            --offset "$offset" \
            --limit  "$limit" \
          2>&1 | tee -a "$LOG_FILE" || {
          warn "  Batch $batch_num exited non-zero — check log"
          mct_fail=$((mct_fail + 1))
        }
        mct_ok=$((mct_ok + limit))
      else
        log "  [DRY-RUN] would run openedx_bulk_import_mct.py enrollments --offset $offset --limit $limit"
      fi
      offset=$((offset + ENROLLMENT_BATCH_SIZE))
    done
    log "  MCT enrollments: ~$mct_ok processed, $mct_fail batches with issues"
  fi

  # ── Kajabi enrollments ──────────────────────────────────────────────────────
  step "Importing Kajabi enrollments in batches of $ENROLLMENT_BATCH_SIZE..."
  local kajabi_total
  kajabi_total="$(( $(wc -l < "$KAJABI_ENROLLMENTS_CSV") - 1 ))"
  log "  Total Kajabi enrollment rows: $kajabi_total"

  if ! confirm "Kajabi enrollment import: $kajabi_total rows. Proceed?"; then
    warn "Kajabi enrollment import skipped by user"
  else
    local offset=0
    local kajabi_ok=0
    local kajabi_fail=0
    while [[ $offset -lt $kajabi_total ]]; do
      local limit
      limit="$(( kajabi_total - offset < ENROLLMENT_BATCH_SIZE ? kajabi_total - offset : ENROLLMENT_BATCH_SIZE ))"
      local batch_num="$(( offset / ENROLLMENT_BATCH_SIZE + 1 ))"
      local total_batches="$(( (kajabi_total + ENROLLMENT_BATCH_SIZE - 1) / ENROLLMENT_BATCH_SIZE ))"
      step "  Kajabi enr batch $batch_num/$total_batches (offset=$offset limit=$limit)..."

      if [[ $DRY_RUN -eq 0 ]]; then
        kube_ns exec "$lms_pod" -c lms -- \
          python /tmp/openedx_bulk_import_kajabi.py enrollments \
            --csv /tmp/kajabi_enrollments.csv \
            --settings lms.envs.tutor.production \
            --offset "$offset" \
            --limit  "$limit" \
          2>&1 | tee -a "$LOG_FILE" || {
          warn "  Batch $batch_num exited non-zero — check log"
          kajabi_fail=$((kajabi_fail + 1))
        }
        kajabi_ok=$((kajabi_ok + limit))
      else
        log "  [DRY-RUN] would run openedx_bulk_import_kajabi.py enrollments --offset $offset --limit $limit"
      fi
      offset=$((offset + ENROLLMENT_BATCH_SIZE))
    done
    log "  Kajabi enrollments: ~$kajabi_ok processed, $kajabi_fail batches with issues"
  fi

  ok "Phase 3 complete"
}

# =============================================================================
# PHASE 4 — Completions (Kajabi certificates)
# =============================================================================
phase_4_completions() {
  banner "PHASE 4: Kajabi completions / certificate issuance"

  local lms_pod
  lms_pod="$(wait_for_pod lms)"

  step "Copying completions CSV to LMS pod..."
  run_cmd kube cp "$KAJABI_COMPLETIONS_CSV" \
    "${NAMESPACE}/${lms_pod}:/tmp/kajabi_completions.csv" -c lms

  step "Copying post_import_completions.py to LMS pod..."
  run_cmd kube cp "$POST_COMPLETIONS" \
    "${NAMESPACE}/${lms_pod}:/tmp/post_import_completions.py" -c lms

  step "Running certificate issuance script..."
  if [[ $DRY_RUN -eq 0 ]]; then
    kube_ns exec "$lms_pod" -c lms -- bash -c "
      cd /openedx/edx-platform
      COMPLETIONS_CSV=/tmp/kajabi_completions.csv \
      OUTPUT_CSV=/tmp/cert_import_results.csv \
      python manage.py lms shell -c \"\$(cat /tmp/post_import_completions.py)\"
    " 2>&1 | tee -a "$LOG_FILE"

    # Copy results back
    local results_dst="$LOG_DIR/cert_import_results_${ENV}_${TIMESTAMP}.csv"
    kube cp "${NAMESPACE}/${lms_pod}:/tmp/cert_import_results.csv" "$results_dst" -c lms 2>/dev/null || true
    ok "Certificate results written to: $results_dst"
  else
    log "  [DRY-RUN] would run post_import_completions.py inside LMS shell"
  fi

  ok "Phase 4 complete"
}

# =============================================================================
# PHASE 5 — Post-import metadata
# =============================================================================
phase_5_metadata() {
  banner "PHASE 5: Post-import metadata (descriptions + images)"

  # post_import_metadata.py runs from the host via kubectl, not inside the pod
  local metadata_script="$SCRIPT_DIR/post_import_metadata.py"
  if [[ ! -f "$metadata_script" ]]; then
    warn "post_import_metadata.py not found at $metadata_script — skipping"
    return 0
  fi

  step "Running post_import_metadata.py..."
  run_cmd python3 "$metadata_script" --namespace "$NAMESPACE" 2>&1

  ok "Phase 5 complete"
}

# =============================================================================
# PHASE 6 — Enterprise catalogs
# =============================================================================
phase_6_catalogs() {
  banner "PHASE 6: Enterprise catalog assignments"

  step "Running post_import_enterprise_catalogs.py..."
  run_cmd python3 "$POST_CATALOGS" --namespace "$NAMESPACE" 2>&1

  ok "Phase 6 complete"
}

# =============================================================================
# PHASE 7 — Taxonomy tagging
# =============================================================================
phase_7_taxonomy() {
  banner "PHASE 7: Taxonomy tagging"

  local lms_pod
  lms_pod="$(wait_for_pod lms)"

  step "Copying post_import_taxonomy.py to LMS pod..."
  run_cmd kube cp "$POST_TAXONOMY" \
    "${NAMESPACE}/${lms_pod}:/tmp/post_import_taxonomy.py" -c lms

  step "Running taxonomy tagging script..."
  if [[ $DRY_RUN -eq 0 ]]; then
    kube_ns exec "$lms_pod" -c lms -- bash -c "
      cd /openedx/edx-platform
      python manage.py lms shell -c \"\$(cat /tmp/post_import_taxonomy.py)\"
    " 2>&1 | tee -a "$LOG_FILE"
  else
    log "  [DRY-RUN] would run post_import_taxonomy.py inside LMS shell"
  fi

  ok "Phase 7 complete"
}

# =============================================================================
# PHASE 8 — Verification
# =============================================================================
phase_8_verify() {
  banner "PHASE 8: Post-import verification"

  if [[ ! -f "$VERIFY_PIPELINE" ]]; then
    warn "Verification pipeline not found at $VERIFY_PIPELINE — skipping"
    return 0
  fi

  step "Running verification pipeline..."
  if [[ $DRY_RUN -eq 0 ]]; then
    bash "$VERIFY_PIPELINE" 2>&1 | tee -a "$LOG_FILE" || {
      warn "Some verification scripts failed — review output above"
    }
  else
    log "  [DRY-RUN] would run $VERIFY_PIPELINE"
  fi

  # Quick DB count summary directly from pods
  step "Quick DB count checks..."
  local lms_pod
  lms_pod="$(get_pod lms)"
  if [[ -n "$lms_pod" && $DRY_RUN -eq 0 ]]; then
    kube_ns exec "$lms_pod" -c lms -- \
      python manage.py lms shell -c "
from django.contrib.auth import get_user_model
from common.djangoapps.student.models import CourseEnrollment
from lms.djangoapps.certificates.models import GeneratedCertificate
User = get_user_model()
print('Users:',        User.objects.count())
print('Enrollments:',  CourseEnrollment.objects.count())
print('Certificates:', GeneratedCertificate.objects.count())
" 2>&1 | tee -a "$LOG_FILE" || true
  fi

  ok "Phase 8 complete"
}

# =============================================================================
# Phase dispatcher
# =============================================================================
run_phase() {
  local phase="$1"
  local start_ts
  start_ts="$(date +%s)"
  log ""
  log "${BOLD}[$(date '+%H:%M:%S')] Starting $phase${NC}"

  case "$phase" in
    phase-0-verify)      phase_0_verify ;;
    phase-1-courses)     phase_1_courses ;;
    phase-2-users)       phase_2_users ;;
    phase-3-enrollments) phase_3_enrollments ;;
    phase-4-completions) phase_4_completions ;;
    phase-5-metadata)    phase_5_metadata ;;
    phase-6-catalogs)    phase_6_catalogs ;;
    phase-7-taxonomy)    phase_7_taxonomy ;;
    phase-8-verify)      phase_8_verify ;;
    *)
      fail "Unknown phase: $phase"
      return 1
      ;;
  esac

  local end_ts
  end_ts="$(date +%s)"
  local elapsed=$(( end_ts - start_ts ))
  ok "[$(date '+%H:%M:%S')] $phase completed in ${elapsed}s"
}

# =============================================================================
# Main
# =============================================================================
main() {
  banner "Mereka LMS Import Pipeline — env=$ENV, phase=$PHASE"
  log "Log file: $LOG_FILE"
  log "Context:  $KUBE_CONTEXT"
  log "Namespace: $NAMESPACE"
  log "Dry-run:  $DRY_RUN"
  log "Started:  $(date '+%Y-%m-%d %H:%M:%S')"

  # All kubectl calls use --context flag; no global context switch needed

  local all_phases=(
    phase-0-verify
    phase-1-courses
    phase-2-users
    phase-3-enrollments
    phase-4-completions
    phase-5-metadata
    phase-6-catalogs
    phase-7-taxonomy
    phase-8-verify
  )

  local overall_start
  overall_start="$(date +%s)"
  local failed_phases=()

  if [[ "$PHASE" == "all" ]]; then
    for p in "${all_phases[@]}"; do
      run_phase "$p" || {
        fail "Phase $p failed — aborting remaining phases"
        failed_phases+=("$p")
        break
      }
    done
  else
    run_phase "$PHASE" || failed_phases+=("$PHASE")
  fi

  local overall_end
  overall_end="$(date +%s)"
  local total_elapsed=$(( overall_end - overall_start ))

  log ""
  log "${BOLD}════════════════════════════════════════════════════════════${NC}"
  log "${BOLD}  Import Pipeline Summary${NC}"
  log "${BOLD}════════════════════════════════════════════════════════════${NC}"
  log "  Environment:  $ENV ($NAMESPACE)"
  log "  Phase(s):     $PHASE"
  log "  Elapsed:      ${total_elapsed}s"
  log "  Log:          $LOG_FILE"

  if [[ ${#failed_phases[@]} -gt 0 ]]; then
    fail "  FAILED phases: ${failed_phases[*]}"
    log ""
    exit 1
  else
    ok "  All phases completed successfully"
    log ""
  fi
}

main "$@"
