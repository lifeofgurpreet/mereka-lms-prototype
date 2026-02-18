#!/usr/bin/env bash
# @covers AC-MFE-001, AC-MFE-002, AC-MFE-003, AC-MFE-004, AC-MFE-005
# @spec: mfe-branding-customization_spec.md
# run-branding-evidence-pipeline.sh — Release evidence pipeline for branding + MFE QA
#
# Runs all branding verification scripts, collects artifacts into a timestamped
# directory, and produces a markdown summary report suitable for release notes.
#
# Usage:
#   ./scripts/qa/run-branding-evidence-pipeline.sh [--env prod|dev]
#   RETENTION_DAYS=30 ./scripts/qa/run-branding-evidence-pipeline.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ENV="${1:-prod}"
[[ "$ENV" == "--env" ]] && ENV="${2:-prod}"

STAMP="$(date -u +%Y%m%d-%H%M%S)"
EVIDENCE_DIR="var/evidence/branding/${STAMP}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
SUMMARY_FILE="${EVIDENCE_DIR}/SUMMARY.md"

mkdir -p "$EVIDENCE_DIR"

echo "=== Branding Evidence Pipeline ==="
echo "Environment: $ENV"
echo "Evidence dir: $EVIDENCE_DIR"
echo "Retention: ${RETENTION_DAYS} days"
echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

total_pass=0
total_fail=0
total_warn=0
gate_results=()

run_gate() {
  local name="$1"; shift
  local log_file="${EVIDENCE_DIR}/${name}.log"
  local rc=0

  echo -n "Running: ${name}... "

  set +e
  timeout 300 "$@" > "$log_file" 2>&1
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo "OK"
    gate_results+=("| ${name} | PASS | [log](${name}.log) |")
    total_pass=$((total_pass + 1))
  elif [[ "$rc" -eq 124 ]]; then
    echo "TIMEOUT"
    gate_results+=("| ${name} | TIMEOUT | [log](${name}.log) |")
    total_fail=$((total_fail + 1))
  else
    echo "FAIL (exit $rc)"
    gate_results+=("| ${name} | FAIL | [log](${name}.log) |")
    total_fail=$((total_fail + 1))
  fi
}

# --- Gate 1: MFE Route Smoke ---
run_gate "mfe-route-smoke" \
  ./scripts/qa/verify-mfe-route-smoke.sh --env "$ENV" --json

# --- Gate 2: Tenant Branding Runtime ---
run_gate "tenant-branding-runtime" \
  ./scripts/qa/verify-tenant-branding-runtime.sh --env "$ENV"

# --- Gate 3: MFE Route Contract ---
run_gate "mfe-route-contract" \
  ./scripts/qa/verify-mfe-route-contract.sh

# --- Gate 4: MFE Route Drift ---
run_gate "mfe-route-drift" \
  ./scripts/qa/verify-mfe-route-drift.sh

# --- Gate 5: Multisite Governance ---
run_gate "multisite-governance" \
  ./scripts/qa/run-multisite-governance-gates.sh --env "$ENV"

# --- Generate Summary Report ---
cat > "$SUMMARY_FILE" <<EOF
# Branding Evidence Report

**Generated**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Environment**: ${ENV}
**Pipeline**: run-branding-evidence-pipeline.sh
**Commit**: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
**Branch**: $(git branch --show-current 2>/dev/null || echo "unknown")

## Gate Results

| Gate | Status | Log |
|------|--------|-----|
$(printf '%s\n' "${gate_results[@]}")

## Failure Taxonomy

| Failure Type | Remediation Owner | Priority | ETA |
|-------------|-------------------|----------|-----|
| MFE dist directory missing | Build engineer | P2 | Next image build |
| SITE_NAME fallback to default | Tenant admin | P3 | branding_config population |
| Brand color tokens absent | Tenant admin | P3 | branding_config population |
| Selector override expired | Frontend lead | P2 | Plugin-slot migration |
| Route 404 on live endpoint | DevOps | P1 | Immediate investigation |

## Artifact Inventory

$(ls -1 "$EVIDENCE_DIR" | sed 's/^/- /')

## Retention Policy

Evidence directories are retained for ${RETENTION_DAYS} days.
Cleanup: \`find var/evidence/branding -maxdepth 1 -mtime +${RETENTION_DAYS} -exec rm -rf {} +\`
EOF

echo ""
echo "=== Summary ==="
echo "Gates run: ${#gate_results[@]}"
echo "Passed: $total_pass"
echo "Failures: $total_fail"
echo "Evidence: $EVIDENCE_DIR"
echo "Report: $SUMMARY_FILE"

# --- Cleanup old evidence ---
if [[ -d "var/evidence/branding" ]]; then
  find var/evidence/branding -maxdepth 1 -mindepth 1 -mtime +${RETENTION_DAYS} -exec rm -rf {} + 2>/dev/null || true
fi

echo ""
if [[ "$total_fail" -eq 0 ]]; then
  echo "ALL GATES PASSED"
  exit 0
else
  echo "GATES FAILED: $total_fail"
  exit 1
fi
