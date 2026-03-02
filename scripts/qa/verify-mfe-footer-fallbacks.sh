#!/usr/bin/env bash
# @covers AC-FTRX-001, AC-FTRX-002, AC-FTRX-003
# @spec: branding-system_spec.md
# verify-mfe-footer-fallbacks.sh — Detect footer fallback rewrites and enforce exception IDs
#
# Fails on unapproved fallback rewrites. Warns only when an explicit exception ID is present.
#
# Usage:
#   ./scripts/qa/verify-mfe-footer-fallbacks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

PASS=0
FAIL=0
WARN=0
SKIP=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $1"; }

PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN="$PLUGIN_MAIN"
REGISTER="$REPO_ROOT/docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md"
EXCEPTIONS="$REPO_ROOT/docs/operations/footer-slot-exceptions.md"
ENTERPRISE_ENV="$REPO_ROOT/deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-contract.XXXXXX)"
  while IFS= read -r plugin_file; do
    cat "$plugin_file" >>"$PLUGIN_BUNDLE"
    printf '\n' >>"$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
  PLUGIN="$PLUGIN_BUNDLE"
fi

cleanup() {
  if [[ -n "$PLUGIN_BUNDLE" && -f "$PLUGIN_BUNDLE" ]]; then
    rm -f "$PLUGIN_BUNDLE"
  fi
}
trap cleanup EXIT

echo "========================================"
echo "MFE Footer Fallback Verification"
echo "========================================"
echo ""

# ── AC-FTRX-001: Enterprise MFE footer slot injection ────────────────────

echo "AC-FTRX-001: Enterprise MFE footer plugin-slot injection"

# Check 1: MerekaFooter component exists in plugin
if [[ -f "$PLUGIN" ]]; then
  if grep -q "const MerekaFooter" "$PLUGIN"; then
    pass "MerekaFooter component defined in mereka_lms.py"
  else
    fail "MerekaFooter component NOT found in mereka_lms.py"
  fi
else
  fail "mereka_lms.py not found"
fi

# Check 2: PLUGIN_SLOTS registration exists (forward-compatible slot wiring)
if [[ -f "$PLUGIN" ]]; then
  if grep -q "PLUGIN_SLOTS" "$PLUGIN"; then
    pass "PLUGIN_SLOTS registration present in mereka_lms.py"
  else
    fail "PLUGIN_SLOTS registration missing — footer slot not forward-compatible"
  fi
fi

# Check 3: Dual-path fallback (apply-patches.sh RenderWidget replacement)
if [[ -f "$APPLY_PATCHES" ]]; then
  if grep -q "RenderWidget" "$APPLY_PATCHES"; then
    pass "apply-patches.sh contains RenderWidget replacement fallback"
  else
    warn "apply-patches.sh has no RenderWidget replacement — slot-only path"
  fi
fi

# Check 4: Enterprise MFE env config — document gap
if [[ -f "$ENTERPRISE_ENV" ]]; then
  if grep -qi "footer\|MerekaFooter\|plugin.slot\|PLUGIN_SLOT" "$ENTERPRISE_ENV"; then
    pass "Enterprise MFE env config references footer customization"
  else
    # This is a KNOWN exception — enterprise MFEs use upstream builds
    # without custom plugin-slot wiring. Documented in footer-slot-exceptions.md
    if [[ -f "$EXCEPTIONS" ]] && grep -q "FTRX-EXC-001" "$EXCEPTIONS"; then
      warn "Enterprise MFE env config has no MerekaFooter wiring — documented exception FTRX-EXC-001"
    else
      fail "Enterprise MFE env config has no MerekaFooter wiring — NOT documented as exception"
    fi
  fi
else
  skip "Enterprise MFE env config not found (enterprise MFEs may not be deployed)"
fi

# Check 5: SITE_VARIANTS covers all 3 production domains
if [[ -f "$PLUGIN" ]]; then
  MISSING_DOMAINS=()
  for domain in "academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io"; do
    if ! grep -q "$domain" "$PLUGIN"; then
      MISSING_DOMAINS+=("$domain")
    fi
  done
  if [[ ${#MISSING_DOMAINS[@]} -eq 0 ]]; then
    pass "SITE_VARIANTS covers all 3 production domains"
  else
    fail "SITE_VARIANTS missing domains: ${MISSING_DOMAINS[*]}"
  fi
fi

echo ""

# ── AC-FTRX-002: Fallback paths documented ───────────────────────────────

echo "AC-FTRX-002: Fallback paths documented in migration register"

if [[ -f "$REGISTER" ]]; then
  # Check migration register has footer entry with status MIGRATED
  if grep -q "MIGRATED" "$REGISTER" && grep -q "footer" "$REGISTER"; then
    pass "Migration register documents footer as MIGRATED"
  else
    fail "Migration register missing footer MIGRATED status"
  fi

  # Check dual-path is documented
  if grep -qi "dual-path\|dual path\|RenderWidget.*PLUGIN_SLOTS\|PLUGIN_SLOTS.*RenderWidget" "$REGISTER"; then
    pass "Migration register documents dual-path wiring strategy"
  else
    warn "Migration register does not explicitly mention dual-path wiring"
  fi
else
  fail "MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md not found"
fi

# Check footer-slot-exceptions.md exists
if [[ -f "$EXCEPTIONS" ]]; then
  pass "footer-slot-exceptions.md exists"
  # Check it has exception IDs
  if grep -qE "FTRX-EXC-[0-9]+" "$EXCEPTIONS"; then
    pass "footer-slot-exceptions.md contains exception IDs"
  else
    fail "footer-slot-exceptions.md has no exception IDs (FTRX-EXC-NNN)"
  fi
  # Check it has expiry dates
  if grep -qE "202[6-9]-Q[1-4]" "$EXCEPTIONS"; then
    pass "footer-slot-exceptions.md contains expiry dates"
  else
    fail "footer-slot-exceptions.md has no expiry dates"
  fi
else
  fail "footer-slot-exceptions.md not found — fallback exceptions not documented"
fi

echo ""

# ── AC-FTRX-003: Fallback rewrite detection ──────────────────────────────

echo "AC-FTRX-003: No unapproved fallback rewrites"

# Check that no MFE source files contain direct DOM footer injection
# outside of the approved plugin path
FALLBACK_PATTERNS=(
  "document.querySelector.*footer"
  "document.getElementById.*footer"
  "innerHTML.*footer"
  "replaceChild.*footer"
)

UNAPPROVED_REWRITES=0
for pattern in "${FALLBACK_PATTERNS[@]}"; do
  MATCHES=$(grep -rl "$pattern" "$REPO_ROOT/infrastructure/tutor/" 2>/dev/null | grep -v node_modules || true)
  if [[ -n "$MATCHES" ]]; then
    for match in $MATCHES; do
      # Check if the match has an exception annotation
      LINE=$(grep "$pattern" "$match" || true)
      if echo "$LINE" | grep -q "FTRX-EXC-"; then
        warn "Fallback rewrite in $(basename "$match") — has exception ID"
      else
        fail "Unapproved fallback rewrite in $(basename "$match"): $pattern"
        UNAPPROVED_REWRITES=$((UNAPPROVED_REWRITES + 1))
      fi
    done
  fi
done

if [[ "$UNAPPROVED_REWRITES" -eq 0 ]]; then
  pass "No unapproved DOM footer fallback rewrites detected"
fi

# Check apply-patches.sh for any footer-related patches beyond the approved RenderWidget swap
if [[ -f "$APPLY_PATCHES" ]]; then
  # Count footer-related lines excluding the known RenderWidget pattern
  FOOTER_PATCH_LINES=$(grep -c -i "footer" "$APPLY_PATCHES" 2>/dev/null || true)
  RENDERWIDGET_LINES=$(grep -c "RenderWidget" "$APPLY_PATCHES" 2>/dev/null || true)

  # If footer references greatly exceed RenderWidget references, there may be extra patches
  FOOTER_COUNT="${FOOTER_PATCH_LINES:-0}"
  RENDER_COUNT="${RENDERWIDGET_LINES:-0}"

  if [[ "$FOOTER_COUNT" -gt 0 ]] && [[ "$RENDER_COUNT" -gt 0 ]]; then
    EXCESS=$((FOOTER_COUNT - RENDER_COUNT * 3))
    if [[ "$EXCESS" -gt 5 ]]; then
      warn "apply-patches.sh has $FOOTER_COUNT footer refs vs $RENDER_COUNT RenderWidget refs — review for extra patches"
    else
      pass "apply-patches.sh footer patch density within expected range"
    fi
  else
    pass "apply-patches.sh footer patch counts nominal"
  fi
fi

echo ""

# ── AC-FTRX-004: Visual evidence pack references ─────────────────────────

echo "AC-FTRX-004: Visual evidence pack documentation"

if [[ -f "$EXCEPTIONS" ]]; then
  MFES=("learner-dashboard" "learning" "profile" "account" "authn")
  DOCUMENTED=0
  for mfe in "${MFES[@]}"; do
    if grep -qi "$mfe" "$EXCEPTIONS"; then
      DOCUMENTED=$((DOCUMENTED + 1))
    fi
  done
  if [[ "$DOCUMENTED" -ge 4 ]]; then
    pass "footer-slot-exceptions.md references $DOCUMENTED/5 target MFEs"
  else
    fail "footer-slot-exceptions.md only references $DOCUMENTED/5 target MFEs (need: ${MFES[*]})"
  fi

  # Check for screenshot naming convention
  if grep -qE "screenshot|evidence|capture|visual" "$EXCEPTIONS"; then
    pass "footer-slot-exceptions.md documents visual evidence requirements"
  else
    warn "footer-slot-exceptions.md does not mention screenshot/evidence capture"
  fi
else
  fail "footer-slot-exceptions.md not found — no visual evidence pack"
fi

echo ""

# ── AC-FTRX-005: Maintenance playbook ────────────────────────────────────

echo "AC-FTRX-005: Maintenance playbook for fallback debt cleanup"

if [[ -f "$EXCEPTIONS" ]]; then
  if grep -qi "maintenance\|quarterly\|cadence\|cleanup\|review cycle" "$EXCEPTIONS"; then
    pass "footer-slot-exceptions.md has maintenance/review cadence section"
  else
    fail "footer-slot-exceptions.md missing maintenance/review cadence"
  fi

  if grep -qi "retire\|remove\|eliminate\|phase.out" "$EXCEPTIONS"; then
    pass "footer-slot-exceptions.md documents retirement criteria"
  else
    fail "footer-slot-exceptions.md missing retirement criteria"
  fi
else
  fail "footer-slot-exceptions.md not found"
fi

echo ""
echo "========================================"
echo "Footer fallbacks: $PASS PASS / $FAIL FAIL / $WARN WARN / $SKIP SKIP"
echo "========================================"
exit $((FAIL > 0 ? 1 : 0))
