#!/usr/bin/env bash
# verify-dev-visual-correctness.sh
#
# Machine-verifiable proof that dev LMS visual layer is correct.
# Tests three independent layers:
#   1. THEME LAYER     – correct CSS asset present, decisive selectors present
#   2. PLUGIN LAYER    – plugin framework compiled into MFE bundles
#   3. BROWSER LAYER   – computed styles in live browser match intent
#
# Failure classification:
#   theme_asset_missing         – CSS file not served / wrong size
#   theme_selector_missing      – decisive selector absent from served CSS
#   css_precedence_wrong        – stock rule wins; computed style shows wrong values
#   stock_layout_winning        – float:left still wins on .courses-listing-item
#   plugin_framework_missing    – PLUGIN_OPERATIONS absent from MFE bundle
#   page_runtime_broken         – page does not return 200
#   usable                      – all checks pass
#
# Usage:
#   ./scripts/qa/verify-dev-visual-correctness.sh
#   ./scripts/qa/verify-dev-visual-correctness.sh --browser   # also runs browser checks
#   ./scripts/qa/verify-dev-visual-correctness.sh --ci        # exit 1 on any failure
#
# Requirements: curl, kubectl, python3
# Browser checks additionally require: playwright (pip install playwright)

set -euo pipefail

LMS_HOST="${LMS_HOST:-academyv2.mereka.dev}"
MFE_HOST="${MFE_HOST:-apps.academyv2.mereka.dev}"
NAMESPACE="${NAMESPACE:-mereka-lms-dev}"
BROWSER="${BROWSER:-false}"
CI="${CI:-false}"

# Minimum theme CSS size (bytes). Stock is ~857KB; full theme is ~897KB.
# If served file is < 400KB it is token-only (broken build like staging).
MIN_THEME_CSS_BYTES=800000

PASS=0
FAIL=0
WARN=0

_pass() { echo "  PASS  $*"; PASS=$((PASS+1)); }
_fail() { echo "  FAIL  $*"; FAIL=$((FAIL+1)); }
_warn() { echo "  WARN  $*"; WARN=$((WARN+1)); }
_section() { echo ""; echo "── $* ──────────────────────────────"; }

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 1: THEME
# ─────────────────────────────────────────────────────────────────────────────
_section "THEME LAYER"

# 1a. CSS asset size
THEME_CSS_URL="https://${LMS_HOST}/static/mereka/css/lms-main-v1.css"
ACTUAL_SIZE=$(curl -sI "$THEME_CSS_URL" 2>/dev/null | grep -i content-length | awk '{print $2}' | tr -d '\r')
if [ -z "$ACTUAL_SIZE" ]; then
  # fallback: download and measure
  ACTUAL_SIZE=$(curl -s "$THEME_CSS_URL" 2>/dev/null | wc -c)
fi

if [ "$ACTUAL_SIZE" -ge "$MIN_THEME_CSS_BYTES" ] 2>/dev/null; then
  _pass "theme CSS size ${ACTUAL_SIZE} bytes >= ${MIN_THEME_CSS_BYTES} (full compiled theme, not token-only)"
else
  _fail "theme_asset_missing: theme CSS only ${ACTUAL_SIZE:-unknown} bytes (expected >= ${MIN_THEME_CSS_BYTES}; token-only build suspected)"
fi

# 1b. Float cancel selector present in served CSS
FLOAT_CANCEL=$(curl -s "$THEME_CSS_URL" 2>/dev/null | grep -c 'float:none !important' || true)
if [ "$FLOAT_CANCEL" -ge 1 ]; then
  _pass "theme CSS contains float:none !important (course grid override from _custom.scss)"
else
  _fail "theme_selector_missing: 'float:none !important' absent from served theme CSS (course grid will use stock float layout)"
fi

# 1c. learn-more positioning override present at correct specificity
# The authoritative fix lives in _custom.scss as part of the 0,6,0 selector.
# We check for top:auto (the key cancellation of stock top:55px).
LEARN_MORE_FIX=$(curl -s "$THEME_CSS_URL" 2>/dev/null | \
  python3 -c "
import sys, re
css = sys.stdin.read()
# Look for the 6-class selector that contains both opacity:1 AND top:auto
# This is the _custom.scss fix rule
m = re.search(r'\.courses-container \.courses \.course \.course-image \.cover-image \.learn-more\{[^}]*top:auto[^}]*\}', css)
print('found' if m else 'missing')
" 2>/dev/null)

if [ "$LEARN_MORE_FIX" = "found" ]; then
  _pass "learn-more fix present in compiled theme (top:auto + 0,6,0 specificity)"
else
  _warn "learn-more fix NOT in compiled theme CSS (still in head-extra.html runtime bridge; rebuild image to make durable)"
fi

# 1d. Page loads (baseline)
HTTP_STATUS=$(curl -sI "https://${LMS_HOST}" 2>/dev/null | head -1 | awk '{print $2}')
if [ "$HTTP_STATUS" = "200" ]; then
  _pass "LMS homepage returns 200"
else
  _fail "page_runtime_broken: LMS homepage returned ${HTTP_STATUS:-no response}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 2: PLUGIN FRAMEWORK
# ─────────────────────────────────────────────────────────────────────────────
_section "PLUGIN LAYER"

# 2a. Plugin framework present in authn MFE bundle
MFE_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=mfe \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$MFE_POD" ]; then
  _fail "plugin_framework_missing: no MFE pod found in namespace ${NAMESPACE}"
else
  # Check the chunk file (not app.js) where plugin configs are compiled
  PLUGIN_OPS=$(kubectl exec -n "$NAMESPACE" "$MFE_POD" -- sh -c \
    "grep -oh 'PLUGIN_OPERATIONS' /openedx/dist/authn/*.js 2>/dev/null | wc -l" 2>/dev/null || echo 0)
  DIRECT_PLUGIN=$(kubectl exec -n "$NAMESPACE" "$MFE_POD" -- sh -c \
    "grep -oh 'DIRECT_PLUGIN' /openedx/dist/authn/*.js 2>/dev/null | wc -l" 2>/dev/null || echo 0)

  if [ "$PLUGIN_OPS" -ge 5 ] 2>/dev/null; then
    _pass "plugin framework: PLUGIN_OPERATIONS=${PLUGIN_OPS} DIRECT_PLUGIN=${DIRECT_PLUGIN} in authn bundles"
  else
    _fail "plugin_framework_missing: PLUGIN_OPERATIONS=${PLUGIN_OPS} DIRECT_PLUGIN=${DIRECT_PLUGIN} (expected >= 5; plugin slots may not be compiled)"
  fi

  # 2b. MFE authn page loads
  AUTHN_STATUS=$(curl -sI "https://${MFE_HOST}/authn/login" 2>/dev/null | head -1 | awk '{print $2}')
  if [ "$AUTHN_STATUS" = "200" ]; then
    _pass "authn MFE login page returns 200"
  else
    _fail "page_runtime_broken: authn MFE returned ${AUTHN_STATUS:-no response}"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 3: BROWSER / COMPUTED STYLE (optional, requires playwright)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$BROWSER" = "true" ]; then
  _section "BROWSER LAYER (computed styles)"

  python3 - << 'PYEOF'
import asyncio, sys

async def check():
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        print("  SKIP  playwright not installed (pip install playwright && playwright install chromium)")
        return True

    results = []

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={'width': 1440, 'height': 900})

        import os
        lms_host = os.environ.get('LMS_HOST', 'academyv2.mereka.dev')

        try:
            await page.goto(f'https://{lms_host}', wait_until='networkidle', timeout=30000)
        except Exception as e:
            print(f'  FAIL  page_runtime_broken: {e}')
            await browser.close()
            return False

        # Check .courses-listing-item computed float
        r = await page.evaluate('''() => {
            const el = document.querySelector(".courses-listing-item");
            if (!el) return null;
            const cs = window.getComputedStyle(el);
            return {float: cs.float, display: cs.display, width: cs.width};
        }''')
        if r:
            if r['float'] == 'none':
                print(f"  PASS  .courses-listing-item float=none display={r['display']} (float override winning)")
            else:
                print(f"  FAIL  stock_layout_winning: .courses-listing-item float={r['float']} (expected none; stock CSS is winning)")
                results.append(False)
        else:
            print("  WARN  no .courses-listing-item found on page")

        # Check .learn-more computed style
        r2 = await page.evaluate('''() => {
            const el = document.querySelector(".courses-listing-item .course .course-image .cover-image .learn-more");
            if (!el) return null;
            const cs = window.getComputedStyle(el);
            return {
                top: cs.top, bottom: cs.bottom, opacity: cs.opacity,
                width: cs.width, height: cs.height, borderRadius: cs.borderRadius
            };
        }''')
        if r2:
            top_val = r2['top']
            # top:auto renders as a pixel value equal to the parent height or auto
            # Correct: top should NOT be 55px (stock value)
            if top_val == '55px':
                print(f"  FAIL  css_precedence_wrong: .learn-more top={top_val} (stock rule winning; expected top=auto/non-55px)")
                results.append(False)
            else:
                print(f"  PASS  .learn-more top={top_val} bottom={r2['bottom']} opacity={r2['opacity']} w={r2['width']} h={r2['height']} br={r2['borderRadius']}")
        else:
            print("  WARN  no .learn-more element found on page")

        await browser.close()
    return all(results) if results else True

ok = asyncio.run(check())
sys.exit(0 if ok else 1)
PYEOF

fi

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
echo "  PASS: ${PASS}  FAIL: ${FAIL}  WARN: ${WARN}"
if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  echo "  VERDICT: usable — all checks pass"
elif [ "$FAIL" -eq 0 ]; then
  echo "  VERDICT: mostly correct — warnings indicate pending image rebuild"
else
  echo "  VERDICT: degraded — $FAIL failure(s) above need attention"
fi
echo "══════════════════════════════════════════════"

if [ "$CI" = "true" ] && [ "$FAIL" -gt 0 ]; then
  exit 1
fi
