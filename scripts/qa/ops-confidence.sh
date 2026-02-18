#!/usr/bin/env bash
# @covers AC-WC-002, AC-WC-006
# @spec: multi-site-domains_spec.md
# ops-confidence.sh — One-command operator confidence bundle
#
# Runs all verification gates and produces a unified PASS/WARN/FAIL report.
# Covers: branding runtime, MFE branding, analytics key, multisite governance,
# post-deploy smoke, and GitOps drift.
#
# Usage:
#   ./scripts/qa/ops-confidence.sh [--env prod|dev] [--evidence-dir DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="prod"
EVIDENCE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="${2:-prod}"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--env prod|dev] [--evidence-dir DIR]"
      echo ""
      echo "One-command operator confidence check covering:"
      echo "  1. verify-tenant-branding-runtime.sh"
      echo "  2. verify-mfe-branding.sh"
      echo "  3. verify-analytics-key.sh"
      echo "  4. run-multisite-governance-gates.sh"
      echo "  5. verify-post-deploy-smoke.sh"
      echo "  6. verify-gitops-drift.sh"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

GATE_PASS=0
GATE_FAIL=0
GATE_WARN=0
RESULTS=()

if [[ -n "$EVIDENCE_DIR" ]]; then
  mkdir -p "$EVIDENCE_DIR"
fi

run_gate() {
  local label="$1"
  local script="$2"
  shift 2
  local args=("$@")
  local artifact
  artifact="$(basename "$script" .sh).log"

  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "GATE: $label"
  echo "════════════════════════════════════════════════════════════════"

  local output exit_code
  output="$("$script" "${args[@]}" 2>&1)" && exit_code=0 || exit_code=$?

  echo "$output"

  if [[ -n "$EVIDENCE_DIR" ]]; then
    echo "$output" > "$EVIDENCE_DIR/$artifact"
  fi

  if [[ "$exit_code" -eq 0 ]]; then
    GATE_PASS=$((GATE_PASS + 1))
    RESULTS+=("PASS: $label")
  else
    GATE_FAIL=$((GATE_FAIL + 1))
    RESULTS+=("FAIL: $label (exit=$exit_code)")
  fi
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Operator Confidence Bundle                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "Environment: $ENV"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Evidence: ${EVIDENCE_DIR:-<none>}"

# Gate 1: Tenant branding runtime
run_gate "Tenant branding runtime" \
  "$REPO_ROOT/scripts/qa/verify-tenant-branding-runtime.sh"

# Gate 2: MFE branding
run_gate "MFE branding" \
  "$REPO_ROOT/scripts/qa/verify-mfe-branding.sh" --env "$ENV"

# Gate 3: Analytics key
if [[ -x "$REPO_ROOT/scripts/qa/verify-analytics-key.sh" ]]; then
  run_gate "Analytics key" \
    "$REPO_ROOT/scripts/qa/verify-analytics-key.sh"
else
  GATE_WARN=$((GATE_WARN + 1))
  RESULTS+=("SKIP: Analytics key (script not found)")
  echo ""
  echo "SKIP: verify-analytics-key.sh not found"
fi

# Gate 4: Multisite governance gates
if [[ -x "$REPO_ROOT/scripts/qa/run-multisite-governance-gates.sh" ]]; then
  run_gate "Multisite governance" \
    "$REPO_ROOT/scripts/qa/run-multisite-governance-gates.sh" --env "$ENV"
else
  GATE_WARN=$((GATE_WARN + 1))
  RESULTS+=("SKIP: Multisite governance (script not found)")
  echo ""
  echo "SKIP: run-multisite-governance-gates.sh not found"
fi

# Gate 5: Post-deploy smoke
if [[ -n "$EVIDENCE_DIR" ]]; then
  run_gate "Post-deploy smoke" \
    "$REPO_ROOT/scripts/qa/verify-post-deploy-smoke.sh" --env "$ENV" --evidence-dir "$EVIDENCE_DIR"
else
  run_gate "Post-deploy smoke" \
    "$REPO_ROOT/scripts/qa/verify-post-deploy-smoke.sh" --env "$ENV"
fi

# Gate 6: GitOps drift
run_gate "GitOps drift" \
  "$REPO_ROOT/scripts/qa/verify-gitops-drift.sh"

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         CONFIDENCE SUMMARY                                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
for result in "${RESULTS[@]}"; do
  echo "  $result"
done
echo ""
echo "Gates: PASS=$GATE_PASS FAIL=$GATE_FAIL WARN=$GATE_WARN"

if [[ -n "$EVIDENCE_DIR" ]]; then
  {
    echo "# Operator Confidence Bundle"
    echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Environment: $ENV"
    echo "Gates: PASS=$GATE_PASS FAIL=$GATE_FAIL WARN=$GATE_WARN"
    echo ""
    echo "## Gate Results"
    for result in "${RESULTS[@]}"; do
      echo "- $result"
    done
  } > "$EVIDENCE_DIR/confidence-summary.md"
  echo "Evidence: $EVIDENCE_DIR"
fi

if [[ "$GATE_FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL — $GATE_FAIL gate(s) failed"
  exit 1
fi

echo "RESULT: PASS — all confidence gates passed"
exit 0
