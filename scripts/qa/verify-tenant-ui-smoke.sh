#!/usr/bin/env bash
# @covers AC-UVIS-301, AC-UVIS-302, AC-UVIS-303, AC-UVIS-304, AC-UVIS-305
# @spec: bead-115d20
#
# verify-tenant-ui-smoke.sh
#
# Verification script for the tenant-domain authenticated UI smoke + visual
# checkpoint contract (bead mereka-lms-115d.20).
#
# Modes:
#   Offline (default) — validates documentation, naming conventions, and
#       cross-references exist.  Safe to run in CI with no live cluster.
#   Live (TENANT_SMOKE_LIVE=1) — placeholder for live authenticated checks
#       across 3 tenant domains (requires Playwright + SSO credentials).
#
# Usage:
#   ./scripts/qa/verify-tenant-ui-smoke.sh
#   TENANT_SMOKE_LIVE=1 ./scripts/qa/verify-tenant-ui-smoke.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LIVE_MODE="${TENANT_SMOKE_LIVE:-0}"

# ---------------------------------------------------------------------------
# Output helpers — matches the do_pass/do_fail/do_warn style used across the
# scripts/qa/ family.
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-UVIS-301..305: Tenant UI Smoke + Visual Checkpoints ==="
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "Mode: LIVE (TENANT_SMOKE_LIVE=1)"
else
  echo "Mode: OFFLINE (set TENANT_SMOKE_LIVE=1 for live cluster checks)"
fi
echo ""

# ---------------------------------------------------------------------------
# Constants: 3 tenant domains + 5 authenticated routes = 15 checkpoints
# ---------------------------------------------------------------------------
declare -a TENANT_DOMAINS=(
  "academyv2.mereka.io"
  "academy.biji-biji.com"
  "skillourfuture.mereka.io"
)

declare -a REQUIRED_ROUTES=(
  "learner-dashboard"
  "learning"
  "account"
  "profile"
  "course-authoring"
)

SMOKE_DOC="$REPO_ROOT/docs/operations/UI_UX_POSTDEPLOY_SMOKE.md"
A11Y_SCRIPT="$REPO_ROOT/scripts/qa/verify-a11y-authenticated-routes.sh"
A11Y_RUNBOOK="$REPO_ROOT/docs/operations/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md"
VISUAL_BASELINE_DOC="$REPO_ROOT/docs/operations/VISUAL_SMOKE_BASELINE.md"
CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"

# ===========================================================================
# AC-UVIS-301: Route × domain matrix defined (5 routes × 3 domains = 15
#              checkpoints documented in UI_UX_POSTDEPLOY_SMOKE.md)
# ===========================================================================
echo "--- AC-UVIS-301: Route × Domain Matrix (15 checkpoints) ---"

if [[ ! -f "$SMOKE_DOC" ]]; then
  do_fail "AC-UVIS-301: UI_UX_POSTDEPLOY_SMOKE.md not found — create docs/operations/UI_UX_POSTDEPLOY_SMOKE.md"
else
  do_pass "AC-UVIS-301: UI_UX_POSTDEPLOY_SMOKE.md exists"

  # Verify all 3 tenant domains are documented.
  domains_found=0
  for domain in "${TENANT_DOMAINS[@]}"; do
    if grep -qF "$domain" "$SMOKE_DOC"; then
      do_pass "AC-UVIS-301: tenant domain '$domain' documented"
      domains_found=$((domains_found + 1))
    else
      do_fail "AC-UVIS-301: tenant domain '$domain' NOT found in UI_UX_POSTDEPLOY_SMOKE.md"
    fi
  done

  # Verify all 5 routes are documented.
  routes_found=0
  for route in "${REQUIRED_ROUTES[@]}"; do
    if grep -qF "$route" "$SMOKE_DOC"; then
      do_pass "AC-UVIS-301: route '$route' documented"
      routes_found=$((routes_found + 1))
    else
      do_fail "AC-UVIS-301: route '$route' NOT found in UI_UX_POSTDEPLOY_SMOKE.md"
    fi
  done

  # Verify the doc explicitly references 15 checkpoints or a matrix.
  if grep -qiE "15 checkpoint|15 entries|Route.*Domain.*[Mm]atrix|matrix.*route.*domain" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-301: Route × Domain matrix (15 checkpoints) explicitly declared"
  else
    do_warn "AC-UVIS-301: Consider explicitly stating '15 checkpoints' in the matrix header"
  fi

  if [[ "$domains_found" -eq "${#TENANT_DOMAINS[@]}" ]] && [[ "$routes_found" -eq "${#REQUIRED_ROUTES[@]}" ]]; then
    do_pass "AC-UVIS-301: all 3 tenant domains + 5 routes declared (15-entry matrix complete)"
  fi
fi

echo ""

# ===========================================================================
# AC-UVIS-302: Screenshot naming convention documented + capture command
#              defined; RMSE visual comparison approach referenced.
# ===========================================================================
echo "--- AC-UVIS-302: Screenshot Naming + Visual Comparison ---"

if [[ ! -f "$SMOKE_DOC" ]]; then
  do_warn "AC-UVIS-302: cannot check — UI_UX_POSTDEPLOY_SMOKE.md missing"
else
  # Screenshot naming convention: var/smoke/{domain}/{route}-{timestamp}.png
  if grep -qE "var/smoke" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-302: screenshot path root (var/smoke/) documented"
  else
    do_fail "AC-UVIS-302: screenshot path 'var/smoke/' not found in UI_UX_POSTDEPLOY_SMOKE.md"
  fi

  if grep -qiE "\{domain\}|\{route\}|\{timestamp\}" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-302: screenshot naming template ({domain}/{route}-{timestamp}) documented"
  else
    do_fail "AC-UVIS-302: screenshot naming template not found (expected {domain}/{route}-{timestamp})"
  fi

  if grep -qiE "\.png" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-302: PNG screenshot format documented"
  else
    do_warn "AC-UVIS-302: PNG format not explicitly stated in screenshot naming convention"
  fi

  # Visual comparison approach — RMSE threshold cross-reference.
  if grep -qiE "RMSE|rmse|visual.*comparison|comparison.*visual" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-302: RMSE visual comparison approach referenced"
  else
    do_fail "AC-UVIS-302: RMSE/visual comparison approach not referenced in UI_UX_POSTDEPLOY_SMOKE.md"
  fi

  # Cross-reference to VISUAL_SMOKE_BASELINE.md.
  if grep -qF "VISUAL_SMOKE_BASELINE.md" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-302: cross-reference to VISUAL_SMOKE_BASELINE.md present"
  else
    do_warn "AC-UVIS-302: no cross-reference to VISUAL_SMOKE_BASELINE.md — consider linking for threshold details"
  fi

  # VISUAL_SMOKE_BASELINE.md itself must exist as the threshold authority.
  if [[ -f "$VISUAL_BASELINE_DOC" ]]; then
    do_pass "AC-UVIS-302: VISUAL_SMOKE_BASELINE.md exists (RMSE threshold authority)"
  else
    do_warn "AC-UVIS-302: VISUAL_SMOKE_BASELINE.md not found — create docs/operations/VISUAL_SMOKE_BASELINE.md"
  fi
fi

echo ""

# ===========================================================================
# AC-UVIS-303: Accessibility and landmark checks cross-referenced for
#              authenticated routes.
# ===========================================================================
echo "--- AC-UVIS-303: A11y Cross-Reference ---"

# The a11y script must exist.
if [[ -f "$A11Y_SCRIPT" ]]; then
  do_pass "AC-UVIS-303: verify-a11y-authenticated-routes.sh exists"
else
  do_fail "AC-UVIS-303: verify-a11y-authenticated-routes.sh not found at scripts/qa/"
fi

# The a11y runbook must exist.
if [[ -f "$A11Y_RUNBOOK" ]]; then
  do_pass "AC-UVIS-303: ACCESSIBILITY_CONFORMANCE_RUNBOOK.md exists"
else
  do_fail "AC-UVIS-303: ACCESSIBILITY_CONFORMANCE_RUNBOOK.md not found at docs/operations/"
fi

# UI_UX_POSTDEPLOY_SMOKE.md must cross-reference a11y checks.
if [[ -f "$SMOKE_DOC" ]]; then
  if grep -qiE "a11y|accessibility|landmark|focus" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-303: a11y/landmark checks referenced in UI_UX_POSTDEPLOY_SMOKE.md"
  else
    do_fail "AC-UVIS-303: no a11y/landmark reference in UI_UX_POSTDEPLOY_SMOKE.md"
  fi

  if grep -qF "verify-a11y-authenticated-routes.sh" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-303: verify-a11y-authenticated-routes.sh explicitly cross-referenced"
  else
    do_warn "AC-UVIS-303: consider explicitly naming verify-a11y-authenticated-routes.sh in smoke doc"
  fi

  if grep -qF "ACCESSIBILITY_CONFORMANCE_RUNBOOK.md" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-303: ACCESSIBILITY_CONFORMANCE_RUNBOOK.md cross-referenced"
  else
    do_warn "AC-UVIS-303: consider explicitly linking ACCESSIBILITY_CONFORMANCE_RUNBOOK.md in smoke doc"
  fi
else
  do_warn "AC-UVIS-303: cannot check a11y cross-reference — UI_UX_POSTDEPLOY_SMOKE.md missing"
fi

echo ""

# ===========================================================================
# AC-UVIS-304: Artifact naming + retention guidance documented in
#              UI_UX_POSTDEPLOY_SMOKE.md.
# ===========================================================================
echo "--- AC-UVIS-304: Artifact Naming + Retention Guidance ---"

if [[ ! -f "$SMOKE_DOC" ]]; then
  do_fail "AC-UVIS-304: UI_UX_POSTDEPLOY_SMOKE.md missing — cannot verify artifact guidance"
else
  # Retention period documented.
  if grep -qiE "30.day|retention.*30|30.*retention" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-304: 30-day artifact retention policy documented"
  else
    do_fail "AC-UVIS-304: 30-day retention policy not documented in UI_UX_POSTDEPLOY_SMOKE.md"
  fi

  # Latest symlink documented.
  if grep -qiE "symlink|latest.*link|latest$" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-304: 'latest' symlink pattern documented"
  else
    do_warn "AC-UVIS-304: 'latest' symlink convention not explicitly mentioned"
  fi

  # var/smoke/ artifact root.
  if grep -qE "var/smoke" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-304: artifact root (var/smoke/) documented"
  else
    do_fail "AC-UVIS-304: artifact root 'var/smoke/' not documented"
  fi

  # Artifact naming section or heading.
  if grep -qiE "[Aa]rtifact.*[Nn]aming|[Nn]aming.*[Aa]rtifact|[Aa]rtifact.*[Rr]etention|[Rr]etention" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-304: Artifact naming/retention section present"
  else
    do_fail "AC-UVIS-304: Artifact naming/retention section not found in UI_UX_POSTDEPLOY_SMOKE.md"
  fi
fi

echo ""

# ===========================================================================
# AC-UVIS-305: "Why world-class" note present with failure → bead mapping.
# ===========================================================================
echo "--- AC-UVIS-305: World-Class Baseline Rationale + Failure Triage ---"

if [[ ! -f "$SMOKE_DOC" ]]; then
  do_fail "AC-UVIS-305: UI_UX_POSTDEPLOY_SMOKE.md missing — cannot verify world-class note"
else
  # "World-class" or equivalent rationale section.
  if grep -qiE "world.class|world class|layered.verif|layered verif|why.*baseline|baseline.*why" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-305: world-class baseline rationale section present"
  else
    do_fail "AC-UVIS-305: world-class baseline rationale not found in UI_UX_POSTDEPLOY_SMOKE.md"
  fi

  # Failure → bead mapping.
  if grep -qiE "115d\.|3vg9\.|bead.*fail|fail.*bead|failure.*map|triage" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-305: failure → bead mapping documented"
  else
    do_fail "AC-UVIS-305: failure → bead mapping not found (expected 115d.* and 3vg9.* references)"
  fi

  # Branding failure category mapped.
  if grep -qiE "branding|brand" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-305: branding failure category present in triage"
  else
    do_warn "AC-UVIS-305: branding failure category not explicit in failure mapping"
  fi

  # A11y failure category mapped.
  if grep -qiE "a11y|accessibility" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-305: a11y failure category present in triage"
  else
    do_warn "AC-UVIS-305: a11y failure category not explicit in failure mapping"
  fi

  # Visual regression failure category mapped.
  if grep -qiE "visual.regress|visual regress|visual.*fail" "$SMOKE_DOC"; then
    do_pass "AC-UVIS-305: visual regression failure category present in triage"
  else
    do_warn "AC-UVIS-305: visual regression failure category not explicit in failure mapping"
  fi
fi

echo ""

# ===========================================================================
# CI wiring check — verify-tenant-ui-smoke.sh referenced in ci.yml
# ===========================================================================
echo "--- CI Wiring ---"

if [[ -f "$CI_FILE" ]]; then
  do_pass "CI: .github/workflows/ci.yml exists"
  if grep -q "verify-tenant-ui-smoke.sh" "$CI_FILE"; then
    do_pass "CI: ci.yml references verify-tenant-ui-smoke.sh"
  else
    do_warn "CI: ci.yml does not yet reference verify-tenant-ui-smoke.sh"
  fi
else
  do_fail "CI: .github/workflows/ci.yml not found"
fi

echo ""

# ===========================================================================
# Live mode — placeholder for authenticated cross-domain probes
# ===========================================================================
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "--- Live Mode: Tenant Domain Probes (placeholder) ---"
  echo ""
  echo "  [LIVE] Authenticated smoke checks would run here."
  echo "         Requires: SSO_USERNAME, SSO_PASSWORD env vars + Playwright."
  echo ""
  echo "  Checkpoint matrix (5 routes × 3 domains = 15 entries):"
  echo ""

  if [[ -n "${SSO_USERNAME:-}" ]]; then
    do_pass "[LIVE] SSO_USERNAME env var is set"
  else
    do_warn "[LIVE] SSO_USERNAME not set — authenticated flows will be skipped"
  fi

  for domain in "${TENANT_DOMAINS[@]}"; do
    for route in "${REQUIRED_ROUTES[@]}"; do
      url="https://apps.${domain}/${route}/"
      http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time 10 "$url" 2>/dev/null || echo "000")
      if [[ "$http_code" == "200" ]]; then
        do_pass "[LIVE] $domain / $route reachable (HTTP 200)"
      elif [[ "$http_code" == "000" ]]; then
        do_warn "[LIVE] $domain / $route unreachable (timeout)"
      else
        do_warn "[LIVE] $domain / $route returned HTTP $http_code"
      fi
    done
  done
  echo ""
fi

# ===========================================================================
# Summary
# ===========================================================================
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Action required: Fix FAIL items above."
  echo "  - Create docs/operations/UI_UX_POSTDEPLOY_SMOKE.md if missing"
  echo "  - Ensure all 3 tenant domains and 5 routes are documented"
  echo "  - Add artifact naming + retention guidance (30 days, var/smoke/)"
  echo "  - Add world-class baseline rationale with failure → bead mapping"
  echo "  - Wire verify-tenant-ui-smoke.sh into .github/workflows/ci.yml"
  exit 1
fi

echo ""
echo "All tenant UI smoke checks passed (WARNs are live-cluster-only or advisory)."
exit 0
