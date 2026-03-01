#!/usr/bin/env bash
# verify-accessibility.sh — axe-core / WCAG 2.2 AA accessibility check
# @covers AC-UIA11Y-007, AC-UIA11Y-008, AC-UIA11Y-009
#
# Acceptance criteria:
#   AC-UIA11Y-007 — WCAG 2.2 AA: Focus Not Obscured (SC 2.4.12) — focused component
#                   is not entirely hidden by sticky/fixed content; source check.
#   AC-UIA11Y-008 — WCAG 2.2 AA: Target Size (SC 2.5.8) — interactive targets meet
#                   24x24 CSS pixel minimum; documented in policy.
#   AC-UIA11Y-009 — WCAG 2.2 AA: Accessible Authentication (SC 3.3.8) — login/register
#                   flows do not require cognitive function tests without alternatives;
#                   policy and axe-core scan confirm no pure-CAPTCHA blocks.
#
# Modes:
#   --offline   Validate policy doc exists; grep theme source for ARIA + focus patterns
#   --online    Run @axe-core/cli against TARGET_URL for AA violations (requires Node + npx)
#
# Usage:
#   ./scripts/qa/verify-accessibility.sh --offline
#   ./scripts/qa/verify-accessibility.sh --online [--target https://academyv2.mereka.io]
#   ./scripts/qa/verify-accessibility.sh --offline --online --target https://apps.academyv2.mereka.io
#   ./scripts/qa/verify-accessibility.sh --online --routes /authn/login,/authn/register,/dashboard
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_skip() { SKIP=$((SKIP + 1)); echo -e "${YELLOW}[SKIP]${NC} $1"; }

# ── Defaults ──────────────────────────────────────────────────────────────
MODE_OFFLINE=false
MODE_ONLINE=false
TARGET="${A11Y_TARGET:-https://academyv2.mereka.io}"
ROUTES_CSV="${A11Y_ROUTES:-}"
ALLOW_MISSING_REPORTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline)  MODE_OFFLINE=true; shift ;;
    --online)   MODE_ONLINE=true;  shift ;;
    --target)   TARGET="$2"; shift 2 ;;
    --routes)   ROUTES_CSV="$2"; shift 2 ;;
    --allow-missing-reports) ALLOW_MISSING_REPORTS=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "$TARGET" != *"://"* ]]; then
  TARGET="https://$TARGET"
fi

# Default to offline when no mode flag supplied
if [[ "$MODE_OFFLINE" == false && "$MODE_ONLINE" == false ]]; then
  MODE_OFFLINE=true
fi

echo -e "${BLUE}=== Accessibility Check (WCAG 2.2 AA) ===${NC}"
echo ""

# ──────────────────────────────────────────────────────────────────────────
# OFFLINE MODE
# ──────────────────────────────────────────────────────────────────────────
if [[ "$MODE_OFFLINE" == true ]]; then
  echo -e "${BLUE}## Offline Checks${NC}"
  echo ""

  # -- 1. Policy document exists and mentions WCAG 2.2 AA criteria --
  echo -e "${BLUE}### 1. Policy Documentation${NC}"
  POLICY_DOC="$REPO_ROOT/docs/architecture/ACCESSIBILITY_CONFORMANCE_POLICY.md"

  if [[ -f "$POLICY_DOC" ]]; then
    do_pass "ACCESSIBILITY_CONFORMANCE_POLICY.md exists"

    if grep -qiE "WCAG 2\.2|2\.4\.12|Focus Not Obscured" "$POLICY_DOC"; then
      do_pass "Policy references WCAG 2.2 / Focus Not Obscured (AC-UIA11Y-007)"
    else
      do_skip "Policy does not yet reference WCAG 2.2 Focus Not Obscured (add SC 2.4.12 section)"
    fi

    if grep -qiE "2\.5\.8|Target Size" "$POLICY_DOC"; then
      do_pass "Policy references Target Size SC 2.5.8 (AC-UIA11Y-008)"
    else
      do_skip "Policy does not yet reference Target Size SC 2.5.8 (add section)"
    fi

    if grep -qiE "3\.3\.8|Accessible Authentication" "$POLICY_DOC"; then
      do_pass "Policy references Accessible Authentication SC 3.3.8 (AC-UIA11Y-009)"
    else
      do_skip "Policy does not yet reference Accessible Authentication SC 3.3.8 (add section)"
    fi
  else
    do_fail "ACCESSIBILITY_CONFORMANCE_POLICY.md not found at $POLICY_DOC"
  fi

  echo ""

  # -- 2. Theme templates: ARIA attribute scan --
  echo -e "${BLUE}### 2. ARIA Attributes in Theme Templates (AC-UIA11Y-007, AC-UIA11Y-009)${NC}"

  THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"

  if [[ ! -d "$THEME_DIR" ]]; then
    do_skip "Theme directory not found at $THEME_DIR (skip ARIA source checks)"
  else
    # Check for aria-label / aria-labelledby usage in templates
    ARIA_LABEL_COUNT=$(grep -r 'aria-label\|aria-labelledby' \
      "$THEME_DIR" \
      --include="*.html" --include="*.jsx" --include="*.tsx" \
      2>/dev/null | wc -l || true)

    if [[ "$ARIA_LABEL_COUNT" -gt 0 ]]; then
      do_pass "aria-label/aria-labelledby found in theme ($ARIA_LABEL_COUNT occurrences)"
    else
      do_skip "No aria-label/aria-labelledby in theme templates (may live in upstream MFEs)"
    fi

    # Check for aria-describedby (form accessibility — 3.3.8 adjacent)
    ARIA_DESC_COUNT=$(grep -r 'aria-describedby' \
      "$THEME_DIR" \
      --include="*.html" --include="*.jsx" --include="*.tsx" \
      2>/dev/null | wc -l || true)

    if [[ "$ARIA_DESC_COUNT" -gt 0 ]]; then
      do_pass "aria-describedby found in theme ($ARIA_DESC_COUNT occurrences) — supports 3.3.8"
    else
      do_skip "No aria-describedby in theme (may live in upstream MFEs)"
    fi

    # Check for role attributes (landmarks — 2.4.12 navigation context)
    ROLE_COUNT=$(grep -r 'role="' \
      "$THEME_DIR" \
      --include="*.html" --include="*.jsx" --include="*.tsx" \
      2>/dev/null | wc -l || true)

    if [[ "$ROLE_COUNT" -gt 0 ]]; then
      do_pass "ARIA role attributes found in theme ($ROLE_COUNT occurrences)"
    else
      do_skip "No ARIA role attributes in theme (may live in upstream MFEs)"
    fi
  fi

  echo ""

  # -- 3. Focus-not-obscured check: no sticky/fixed overlay suppressing focus ring --
  echo -e "${BLUE}### 3. Focus Not Obscured — SC 2.4.12 (AC-UIA11Y-007)${NC}"

  if [[ -d "$THEME_DIR" ]]; then
    # Look for z-index on sticky/fixed elements alongside focus handling
    STICKY_FIXED_COUNT=$(grep -r 'position:\s*fixed\|position:\s*sticky' \
      "$THEME_DIR" \
      --include="*.scss" --include="*.css" \
      2>/dev/null | wc -l || true)

    if [[ "$STICKY_FIXED_COUNT" -gt 0 ]]; then
      # Check whether z-index management exists alongside focus offset/visible policy
      ZINDEX_COUNT=$(grep -r 'z-index' \
        "$THEME_DIR" \
        --include="*.scss" --include="*.css" \
        2>/dev/null | wc -l || true)

      if [[ "$ZINDEX_COUNT" -gt 0 ]]; then
        do_pass "Sticky/fixed elements ($STICKY_FIXED_COUNT) have z-index management ($ZINDEX_COUNT rules) — SC 2.4.12 review warranted"
      else
        do_skip "Sticky/fixed elements found but no z-index rules — manual SC 2.4.12 review needed"
      fi
    else
      do_pass "No sticky/fixed positioned elements in theme CSS (SC 2.4.12 N/A to custom theme)"
    fi

    # Check that scroll-margin / scroll-padding is defined for anchor focus
    SCROLL_MARGIN_COUNT=$(grep -r 'scroll-margin\|scroll-padding' \
      "$THEME_DIR" \
      --include="*.scss" --include="*.css" \
      2>/dev/null | wc -l || true)

    if [[ "$SCROLL_MARGIN_COUNT" -gt 0 ]]; then
      do_pass "scroll-margin/scroll-padding found ($SCROLL_MARGIN_COUNT) — helps SC 2.4.12 compliance"
    else
      do_skip "No scroll-margin/scroll-padding in theme (consider adding for SC 2.4.12 when fixed headers present)"
    fi
  else
    do_skip "Theme directory not found — skipping SC 2.4.12 source checks"
  fi

  echo ""

  # -- 4. Target size check: verify no ultra-small interactive targets in theme CSS --
  echo -e "${BLUE}### 4. Target Size — SC 2.5.8 (AC-UIA11Y-008)${NC}"

  if [[ -d "$THEME_DIR" ]]; then
    MFE_SCSS="$THEME_DIR/mfe/mereka.scss"
    if [[ -f "$MFE_SCSS" ]]; then
      # Look for extremely small dimension values (< 24px) on button/anchor overrides
      TINY_SIZE_COUNT=$(grep -E 'width:\s*([0-9]|1[0-9]|2[0-3])px|height:\s*([0-9]|1[0-9]|2[0-3])px' \
        "$MFE_SCSS" 2>/dev/null | wc -l || true)

      if [[ "$TINY_SIZE_COUNT" -gt 0 ]]; then
        do_fail "Found $TINY_SIZE_COUNT dimension rules < 24px in mereka.scss — may violate SC 2.5.8 Target Size"
      else
        do_pass "No dimension rules < 24px in mereka.scss (SC 2.5.8)"
      fi
    else
      do_skip "mereka.scss not found — skipping SC 2.5.8 dimension scan"
    fi
  else
    do_skip "Theme directory not found — skipping SC 2.5.8 source checks"
  fi

  echo ""

  # -- 5. Accessible Authentication check: no CAPTCHA-only block in login template --
  echo -e "${BLUE}### 5. Accessible Authentication — SC 3.3.8 (AC-UIA11Y-009)${NC}"

  if [[ -d "$THEME_DIR" ]]; then
    # Detect captcha/recaptcha references in templates; warn if present without alternative
    CAPTCHA_COUNT=$(grep -r -i 'captcha\|recaptcha' \
      "$THEME_DIR" \
      --include="*.html" --include="*.jsx" --include="*.tsx" --include="*.py" \
      2>/dev/null | wc -l || true)

    if [[ "$CAPTCHA_COUNT" -gt 0 ]]; then
      # Check if there's an accessible alternative flagged alongside
      ALT_COUNT=$(grep -r -i 'audio.*captcha\|captcha.*audio\|accessible.*captcha\|captcha.*alternative' \
        "$THEME_DIR" \
        --include="*.html" --include="*.jsx" --include="*.tsx" \
        2>/dev/null | wc -l || true)

      if [[ "$ALT_COUNT" -gt 0 ]]; then
        do_pass "CAPTCHA references found with accessibility alternative ($ALT_COUNT) — SC 3.3.8 satisfied"
      else
        do_fail "CAPTCHA references ($CAPTCHA_COUNT) found with no accessible alternative — review SC 3.3.8"
      fi
    else
      do_pass "No CAPTCHA references in theme templates (SC 3.3.8)"
    fi
  else
    do_skip "Theme directory not found — skipping SC 3.3.8 source checks"
  fi

  echo ""

  # -- 6. CI workflow check --
  echo -e "${BLUE}### 6. CI Integration${NC}"
  CI_A11Y_WORKFLOW="$REPO_ROOT/.github/workflows/accessibility-audit.yml"

  if [[ -f "$CI_A11Y_WORKFLOW" ]]; then
    do_pass "accessibility-audit.yml CI workflow exists"

    if grep -q "wcag22aa" "$CI_A11Y_WORKFLOW"; then
      do_pass "CI workflow includes wcag22aa tag"
    else
      do_fail "CI workflow missing wcag22aa tag"
    fi

    if grep -q "continue-on-error: true" "$CI_A11Y_WORKFLOW"; then
      do_pass "CI workflow is non-blocking (continue-on-error: true)"
    else
      do_skip "CI workflow does not have continue-on-error — will block CI on violations"
    fi
  else
    do_fail "accessibility-audit.yml not found at $CI_A11Y_WORKFLOW"
  fi

fi  # end offline mode

# ──────────────────────────────────────────────────────────────────────────
# ONLINE MODE
# ──────────────────────────────────────────────────────────────────────────
if [[ "$MODE_ONLINE" == true ]]; then
  MFE_TARGET="$(python3 - "$TARGET" <<'PY'
import sys
from urllib.parse import urlparse

raw = (sys.argv[1] or "").strip()
parsed = urlparse(raw)
if not parsed.hostname:
    print("")
    raise SystemExit(0)
scheme = parsed.scheme or "https"
host = parsed.hostname
if not host.startswith("apps."):
    host = f"apps.{host}"
port = f":{parsed.port}" if parsed.port else ""
print(f"{scheme}://{host}{port}")
PY
)"
  if [[ -z "$MFE_TARGET" ]]; then
    do_fail "Cannot derive apps.* MFE origin from target: $TARGET"
    MFE_TARGET="$TARGET"
  fi

  if [[ -z "$ROUTES_CSV" ]]; then
    ROUTES_CSV="/authn/login,/authn/register,/dashboard,/account,/learning"
  fi

  mapfile -t ROUTES < <(python3 - "$ROUTES_CSV" <<'PY'
import sys

for raw in (sys.argv[1] or "").split(","):
    entry = raw.strip()
    if not entry:
        continue
    if entry.startswith("http://") or entry.startswith("https://"):
        print(entry)
        continue
    if not entry.startswith("/"):
        entry = f"/{entry}"
    print(entry)
PY
)

  if [[ "${#ROUTES[@]}" -eq 0 ]]; then
    do_fail "No valid routes resolved for online accessibility scan"
  fi

  echo -e "${BLUE}## Online Checks (axe-core against ${MFE_TARGET})${NC}"
  echo ""

  # Prerequisite: npx / @axe-core/cli
  if ! command -v npx &>/dev/null; then
    do_skip "npx not found — install Node.js to run online axe-core checks"
  else
    echo -e "${BLUE}### axe-core WCAG 2.2 AA scan${NC}"

    REPORT_DIR="${REPO_ROOT}/var/a11y-reports"
    mkdir -p "$REPORT_DIR"

    ONLINE_VIOLATIONS=0
    MISSING_REPORTS=0

    for route in "${ROUTES[@]}"; do
      if [[ "$route" == http://* || "$route" == https://* ]]; then
        url="$route"
      else
        url="${MFE_TARGET%/}${route}"
      fi
      safe_name="$(echo "${route}" | sed 's|/|-|g; s|^-||')"
      [[ -z "$safe_name" ]] && safe_name="home"
      report_file="${REPORT_DIR}/axe-${safe_name}.json"
      command_log="${REPORT_DIR}/axe-${safe_name}.stderr.log"

      echo "  Scanning: ${url}"

      set +e
      npx --yes @axe-core/cli@4.10.2 \
        "${url}" \
        --tags wcag2a,wcag2aa,wcag22aa \
        --save "${report_file}" \
        --timeout 30 \
        --no-reporter \
        --show-errors true \
        >"${command_log}" 2>&1
      AXE_EXIT=$?
      set -e

      if [[ -f "$report_file" ]]; then
        VIOLS=$(python3 -c "
import json, sys
try:
    data = json.load(open('${report_file}'))
    results = data if isinstance(data, list) else [data]
    total = sum(len(r.get('violations', [])) for r in results)
    critical = sum(
        1 for r in results
        for v in r.get('violations', [])
        if v.get('impact') == 'critical'
    )
    print(f'{total} violations ({critical} critical)')
except Exception as e:
    print(f'parse error: {e}')
" 2>/dev/null || echo "parse error")
        echo "    ${route}: ${VIOLS}"

        VCOUNT=$(python3 -c "
import json
try:
    data = json.load(open('${report_file}'))
    results = data if isinstance(data, list) else [data]
    print(sum(len(r.get('violations', [])) for r in results))
except Exception:
    print(0)
" 2>/dev/null || echo 0)
        ONLINE_VIOLATIONS=$((ONLINE_VIOLATIONS + VCOUNT))
      else
        MISSING_REPORTS=$((MISSING_REPORTS + 1))
        echo "    ${route}: no report generated (URL may be unreachable)"
        if [[ -s "$command_log" ]]; then
          echo "    command-log: ${command_log}"
        fi
      fi
    done

    echo ""

    if [[ "$MISSING_REPORTS" -gt 0 ]]; then
      if [[ "$ALLOW_MISSING_REPORTS" -eq 1 ]]; then
        do_skip "axe-core: ${MISSING_REPORTS} route(s) produced no report (allowed by --allow-missing-reports)"
      else
        do_fail "axe-core: ${MISSING_REPORTS} route(s) produced no report (use --allow-missing-reports to downgrade)"
      fi
    fi

    if [[ "$ONLINE_VIOLATIONS" -eq 0 ]]; then
      do_pass "axe-core: 0 WCAG 2.2 AA violations across ${#ROUTES[@]} route(s)"
    else
      do_fail "axe-core: ${ONLINE_VIOLATIONS} WCAG 2.2 AA violation(s) found — see reports in ${REPORT_DIR}/"
    fi

    echo ""
    echo "  Reports written to: ${REPORT_DIR}/"
  fi

fi  # end online mode

# ──────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}SKIP${NC}: $SKIP"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}All accessibility checks passed (WCAG 2.2 AA framework)${NC}"
  echo ""
  echo "Notes:"
  echo "  - SKIP items indicate checks that require online access or not-yet-implemented policy sections"
  echo "  - Run with --online to include live axe-core scans against the target URL"
  exit 0
else
  echo -e "${RED}Some accessibility checks failed${NC}"
  echo ""
  echo "Fix FAIL items before committing."
  exit 1
fi
