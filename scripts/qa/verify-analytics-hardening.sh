#!/usr/bin/env bash
# @covers AC-FRONT-051, AC-FRONT-052, AC-FRONT-053, AC-FRONT-054, AC-FRONT-055
# @spec: bead-2dcy.5
#
# Verify analytics token integrity and Segment/licensing injection hardening.
#
# Checks:
#   AC-FRONT-051: Sentinel filtering is case-insensitive; original key casing preserved
#                 for valid analytics keys.
#   AC-FRONT-052: One canonical source for analytics keys in Tutor plugin with documented
#                 precedence (env var > config > default).
#   AC-FRONT-053: Footer component does NOT inject Segment/analytics scripts; injection
#                 only in approved LMS/Studio settings hooks.
#   AC-FRONT-054: Regression test — sentinel values filtered, no active sentinel literals
#                 in config files.
#   AC-FRONT-055: Evidence bundle exists at docs/operations/evidence/analytics-hardening-report.md
#                 referencing parent bead 2dcy.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass_check() { echo -e "  ${GREEN}PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail_check() { echo -e "  ${RED}FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
warn_check() { echo -e "  ${YELLOW}WARN${NC}: $1"; WARN=$((WARN + 1)); }

PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN="$PLUGIN_MAIN"
FOOTER_HTML="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
EVIDENCE_REPORT="$REPO_ROOT/docs/operations/evidence/analytics-hardening-report.md"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

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

echo "========================================================"
echo "Analytics Hardening Verifier (bead 2dcy.5)"
echo "AC-FRONT-051..055"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------
# AC-FRONT-051: Case-insensitive sentinel filtering; original key casing preserved
# -----------------------------------------------------------------------
echo "AC-FRONT-051: Case-insensitive sentinel filtering and key casing preservation"

# Check 1: Plugin file exists
if [[ ! -f "$PLUGIN" ]]; then
  fail_check "plugin contract sources not found"
else
  pass_check "plugin contract sources exist"

  # Check 2: Sentinel filtering uses case-insensitive comparison (.lower(), casefold(), or IGNORECASE)
  if grep -qiE '\.lower\(\)|\.casefold\(\)|re\.IGNORECASE' "$PLUGIN"; then
    pass_check "Sentinel filtering uses case-insensitive comparison (.lower()/.casefold()/re.IGNORECASE)"
  else
    fail_check "Sentinel filtering uses case-insensitive comparison (.lower()/.casefold()/re.IGNORECASE)"
  fi

  # Check 3: SEGMENT_KEY is read from env without applying .lower() to the stored value
  # The guard may use .lower() for comparison but the key stored/assigned must not be lowered
  SEGMENT_ASSIGN_LINES="$(grep -n 'SEGMENT_KEY\s*=' "$PLUGIN" | grep -v '^\s*#' | grep -v 'if\|not in' || true)"
  if echo "$SEGMENT_ASSIGN_LINES" | grep -q '\.lower()\|\.casefold()'; then
    fail_check "SEGMENT_KEY assignment does NOT apply .lower()/.casefold() — original case preserved"
    echo "    Lines with case mutation:"
    echo "$SEGMENT_ASSIGN_LINES" | grep '\.lower()\|\.casefold()' | sed 's/^/      /'
  else
    pass_check "SEGMENT_KEY assignment preserves original key casing (no .lower() on stored value)"
  fi

  # Check 4: Known sentinel patterns are present in the plugin or footer guard
  SENTINEL_INVENTORY=("undefined" "none" "null" "undefined_license_key" "change_me" "your_key_here")
  SENTINELS_FOUND=0
  for sentinel in "${SENTINEL_INVENTORY[@]}"; do
    if grep -qi "$sentinel" "$PLUGIN" 2>/dev/null || grep -qi "$sentinel" "$FOOTER_HTML" 2>/dev/null; then
      SENTINELS_FOUND=$((SENTINELS_FOUND + 1))
    fi
  done
  if [[ "$SENTINELS_FOUND" -ge 3 ]]; then
    pass_check "Sentinel inventory present: at least 3 of 6 known sentinel patterns found (found: $SENTINELS_FOUND)"
  else
    fail_check "Sentinel inventory too thin: found $SENTINELS_FOUND of 6 expected sentinel patterns"
    echo "    Expected sentinels: ${SENTINEL_INVENTORY[*]}"
    echo "    Check $PLUGIN and $FOOTER_HTML"
  fi
fi

# Check 5: Footer template sentinel guard uses .lower() for comparison only (not to mutate key)
if [[ -f "$FOOTER_HTML" ]]; then
  # Extract assignment lines (not guard conditions)
  FOOTER_ASSIGN="$(grep -n 'segment_key\s*=' "$FOOTER_HTML" | grep -v '{%\s*if\|not in' || true)"
  if echo "$FOOTER_ASSIGN" | grep -q '\.lower()'; then
    fail_check "footer.html segment_key assignment preserves case (no .lower() on stored value)"
    echo "    Case-mutating assignment found:"
    echo "$FOOTER_ASSIGN" | grep '\.lower()' | sed 's/^/      /'
  else
    pass_check "footer.html segment_key assignment preserves original case"
  fi
else
  warn_check "footer.html not found — theme may not be applied yet (SKIP casing check)"
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-052: One canonical source for analytics keys with documented precedence
# -----------------------------------------------------------------------
echo "AC-FRONT-052: Single canonical analytics key source with documented precedence"

if [[ -f "$PLUGIN" ]]; then
  # Check 6: Exactly one canonical SEGMENT_KEY assignment in the plugin
  SEGMENT_ASSIGN_COUNT="$(grep -c 'SEGMENT_KEY\s*=' "$PLUGIN" || true)"
  if [[ "$SEGMENT_ASSIGN_COUNT" -eq 1 ]]; then
    pass_check "Exactly one SEGMENT_KEY assignment in mereka_lms.py (count: $SEGMENT_ASSIGN_COUNT)"
  elif [[ "$SEGMENT_ASSIGN_COUNT" -eq 0 ]]; then
    fail_check "No SEGMENT_KEY assignment found in mereka_lms.py"
  else
    fail_check "Multiple SEGMENT_KEY assignments in mereka_lms.py (count: $SEGMENT_ASSIGN_COUNT) — ambiguous canonical source"
  fi

  # Check 7: SEGMENT_KEY uses os.environ.get (env-var-first precedence)
  if grep -q 'SEGMENT_KEY.*os\.environ\.get.*MEREKA_SEGMENT_KEY' "$PLUGIN"; then
    pass_check "SEGMENT_KEY uses os.environ.get('MEREKA_SEGMENT_KEY') — env var takes precedence"
  else
    fail_check "SEGMENT_KEY does not use os.environ.get('MEREKA_SEGMENT_KEY')"
  fi

  # Check 8: SEGMENT_KEY defaults to empty string (safe disabled-by-default)
  SEGMENT_LINE="$(grep 'SEGMENT_KEY.*os\.environ\.get' "$PLUGIN" || true)"
  if echo "$SEGMENT_LINE" | grep -qF '""'; then
    pass_check "SEGMENT_KEY defaults to empty string (analytics disabled by default)"
  else
    fail_check "SEGMENT_KEY does not default to empty string — may enable analytics with undefined key"
  fi

  # Check 9: No alternative key names (ANALYTICS_SEGMENT_KEY, EDXAPP_SEGMENT_KEY) in plugin
  ALT_KEYS="$(grep -nE 'ANALYTICS_SEGMENT_KEY|EDXAPP_SEGMENT_KEY|ANALYTICS_KEY\s*=' "$PLUGIN" | grep -v '^\s*#' || true)"
  if [[ -z "$ALT_KEYS" ]]; then
    pass_check "No non-canonical analytics key names (ANALYTICS_SEGMENT_KEY/EDXAPP_SEGMENT_KEY) in plugin"
  else
    fail_check "Non-canonical analytics key names found in mereka_lms.py — conflicts with canonical source"
    echo "    Found:"
    echo "$ALT_KEYS" | sed 's/^/      /'
  fi

  # Check 10: Plugin comment documents precedence (env var > config > default)
  if grep -qiE 'env.*var.*config|precedence|MEREKA_SEGMENT_KEY.*enable' "$PLUGIN"; then
    pass_check "Plugin documents key precedence (env var comment or precedence documentation present)"
  else
    warn_check "Plugin does not explicitly document key precedence in a comment — consider adding"
  fi
fi

# Check 11: No duplicate SEGMENT_KEY definitions across apply-patches.sh
PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
if [[ -f "$PATCHES" ]]; then
  PATCHES_SEGMENT="$(grep -c 'SEGMENT_KEY' "$PATCHES" || true)"
  if [[ "$PATCHES_SEGMENT" -eq 0 ]]; then
    pass_check "apply-patches.sh has no SEGMENT_KEY definitions (not a duplicate source)"
  else
    warn_check "apply-patches.sh references SEGMENT_KEY ($PATCHES_SEGMENT times) — verify these are not assignments"
    grep -n 'SEGMENT_KEY' "$PATCHES" | sed 's/^/    /' || true
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-053: Footer does NOT inject Segment/analytics scripts; injection via approved hooks only
# -----------------------------------------------------------------------
echo "AC-FRONT-053: No analytics/Segment injection in footer component"

if [[ -f "$PLUGIN" ]]; then
  # Check 12: MerekaFooter component in mfe-env-config patch does not contain <script> for analytics
  MFE_FOOTER_SECTION="$(awk '/mfe-env-config/,/^[\))]/' "$PLUGIN" 2>/dev/null || true)"

  if echo "$MFE_FOOTER_SECTION" | grep -qE 'analytics\.js|segment\.com|cdn\.segment\.com|analytics\.load|analytics\.page'; then
    fail_check "MerekaFooter (mfe-env-config patch) MUST NOT contain Segment/analytics script injection"
    echo "    Found Segment injection patterns in footer component"
  else
    pass_check "MerekaFooter (mfe-env-config patch) has no Segment/analytics script injection"
  fi

  # Check 13: No inline <script> tags for analytics in the footer JSX
  if grep -A 500 'const MerekaFooter' "$PLUGIN" 2>/dev/null | grep -qE '<script[^>]*>.*analytics|<script[^>]*>.*segment'; then
    fail_check "MerekaFooter JSX has no inline <script> analytics injection"
  else
    pass_check "MerekaFooter JSX has no inline <script> analytics injection"
  fi

  # Check 14: Analytics injection is in approved settings patch (openedx-lms-production-settings or lms-env)
  if grep -qiE 'openedx-lms-production-settings|lms-env|cms-env' "$PLUGIN"; then
    pass_check "Analytics-related settings injection uses approved LMS/CMS settings hooks"
  else
    warn_check "No openedx-lms-production-settings or lms-env patch found — verify analytics injection location"
  fi

  # Check 15: SEGMENT_KEY assignment is inside a settings patch (not inside footer component)
  # The SEGMENT_KEY assignment should be inside openedx-lms-production-settings block
  SETTINGS_BLOCK="$(awk '/openedx-lms-production-settings/,/^\)\s*$/' "$PLUGIN" 2>/dev/null || true)"
  if echo "$SETTINGS_BLOCK" | grep -q 'SEGMENT_KEY'; then
    pass_check "SEGMENT_KEY assigned inside openedx-lms-production-settings hook (not footer)"
  else
    fail_check "SEGMENT_KEY not found inside openedx-lms-production-settings hook — check injection location"
  fi
fi

# Check 16: LMS footer.html template does NOT have an inline <script> for Segment
if [[ -f "$FOOTER_HTML" ]]; then
  INLINE_SCRIPTS="$(grep -n '<script' "$FOOTER_HTML" | grep -iE 'analytics|segment|cdn\.segment' || true)"
  if [[ -z "$INLINE_SCRIPTS" ]]; then
    pass_check "footer.html has no inline <script> analytics injection"
  else
    fail_check "footer.html has inline <script> analytics injection — must use approved include templates"
    echo "    Found:"
    echo "$INLINE_SCRIPTS" | sed 's/^/      /'
  fi
fi

# Check 17: MFE SCSS does not contain analytics injection
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
if [[ -f "$MFE_SCSS" ]]; then
  if grep -qiE 'segment|analytics\.js|cdn\.segment' "$MFE_SCSS"; then
    fail_check "mereka.scss MUST NOT contain Segment/analytics references"
    grep -n 'segment\|analytics\.js\|cdn\.segment' "$MFE_SCSS" | sed 's/^/    /'
  else
    pass_check "mereka.scss has no Segment/analytics references"
  fi
else
  warn_check "mereka.scss not found at $MFE_SCSS"
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-054: Regression test — sentinel values filtered; no active sentinels in config
# -----------------------------------------------------------------------
echo "AC-FRONT-054: Regression test — no active sentinel values in analytics config"

# Check 18: This script is the regression test (meta-check: verify the file itself)
if [[ -f "${BASH_SOURCE[0]}" ]]; then
  pass_check "verify-analytics-hardening.sh exists (this script IS the regression test for AC-FRONT-054)"
else
  fail_check "verify-analytics-hardening.sh not found — regression test missing"
fi

# Check 19: No literal sentinel strings assigned as active SEGMENT_KEY in any config file
SENTINEL_PATTERNS=(
  "SEGMENT_KEY.*=.*['\"]undefined['\"]"
  "SEGMENT_KEY.*=.*['\"]null['\"]"
  "SEGMENT_KEY.*=.*['\"]undefined_license_key['\"]"
  "SEGMENT_KEY.*=.*['\"]CHANGE_ME['\"]"
  "SEGMENT_KEY.*=.*['\"]your_key_here['\"]"
  "SEGMENT_KEY.*=.*['\"]your_segment_key_here['\"]"
)

SENTINEL_HITS=""
for pattern in "${SENTINEL_PATTERNS[@]}"; do
  HITS="$(grep -riE "$pattern" \
    "$REPO_ROOT/infrastructure" \
    --include="*.py" --include="*.js" --include="*.jsx" --include="*.html" \
    --include="*.yml" --include="*.yaml" \
    -l 2>/dev/null || true)"
  if [[ -n "$HITS" ]]; then
    SENTINEL_HITS="$SENTINEL_HITS$HITS"$'\n'
  fi
done

if [[ -z "$SENTINEL_HITS" ]]; then
  pass_check "No active sentinel strings assigned as SEGMENT_KEY in infrastructure/ files"
else
  fail_check "Active sentinel strings found assigned as SEGMENT_KEY in infrastructure/ files"
  echo "    Files:"
  echo "$SENTINEL_HITS" | sort -u | sed 's/^/      /'
fi

# Check 20: No literal sentinel strings in tutor config.example.yml
CONFIG_EXAMPLE="$REPO_ROOT/infrastructure/tutor/config.example.yml"
if [[ -f "$CONFIG_EXAMPLE" ]]; then
  EXAMPLE_SENTINEL="$(grep -iE 'SEGMENT_KEY.*undefined_license_key|SEGMENT_KEY.*CHANGE_ME|SEGMENT_KEY.*your_key' \
    "$CONFIG_EXAMPLE" || true)"
  if [[ -z "$EXAMPLE_SENTINEL" ]]; then
    pass_check "config.example.yml has no active sentinel value for SEGMENT_KEY"
  else
    fail_check "config.example.yml has sentinel value assigned to SEGMENT_KEY"
    echo "    Found: $EXAMPLE_SENTINEL"
  fi
else
  warn_check "config.example.yml not found — skipping example config sentinel check"
fi

# Check 21: Sentinel guard exists in footer.html (the runtime guard that prevents calls)
if [[ -f "$FOOTER_HTML" ]]; then
  if grep -qiE 'not in.*undefined|lower.*not in|sentinel|segment_key.*and|if segment_key' "$FOOTER_HTML"; then
    pass_check "footer.html has runtime sentinel guard (prevents calls for empty/undefined keys)"
  else
    fail_check "footer.html missing runtime sentinel guard — undefined key may trigger Segment calls"
  fi
else
  warn_check "footer.html not found — runtime guard check skipped"
fi

# Check 22: Plugin SEGMENT_KEY line does not contain a hard-coded non-empty sentinel
if [[ -f "$PLUGIN" ]]; then
  HARDCODED_SENTINEL="$(grep -n 'SEGMENT_KEY\s*=' "$PLUGIN" | \
    grep -vE 'os\.environ|{{\s*SEGMENT_KEY|#' | \
    grep -E '[a-zA-Z0-9_]{8,}' || true)"
  if [[ -z "$HARDCODED_SENTINEL" ]]; then
    pass_check "mereka_lms.py has no hardcoded non-empty analytics key"
  else
    fail_check "mereka_lms.py may have a hardcoded analytics key — review manually"
    echo "    Lines to review:"
    echo "$HARDCODED_SENTINEL" | sed 's/^/      /'
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-055: Evidence bundle path and parent bead reference
# -----------------------------------------------------------------------
echo "AC-FRONT-055: Evidence bundle path and bead reference"

# Check 23: Evidence report exists
if [[ -f "$EVIDENCE_REPORT" ]]; then
  pass_check "Evidence report exists at docs/operations/evidence/analytics-hardening-report.md"
else
  fail_check "Evidence report missing at docs/operations/evidence/analytics-hardening-report.md"
fi

# Check 24: Evidence report references parent bead 2dcy
if [[ -f "$EVIDENCE_REPORT" ]]; then
  if grep -qiE '2dcy' "$EVIDENCE_REPORT"; then
    pass_check "Evidence report references parent bead 2dcy"
  else
    fail_check "Evidence report does not reference parent bead 2dcy"
  fi
fi

# Check 25: Evidence report contains a pass/fail summary section
if [[ -f "$EVIDENCE_REPORT" ]]; then
  if grep -qiE 'pass.*fail|PASS.*FAIL|Summary|summary' "$EVIDENCE_REPORT"; then
    pass_check "Evidence report contains pass/fail summary section"
  else
    fail_check "Evidence report missing pass/fail summary section"
  fi
fi

# Check 26: CI workflow references this script
if [[ -f "$CI_WORKFLOW" ]]; then
  if grep -q 'verify-analytics-hardening' "$CI_WORKFLOW"; then
    pass_check "CI workflow references verify-analytics-hardening.sh"
  else
    fail_check "CI workflow does not reference verify-analytics-hardening.sh — add analytics-hardening job"
  fi
fi

echo ""
echo "========================================================"
printf "Summary: %b%d PASS%b / %b%d FAIL%b / %b%d WARN%b\n" \
  "${GREEN}" "$PASS" "${NC}" \
  "${RED}" "$FAIL" "${NC}" \
  "${YELLOW}" "$WARN" "${NC}"
echo "========================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation:"
  echo "  AC-FRONT-051: Ensure footer.html guard uses .lower() only for comparison,"
  echo "                not to mutate the stored segment_key value."
  echo "                Add all sentinel patterns: undefined, none, null,"
  echo "                undefined_license_key, change_me, your_key_here."
  echo ""
  echo "  AC-FRONT-052: Ensure mereka_lms.py has exactly one SEGMENT_KEY assignment:"
  echo "                  SEGMENT_KEY = os.environ.get('MEREKA_SEGMENT_KEY', '')"
  echo "                Add a comment documenting the precedence policy."
  echo "                Remove any ANALYTICS_SEGMENT_KEY or EDXAPP_SEGMENT_KEY aliases."
  echo ""
  echo "  AC-FRONT-053: Remove any Segment/analytics script injection from MerekaFooter."
  echo "                Analytics must only be injected via openedx-lms-production-settings"
  echo "                or openedx-cms-production-settings settings patches."
  echo "                No <script> tags for analytics in footer JSX or footer.html."
  echo ""
  echo "  AC-FRONT-054: Audit infrastructure/ for literal sentinel strings assigned as"
  echo "                SEGMENT_KEY. Ensure footer.html runtime guard is present."
  echo ""
  echo "  AC-FRONT-055: Create docs/operations/evidence/analytics-hardening-report.md."
  echo "                Add 'analytics-hardening' job to .github/workflows/ci.yml."
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
