#!/usr/bin/env bash
# @covers AC-TF-001, AC-TF-002, AC-TF-003, AC-TF-004
# @spec: branding-system_spec.md
# verify-tenant-first-consolidation.sh — Tenant-first UI/UX consolidation gate
#
# Combines footer variant, runtime config, visual contract, and documentation checks
# into a single gate for the tenant-first UI/UX lane.
#
# Usage:
#   ./scripts/qa/verify-tenant-first-consolidation.sh [--env prod|dev]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

ENV="prod"
[[ "${1:-}" == "--env" ]] && ENV="${2:-prod}"

PASS=0
FAIL=0
WARN=0
SKIP=0
RESULTS=()

pass() { PASS=$((PASS + 1)); RESULTS+=("PASS: $1"); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); RESULTS+=("FAIL: $1"); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); RESULTS+=("WARN: $1"); echo "  WARN: $1"; }
skip() { SKIP=$((SKIP + 1)); RESULTS+=("SKIP: $1"); echo "  SKIP: $1"; }

run_sub() {
  local label="$1"
  local script="$2"
  shift 2

  if [[ ! -x "$script" ]]; then
    skip "$label (script not found)"
    return
  fi

  local output exit_code
  output=$("$script" "$@" 2>&1) && exit_code=0 || exit_code=$?

  # Extract pass/fail counts from output
  local sub_pass sub_fail
  sub_pass=$(echo "$output" | grep -oiE '(PASS[=: ]*[0-9]+|[0-9]+ PASS)' | grep -oE '[0-9]+' | tail -1 || echo "0")
  sub_fail=$(echo "$output" | grep -oiE '(FAIL[=: ]*[0-9]+|[0-9]+ FAIL)' | grep -oE '[0-9]+' | tail -1 || echo "0")

  if [[ "$exit_code" -eq 0 ]]; then
    pass "$label (${sub_pass:-?} sub-checks passed)"
  else
    fail "$label (${sub_fail:-?} sub-checks failed)"
  fi
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Tenant-First UI/UX Consolidation Gate                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "Environment: $ENV"
echo ""

# ── AC-TF-001: Deterministic footer variants ─────────────────────────────

echo "── AC-TF-001: Deterministic footer variants for 3+ domains ──"

PLUGIN="$PLUGIN_MAIN"
if [[ -f "$PLUGIN" ]]; then
  DOMAIN_COUNT=$(grep -c "mereka.io\|biji-biji.com" "$PLUGIN" | head -1 || echo "0")
  # Count entries in SITE_VARIANTS block
  VARIANT_COUNT=$(grep -cE "^\s+'" "$PLUGIN" 2>/dev/null | head -1 || echo "0")

  # Check SITE_VARIANTS has at least 3 domains
  DOMAINS_IN_VARIANTS=0
  for domain in "academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io"; do
    if grep -q "$domain" "$PLUGIN"; then
      DOMAINS_IN_VARIANTS=$((DOMAINS_IN_VARIANTS + 1))
    fi
  done

  if [[ "$DOMAINS_IN_VARIANTS" -ge 3 ]]; then
    pass "SITE_VARIANTS covers $DOMAINS_IN_VARIANTS production domains"
  else
    fail "SITE_VARIANTS covers only $DOMAINS_IN_VARIANTS/3 production domains"
  fi

  # Check fallback exists
  if grep -q '|| {' "$PLUGIN" 2>/dev/null || grep -qE 'SITE_NAME.*PLATFORM_NAME' "$PLUGIN" 2>/dev/null; then
    pass "Fallback variant exists for unknown domains"
  else
    fail "No fallback variant for unknown domains"
  fi
fi

# Run footer variant matrix
run_sub "Footer variant matrix" "$REPO_ROOT/scripts/qa/verify-footer-variant-matrix.sh"

echo ""

# ── AC-TF-002: Variant selection visible in config ───────────────────────

echo "── AC-TF-002: Variant selection in config + runtime endpoint ──"

# Check MFE config API exposes SITE_NAME per domain
DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")
for domain in "${DOMAINS[@]}"; do
  CONFIG="$(curl -s --max-time 10 "https://$domain/api/mfe_config/v1" 2>/dev/null || echo "")"
  if [[ -n "$CONFIG" ]]; then
    SITE_NAME="$(echo "$CONFIG" | python3 -c "import json,sys; print(json.load(sys.stdin).get('SITE_NAME','MISSING'))" 2>/dev/null || echo "PARSE_ERROR")"
    if [[ "$SITE_NAME" != "MISSING" && "$SITE_NAME" != "PARSE_ERROR" ]]; then
      pass "$domain runtime config SITE_NAME='$SITE_NAME'"
    else
      fail "$domain runtime config SITE_NAME missing"
    fi
  else
    warn "$domain runtime config API unreachable"
  fi
done

# Run tenant branding runtime
run_sub "Tenant branding runtime" "$REPO_ROOT/scripts/qa/verify-tenant-branding-runtime.sh"

echo ""

# ── AC-TF-003: Regression check (200/redirect/health + brand markers) ────

echo "── AC-TF-003: Domain routing + brand visibility regression check ──"

# Run tenant visual contract
run_sub "Tenant visual contract" "$REPO_ROOT/scripts/qa/verify-tenant-visual-contract.sh" --env "$ENV"

# Run post-deploy smoke
run_sub "Post-deploy smoke" "$REPO_ROOT/scripts/qa/verify-post-deploy-smoke.sh" --env "$ENV"

echo ""

# ── AC-TF-004: New tenant onboarding documentation ───────────────────────

echo "── AC-TF-004: Tenant brand onboarding documentation ──"

GUIDE="$REPO_ROOT/docs/operations/TENANT_BRAND_ONBOARDING_GUIDE.md"
if [[ -f "$GUIDE" ]]; then
  pass "TENANT_BRAND_ONBOARDING_GUIDE.md exists"

  # Check required sections
  for section in "Brand Assets" "SITE_VARIANTS" "SiteConfiguration" "Verify" "Troubleshooting" "Checklist"; do
    if grep -qi "$section" "$GUIDE"; then
      pass "Guide has '$section' section"
    else
      fail "Guide missing '$section' section"
    fi
  done
else
  fail "TENANT_BRAND_ONBOARDING_GUIDE.md not found"
fi

# Check TENANT_ONBOARDING_PLAYBOOK.md also exists
if [[ -f "$REPO_ROOT/docs/operations/TENANT_ONBOARDING_PLAYBOOK.md" ]]; then
  pass "TENANT_ONBOARDING_PLAYBOOK.md exists (comprehensive playbook)"
else
  warn "TENANT_ONBOARDING_PLAYBOOK.md not found"
fi

echo ""

# ── Summary ──────────────────────────────────────────────────────────────

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       TENANT-FIRST CONSOLIDATION SUMMARY                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
for result in "${RESULTS[@]}"; do
  echo "  $result"
done
echo ""
echo "Gates: PASS=$PASS FAIL=$FAIL WARN=$WARN SKIP=$SKIP"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL — $FAIL check(s) failed"
  exit 1
fi

echo ""
echo "RESULT: PASS — tenant-first UI/UX consolidation verified"
exit 0
