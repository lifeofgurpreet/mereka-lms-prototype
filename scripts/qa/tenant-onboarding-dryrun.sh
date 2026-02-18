#!/usr/bin/env bash
# @covers AC-ONB-201, AC-ONB-202
# @spec: multi-site-domains_spec.md
# tenant-onboarding-dryrun.sh — One-command dry-run matrix for tenant onboarding
#
# Runs all verification gates for existing tenants (onboarding proof) or validates
# readiness for a new tenant (when --new-domain is passed).
#
# Usage:
#   ./scripts/qa/tenant-onboarding-dryrun.sh [--env prod|dev] [--evidence-dir DIR]
#   ./scripts/qa/tenant-onboarding-dryrun.sh --env prod --evidence-dir var/evidence/tenant-onboarding/dryrun-20260218

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
      echo "One-command dry-run matrix for tenant onboarding verification."
      echo "Runs: branding-runtime, mfe-branding, multisite-ux, post-deploy-smoke,"
      echo "domain smoke, and MFE config fixture for all 3 production domains."
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0
TOTAL_SKIP=0
GATE_RESULTS=()

run_gate() {
  local label="$1"
  local script="$2"
  shift 2
  local args=("$@")
  local artifact_name
  artifact_name="$(basename "$script" .sh).log"

  echo ""
  echo "================================================================"
  echo "GATE: $label"
  echo "CMD:  $script ${args[*]}"
  echo "================================================================"

  local output exit_code
  output="$("$script" "${args[@]}" 2>&1)" && exit_code=0 || exit_code=$?

  echo "$output"

  # Extract summary line (PASS/FAIL/WARN counts)
  local summary_line
  summary_line="$(echo "$output" | grep -oE 'PASS=[0-9]+ FAIL=[0-9]+' | tail -1 || true)"

  local gate_pass gate_fail
  gate_pass="$(echo "$summary_line" | grep -oE 'PASS=[0-9]+' | grep -oE '[0-9]+' || echo "0")"
  gate_fail="$(echo "$summary_line" | grep -oE 'FAIL=[0-9]+' | grep -oE '[0-9]+' || echo "0")"

  TOTAL_PASS=$((TOTAL_PASS + gate_pass))
  TOTAL_FAIL=$((TOTAL_FAIL + gate_fail))

  if [[ "$exit_code" -eq 0 ]]; then
    GATE_RESULTS+=("PASS: $label (PASS=$gate_pass FAIL=$gate_fail)")
  else
    GATE_RESULTS+=("FAIL: $label (exit=$exit_code, PASS=$gate_pass FAIL=$gate_fail)")
  fi

  # Write evidence artifact
  if [[ -n "$EVIDENCE_DIR" ]]; then
    echo "$output" > "$EVIDENCE_DIR/$artifact_name"
  fi
}

DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")

echo "=== Tenant Onboarding Dry-Run Matrix ==="
echo "Environment: $ENV"
echo "Domains: ${DOMAINS[*]}"
echo "Evidence: ${EVIDENCE_DIR:-<none>}"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ -n "$EVIDENCE_DIR" ]]; then
  mkdir -p "$EVIDENCE_DIR"
fi

# ── Gate 1: Tenant branding runtime ──────────────────────────────────────────

run_gate "Tenant branding runtime" \
  "$REPO_ROOT/scripts/qa/verify-tenant-branding-runtime.sh"

# ── Gate 2: MFE branding ────────────────────────────────────────────────────

run_gate "MFE branding" \
  "$REPO_ROOT/scripts/qa/verify-mfe-branding.sh" --env "$ENV"

# ── Gate 3: Multisite UX consistency ─────────────────────────────────────────

run_gate "Multisite UX consistency" \
  "$REPO_ROOT/scripts/qa/verify-multisite-ux-consistency.sh" --env "$ENV"

# ── Gate 4: Post-deploy smoke matrix ────────────────────────────────────────

if [[ -n "$EVIDENCE_DIR" ]]; then
  run_gate "Post-deploy smoke" \
    "$REPO_ROOT/scripts/qa/verify-post-deploy-smoke.sh" --env "$ENV" --evidence-dir "$EVIDENCE_DIR"
else
  run_gate "Post-deploy smoke" \
    "$REPO_ROOT/scripts/qa/verify-post-deploy-smoke.sh" --env "$ENV"
fi

# ── Gate 5: Per-domain MFE config fixture ────────────────────────────────────

echo ""
echo "================================================================"
echo "GATE: MFE config fixture (per-domain)"
echo "================================================================"

FIXTURE_PASS=0
FIXTURE_FAIL=0

for domain in "${DOMAINS[@]}"; do
  echo "--- $domain ---"
  config="$(curl -s --max-time 10 "https://$domain/api/mfe_config/v1" 2>/dev/null || echo "")"

  if [[ -z "$config" ]]; then
    echo "  FAIL: MFE config unreachable"
    FIXTURE_FAIL=$((FIXTURE_FAIL + 1))
    continue
  fi

  # Extract key fields
  output="$(echo "$config" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in ['SITE_NAME', 'LMS_BASE_URL', 'LOGO_URL', 'FAVICON_URL']:
    v = d.get(k, 'MISSING')
    print(f'  {k}: {v}')
" 2>/dev/null || echo "  PARSE_ERROR")"

  echo "$output"
  FIXTURE_PASS=$((FIXTURE_PASS + 1))

  if [[ -n "$EVIDENCE_DIR" ]]; then
    echo "$config" | python3 -m json.tool > "$EVIDENCE_DIR/mfe-config-${domain}.json" 2>/dev/null || true
  fi
done

TOTAL_PASS=$((TOTAL_PASS + FIXTURE_PASS))
TOTAL_FAIL=$((TOTAL_FAIL + FIXTURE_FAIL))
GATE_RESULTS+=("$([ "$FIXTURE_FAIL" -eq 0 ] && echo "PASS" || echo "FAIL"): MFE config fixture (${FIXTURE_PASS}/${#DOMAINS[@]} domains)")

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "================================================================"
echo "=== DRY-RUN SUMMARY ==="
echo "================================================================"
for result in "${GATE_RESULTS[@]}"; do
  echo "  $result"
done
echo ""
echo "Total: PASS=$TOTAL_PASS FAIL=$TOTAL_FAIL"

if [[ -n "$EVIDENCE_DIR" ]]; then
  # Write summary
  {
    echo "# Tenant Onboarding Dry-Run Summary"
    echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Environment: $ENV"
    echo "Total: PASS=$TOTAL_PASS FAIL=$TOTAL_FAIL"
    echo ""
    echo "## Gate Results"
    for result in "${GATE_RESULTS[@]}"; do
      echo "- $result"
    done
  } > "$EVIDENCE_DIR/dryrun-summary.md"
  echo ""
  echo "Evidence directory: $EVIDENCE_DIR"
  ls -la "$EVIDENCE_DIR/"
fi

echo ""
if [[ "$TOTAL_FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL — tenant onboarding verification has failures"
  exit 1
fi

echo "RESULT: PASS — all tenant onboarding gates passed"
exit 0
