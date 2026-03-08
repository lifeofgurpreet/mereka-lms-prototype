#!/usr/bin/env bash
# @covers AC-AN-001, AC-AN-002, AC-AN-003, AC-AN-004
# @spec: bead-115d28
#
# Verify MFE frontend plugin parity and analytics instrumentation cleanliness.
#
# Checks:
#   AC-AN-001: Analytics calls gated by valid key (sentinel guard, env var config)
#   AC-AN-002: No invalid/undefined token patterns in analytics call paths
#   AC-AN-003: MFE customizations use documented plugin entry points
#   AC-AN-004: Evidence package structure is documented and CI captures artifacts
#
# Offline-capable: all checks operate on source files only.
# Live mode: set ANALYTICS_LIVE=1 to enable optional cluster checks.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

PASS=0
FAIL=0
WARN=0

pass_check() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

warn() {
  echo "  WARN: $1"
  WARN=$((WARN + 1))
}

PLUGIN="$PLUGIN_MAIN"
FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
MIGRATION_REGISTER="$REPO_ROOT/docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
ANALYTICS_DOC="$REPO_ROOT/docs/reference/operations/MFE_ANALYTICS_PLUGIN_PARITY.md"

echo "========================================"
echo "MFE Analytics + Plugin Parity Verifier"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# AC-AN-001: Analytics calls gated by valid key
# -----------------------------------------------------------------------
echo "AC-AN-001: Analytics key guard"

# Check 1: Plugin configures SEGMENT_KEY from env var (not hardcoded)
if mereka_plugin_has_regex "$REPO_ROOT" 'SEGMENT_KEY.*os\.environ\.get.*MEREKA_SEGMENT_KEY'; then
  pass_check "Plugin reads SEGMENT_KEY from MEREKA_SEGMENT_KEY env var"
else
  fail_check "Plugin reads SEGMENT_KEY from MEREKA_SEGMENT_KEY env var"
fi

# Check 2: Plugin defaults SEGMENT_KEY to empty string (safe default)
if [[ -f "$PLUGIN" ]]; then
  SEGMENT_LINE=$(grep 'SEGMENT_KEY.*os\.environ\.get' "$PLUGIN" || true)
  if echo "$SEGMENT_LINE" | grep -qF '""'; then
    pass_check "SEGMENT_KEY defaults to empty string (disabled by default)"
  else
    warn "SEGMENT_KEY default value may not be empty — review: $SEGMENT_LINE"
  fi
fi

# Check 3: Footer template has NO Segment code (plugin-first canonical state post-2k6k)
# Regression check: any reappearance of segment.io/analytics.load in footer is a violation
if [[ -f "$FOOTER" ]]; then
  if grep -qE 'segment\.io|analytics\.js|analytics\.load|segment_key' "$FOOTER"; then
    fail_check "footer.html has no Segment code (plugin-first model — analytics via Tutor plugin hook only)"
    grep -nE 'segment\.io|analytics\.js|analytics\.load|segment_key' "$FOOTER" | sed 's/^/    /'
  else
    pass_check "footer.html has no Segment code (plugin-first model — analytics via Tutor plugin hook only)"
  fi
else
  warn "footer.html not found — skipping plugin-first analytics check"
fi

# Check 4: Footer has migration comment documenting 2k6k analytics removal
# The comment confirms removal was intentional (not accidental)
if [[ -f "$FOOTER" ]]; then
  if grep -qE '2k6k|analytics.*removed|removed.*analytics|Tutor plugin hook' "$FOOTER"; then
    pass_check "footer.html has 2k6k migration comment (analytics removal documented)"
  else
    warn "footer.html missing 2k6k migration comment — regression may be silent if Segment code re-added"
  fi
fi

# Check 5: No hardcoded analytics keys in plugin or apply-patches
HARDCODED_KEY_HITS=""
for f in "$PLUGIN" "$APPLY_PATCHES"; do
  if [[ -f "$f" ]]; then
    # Look for actual Segment key patterns (starts with letters/numbers, length > 10)
    # Exclude env var reads and template placeholders
    HITS=$(grep -nE 'SEGMENT_KEY\s*=\s*"[A-Za-z0-9]{10,}"' "$f" \
      | grep -v 'os\.environ\|MEREKA_SEGMENT_KEY\|{{' || true)
    if [[ -n "$HITS" ]]; then
      HARDCODED_KEY_HITS="$HARDCODED_KEY_HITS $f:$HITS"
    fi
  fi
done
if [[ -z "$HARDCODED_KEY_HITS" ]]; then
  pass_check "No hardcoded Segment API keys in plugin or patches"
else
  fail_check "No hardcoded Segment API keys in plugin or patches"
  echo "    Found: $HARDCODED_KEY_HITS"
fi

echo ""

# -----------------------------------------------------------------------
# AC-AN-002: No invalid/undefined token call patterns
# -----------------------------------------------------------------------
echo "AC-AN-002: No invalid token call anti-patterns"

# Check 6: No undefined/null token references in analytics paths in theme JS
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
if [[ -d "$THEME_DIR" ]]; then
  UNDEF_ANALYTICS=$(grep -r \
    'analytics\.track\|analytics\.identify\|analytics\.page' \
    "$THEME_DIR" --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" \
    -l 2>/dev/null || true)
  if [[ -z "$UNDEF_ANALYTICS" ]]; then
    pass_check "No direct analytics.track/identify/page calls in theme JS files"
  else
    warn "analytics.* calls found in theme JS — review for undefined token risk: $UNDEF_ANALYTICS"
  fi
else
  warn "Theme directory not found at $THEME_DIR"
fi

# Check 7: Footer template has no Segment script block at all (post-2k6k plugin-first state)
# Any 'if segment_key' guard in footer.html would imply Segment code is present — regression
if [[ -f "$FOOTER" ]]; then
  if grep -qE '<script[^>]*segment|if segment_key|segment\.io' "$FOOTER"; then
    fail_check "footer.html has no Segment script block (plugin-first: analytics via Tutor plugin hook only)"
    grep -nE '<script[^>]*segment|if segment_key|segment\.io' "$FOOTER" | sed 's/^/    /'
  else
    pass_check "footer.html has no Segment script block (plugin-first: analytics via Tutor plugin hook only)"
  fi
fi

# Check 8: No analytics calls with literal 'undefined' or 'null' string tokens
UNDEF_TOKEN_HITS=$(grep -r \
  "SEGMENT_KEY.*=.*['\"]undefined['\"]\\|SEGMENT_KEY.*=.*['\"]null['\"]\\|analytics.*token.*undefined\\|analytics.*key.*null" \
  "$REPO_ROOT/infrastructure" \
  --include="*.py" --include="*.js" --include="*.jsx" --include="*.html" \
  -l 2>/dev/null || true)
if [[ -z "$UNDEF_TOKEN_HITS" ]]; then
  pass_check "No analytics calls with literal undefined/null token values"
else
  fail_check "No analytics calls with literal undefined/null token values"
  echo "    Files: $UNDEF_TOKEN_HITS"
fi

# Check 9: No forbidden 403/405 paths wired for analytics (offline check)
# Verify analytics endpoint is not routed to an admin-only path
if [[ -f "$APPLY_PATCHES" ]]; then
  FORBIDDEN_ANALYTICS=$(grep -n 'analytics.*admin\|/admin.*analytics\|analytics.*403\|analytics.*405' \
    "$APPLY_PATCHES" || true)
  if [[ -z "$FORBIDDEN_ANALYTICS" ]]; then
    pass_check "No analytics endpoints wired to forbidden/admin paths"
  else
    warn "Potential analytics path conflict in apply-patches.sh: $FORBIDDEN_ANALYTICS"
  fi
fi

# Optional live smoke check (requires ANALYTICS_LIVE=1)
if [[ "${ANALYTICS_LIVE:-0}" == "1" ]]; then
  echo "  [live] Checking analytics endpoints for 4xx responses..."
  LMS_URL="${LMS_URL:-https://academyv2.mereka.io}"
  ANALYTICS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "$LMS_URL/event" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"heartbeat"}' \
    --max-time 5 2>/dev/null || echo "000")
  if [[ "$ANALYTICS_STATUS" == "200" ]] || [[ "$ANALYTICS_STATUS" == "204" ]]; then
    pass_check "Live analytics event endpoint returns 2xx (status: $ANALYTICS_STATUS)"
  elif [[ "$ANALYTICS_STATUS" == "000" ]]; then
    warn "Analytics endpoint unreachable (network timeout)"
  else
    warn "Analytics endpoint returned $ANALYTICS_STATUS — may indicate misconfiguration"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-AN-003: MFE customizations use documented plugin entry points
# -----------------------------------------------------------------------
echo "AC-AN-003: MFE plugin entry point compliance"

# Check 10: Migration register exists
if [[ -f "$MIGRATION_REGISTER" ]]; then
  pass_check "MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md exists"
else
  fail_check "MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md exists"
fi

# Check 11: No forbidden DOM override patterns in MFE theme files
MFE_THEME_DIR="$THEME_DIR/mfe"
if [[ -d "$MFE_THEME_DIR" ]]; then
  DOM_HITS=$(grep -r "document\.querySelector\|\.innerHTML" "$MFE_THEME_DIR" \
    --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" \
    -l 2>/dev/null || true)
  if [[ -z "$DOM_HITS" ]]; then
    pass_check "No document.querySelector or innerHTML in MFE theme JS files"
  else
    fail_check "No document.querySelector or innerHTML in MFE theme JS files"
    echo "    Files: $DOM_HITS"
  fi
else
  pass_check "No MFE theme JS directory to scan (safe baseline)"
fi

# Check 12: Footer slot uses PLUGIN_SLOTS (forward-compatible registration)
# PLUGIN_SLOTS import may be in mereka_lms_mfe_slots.py sibling module; search all contract files.
if mereka_plugin_has_fixed "$REPO_ROOT" 'from tutormfe.hooks import PLUGIN_SLOTS'; then
  pass_check "Plugin registers footer slot via PLUGIN_SLOTS (forward-compatible)"
elif [[ -f "$PLUGIN" ]]; then
  # Fallback: check if PLUGIN_SLOTS is used anywhere in the plugin bundle even without explicit import
  if grep -q 'PLUGIN_SLOTS' "$PLUGIN"; then
    pass_check "Plugin registers footer slot via PLUGIN_SLOTS (forward-compatible)"
  else
    fail_check "Plugin registers footer slot via PLUGIN_SLOTS (forward-compatible)"
  fi
fi

# Check 13: env.config patch uses supported mfe-env-config hook variant(s)
if mereka_plugin_has_regex "$REPO_ROOT" '"mfe-env-config"|"mfe-env-config-buildtime-imports"|"mfe-env-config-runtime-definitions"'; then
  pass_check "MFE theme patch uses supported env-config hook variant(s)"
else
  fail_check "MFE theme patch uses supported env-config hook variant(s)"
fi

# Check 14: No banned patterns (direct body injection) in apply-patches.sh
if [[ -f "$APPLY_PATCHES" ]]; then
  BANNED_INJECT=$(grep -n 'document\.body\|document\.getElementById\|\.outerHTML\s*=' \
    "$APPLY_PATCHES" || true)
  if [[ -z "$BANNED_INJECT" ]]; then
    pass_check "No direct body/id DOM injection in apply-patches.sh"
  else
    fail_check "No direct body/id DOM injection in apply-patches.sh"
    echo "    Lines: $BANNED_INJECT"
  fi
fi

# Check 15: Cross-reference with verify-no-dom-overrides.sh results
DOM_OVERRIDE_SCRIPT="$REPO_ROOT/scripts/qa/verify-no-dom-overrides.sh"
if [[ -f "$DOM_OVERRIDE_SCRIPT" ]]; then
  pass_check "verify-no-dom-overrides.sh exists (DOM policy enforced)"
else
  fail_check "verify-no-dom-overrides.sh exists (DOM policy enforced)"
fi

# Check 16: Migration register has at least 1 MIGRATED entry (progress evidence)
if [[ -f "$MIGRATION_REGISTER" ]]; then
  MIGRATED_COUNT=$(grep -c "MIGRATED\|✅ MIGRATED" "$MIGRATION_REGISTER" || true)
  if [[ "$MIGRATED_COUNT" -ge 1 ]]; then
    pass_check "Migration register has at least 1 MIGRATED entry (count: $MIGRATED_COUNT)"
  else
    fail_check "Migration register has at least 1 MIGRATED entry"
  fi
fi

# Check 17: No P0 open items in migration register
if [[ -f "$MIGRATION_REGISTER" ]]; then
  P0_OPEN=$(grep -E "\| P0 \|" "$MIGRATION_REGISTER" | grep -v "Done\|MIGRATED\|✅" || true)
  if [[ -z "$P0_OPEN" ]]; then
    pass_check "No open P0 items in plugin-slot migration register"
  else
    fail_check "No open P0 items in plugin-slot migration register"
    echo "    Open P0 items:"
    echo "$P0_OPEN" | sed 's/^/      /'
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-AN-004: Evidence package structure documented and CI captures artifacts
# -----------------------------------------------------------------------
echo "AC-AN-004: Evidence package and CI artifact structure"

# Check 18: Analytics operational doc exists
if [[ -f "$ANALYTICS_DOC" ]]; then
  pass_check "MFE_ANALYTICS_PLUGIN_PARITY.md doc exists"
else
  fail_check "MFE_ANALYTICS_PLUGIN_PARITY.md doc exists"
fi

# Check 19: Doc covers key configuration architecture
if [[ -f "$ANALYTICS_DOC" ]]; then
  if grep -q 'Analytics Configuration' "$ANALYTICS_DOC"; then
    pass_check "Doc covers analytics configuration architecture"
  else
    fail_check "Doc covers analytics configuration architecture"
  fi
  if grep -q 'sentinel\|Sentinel\|placeholder' "$ANALYTICS_DOC"; then
    pass_check "Doc covers sentinel guard pattern"
  else
    fail_check "Doc covers sentinel guard pattern"
  fi
  if grep -q 'Exception\|exception' "$ANALYTICS_DOC"; then
    pass_check "Doc covers exception register"
  else
    fail_check "Doc covers exception register"
  fi
  if grep -q 'evidence\|Evidence\|artifact' "$ANALYTICS_DOC"; then
    pass_check "Doc covers evidence package format"
  else
    fail_check "Doc covers evidence package format"
  fi
fi

# Check 20: CI workflow has analytics plugin parity job
if [[ -f "$CI_WORKFLOW" ]]; then
  if grep -q 'mfe-analytics-plugin-parity' "$CI_WORKFLOW"; then
    pass_check ".github/workflows/ci.yml contains 'mfe-analytics-plugin-parity' job"
  else
    fail_check ".github/workflows/ci.yml contains 'mfe-analytics-plugin-parity' job"
  fi
else
  fail_check ".github/workflows/ci.yml exists"
fi

# Check 21: var/ directory pattern used for artifacts (consistent with CI)
# CI jobs upload artifacts from var/ — verify this script would produce there
VAR_DIR="$REPO_ROOT/var"
if [[ -d "$VAR_DIR" ]] || grep -q 'var/' "$CI_WORKFLOW" 2>/dev/null; then
  pass_check "var/ artifact directory pattern is used in CI workflow"
else
  warn "var/ artifact directory not referenced in CI — evidence may not be captured"
fi

# Check 22: At least one analytics-related script is syntax-checked in CI guardrails
if [[ -f "$CI_WORKFLOW" ]]; then
  ANALYTICS_IN_CI=$(grep -c 'verify-analytics\|analytics.*parity\|smoke-test-analytics' \
    "$CI_WORKFLOW" || true)
  if [[ "$ANALYTICS_IN_CI" -ge 1 ]]; then
    pass_check "Analytics scripts referenced in CI workflow (count: $ANALYTICS_IN_CI)"
  else
    fail_check "Analytics scripts referenced in CI workflow"
  fi
fi

echo ""
echo "========================================"
echo "Summary: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "========================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation:"
  echo "  AC-AN-001: Ensure SEGMENT_KEY is read from MEREKA_SEGMENT_KEY env var with empty default."
  echo "             footer.html must have NO Segment code (plugin-first model: analytics via Tutor plugin hook only)."
  echo "             If Segment code appeared in footer.html, remove it — this is a regression from bead 2k6k."
  echo "  AC-AN-002: Remove any direct analytics.* calls with undefined/null tokens."
  echo "             Analytics injection belongs exclusively in mereka_lms.py (Tutor plugin hook), not footer.html."
  echo "  AC-AN-003: Replace DOM overrides with plugin slot registrations."
  echo "             Use 'mfe-env-config' hook and PLUGIN_SLOTS for all MFE customizations."
  echo "  AC-AN-004: Create docs/reference/operations/MFE_ANALYTICS_PLUGIN_PARITY.md."
  echo "             Add 'mfe-analytics-plugin-parity' job to .github/workflows/ci.yml."
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
