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

echo "=== Analytics Key Injection Verification ==="
echo ""

# AC-ANAL-001: No sentinel keys in templates
FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/footer.html"
if [[ -f "$FOOTER" ]]; then
  if grep -qi 'undefined_license_key' "$FOOTER"; then
    # Check if it's in the guard or in the actual key extraction
    if grep -q 'segment_key.lower() not in.*undefined_license_key' "$FOOTER"; then
      pass "AC-ANAL-001: Sentinel guard includes 'undefined_license_key' rejection"
    else
      fail "AC-ANAL-001: footer.html contains 'undefined_license_key' literal outside guard"
    fi
  else
    fail "AC-ANAL-001: footer.html missing sentinel guard for 'undefined_license_key'"
  fi

  # Check guard rejects known sentinels
  if grep -qE 'segment_key.lower\(\) not in.*\("undefined".*"none".*"null"' "$FOOTER"; then
    pass "AC-ANAL-001: Sentinel guard present with undefined/none/null rejection"
  else
    fail "AC-ANAL-001: No comprehensive sentinel guard found in footer.html"
  fi
else
  skip "AC-ANAL-001: footer.html not found"
fi

# AC-ANAL-002: No .lower() transform on segment key in rendering layer
if [[ -f "$FOOTER" ]]; then
  # Check the key extraction/normalization lines (not the guard comparison)
  # The guard can use .lower() for comparison, but the key value itself should not be lowercased
  # Look for lines that assign to segment_key but are NOT part of the guard condition
  EXTRACTION_LINES=$(grep -n 'segment_key' "$FOOTER" | grep -v '% if' | grep -v 'include' || true)
  if echo "$EXTRACTION_LINES" | grep '= .*segment_key' | grep -q '\.lower()'; then
    fail "AC-ANAL-002: segment_key extraction uses .lower() — key case is mutated"
    echo "  Lines:"
    echo "$EXTRACTION_LINES" | grep '\.lower()' | sed 's/^/    /'
  else
    pass "AC-ANAL-002: segment_key extraction preserves original case"
  fi
else
  skip "AC-ANAL-002: footer.html not found"
fi

# AC-ANAL-003: Segment injection uses canonical template extension points
if [[ -f "$FOOTER" ]]; then
  if grep -q 'segment-io.html' "$FOOTER" || grep -q 'segment-io-footer.html' "$FOOTER"; then
    pass "AC-ANAL-003: Segment includes use standard widget templates"
  else
    skip "AC-ANAL-003: No segment-io includes found (Segment may be disabled)"
  fi
else
  skip "AC-ANAL-003: footer.html not found"
fi

# AC-ANAL-004: Single canonical key source
if [[ -f "$FOOTER" ]]; then
  FALLBACK_COUNT=$(grep -cE 'ANALYTICS_SEGMENT_KEY|EDXAPP_SEGMENT_KEY' "$FOOTER" || true)
  if [[ "$FALLBACK_COUNT" -gt 0 ]]; then
    fail "AC-ANAL-004: footer.html has $FALLBACK_COUNT non-canonical key source references"
    echo "  Expected: only SEGMENT_KEY (Tutor standard)"
    echo "  Found:"
    grep -n 'ANALYTICS_SEGMENT_KEY\|EDXAPP_SEGMENT_KEY' "$FOOTER" | sed 's/^/    /'
  else
    pass "AC-ANAL-004: Single canonical key source (SEGMENT_KEY only)"
  fi
else
  skip "AC-ANAL-004: footer.html not found"
fi

# AC-ANAL-005: Plugin sets SEGMENT_KEY from environment
PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
if [[ -f "$PLUGIN" ]]; then
  if grep -q 'SEGMENT_KEY.*os.environ.get.*MEREKA_SEGMENT_KEY' "$PLUGIN"; then
    pass "AC-ANAL-005: Plugin configures SEGMENT_KEY from environment"
  else
    fail "AC-ANAL-005: Plugin does not configure SEGMENT_KEY from environment"
  fi
else
  skip "AC-ANAL-005: mereka_lms.py not found"
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation steps:"
  echo "1. Use only settings.SEGMENT_KEY as the canonical source"
  echo "2. Remove .lower() from key extraction (preserve case)"
  echo "3. Add sentinel guard for 'undefined_license_key' and other placeholders"
  echo "4. Set MEREKA_SEGMENT_KEY in environment/secrets"
  exit 1
fi

exit 0
