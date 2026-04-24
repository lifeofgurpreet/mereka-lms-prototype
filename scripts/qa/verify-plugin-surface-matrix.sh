#!/usr/bin/env bash
# @covers AC-UI-002
# @spec: branding-system_spec.md
# verify-plugin-surface-matrix.sh — Unified plugin-surface test matrix
#
# Runs all plugin slot, branding surface, and authn MFE checks in one pass.
# Covers: plugin slots, DOM override policy, template inventory, MFE branding,
# footer migration, and forbidden override gate.
#
# Usage:
#   ./scripts/qa/verify-plugin-surface-matrix.sh [--evidence-dir DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

EVIDENCE_DIR=""
[[ "${1:-}" == "--evidence-dir" ]] && EVIDENCE_DIR="${2:-}" && shift 2

GATE_PASS=0
GATE_FAIL=0
GATE_SKIP=0
RESULTS=()

if [[ -n "$EVIDENCE_DIR" ]]; then
  mkdir -p "$EVIDENCE_DIR"
fi

run_gate() {
  local label="$1"
  local script="$2"
  local artifact
  artifact="$(basename "$script" .sh).log"

  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "GATE: $label"
  echo "════════════════════════════════════════════════════════════════"

  if [[ ! -x "$script" ]]; then
    GATE_SKIP=$((GATE_SKIP + 1))
    RESULTS+=("SKIP: $label (script not found)")
    echo "SKIP: $script not found or not executable"
    return
  fi

  local output exit_code
  output=$("$script" 2>&1) && exit_code=0 || exit_code=$?

  echo "$output" | tail -10

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
echo "║       Plugin-Surface Test Matrix                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Evidence: ${EVIDENCE_DIR:-<none>}"

# ── Category 1: Plugin Slot Verification ─────────────────────────────────

echo ""
echo "▸ Category 1: Plugin Slot Verification"

run_gate "MFE footer slot wiring" \
  "$REPO_ROOT/scripts/qa/verify-mfe-footer-slot.sh"

run_gate "Plugin slot wiring (env.config.jsx)" \
  "$REPO_ROOT/scripts/qa/verify-plugin-slot-wiring.sh"

run_gate "Footer slot migration status" \
  "$REPO_ROOT/scripts/qa/verify-footer-slot-migration.sh"

run_gate "Footer slot-only (no legacy)" \
  "$REPO_ROOT/scripts/qa/verify-footer-slot-only.sh"

# ── Category 2: Branding Surface Checks ──────────────────────────────────

echo ""
echo "▸ Category 2: Branding Surface Checks"

run_gate "Tenant branding runtime" \
  "$REPO_ROOT/scripts/qa/verify-tenant-branding-runtime.sh"

run_gate "MFE branding (theme SCSS + assets)" \
  "$REPO_ROOT/scripts/qa/verify-mfe-branding.sh"

run_gate "Footer variant matrix" \
  "$REPO_ROOT/scripts/qa/verify-footer-variant-matrix.sh"

run_gate "Footer parity (MFE vs LMS)" \
  "$REPO_ROOT/scripts/qa/verify-footer-parity.sh"

# ── Category 3: DOM Override Policy ──────────────────────────────────────

echo ""
echo "▸ Category 3: DOM Override Policy"

run_gate "No DOM overrides" \
  "$REPO_ROOT/scripts/qa/verify-no-dom-overrides.sh"

run_gate "Plugin slot migration register" \
  "$REPO_ROOT/scripts/qa/verify-plugin-slot-migration-register.sh"

run_gate "Forbidden override gate" \
  "$REPO_ROOT/scripts/qa/check-forbidden-overrides.sh"

# ── Category 4: Authn MFE Checks ────────────────────────────────────────

echo ""
echo "▸ Category 4: Authn MFE Checks"

run_gate "Branding token integrity" \
  "$REPO_ROOT/scripts/qa/verify-branding-token-integrity.sh"

run_gate "Design token CI pipeline" \
  "$REPO_ROOT/scripts/qa/verify-design-token-ci.sh"

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       PLUGIN-SURFACE MATRIX SUMMARY                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
for result in "${RESULTS[@]}"; do
  echo "  $result"
done
echo ""
echo "Gates: PASS=$GATE_PASS FAIL=$GATE_FAIL SKIP=$GATE_SKIP"

if [[ -n "$EVIDENCE_DIR" ]]; then
  {
    echo "# Plugin-Surface Test Matrix"
    echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Gates: PASS=$GATE_PASS FAIL=$GATE_FAIL SKIP=$GATE_SKIP"
    echo ""
    echo "## Results"
    for result in "${RESULTS[@]}"; do
      echo "- $result"
    done
  } > "$EVIDENCE_DIR/plugin-surface-matrix-summary.md"
  echo "Evidence: $EVIDENCE_DIR/plugin-surface-matrix-summary.md"
fi

if [[ "$GATE_FAIL" -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL — $GATE_FAIL gate(s) failed"
  exit 1
fi

echo ""
echo "RESULT: PASS — all plugin-surface gates passed"
exit 0
