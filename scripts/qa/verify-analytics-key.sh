#!/usr/bin/env bash
# @covers AC-ANAL-001, AC-ANAL-002, AC-ANAL-003, AC-ANAL-004, AC-ANAL-005
# @spec: ui-ux-hardening-s6_spec.md
# Verify analytics (Segment) key injection is safe and follows canonical path.
#
# Checks:
# 1. No sentinel keys in rendered templates or settings
# 2. No .lower() transform on segment key in rendering layer
# 3. Segment injection uses canonical template extension points
# 4. Single canonical key source (SEGMENT_KEY only)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; SKIP=$((SKIP + 1)); }

plugin_segment_lower_matches() {
  local file
  while IFS= read -r file; do
    grep -n 'SEGMENT_KEY' "$file" 2>/dev/null \
      | grep -vE '^[0-9]+:[[:space:]]*#' \
      | grep '\.lower()' \
      | sed "s|^|${file#$REPO_ROOT/}:|"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
}

plugin_print_matches() {
  local pattern="$1"
  local file
  while IFS= read -r file; do
    grep -nE "$pattern" "$file" 2>/dev/null | sed "s|^|${file#$REPO_ROOT/}:|"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
}

echo "=== Analytics Key Injection Verification ==="
echo ""

# AC-ANAL-001: footer.html must have NO Segment code (plugin-first canonical state post-2k6k)
# Analytics injection moved to Tutor plugin hook (mereka_lms.py) in bead 2k6k.
# Any reappearance of segment.io/analytics code in footer.html is a regression.
FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
if [[ -f "$FOOTER" ]]; then
  if grep -qE 'segment\.io|analytics\.js|analytics\.load|segment_key|undefined_license_key' "$FOOTER"; then
    fail "AC-ANAL-001: footer.html has Segment/analytics code — regression from bead 2k6k plugin-first migration"
    grep -nE 'segment\.io|analytics\.js|analytics\.load|segment_key|undefined_license_key' "$FOOTER" | sed 's/^/    /'
  else
    pass "AC-ANAL-001: footer.html has no Segment/analytics code (plugin-first canonical state)"
  fi

  # Check that migration comment exists (confirms removal was intentional)
  if grep -qE '2k6k|analytics.*removed|removed.*analytics|Tutor plugin hook' "$FOOTER"; then
    pass "AC-ANAL-001: footer.html has 2k6k migration comment (intentional removal documented)"
  else
    skip "AC-ANAL-001: footer.html missing 2k6k migration comment — regression may be silent"
  fi
else
  skip "AC-ANAL-001: footer.html not found"
fi

# AC-ANAL-002: No .lower() transform on segment key in the plugin (canonical injection point)
# Post-2k6k: segment_key logic lives in mereka_lms.py, not footer.html
if mereka_plugin_has_any "$REPO_ROOT"; then
  # Key must be used as-is from env var (no case mutation)
  SEGMENT_LOWER_MATCHES="$(plugin_segment_lower_matches || true)"
  if [[ -n "$SEGMENT_LOWER_MATCHES" ]]; then
    fail "AC-ANAL-002: SEGMENT_KEY uses .lower() in plugin — key case is mutated"
    echo "$SEGMENT_LOWER_MATCHES" | sed 's/^/    /'
  else
    pass "AC-ANAL-002: SEGMENT_KEY preserves original case in plugin contract sources (no .lower() mutation)"
  fi
else
  skip "AC-ANAL-002: plugin contract sources not found"
fi

# AC-ANAL-003: Analytics injection uses canonical Tutor plugin hook (not footer template)
# Post-2k6k: segment-io.html includes are no longer used in footer.html
if [[ -f "$FOOTER" ]]; then
  if grep -qE 'segment-io\.html|segment-io-footer\.html' "$FOOTER"; then
    fail "AC-ANAL-003: footer.html has segment-io template includes — regression (remove, use plugin hook)"
    grep -nE 'segment-io\.html|segment-io-footer\.html' "$FOOTER" | sed 's/^/    /'
  else
    pass "AC-ANAL-003: footer.html has no segment-io template includes (plugin hook is canonical)"
  fi
else
  skip "AC-ANAL-003: footer.html not found"
fi

# AC-ANAL-004: Single canonical key source in plugin (not footer or other surfaces)
if mereka_plugin_has_any "$REPO_ROOT"; then
  FALLBACK_COUNT="$(mereka_plugin_count_regex "$REPO_ROOT" 'ANALYTICS_SEGMENT_KEY|EDXAPP_SEGMENT_KEY')"
  if [[ "$FALLBACK_COUNT" -gt 0 ]]; then
    fail "AC-ANAL-004: plugin contract sources have $FALLBACK_COUNT non-canonical key source references"
    echo "  Expected: only MEREKA_SEGMENT_KEY"
    plugin_print_matches 'ANALYTICS_SEGMENT_KEY|EDXAPP_SEGMENT_KEY' | sed 's/^/    /'
  else
    pass "AC-ANAL-004: Single canonical key source (MEREKA_SEGMENT_KEY via env var)"
  fi
else
  skip "AC-ANAL-004: plugin contract sources not found"
fi

# AC-ANAL-005: Plugin sets SEGMENT_KEY from environment
if mereka_plugin_has_any "$REPO_ROOT"; then
  if mereka_plugin_has_regex "$REPO_ROOT" 'SEGMENT_KEY.*os\.environ\.get.*MEREKA_SEGMENT_KEY'; then
    pass "AC-ANAL-005: Plugin configures SEGMENT_KEY from environment"
  else
    fail "AC-ANAL-005: Plugin does not configure SEGMENT_KEY from environment"
  fi
else
  skip "AC-ANAL-005: plugin contract sources not found"
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation steps:"
  echo "1. footer.html must have ZERO analytics/Segment code (plugin-first model, bead 2k6k)"
  echo "   If Segment code appeared in footer.html, remove it — redirect to mereka_lms.py plugin hook"
  echo "2. Use only MEREKA_SEGMENT_KEY env var as the canonical key source (mereka_lms.py)"
  echo "3. Do not lowercase SEGMENT_KEY — preserve case as read from env var"
  echo "4. Set MEREKA_SEGMENT_KEY in Infisical/GCP SM to enable analytics"
  exit 1
fi

exit 0
