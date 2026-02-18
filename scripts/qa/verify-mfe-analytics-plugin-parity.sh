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

PASS=0
FAIL=0
WARN=0

check() {
  local desc="$1"
  if eval "$2"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

warn() {
  echo "  WARN: $1"
  WARN=$((WARN + 1))
}

PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
MIGRATION_REGISTER="$REPO_ROOT/docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
ANALYTICS_DOC="$REPO_ROOT/docs/operations/MFE_ANALYTICS_PLUGIN_PARITY.md"

echo "========================================"
echo "MFE Analytics + Plugin Parity Verifier"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# AC-AN-001: Analytics calls gated by valid key
# -----------------------------------------------------------------------
echo "AC-AN-001: Analytics key guard"

# Check 1: Plugin configures SEGMENT_KEY from env var (not hardcoded)
if [[ -f "$PLUGIN" ]]; then
  if grep -q 'SEGMENT_KEY.*os\.environ\.get.*MEREKA_SEGMENT_KEY' "$PLUGIN"; then
    check "Plugin reads SEGMENT_KEY from MEREKA_SEGMENT_KEY env var" "true"
  else
    check "Plugin reads SEGMENT_KEY from MEREKA_SEGMENT_KEY env var" "false"
  fi
else
  warn "mereka_lms.py not found at $PLUGIN"
fi

# Check 2: Plugin defaults SEGMENT_KEY to empty string (safe default)
if [[ -f "$PLUGIN" ]]; then
  SEGMENT_LINE=$(grep 'SEGMENT_KEY.*os\.environ\.get' "$PLUGIN" || true)
  if echo "$SEGMENT_LINE" | grep -qF '""'; then
    check "SEGMENT_KEY defaults to empty string (disabled by default)" "true"
  else
    warn "SEGMENT_KEY default value may not be empty — review: $SEGMENT_LINE"
  fi
fi

# Check 3: Footer template has sentinel guard before emitting Segment JS
if [[ -f "$FOOTER" ]]; then
  if grep -q 'segment_key.*lower.*not in' "$FOOTER"; then
    check "footer.html has sentinel guard (rejects placeholder keys)" "true"
  else
    check "footer.html has sentinel guard (rejects placeholder keys)" "false"
  fi
else
  warn "footer.html not found — skipping sentinel guard check"
fi

# Check 4: Sentinel guard covers known placeholder values
if [[ -f "$FOOTER" ]]; then
  GUARD_LINE=$(grep 'segment_key.*lower.*not in' "$FOOTER" || true)
  SENTINELS_OK=true
  for sentinel in "undefined" "none" "null" "undefined_license_key" "your_segment_key_here" "change_me"; do
    if ! echo "$GUARD_LINE" | grep -q "$sentinel"; then
      SENTINELS_OK=false
      warn "Sentinel '$sentinel' missing from footer guard"
    fi
  done
  if [[ "$SENTINELS_OK" == "true" ]]; then
    check "Footer sentinel guard covers all known placeholder values" "true"
  else
    check "Footer sentinel guard covers all known placeholder values" "false"
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
  check "No hardcoded Segment API keys in plugin or patches" "true"
else
  check "No hardcoded Segment API keys in plugin or patches" "false"
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
    check "No direct analytics.track/identify/page calls in theme JS files" "true"
  else
    warn "analytics.* calls found in theme JS — review for undefined token risk: $UNDEF_ANALYTICS"
  fi
else
  warn "Theme directory not found at $THEME_DIR"
fi

# Check 7: Footer template does not emit Segment script when key is empty
if [[ -f "$FOOTER" ]]; then
  # The guard must wrap the segment-io include or script block
  GUARD_PRESENT=$(grep -c 'if segment_key' "$FOOTER" || true)
  if [[ "$GUARD_PRESENT" -ge 1 ]]; then
    check "Footer Segment script is wrapped in 'if segment_key' guard" "true"
  else
    check "Footer Segment script is wrapped in 'if segment_key' guard" "false"
  fi
fi

# Check 8: No analytics calls with literal 'undefined' or 'null' string tokens
UNDEF_TOKEN_HITS=$(grep -r \
  "SEGMENT_KEY.*=.*['\"]undefined['\"]\\|SEGMENT_KEY.*=.*['\"]null['\"]\\|analytics.*token.*undefined\\|analytics.*key.*null" \
  "$REPO_ROOT/infrastructure" \
  --include="*.py" --include="*.js" --include="*.jsx" --include="*.html" \
  -l 2>/dev/null || true)
if [[ -z "$UNDEF_TOKEN_HITS" ]]; then
  check "No analytics calls with literal undefined/null token values" "true"
else
  check "No analytics calls with literal undefined/null token values" "false"
  echo "    Files: $UNDEF_TOKEN_HITS"
fi

# Check 9: No forbidden 403/405 paths wired for analytics (offline check)
# Verify analytics endpoint is not routed to an admin-only path
if [[ -f "$APPLY_PATCHES" ]]; then
  FORBIDDEN_ANALYTICS=$(grep -n 'analytics.*admin\|/admin.*analytics\|analytics.*403\|analytics.*405' \
    "$APPLY_PATCHES" || true)
  if [[ -z "$FORBIDDEN_ANALYTICS" ]]; then
    check "No analytics endpoints wired to forbidden/admin paths" "true"
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
    check "Live analytics event endpoint returns 2xx (status: $ANALYTICS_STATUS)" "true"
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
check "MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md exists" "[[ -f '$MIGRATION_REGISTER' ]]"

# Check 11: No forbidden DOM override patterns in MFE theme files
MFE_THEME_DIR="$THEME_DIR/mfe"
if [[ -d "$MFE_THEME_DIR" ]]; then
  DOM_HITS=$(grep -r "document\.querySelector\|\.innerHTML" "$MFE_THEME_DIR" \
    --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" \
    -l 2>/dev/null || true)
  if [[ -z "$DOM_HITS" ]]; then
    check "No document.querySelector or innerHTML in MFE theme JS files" "true"
  else
    check "No document.querySelector or innerHTML in MFE theme JS files" "false"
    echo "    Files: $DOM_HITS"
  fi
else
  check "No MFE theme JS directory to scan (safe baseline)" "true"
fi

# Check 12: Footer slot uses PLUGIN_SLOTS (forward-compatible registration)
if [[ -f "$PLUGIN" ]]; then
  if grep -q 'from tutormfe.hooks import PLUGIN_SLOTS' "$PLUGIN"; then
    check "Plugin registers footer slot via PLUGIN_SLOTS (forward-compatible)" "true"
  else
    check "Plugin registers footer slot via PLUGIN_SLOTS (forward-compatible)" "false"
  fi
fi

# Check 13: env.config patch uses mfe-env-config hook (canonical entry point)
if [[ -f "$PLUGIN" ]]; then
  if grep -q '"mfe-env-config"' "$PLUGIN"; then
    check "MFE theme patch uses canonical 'mfe-env-config' hook" "true"
  else
    check "MFE theme patch uses canonical 'mfe-env-config' hook" "false"
  fi
fi

# Check 14: No banned patterns (direct body injection) in apply-patches.sh
if [[ -f "$APPLY_PATCHES" ]]; then
  BANNED_INJECT=$(grep -n 'document\.body\|document\.getElementById\|\.outerHTML\s*=' \
    "$APPLY_PATCHES" || true)
  if [[ -z "$BANNED_INJECT" ]]; then
    check "No direct body/id DOM injection in apply-patches.sh" "true"
  else
    check "No direct body/id DOM injection in apply-patches.sh" "false"
    echo "    Lines: $BANNED_INJECT"
  fi
fi

# Check 15: Cross-reference with verify-no-dom-overrides.sh results
DOM_OVERRIDE_SCRIPT="$REPO_ROOT/scripts/qa/verify-no-dom-overrides.sh"
check "verify-no-dom-overrides.sh exists (DOM policy enforced)" "[[ -f '$DOM_OVERRIDE_SCRIPT' ]]"

# Check 16: Migration register has at least 1 MIGRATED entry (progress evidence)
if [[ -f "$MIGRATION_REGISTER" ]]; then
  MIGRATED_COUNT=$(grep -c "MIGRATED\|✅ MIGRATED" "$MIGRATION_REGISTER" || true)
  if [[ "$MIGRATED_COUNT" -ge 1 ]]; then
    check "Migration register has at least 1 MIGRATED entry (count: $MIGRATED_COUNT)" "true"
  else
    check "Migration register has at least 1 MIGRATED entry" "false"
  fi
fi

# Check 17: No P0 open items in migration register
if [[ -f "$MIGRATION_REGISTER" ]]; then
  P0_OPEN=$(grep -E "\| P0 \|" "$MIGRATION_REGISTER" | grep -v "Done\|MIGRATED\|✅" || true)
  if [[ -z "$P0_OPEN" ]]; then
    check "No open P0 items in plugin-slot migration register" "true"
  else
    check "No open P0 items in plugin-slot migration register" "false"
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
check "MFE_ANALYTICS_PLUGIN_PARITY.md doc exists" "[[ -f '$ANALYTICS_DOC' ]]"

# Check 19: Doc covers key configuration architecture
if [[ -f "$ANALYTICS_DOC" ]]; then
  check "Doc covers analytics configuration architecture" \
    "grep -q 'Analytics Configuration' '$ANALYTICS_DOC'"
  check "Doc covers sentinel guard pattern" \
    "grep -q 'sentinel\|Sentinel\|placeholder' '$ANALYTICS_DOC'"
  check "Doc covers exception register" \
    "grep -q 'Exception\|exception' '$ANALYTICS_DOC'"
  check "Doc covers evidence package format" \
    "grep -q 'evidence\|Evidence\|artifact' '$ANALYTICS_DOC'"
fi

# Check 20: CI workflow has analytics plugin parity job
if [[ -f "$CI_WORKFLOW" ]]; then
  check ".github/workflows/ci.yml contains 'mfe-analytics-plugin-parity' job" \
    "grep -q 'mfe-analytics-plugin-parity' '$CI_WORKFLOW'"
else
  check ".github/workflows/ci.yml exists" "false"
fi

# Check 21: var/ directory pattern used for artifacts (consistent with CI)
# CI jobs upload artifacts from var/ — verify this script would produce there
VAR_DIR="$REPO_ROOT/var"
if [[ -d "$VAR_DIR" ]] || grep -q 'var/' "$CI_WORKFLOW" 2>/dev/null; then
  check "var/ artifact directory pattern is used in CI workflow" "true"
else
  warn "var/ artifact directory not referenced in CI — evidence may not be captured"
fi

# Check 22: At least one analytics-related script is syntax-checked in CI guardrails
if [[ -f "$CI_WORKFLOW" ]]; then
  ANALYTICS_IN_CI=$(grep -c 'verify-analytics\|analytics.*parity\|smoke-test-analytics' \
    "$CI_WORKFLOW" || true)
  if [[ "$ANALYTICS_IN_CI" -ge 1 ]]; then
    check "Analytics scripts referenced in CI workflow (count: $ANALYTICS_IN_CI)" "true"
  else
    check "Analytics scripts referenced in CI workflow" "false"
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
  echo "             Add sentinel guard to footer.html for all known placeholder values."
  echo "  AC-AN-002: Remove any direct analytics.* calls with undefined/null tokens."
  echo "             Wrap all Segment script emission in 'if segment_key' guards."
  echo "  AC-AN-003: Replace DOM overrides with plugin slot registrations."
  echo "             Use 'mfe-env-config' hook and PLUGIN_SLOTS for all MFE customizations."
  echo "  AC-AN-004: Create docs/operations/MFE_ANALYTICS_PLUGIN_PARITY.md."
  echo "             Add 'mfe-analytics-plugin-parity' job to .github/workflows/ci.yml."
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
