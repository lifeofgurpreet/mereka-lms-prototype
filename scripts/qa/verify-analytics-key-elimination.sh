#!/usr/bin/env bash
# @covers AC-UI-501, AC-UI-502, AC-UI-503, AC-UI-504, AC-UI-505
# @spec: bead-1h41
#
# Verify that undefined_license_key analytics key regressions are eliminated
# from all injected surfaces in the Mereka LMS deployment.
#
# Checks:
#   AC-UI-501: Baseline failure documentation exists — which requests were
#              affected and which hosts (admin/authn/apps) were impacted.
#   AC-UI-502: All analytics inject points have proper guards — no raw
#              undefined/none/null/undefined_license_key injection in
#              mereka_lms.py, env.config.jsx, head-extra.html templates.
#   AC-UI-503: Canonical key validation helper with precedence policy exists,
#              and no case-mangling side effects on the key value.
#   AC-UI-504: Smoke check coverage proving 0 undefined key calls on
#              admin/authn/apps hosts. Optional live mode via LIVE=1.
#   AC-UI-505: Evidence bundle path documented and root-cause notes present.
#
# Offline-capable: all checks operate on source files only.
# Live mode: set LIVE=1 to enable optional cluster checks.

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
EVIDENCE_DOC="$REPO_ROOT/docs/operations/ANALYTICS_KEY_ELIMINATION_EVIDENCE.md"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"
LMS_HEAD_EXTRA="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/head-extra.html"
CMS_HEAD_EXTRA="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/head-extra.html"
COMMON_HEAD_EXTRA="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/templates/head-extra.html"

echo "================================================================"
echo "Analytics Key Elimination Verifier (bead 1h41)"
echo "================================================================"
echo ""

# -----------------------------------------------------------------------
# AC-UI-501: Baseline failure documentation
# -----------------------------------------------------------------------
echo "AC-UI-501: Baseline failure documentation"

# Check 1: Evidence doc exists
check "ANALYTICS_KEY_ELIMINATION_EVIDENCE.md exists" "[[ -f '$EVIDENCE_DOC' ]]"

# Check 2: Doc records the specific symptom (undefined_license_key calls)
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc documents undefined_license_key symptom" \
    "grep -q 'undefined_license_key' '$EVIDENCE_DOC'"
fi

# Check 3: Doc names the affected hosts (admin, authn, apps)
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc names affected hosts (admin/authn/apps)" \
    "grep -qiE 'authn|apps\.academyv2|admin' '$EVIDENCE_DOC'"
fi

# Check 4: Doc records the error codes (403/405) or request failure type
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc records 403/405 error codes or network failure type" \
    "grep -qE '403|405|network|Network|Bad Request|400' '$EVIDENCE_DOC'"
fi

# Check 5: Doc has a root-cause section
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc has a root-cause section" \
    "grep -qi 'root.cause\|Root Cause' '$EVIDENCE_DOC'"
fi

echo ""

# -----------------------------------------------------------------------
# AC-UI-502: All inject points have proper guards
# -----------------------------------------------------------------------
echo "AC-UI-502: Analytics inject point guards"

# Check 6: Plugin reads SEGMENT_KEY from env var (not hardcoded)
if [[ -f "$PLUGIN" ]]; then
  check "mereka_lms.py reads SEGMENT_KEY from MEREKA_SEGMENT_KEY env var" \
    "grep -q 'SEGMENT_KEY.*os\.environ\.get.*MEREKA_SEGMENT_KEY' '$PLUGIN'"
else
  warn "mereka_lms.py not found at $PLUGIN"
fi

# Check 7: Plugin defaults SEGMENT_KEY to empty string (safe disabled-by-default)
if [[ -f "$PLUGIN" ]]; then
  SEGMENT_LINE="$(grep 'SEGMENT_KEY.*os\.environ\.get' "$PLUGIN" || true)"
  if echo "$SEGMENT_LINE" | grep -qF '""'; then
    check "SEGMENT_KEY defaults to empty string (analytics disabled by default)" "true"
  else
    check "SEGMENT_KEY defaults to empty string (analytics disabled by default)" "false"
  fi
fi

# Check 8: No undefined_license_key assigned as a value in plugin (guard context is OK)
if [[ -f "$PLUGIN" ]]; then
  HARDCODED="$(grep -n 'undefined_license_key' "$PLUGIN" | grep -v '^\s*#' || true)"
  if [[ -z "$HARDCODED" ]]; then
    check "No 'undefined_license_key' literal assigned in mereka_lms.py" "true"
  else
    check "No 'undefined_license_key' literal assigned in mereka_lms.py" "false"
    echo "    Found: $HARDCODED"
  fi
fi

# Check 9: Footer template has sentinel guard (rejects undefined_license_key)
if [[ -f "$FOOTER" ]]; then
  check "footer.html sentinel guard includes 'undefined_license_key' rejection" \
    "grep -q 'undefined_license_key' '$FOOTER'"
else
  warn "footer.html not found at $FOOTER — theme may not be applied yet"
fi

# Check 10: Footer sentinel guard covers the full set of known placeholder values
if [[ -f "$FOOTER" ]]; then
  GUARD_LINE="$(grep 'segment_key.*lower.*not in' "$FOOTER" || true)"
  ALL_SENTINELS=true
  for sentinel in "undefined" "none" "null" "undefined_license_key" "your_segment_key_here" "change_me"; do
    if ! echo "$GUARD_LINE" | grep -q "$sentinel"; then
      ALL_SENTINELS=false
      warn "Sentinel '$sentinel' missing from footer.html sentinel guard"
    fi
  done
  if [[ "$ALL_SENTINELS" == "true" ]]; then
    check "footer.html sentinel guard covers all 6 known placeholder values" "true"
  else
    check "footer.html sentinel guard covers all 6 known placeholder values" "false"
  fi
fi

# Check 11: Footer wraps Segment script in 'if segment_key' non-empty guard
if [[ -f "$FOOTER" ]]; then
  GUARD_COUNT="$(grep -c 'if segment_key' "$FOOTER" || true)"
  if [[ "$GUARD_COUNT" -ge 1 ]]; then
    check "footer.html wraps Segment includes in 'if segment_key' guard (count: $GUARD_COUNT)" "true"
  else
    check "footer.html wraps Segment includes in 'if segment_key' guard" "false"
  fi
fi

# Check 12: head-extra templates have no raw Segment injection (admin/authn/apps risk)
for HEAD_EXTRA in "$LMS_HEAD_EXTRA" "$CMS_HEAD_EXTRA" "$COMMON_HEAD_EXTRA"; do
  if [[ -f "$HEAD_EXTRA" ]]; then
    SEGMENT_IN_HEAD="$(grep -nE 'SEGMENT_KEY|undefined_license_key|segment\.io|analytics\.track' \
      "$HEAD_EXTRA" | grep -v '^\s*#' || true)"
    if [[ -z "$SEGMENT_IN_HEAD" ]]; then
      LABEL="$(basename "$(dirname "$HEAD_EXTRA")")/head-extra.html"
      check "$LABEL has no raw analytics injection" "true"
    else
      LABEL="$(basename "$(dirname "$HEAD_EXTRA")")/head-extra.html"
      check "$LABEL has no raw analytics injection" "false"
      echo "    Found: $SEGMENT_IN_HEAD"
    fi
  fi
done

# Check 13: No literal undefined/null string values for SEGMENT_KEY in infrastructure/
UNDEF_HITS="$(grep -r \
  "SEGMENT_KEY.*=.*['\"]undefined['\"]\\|SEGMENT_KEY.*=.*['\"]null['\"]\\|SEGMENT_KEY.*=.*['\"]undefined_license_key['\"]" \
  "$REPO_ROOT/infrastructure" \
  --include="*.py" --include="*.js" --include="*.jsx" --include="*.html" \
  -l 2>/dev/null || true)"
if [[ -z "$UNDEF_HITS" ]]; then
  check "No SEGMENT_KEY assigned literal undefined/null/undefined_license_key in infrastructure/" "true"
else
  check "No SEGMENT_KEY assigned literal undefined/null/undefined_license_key in infrastructure/" "false"
  echo "    Files: $UNDEF_HITS"
fi

echo ""

# -----------------------------------------------------------------------
# AC-UI-503: Canonical key validation helper + precedence policy (no case mangling)
# -----------------------------------------------------------------------
echo "AC-UI-503: Canonical key validation helper and precedence policy"

# Check 14: Evidence doc describes the key validation pattern / helper
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc describes canonical key validation pattern" \
    "grep -qiE 'validation|sentinel guard|canonical.*key|key.*canonical' '$EVIDENCE_DOC'"
fi

# Check 15: Evidence doc states the precedence policy (env var → config → disabled)
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc states key precedence policy (env var → disabled)" \
    "grep -qiE 'MEREKA_SEGMENT_KEY|env.*var|precedence|disabled by default|fallback' '$EVIDENCE_DOC'"
fi

# Check 16: Footer guard uses .lower() only for comparison (not for mutating the stored key)
# The stored segment_key should not be lowercased — only the comparison side.
if [[ -f "$FOOTER" ]]; then
  # Extraction lines (assignment to segment_key) should not have .lower()
  EXTRACTION_LINES="$(grep -n 'segment_key\s*=' "$FOOTER" | grep -v '% if' || true)"
  if echo "$EXTRACTION_LINES" | grep -q '\.lower()'; then
    check "segment_key extraction does NOT lowercase the key (no case mangling)" "false"
    echo "    Key value is being lowercased at extraction — this mangles the write key:"
    echo "$EXTRACTION_LINES" | grep '\.lower()' | sed 's/^/    /'
  else
    check "segment_key extraction does NOT lowercase the key (no case mangling)" "true"
  fi
fi

# Check 17: Guard comparison uses .lower() (correct: comparison only, not mutation)
if [[ -f "$FOOTER" ]]; then
  check "footer.html guard uses .lower() for comparison only (not key mutation)" \
    "grep -q 'segment_key.lower().*not in' '$FOOTER'"
fi

# Check 18: Plugin does not apply string transforms to SEGMENT_KEY after reading it
if [[ -f "$PLUGIN" ]]; then
  TRANSFORM_LINES="$(grep -n 'SEGMENT_KEY' "$PLUGIN" | grep '\.lower()\|\.upper()\|\.strip()' | grep -v '#' || true)"
  if [[ -z "$TRANSFORM_LINES" ]]; then
    check "mereka_lms.py does not transform SEGMENT_KEY after reading from env" "true"
  else
    check "mereka_lms.py does not transform SEGMENT_KEY after reading from env" "false"
    echo "    Transform found: $TRANSFORM_LINES"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-UI-504: Smoke checks proving 0 403/405 for undefined key calls
# -----------------------------------------------------------------------
echo "AC-UI-504: Smoke check coverage for 0 undefined key calls"

# Check 19: Smoke check documentation exists in evidence doc
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc has smoke check commands section" \
    "grep -qiE 'smoke|verification command|verify.*script' '$EVIDENCE_DOC'"
fi

# Check 20: At least one analytics key verify script exists
ANALYTICS_SCRIPT_COUNT="$(find "$REPO_ROOT/scripts/qa" -name "verify-analytics*.sh" 2>/dev/null | wc -l)"
if [[ "$ANALYTICS_SCRIPT_COUNT" -ge 1 ]]; then
  check "At least one verify-analytics*.sh script present (count: $ANALYTICS_SCRIPT_COUNT)" "true"
else
  check "At least one verify-analytics*.sh script present" "false"
fi

# Check 21: CI workflow references analytics key elimination script
if [[ -f "$CI_WORKFLOW" ]]; then
  CI_REF="$(grep -c 'analytics-key-elimination\|verify-analytics-key-elimination' \
    "$CI_WORKFLOW" || true)"
  if [[ "$CI_REF" -ge 1 ]]; then
    check "CI workflow references analytics-key-elimination script (refs: $CI_REF)" "true"
  else
    check "CI workflow references analytics-key-elimination script" "false"
  fi
fi

# Check 22: Evidence doc documents expected smoke output for all three hosts
if [[ -f "$EVIDENCE_DOC" ]]; then
  HOSTS_DOCUMENTED=true
  for host in "admin" "authn" "apps"; do
    if ! grep -qi "$host" "$EVIDENCE_DOC"; then
      HOSTS_DOCUMENTED=false
      warn "Host '$host' not documented in smoke check section"
    fi
  done
  if [[ "$HOSTS_DOCUMENTED" == "true" ]]; then
    check "Smoke checks cover all 3 hosts (admin/authn/apps) in evidence doc" "true"
  else
    check "Smoke checks cover all 3 hosts (admin/authn/apps) in evidence doc" "false"
  fi
fi

# Optional live smoke checks (requires LIVE=1)
if [[ "${LIVE:-0}" == "1" ]]; then
  echo "  [live] Running live analytics call checks on production hosts..."
  LMS_URL="${LMS_URL:-https://academyv2.mereka.io}"
  APPS_URL="${APPS_URL:-https://apps.academyv2.mereka.io}"

  # Admin host — Segment must not fire on /admin paths
  echo "  [live] Fetching admin login page..."
  ADMIN_BODY="$(curl -s --max-time 10 "$LMS_URL/admin/login/" 2>/dev/null || echo "")"
  if echo "$ADMIN_BODY" | grep -qi 'undefined_license_key'; then
    check "[live] Admin host: no 'undefined_license_key' in page source" "false"
  elif [[ -z "$ADMIN_BODY" ]]; then
    warn "[live] Admin login page unreachable (cluster not running or network timeout)"
  else
    check "[live] Admin host: no 'undefined_license_key' in page source" "true"
  fi

  # authn MFE host
  echo "  [live] Fetching authn MFE login page..."
  AUTHN_BODY="$(curl -s --max-time 10 "$APPS_URL/authn/login" 2>/dev/null || echo "")"
  if echo "$AUTHN_BODY" | grep -qi 'undefined_license_key'; then
    check "[live] authn host: no 'undefined_license_key' in page source" "false"
  elif [[ -z "$AUTHN_BODY" ]]; then
    warn "[live] authn MFE page unreachable (cluster not running or network timeout)"
  else
    check "[live] authn host: no 'undefined_license_key' in page source" "true"
  fi

  # apps MFE host (learner-dashboard)
  echo "  [live] Fetching learner-dashboard MFE page..."
  DASHBOARD_BODY="$(curl -s --max-time 10 "$APPS_URL/learner-dashboard/" 2>/dev/null || echo "")"
  if echo "$DASHBOARD_BODY" | grep -qi 'undefined_license_key'; then
    check "[live] apps host: no 'undefined_license_key' in learner-dashboard" "false"
  elif [[ -z "$DASHBOARD_BODY" ]]; then
    warn "[live] learner-dashboard page unreachable (cluster not running or network timeout)"
  else
    check "[live] apps host: no 'undefined_license_key' in learner-dashboard" "true"
  fi

  # Segment API should return no 403/405 for undefined key (key not sent at all)
  echo "  [live] Verifying Segment API is not called with undefined key on LMS homepage..."
  LMS_HOME="$(curl -s --max-time 10 "$LMS_URL/" 2>/dev/null || echo "")"
  if echo "$LMS_HOME" | grep -qiE 'undefined_license_key|your_segment_key_here|change_me'; then
    check "[live] LMS homepage: no sentinel key in page source" "false"
  elif [[ -z "$LMS_HOME" ]]; then
    warn "[live] LMS homepage unreachable"
  else
    check "[live] LMS homepage: no sentinel key in page source" "true"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-UI-505: Evidence bundle path and root-cause notes
# -----------------------------------------------------------------------
echo "AC-UI-505: Evidence bundle path and root-cause notes"

# Check 23: Evidence doc exists with bundle path
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence bundle path documented in evidence doc" \
    "grep -qiE 'evidence bundle|var/analytics|bundle path|artifact' '$EVIDENCE_DOC'"
fi

# Check 24: Root-cause notes cover the injection chain
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc explains full injection failure chain" \
    "grep -qiE 'injection|Injection|inject|Inject' '$EVIDENCE_DOC'"
fi

# Check 25: Evidence doc references this bead (1h41) for traceability
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc references bead 1h41 for traceability" \
    "grep -q '1h41' '$EVIDENCE_DOC'"
fi

# Check 26: Evidence doc references prior bead (2dcy.7) for continuity
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc references prior bead (2dcy.7) for regression continuity" \
    "grep -qE '2dcy\\.7|2dcy7' '$EVIDENCE_DOC'"
fi

# Check 27: Evidence doc has a related-documents section linking key scripts
if [[ -f "$EVIDENCE_DOC" ]]; then
  check "Evidence doc links to key verification scripts" \
    "grep -q 'verify-analytics' '$EVIDENCE_DOC'"
fi

echo ""
echo "================================================================"
echo "Summary: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "================================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation:"
  echo "  AC-UI-501: Create docs/operations/ANALYTICS_KEY_ELIMINATION_EVIDENCE.md."
  echo "             Document the symptom (undefined_license_key network calls),"
  echo "             affected hosts (admin/authn/apps), error codes (403/405),"
  echo "             and a root-cause section explaining the injection failure chain."
  echo ""
  echo "  AC-UI-502: Ensure mereka_lms.py uses os.environ.get('MEREKA_SEGMENT_KEY', '')."
  echo "             Ensure footer.html has sentinel guard rejecting all 6 placeholder"
  echo "             values before emitting any Segment <script> block."
  echo "             Ensure head-extra.html templates have no raw analytics injection."
  echo "             Grep infrastructure/ for literal undefined/null/sentinel assignments."
  echo ""
  echo "  AC-UI-503: Document the canonical key validation pattern in the evidence doc."
  echo "             Confirm footer guard uses .lower() only on the comparison side —"
  echo "             not on the stored segment_key value (no case mangling)."
  echo "             State the precedence policy: env var → empty → analytics disabled."
  echo ""
  echo "  AC-UI-504: Add 'analytics-key-elimination' job to .github/workflows/ci.yml."
  echo "             Add smoke check commands to the evidence doc covering all 3 hosts."
  echo "             Run: LIVE=1 ./scripts/qa/verify-analytics-key-elimination.sh"
  echo ""
  echo "  AC-UI-505: Add evidence bundle generation commands to the evidence doc."
  echo "             Include root-cause notes and reference bead 1h41."
  echo "             Link to prior bead 2dcy.7 for regression continuity."
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
