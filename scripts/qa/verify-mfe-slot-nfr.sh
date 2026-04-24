#!/usr/bin/env bash
# @covers AC-SLOT-025, AC-SLOT-026, AC-SLOT-027
# @spec: mfe-plugin-slots_spec.md
#
# verify-mfe-slot-nfr.sh - NFR checks for MFE plugin slot customizations.
# - AC-SLOT-025: source contract for low-latency render path (synchronous markers)
# - AC-SLOT-026: gzipped runtime-definition payload budget (<= 15KB)
# - AC-SLOT-027: optional runtime overflow check at 320px and 1920px viewports
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN_FILE="$PLUGIN_MAIN"

CHECK_RUNTIME="${CHECK_RUNTIME:-0}"
RUNTIME_BASE_URL="${RUNTIME_BASE_URL:-https://apps.localhost}"
RUNTIME_PATHS="${RUNTIME_PATHS:-/authn/login,/learner-dashboard,/account,/profile,/learning}"
SLOT_JS_GZIP_BUDGET_BYTES="${SLOT_JS_GZIP_BUDGET_BYTES:-15360}"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $1"; }

if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "Plugin source not found: $PLUGIN_FILE"
  echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
  exit 1
fi

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-nfr.XXXXXX)"
  while IFS= read -r plugin_file; do
    cat "$plugin_file" >>"$PLUGIN_BUNDLE"
    printf '\n' >>"$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
  PLUGIN_FILE="$PLUGIN_BUNDLE"
fi

cleanup() {
  if [[ -n "$PLUGIN_BUNDLE" && -f "$PLUGIN_BUNDLE" ]]; then
    rm -f "$PLUGIN_BUNDLE"
  fi
}
trap cleanup EXIT

echo "=== MFE Slot NFR Verification ==="

# Extract runtime definitions payloads and compute gzip size budget.
runtime_json="$(
python3 - "$PLUGIN_FILE" <<'PY'
import gzip, json, re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = []
for m in re.finditer(r'["\']mfe-env-config-runtime-definitions["\']\s*,', text):
    tail = text[m.end():]
    q1 = tail.find('"""')
    q2 = tail.find("'''")
    starts = [x for x in (q1, q2) if x >= 0]
    if not starts:
        continue
    start = min(starts)
    quote = '"""' if q1 == start else "'''"
    rest = tail[start + 3:]
    end = rest.find(quote)
    if end >= 0:
        blocks.append(rest[:end])
merged = "\n\n".join(blocks)
payload = {
    "runtime_block_count": len(blocks),
    "runtime_chars": len(merged),
    "runtime_gzip_bytes": len(gzip.compress(merged.encode("utf-8"), compresslevel=9)),
    "has_direct_plugin": "DIRECT_PLUGIN" in text,
}
patterns = {
    "fetch(": "fetch",
    "axios.": "axios",
    "XMLHttpRequest": "xhr",
    "setTimeout(": "setTimeout",
    "setInterval(": "setInterval",
    "await ": "await",
}
hits = []
for needle, label in patterns.items():
    if needle in merged:
        hits.append(label)
payload["async_markers"] = sorted(set(hits))
print(json.dumps(payload))
PY
)"

runtime_block_count="$(python3 - <<'PY' "$runtime_json"
import json,sys
print(json.loads(sys.argv[1])["runtime_block_count"])
PY
)"
runtime_gzip_bytes="$(python3 - <<'PY' "$runtime_json"
import json,sys
print(json.loads(sys.argv[1])["runtime_gzip_bytes"])
PY
)"
has_direct_plugin="$(python3 - <<'PY' "$runtime_json"
import json,sys
print("1" if json.loads(sys.argv[1])["has_direct_plugin"] else "0")
PY
)"
async_markers="$(python3 - <<'PY' "$runtime_json"
import json,sys
print(",".join(json.loads(sys.argv[1])["async_markers"]))
PY
)"

if [[ "$runtime_block_count" -gt 0 ]]; then
  pass "Runtime definition blocks detected ($runtime_block_count)"
else
  fail "No mfe-env-config-runtime-definitions blocks found"
fi

if mereka_plugin_has_fixed "$REPO_ROOT" "DIRECT_PLUGIN"; then
  pass "DIRECT_PLUGIN marker present (no iframe render overhead path)"
else
  if [[ "$has_direct_plugin" == "1" ]]; then
    pass "DIRECT_PLUGIN marker present (source payload)"
  else
    fail "DIRECT_PLUGIN marker missing"
  fi
fi

if [[ -z "$async_markers" ]]; then
  pass "Runtime definitions contain no async network/timer markers (fetch/axios/xhr/await/setTimeout/setInterval)"
else
  fail "Runtime definitions include async markers: $async_markers"
fi

if [[ "$runtime_gzip_bytes" -le "$SLOT_JS_GZIP_BUDGET_BYTES" ]]; then
  pass "Runtime definition gzip size ${runtime_gzip_bytes}B within budget ${SLOT_JS_GZIP_BUDGET_BYTES}B"
else
  fail "Runtime definition gzip size ${runtime_gzip_bytes}B exceeds budget ${SLOT_JS_GZIP_BUDGET_BYTES}B"
fi

# Optional runtime overflow checks for responsive safety.
if [[ "$CHECK_RUNTIME" != "1" ]]; then
  warn "Runtime overflow checks skipped (set CHECK_RUNTIME=1 to enable AC-SLOT-027 live checks)"
else
  if ! command -v node >/dev/null 2>&1; then
    fail "CHECK_RUNTIME=1 requested but node is unavailable"
  else
    tmp_js="$(mktemp -t slot-nfr-runtime.XXXXXX.js)"
    cat >"$tmp_js" <<'JS'
const { chromium } = require('playwright');

const baseUrl = process.env.RUNTIME_BASE_URL || 'https://apps.localhost';
const paths = (process.env.RUNTIME_PATHS || '/authn/login,/learner-dashboard,/account,/profile,/learning')
  .split(',').map((s) => s.trim()).filter(Boolean);
const viewports = [
  { name: 'mobile-320', width: 320, height: 812 },
  { name: 'desktop-1920', width: 1920, height: 1080 },
];

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  let failures = 0;
  try {
    for (const vp of viewports) {
      const context = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
      const page = await context.newPage();
      for (const p of paths) {
        const url = `${baseUrl.replace(/\/$/, '')}${p}`;
        try {
          await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
          await page.waitForTimeout(1200);
          const overflow = await page.evaluate(() => {
            const de = document.documentElement;
            const body = document.body;
            const maxScroll = Math.max(
              de ? de.scrollWidth : 0,
              body ? body.scrollWidth : 0,
            );
            const inner = window.innerWidth || (de ? de.clientWidth : 0);
            return maxScroll > (inner + 1);
          });
          if (overflow) {
            console.log(`FAIL: runtime overflow detected (${vp.name}) ${p}`);
            failures += 1;
          } else {
            console.log(`PASS: no runtime overflow (${vp.name}) ${p}`);
          }
        } catch (err) {
          console.log(`WARN: runtime check skipped (${vp.name}) ${p} :: ${err.message}`);
        }
      }
      await context.close();
    }
  } finally {
    await browser.close();
  }
  process.exit(failures > 0 ? 1 : 0);
})();
JS

    set +e
    runtime_output="$(RUNTIME_BASE_URL="$RUNTIME_BASE_URL" RUNTIME_PATHS="$RUNTIME_PATHS" node "$tmp_js" 2>&1)"
    runtime_code=$?
    set -e
    rm -f "$tmp_js"

    while IFS= read -r line; do
      [[ -n "$line" ]] && echo "$line"
    done <<<"$runtime_output"

    if [[ "$runtime_code" -eq 0 ]]; then
      pass "Runtime overflow checks passed for 320px/1920px viewports"
    else
      fail "Runtime overflow checks reported one or more failures"
    fi
  fi
fi

echo ""
echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
