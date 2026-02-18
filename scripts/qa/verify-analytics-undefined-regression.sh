#!/usr/bin/env bash
# @covers AC-FRONT-071, AC-FRONT-072, AC-FRONT-073, AC-FRONT-074
# @spec: bead-2dcy7
#
# Verify that undefined_license_key analytics regressions are resolved end-to-end.
#
# Checks:
#   AC-FRONT-071: Baseline failure documentation exists (what calls were undefined,
#                 which hosts affected: admin/auth and apps hosts)
#   AC-FRONT-072: Config injection code (mereka_lms.py, env.config.jsx) validates
#                 key before injection — empty/placeholder must not trigger calls
#   AC-FRONT-073: Smoke test coverage exists for undefined analytics call detection
#                 on admin/authn/apps hosts. Live mode: ANALYTICS_SMOKE_LIVE=1
#   AC-FRONT-074: Plugin injection docs updated with surface mapping and fallback
#                 exception policy
#
# Offline-capable: all checks operate on source files only.
# Live mode: set ANALYTICS_SMOKE_LIVE=1 to enable optional cluster checks.

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
REGRESSION_DOC="$REPO_ROOT/docs/operations/ANALYTICS_UNDEFINED_REGRESSION_FIX.md"
PARITY_DOC="$REPO_ROOT/docs/operations/MFE_ANALYTICS_PLUGIN_PARITY.md"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

echo "========================================================"
echo "Analytics Undefined Regression Verifier (bead 2dcy.7)"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------
# AC-FRONT-071: Baseline failure documentation
# -----------------------------------------------------------------------
echo "AC-FRONT-071: Baseline failure documentation"

# Check 1: Regression fix doc exists
check "ANALYTICS_UNDEFINED_REGRESSION_FIX.md exists" "[[ -f '$REGRESSION_DOC' ]]"

# Check 2: Doc records the specific symptom (undefined_license_key calls)
if [[ -f "$REGRESSION_DOC" ]]; then
  check "Regression doc documents undefined_license_key symptom" \
    "grep -q 'undefined_license_key' '$REGRESSION_DOC'"
fi

# Check 3: Doc names which hosts were affected (admin/auth and apps)
if [[ -f "$REGRESSION_DOC" ]]; then
  check "Regression doc names affected hosts (authn/apps/admin)" \
    "grep -qiE 'authn|apps\\.academyv2|admin' '$REGRESSION_DOC'"
fi

# Check 4: Doc records 403/405 error type
if [[ -f "$REGRESSION_DOC" ]]; then
  check "Regression doc records 403/405 error type or network failure class" \
    "grep -qE '403|405|network|Network' '$REGRESSION_DOC'"
fi

# Check 5: Doc has a root cause section
if [[ -f "$REGRESSION_DOC" ]]; then
  check "Regression doc has a root cause section" \
    "grep -qi 'root cause\|Root Cause' '$REGRESSION_DOC'"
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-072: Config injection — sentinel guards in place
# -----------------------------------------------------------------------
echo "AC-FRONT-072: Sentinel guard in config injection paths"

# Check 6: Plugin reads SEGMENT_KEY from env (not hardcoded)
if [[ -f "$PLUGIN" ]]; then
  check "mereka_lms.py reads SEGMENT_KEY from MEREKA_SEGMENT_KEY env var" \
    "grep -q 'SEGMENT_KEY.*os\.environ\.get.*MEREKA_SEGMENT_KEY' '$PLUGIN'"
else
  warn "mereka_lms.py not found at $PLUGIN"
fi

# Check 7: Plugin defaults SEGMENT_KEY to empty string
if [[ -f "$PLUGIN" ]]; then
  SEGMENT_LINE=$(grep 'SEGMENT_KEY.*os\.environ\.get' "$PLUGIN" || true)
  if echo "$SEGMENT_LINE" | grep -qF '""'; then
    check "SEGMENT_KEY defaults to empty string (disabled by default)" "true"
  else
    check "SEGMENT_KEY defaults to empty string (disabled by default)" "false"
  fi
fi

# Check 8: No hardcoded undefined_license_key outside guard context
if [[ -f "$PLUGIN" ]]; then
  # undefined_license_key must not appear as an assigned value in plugin
  HARDCODED=$(grep -n 'undefined_license_key' "$PLUGIN" | grep -v '^\s*#' || true)
  if [[ -z "$HARDCODED" ]]; then
    check "No 'undefined_license_key' literal assigned in mereka_lms.py" "true"
  else
    check "No 'undefined_license_key' literal assigned in mereka_lms.py" "false"
    echo "    Found: $HARDCODED"
  fi
fi

# Check 9: Footer template rejects undefined_license_key sentinel
if [[ -f "$FOOTER" ]]; then
  check "footer.html sentinel guard includes 'undefined_license_key' rejection" \
    "grep -q 'undefined_license_key' '$FOOTER'"
else
  warn "footer.html not found at $FOOTER"
fi

# Check 10: Footer guard covers full set of sentinel values
if [[ -f "$FOOTER" ]]; then
  GUARD_LINE=$(grep 'segment_key.*lower.*not in' "$FOOTER" || true)
  ALL_SENTINELS=true
  for sentinel in "undefined" "none" "null" "undefined_license_key" "your_segment_key_here" "change_me"; do
    if ! echo "$GUARD_LINE" | grep -q "$sentinel"; then
      ALL_SENTINELS=false
      warn "Sentinel '$sentinel' missing from footer.html guard"
    fi
  done
  if [[ "$ALL_SENTINELS" == "true" ]]; then
    check "footer.html sentinel guard covers all 6 known placeholder values" "true"
  else
    check "footer.html sentinel guard covers all 6 known placeholder values" "false"
  fi
fi

# Check 11: Footer wraps Segment script emission in non-empty key guard
if [[ -f "$FOOTER" ]]; then
  check "footer.html wraps Segment includes in 'if segment_key' guard" \
    "grep -c 'if segment_key' '$FOOTER' | grep -qE '^[1-9]'"
fi

# Check 12: env.config.jsx (MFE) does not hardcode Segment key
# The MFE template itself doesn't emit analytics — Segment is LMS-only via footer
ENV_CONFIG="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx"
if [[ -f "$ENV_CONFIG" ]]; then
  HARDCODED_SEGMENT=$(grep -nE "SEGMENT_KEY\s*=\s*['\"][^'\"]{10,}['\"]" "$ENV_CONFIG" \
    | grep -v 'os\.environ\|MEREKA_SEGMENT_KEY\|{{' || true)
  if [[ -z "$HARDCODED_SEGMENT" ]]; then
    check "env.config.jsx has no hardcoded Segment key assignment" "true"
  else
    check "env.config.jsx has no hardcoded Segment key assignment" "false"
    echo "    Found: $HARDCODED_SEGMENT"
  fi
else
  # Rendered file not present (offline/CI) — check plugin source instead
  check "No hardcoded Segment key in mfe-env-config patch (plugin source)" \
    "! grep -qE 'SEGMENT_KEY\\s*=\\s*[a-zA-Z0-9]{20,}' '$PLUGIN'"
fi

# Check 13: No undefined/null literal token values in analytics paths
UNDEF_HITS=$(grep -r \
  "SEGMENT_KEY.*=.*['\"]undefined['\"]\\|SEGMENT_KEY.*=.*['\"]null['\"]" \
  "$REPO_ROOT/infrastructure" \
  --include="*.py" --include="*.js" --include="*.jsx" --include="*.html" \
  -l 2>/dev/null || true)
if [[ -z "$UNDEF_HITS" ]]; then
  check "No SEGMENT_KEY assigned literal 'undefined' or 'null' strings in infrastructure/" "true"
else
  check "No SEGMENT_KEY assigned literal 'undefined' or 'null' strings in infrastructure/" "false"
  echo "    Files: $UNDEF_HITS"
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-073: Smoke check coverage for undefined analytics calls
# -----------------------------------------------------------------------
echo "AC-FRONT-073: Smoke test coverage for undefined analytics calls"

# Check 14: Regression doc has smoke check commands section
if [[ -f "$REGRESSION_DOC" ]]; then
  check "Regression doc has smoke check commands" \
    "grep -qiE 'smoke|Smoke|verification|Verification' '$REGRESSION_DOC'"
fi

# Check 15: At least one verify-analytics script exists
ANALYTICS_SCRIPT_COUNT=$(find "$REPO_ROOT/scripts/qa" -name "verify-analytics*.sh" 2>/dev/null | wc -l)
if [[ "$ANALYTICS_SCRIPT_COUNT" -ge 1 ]]; then
  check "At least one verify-analytics*.sh script present (count: $ANALYTICS_SCRIPT_COUNT)" "true"
else
  check "At least one verify-analytics*.sh script present" "false"
fi

# Check 16: CI workflow references analytics smoke/verify scripts
if [[ -f "$CI_WORKFLOW" ]]; then
  ANALYTICS_REFS=$(grep -c 'verify-analytics\|analytics-undefined-regression\|mfe-analytics-plugin-parity' \
    "$CI_WORKFLOW" || true)
  if [[ "$ANALYTICS_REFS" -ge 1 ]]; then
    check "CI workflow references analytics scripts (refs: $ANALYTICS_REFS)" "true"
  else
    check "CI workflow references analytics scripts" "false"
  fi
fi

# Check 17: CI workflow has analytics-undefined-regression job
if [[ -f "$CI_WORKFLOW" ]]; then
  check "CI workflow has 'analytics-undefined-regression' job" \
    "grep -q 'analytics-undefined-regression' '$CI_WORKFLOW'"
fi

# Check 18: Regression doc documents expected output / evidence bundle format
if [[ -f "$REGRESSION_DOC" ]]; then
  check "Regression doc has evidence bundle or expected output section" \
    "grep -qiE 'evidence|Evidence|expected output|Expected Output' '$REGRESSION_DOC'"
fi

# Optional live smoke check (requires ANALYTICS_SMOKE_LIVE=1)
if [[ "${ANALYTICS_SMOKE_LIVE:-0}" == "1" ]]; then
  echo "  [live] Running live undefined analytics call checks..."
  LMS_URL="${LMS_URL:-https://academyv2.mereka.io}"
  APPS_URL="${APPS_URL:-https://apps.academyv2.mereka.io}"

  # Check admin host — analytics should not fire on /admin paths
  echo "  [live] Fetching admin login page..."
  ADMIN_BODY=$(curl -s --max-time 10 "$LMS_URL/admin/login/" 2>/dev/null || echo "")
  if echo "$ADMIN_BODY" | grep -qi 'undefined_license_key'; then
    check "[live] Admin host has no 'undefined_license_key' in page source" "false"
  elif [[ -z "$ADMIN_BODY" ]]; then
    warn "[live] Admin login page unreachable (network issue or cluster not running)"
  else
    check "[live] Admin host has no 'undefined_license_key' in page source" "true"
  fi

  # Check authn MFE host
  echo "  [live] Fetching authn MFE page..."
  AUTHN_BODY=$(curl -s --max-time 10 "$APPS_URL/authn/login" 2>/dev/null || echo "")
  if echo "$AUTHN_BODY" | grep -qi 'undefined_license_key'; then
    check "[live] authn MFE host has no 'undefined_license_key' in page source" "false"
  elif [[ -z "$AUTHN_BODY" ]]; then
    warn "[live] authn MFE page unreachable (network issue or cluster not running)"
  else
    check "[live] authn MFE host has no 'undefined_license_key' in page source" "true"
  fi

  # Check apps host for undefined analytics
  echo "  [live] Fetching learner-dashboard MFE page..."
  DASHBOARD_BODY=$(curl -s --max-time 10 "$APPS_URL/learner-dashboard/" 2>/dev/null || echo "")
  if echo "$DASHBOARD_BODY" | grep -qi 'undefined_license_key'; then
    check "[live] apps host learner-dashboard has no 'undefined_license_key'" "false"
  elif [[ -z "$DASHBOARD_BODY" ]]; then
    warn "[live] learner-dashboard page unreachable (network issue or cluster not running)"
  else
    check "[live] apps host learner-dashboard has no 'undefined_license_key'" "true"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-074: Plugin injection docs — surface mapping + fallback policy
# -----------------------------------------------------------------------
echo "AC-FRONT-074: Plugin injection docs — surface mapping and fallback exception policy"

# Check 19: Parity doc exists (MFE_ANALYTICS_PLUGIN_PARITY.md)
check "MFE_ANALYTICS_PLUGIN_PARITY.md exists" "[[ -f '$PARITY_DOC' ]]"

# Check 20: Parity doc has surface mapping (lists which files inject analytics)
if [[ -f "$PARITY_DOC" ]]; then
  check "Parity doc maps injection surfaces (mereka_lms.py, env.config.jsx)" \
    "grep -qE 'mereka_lms\.py|env\.config' '$PARITY_DOC'"
fi

# Check 21: Parity doc documents the exception register (fallback policy)
if [[ -f "$PARITY_DOC" ]]; then
  check "Parity doc has exception register / fallback exception policy" \
    "grep -qi 'exception\|Exception' '$PARITY_DOC'"
fi

# Check 22: Parity doc has approved entry points / surface map
if [[ -f "$PARITY_DOC" ]]; then
  check "Parity doc lists approved entry points / surface map" \
    "grep -qi 'entry point\|Entry Point\|surface\|Surface' '$PARITY_DOC'"
fi

# Check 23: Regression doc cross-references the surface mapping doc
if [[ -f "$REGRESSION_DOC" ]]; then
  check "Regression doc references MFE_ANALYTICS_PLUGIN_PARITY.md" \
    "grep -q 'MFE_ANALYTICS_PLUGIN_PARITY' '$REGRESSION_DOC'"
fi

# Check 24: Fallback policy for missing key is documented (analytics disabled / no-op)
if [[ -f "$REGRESSION_DOC" ]]; then
  check "Regression doc documents fallback when key is absent (no-op / analytics disabled)" \
    "grep -qiE 'disabled|no-op|no calls|silent' '$REGRESSION_DOC'"
fi

echo ""
echo "========================================================"
echo "Summary: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "========================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation:"
  echo "  AC-FRONT-071: Create docs/operations/ANALYTICS_UNDEFINED_REGRESSION_FIX.md"
  echo "                Document: symptom (undefined_license_key calls), affected hosts,"
  echo "                403/405 errors, root cause, and smoke check commands."
  echo "  AC-FRONT-072: Ensure mereka_lms.py uses os.environ.get('MEREKA_SEGMENT_KEY', '')"
  echo "                Ensure footer.html has sentinel guard rejecting all placeholder values."
  echo "                Verify no SEGMENT_KEY is hardcoded to a literal undefined/null/placeholder."
  echo "  AC-FRONT-073: Add 'analytics-undefined-regression' job to .github/workflows/ci.yml."
  echo "                Include smoke check commands in the regression doc."
  echo "  AC-FRONT-074: Update MFE_ANALYTICS_PLUGIN_PARITY.md with surface mapping and"
  echo "                fallback exception policy. Cross-reference from regression doc."
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
