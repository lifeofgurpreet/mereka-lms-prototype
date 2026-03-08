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

PLUGIN_BUNDLE=""
cleanup() {
  if [[ -n "${PLUGIN_BUNDLE:-}" && -f "${PLUGIN_BUNDLE}" ]]; then
    rm -f "${PLUGIN_BUNDLE}"
  fi
}
trap cleanup EXIT

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp "${TMPDIR:-/tmp}/mereka-plugin-contract.analytics-undefined.XXXXXX.py")"
  while IFS= read -r plugin_src; do
    [[ -f "$plugin_src" ]] || continue
    cat "$plugin_src" >> "$PLUGIN_BUNDLE"
    printf "\n" >> "$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
fi

PLUGIN="${PLUGIN_BUNDLE:-$PLUGIN_MAIN}"
FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
REGRESSION_DOC="$REPO_ROOT/reports/2026/learnings/ANALYTICS_UNDEFINED_REGRESSION_FIX.md"
PARITY_DOC="$REPO_ROOT/docs/reference/operations/MFE_ANALYTICS_PLUGIN_PARITY.md"
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
if [[ -f "$REGRESSION_DOC" ]]; then
  pass_check "ANALYTICS_UNDEFINED_REGRESSION_FIX.md exists"
else
  fail_check "ANALYTICS_UNDEFINED_REGRESSION_FIX.md exists"
fi

# Check 2: Doc records the specific symptom (undefined_license_key calls)
if [[ -f "$REGRESSION_DOC" ]]; then
  if grep -q 'undefined_license_key' "$REGRESSION_DOC"; then
    pass_check "Regression doc documents undefined_license_key symptom"
  else
    fail_check "Regression doc documents undefined_license_key symptom"
  fi
fi

# Check 3: Doc names which hosts were affected (admin/auth and apps)
if [[ -f "$REGRESSION_DOC" ]]; then
  if grep -qiE 'authn|apps\.academyv2|admin' "$REGRESSION_DOC"; then
    pass_check "Regression doc names affected hosts (authn/apps/admin)"
  else
    fail_check "Regression doc names affected hosts (authn/apps/admin)"
  fi
fi

# Check 4: Doc records 403/405 error type
if [[ -f "$REGRESSION_DOC" ]]; then
  if grep -qE '403|405|network|Network' "$REGRESSION_DOC"; then
    pass_check "Regression doc records 403/405 error type or network failure class"
  else
    fail_check "Regression doc records 403/405 error type or network failure class"
  fi
fi

# Check 5: Doc has a root cause section
if [[ -f "$REGRESSION_DOC" ]]; then
  if grep -qi 'root cause\|Root Cause' "$REGRESSION_DOC"; then
    pass_check "Regression doc has a root cause section"
  else
    fail_check "Regression doc has a root cause section"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-072: Config injection — sentinel guards in place
# -----------------------------------------------------------------------
echo "AC-FRONT-072: Sentinel guard in config injection paths"

# Check 6: Plugin reads SEGMENT_KEY from env (not hardcoded)
if [[ -f "$PLUGIN" ]]; then
  if grep -q 'SEGMENT_KEY.*os\.environ\.get.*MEREKA_SEGMENT_KEY' "$PLUGIN"; then
    pass_check "mereka_lms.py reads SEGMENT_KEY from MEREKA_SEGMENT_KEY env var"
  else
    fail_check "mereka_lms.py reads SEGMENT_KEY from MEREKA_SEGMENT_KEY env var"
  fi
else
  warn "Plugin contract sources not found (expected at least $PLUGIN_MAIN)"
fi

# Check 7: Plugin defaults SEGMENT_KEY to empty string
if [[ -f "$PLUGIN" ]]; then
  SEGMENT_LINE=$(grep 'SEGMENT_KEY.*os\.environ\.get' "$PLUGIN" || true)
  if echo "$SEGMENT_LINE" | grep -qF '""'; then
    pass_check "SEGMENT_KEY defaults to empty string (disabled by default)"
  else
    fail_check "SEGMENT_KEY defaults to empty string (disabled by default)"
  fi
fi

# Check 8: No hardcoded undefined_license_key outside guard context
if [[ -f "$PLUGIN" ]]; then
  # undefined_license_key must not appear as an assigned value in plugin
  HARDCODED=$(grep -n 'undefined_license_key' "$PLUGIN" | grep -v '^\s*#' || true)
  if [[ -z "$HARDCODED" ]]; then
    pass_check "No 'undefined_license_key' literal assigned in mereka_lms.py"
  else
    fail_check "No 'undefined_license_key' literal assigned in mereka_lms.py"
    echo "    Found: $HARDCODED"
  fi
fi

# Check 9: Footer template has NO Segment script block (plugin-first: analytics via Tutor hook)
# Post-2k6k: Segment removed from footer entirely. Correct state = absence, not guarded presence.
if [[ -f "$FOOTER" ]]; then
  if grep -qE "segment\.io|analytics\.js|analytics\.load|segment_key" "$FOOTER"; then
    fail_check "footer.html still contains Segment script block (must be removed — use Tutor plugin hook)"
  else
    pass_check "footer.html has no Segment script block (plugin-first: analytics via Tutor hook)"
  fi
else
  warn "footer.html not found at $FOOTER"
fi

# Check 10: Footer comment confirms analytics moved to plugin hook (documents canonical approach)
if [[ -f "$FOOTER" ]]; then
  if grep -q "Tutor plugin hook\|plugin hook\|MIGRATED\|analytics.*removed\|removed.*analytics" "$FOOTER"; then
    pass_check "footer.html comment confirms analytics moved to Tutor plugin hook"
  else
    warn "footer.html has no comment confirming analytics migration to plugin hook (add for auditability)"
  fi
fi

# Check 11: Footer has no undefined_license_key literal (regression guard)
if [[ -f "$FOOTER" ]]; then
  if grep -q 'undefined_license_key' "$FOOTER"; then
    fail_check "footer.html contains 'undefined_license_key' literal (regression — must not appear)"
  else
    pass_check "footer.html has no 'undefined_license_key' literal"
  fi
fi

# Check 12: env.config.jsx (MFE) does not hardcode Segment key
# The MFE template itself doesn't emit analytics — Segment is LMS-only via footer
ENV_CONFIG="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx"
if [[ -f "$ENV_CONFIG" ]]; then
  HARDCODED_SEGMENT=$(grep -nE "SEGMENT_KEY\s*=\s*['\"][^'\"]{10,}['\"]" "$ENV_CONFIG" \
    | grep -v 'os\.environ\|MEREKA_SEGMENT_KEY\|{{' || true)
  if [[ -z "$HARDCODED_SEGMENT" ]]; then
    pass_check "env.config.jsx has no hardcoded Segment key assignment"
  else
    fail_check "env.config.jsx has no hardcoded Segment key assignment"
    echo "    Found: $HARDCODED_SEGMENT"
  fi
else
  # Rendered file not present (offline/CI) — check plugin source instead
  if ! grep -qE 'SEGMENT_KEY\s*=\s*[a-zA-Z0-9]{20,}' "$PLUGIN"; then
    pass_check "No hardcoded Segment key in mfe-env-config patch (plugin source)"
  else
    fail_check "No hardcoded Segment key in mfe-env-config patch (plugin source)"
  fi
fi

# Check 13: No undefined/null literal token values in analytics paths
UNDEF_HITS=$(grep -r \
  "SEGMENT_KEY.*=.*['\"]undefined['\"]\\|SEGMENT_KEY.*=.*['\"]null['\"]" \
  "$REPO_ROOT/infrastructure" \
  --include="*.py" --include="*.js" --include="*.jsx" --include="*.html" \
  -l 2>/dev/null || true)
if [[ -z "$UNDEF_HITS" ]]; then
  pass_check "No SEGMENT_KEY assigned literal 'undefined' or 'null' strings in infrastructure/"
else
  fail_check "No SEGMENT_KEY assigned literal 'undefined' or 'null' strings in infrastructure/"
  echo "    Files: $UNDEF_HITS"
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-073: Smoke check coverage for undefined analytics calls
# -----------------------------------------------------------------------
echo "AC-FRONT-073: Smoke test coverage for undefined analytics calls"

# Check 14: Regression doc has smoke check commands section
if [[ -f "$REGRESSION_DOC" ]] && grep -qiE 'smoke|verification' "$REGRESSION_DOC"; then
  pass_check "Regression doc has smoke check commands"
elif [[ -f "$REGRESSION_DOC" ]]; then
  fail_check "Regression doc missing smoke check commands"
fi

# Check 15: At least one verify-analytics script exists
ANALYTICS_SCRIPT_COUNT=$(find "$REPO_ROOT/scripts/qa" -name "verify-analytics*.sh" 2>/dev/null | wc -l)
if [[ "$ANALYTICS_SCRIPT_COUNT" -ge 1 ]]; then
  pass_check "At least one verify-analytics*.sh script present (count: $ANALYTICS_SCRIPT_COUNT)"
else
  fail_check "At least one verify-analytics*.sh script present"
fi

# Check 16: CI workflow references analytics smoke/verify scripts
if [[ -f "$CI_WORKFLOW" ]]; then
  ANALYTICS_REFS=$(grep -c 'verify-analytics\|analytics-undefined-regression\|mfe-analytics-plugin-parity' \
    "$CI_WORKFLOW" || true)
  if [[ "$ANALYTICS_REFS" -ge 1 ]]; then
    pass_check "CI workflow references analytics scripts (refs: $ANALYTICS_REFS)"
  else
    fail_check "CI workflow references analytics scripts"
  fi
fi

# Check 17: CI workflow has analytics-undefined-regression job
if [[ -f "$CI_WORKFLOW" ]] && grep -q 'analytics-undefined-regression' "$CI_WORKFLOW"; then
  pass_check "CI workflow has 'analytics-undefined-regression' job"
elif [[ -f "$CI_WORKFLOW" ]]; then
  fail_check "CI workflow has 'analytics-undefined-regression' job"
fi

# Check 18: Regression doc documents expected output / evidence bundle format
if [[ -f "$REGRESSION_DOC" ]] && grep -qiE 'evidence|expected output' "$REGRESSION_DOC"; then
  pass_check "Regression doc has evidence bundle or expected output section"
elif [[ -f "$REGRESSION_DOC" ]]; then
  fail_check "Regression doc has evidence bundle or expected output section"
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
    fail_check "[live] Admin host has no 'undefined_license_key' in page source"
  elif [[ -z "$ADMIN_BODY" ]]; then
    warn "[live] Admin login page unreachable (network issue or cluster not running)"
  else
    pass_check "[live] Admin host has no 'undefined_license_key' in page source"
  fi

  # Check authn MFE host
  echo "  [live] Fetching authn MFE page..."
  AUTHN_BODY=$(curl -s --max-time 10 "$APPS_URL/authn/login" 2>/dev/null || echo "")
  if echo "$AUTHN_BODY" | grep -qi 'undefined_license_key'; then
    fail_check "[live] authn MFE host has no 'undefined_license_key' in page source"
  elif [[ -z "$AUTHN_BODY" ]]; then
    warn "[live] authn MFE page unreachable (network issue or cluster not running)"
  else
    pass_check "[live] authn MFE host has no 'undefined_license_key' in page source"
  fi

  # Check apps host for undefined analytics
  echo "  [live] Fetching learner-dashboard MFE page..."
  DASHBOARD_BODY=$(curl -s --max-time 10 "$APPS_URL/learner-dashboard/" 2>/dev/null || echo "")
  if echo "$DASHBOARD_BODY" | grep -qi 'undefined_license_key'; then
    fail_check "[live] apps host learner-dashboard has no 'undefined_license_key'"
  elif [[ -z "$DASHBOARD_BODY" ]]; then
    warn "[live] learner-dashboard page unreachable (network issue or cluster not running)"
  else
    pass_check "[live] apps host learner-dashboard has no 'undefined_license_key'"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-074: Plugin injection docs — surface mapping + fallback policy
# -----------------------------------------------------------------------
echo "AC-FRONT-074: Plugin injection docs — surface mapping and fallback exception policy"

# Check 19: Parity doc exists (MFE_ANALYTICS_PLUGIN_PARITY.md)
if [[ -f "$PARITY_DOC" ]]; then
  pass_check "MFE_ANALYTICS_PLUGIN_PARITY.md exists"
else
  fail_check "MFE_ANALYTICS_PLUGIN_PARITY.md exists"
fi

# Check 20: Parity doc has surface mapping (lists which files inject analytics)
if [[ -f "$PARITY_DOC" ]]; then
  if grep -qE 'mereka_lms\.py|env\.config' "$PARITY_DOC"; then
    pass_check "Parity doc maps injection surfaces (mereka_lms.py, env.config.jsx)"
  else
    fail_check "Parity doc maps injection surfaces (mereka_lms.py, env.config.jsx)"
  fi
fi

# Check 21: Parity doc documents the exception register (fallback policy)
if [[ -f "$PARITY_DOC" ]]; then
  if grep -qi 'exception\|Exception' "$PARITY_DOC"; then
    pass_check "Parity doc has exception register / fallback exception policy"
  else
    fail_check "Parity doc has exception register / fallback exception policy"
  fi
fi

# Check 22: Parity doc has approved entry points / surface map
if [[ -f "$PARITY_DOC" ]]; then
  if grep -qi 'entry point\|Entry Point\|surface\|Surface' "$PARITY_DOC"; then
    pass_check "Parity doc lists approved entry points / surface map"
  else
    fail_check "Parity doc lists approved entry points / surface map"
  fi
fi

# Check 23: Regression doc cross-references the surface mapping doc
if [[ -f "$REGRESSION_DOC" ]]; then
  if grep -q 'MFE_ANALYTICS_PLUGIN_PARITY' "$REGRESSION_DOC"; then
    pass_check "Regression doc references MFE_ANALYTICS_PLUGIN_PARITY.md"
  else
    fail_check "Regression doc references MFE_ANALYTICS_PLUGIN_PARITY.md"
  fi
fi

# Check 24: Fallback policy for missing key is documented (analytics disabled / no-op)
if [[ -f "$REGRESSION_DOC" ]]; then
  if grep -qiE 'disabled|no-op|no calls|silent' "$REGRESSION_DOC"; then
    pass_check "Regression doc documents fallback when key is absent (no-op / analytics disabled)"
  else
    fail_check "Regression doc documents fallback when key is absent (no-op / analytics disabled)"
  fi
fi

echo ""
echo "========================================================"
echo "Summary: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "========================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation:"
  echo "  AC-FRONT-071: Create reports/2026/learnings/ANALYTICS_UNDEFINED_REGRESSION_FIX.md"
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
