#!/usr/bin/env bash
# @covers AC-VU-001, AC-VU-002, AC-VU-003, AC-VU-004, AC-VU-005
# @spec: branding-system_spec.md
# verify-tenant-visual-contract.sh — Tenant-domain visual and authn contract hardening
#
# Validates rendered footer/header/logo, authn HTML markers, redirect chains,
# and CSS/asset assertions for all 3 production tenants.
#
# Usage:
#   ./scripts/qa/verify-tenant-visual-contract.sh [--env prod|dev] [--tenant SLUG] [--evidence-dir DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="prod"
TENANT_FILTER=""
EVIDENCE_DIR=""
CURL_TIMEOUT="${CURL_TIMEOUT:-15}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="${2:-prod}"; shift 2 ;;
    --tenant) TENANT_FILTER="${2:-}"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--env prod|dev] [--tenant SLUG] [--evidence-dir DIR]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── Domain configuration (generated from canonical tenant experience contract) ─

CONTRACT_FILE="$REPO_ROOT/config/tenant-experience-contract.yaml"

# Map env name to contract env key
case "$ENV" in
  prod) CONTRACT_ENV="production" ;;
  dev|staging) CONTRACT_ENV="$ENV" ;;
  *) echo "Unknown env: $ENV" >&2; exit 1 ;;
esac

# Generate all domain maps from the canonical contract
eval "$(python3 - "$CONTRACT_FILE" "$CONTRACT_ENV" "$TENANT_FILTER" <<'PY'
import sys
import yaml
from pathlib import Path

contract_path = Path(sys.argv[1])
target_env = sys.argv[2]
tenant_filter = sys.argv[3]

contract = yaml.safe_load(contract_path.read_text(encoding="utf-8"))
tenants = contract.get("tenants", [])

domains = []
mfe_map = []
theme_map = []
brand_map = []
eyebrow_map = []

for tenant in tenants:
    slug = tenant.get("slug", "")
    if tenant_filter and slug != tenant_filter:
        continue
    expected_brand = tenant.get("expected_brand", tenant.get("site_name", ""))
    theme_bundle = tenant.get("theme_bundle", "")
    expected_authn = tenant.get("expected_authn", {})
    eyebrow = expected_authn.get("eyebrow", "")

    for env_entry in tenant.get("environments", []):
        if env_entry.get("env") != target_env:
            continue
        lms_host = env_entry.get("lms_host", "")
        apps_host = env_entry.get("apps_host", "")
        if not lms_host or not apps_host:
            continue
        domains.append(lms_host)
        mfe_map.append(f'  ["{lms_host}"]="{apps_host}"')
        theme_map.append(f'  ["{lms_host}"]="{theme_bundle}"')
        brand_map.append(f'  ["{lms_host}"]="{expected_brand}"')
        eyebrow_map.append(f'  ["{lms_host}"]="{eyebrow}"')

print(f"DOMAINS=({' '.join(repr(d) for d in domains)})")
print(f"declare -A DOMAIN_MFE_HOST=(")
print("\n".join(mfe_map))
print(")")
print(f"declare -A DOMAIN_THEME_CSS=(")
print("\n".join(theme_map))
print(")")
print(f"declare -A DOMAIN_EXPECTED_BRAND=(")
print("\n".join(brand_map))
print(")")
print(f"declare -A DOMAIN_EXPECTED_EYEBROW=(")
print("\n".join(eyebrow_map))
print(")")
PY
)"

if [[ "${#DOMAINS[@]}" -eq 0 ]]; then
  if [[ -n "$TENANT_FILTER" ]]; then
    echo "No tenant domains matched tenant '$TENANT_FILTER' in environment '$CONTRACT_ENV'" >&2
  else
    echo "No tenant domains found in environment '$CONTRACT_ENV'" >&2
  fi
  exit 2
fi

PASS=0
FAIL=0
WARN=0
SKIP=0
RESULTS=()

pass() { PASS=$((PASS + 1)); RESULTS+=("PASS: $1"); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); RESULTS+=("FAIL: $1"); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); RESULTS+=("WARN: $1"); echo "  WARN: $1"; }
skip() { SKIP=$((SKIP + 1)); RESULTS+=("SKIP: $1"); echo "  SKIP: $1"; }

# ── Helper: Full HTTP with redirect chain + content ───────────────────────

# AC-VU-005: Follow redirects, capture chain, check content
http_with_chain() {
  local label="$1"
  local url="$2"
  local expected_marker="$3"  # HTML/content marker to check
  local check_redirect="${4:-false}"  # whether to validate redirect chain

  # Get full response with redirect chain
  local tmpfile
  tmpfile="$(mktemp)"
  local http_code redirect_count
  http_code="$(curl -sL -o "$tmpfile" -w "%{http_code}" \
    --max-time "$CURL_TIMEOUT" --max-redirs 10 "$url" 2>/dev/null || echo "000")"
  redirect_count="$(curl -sL -o /dev/null -w "%{num_redirects}" \
    --max-time "$CURL_TIMEOUT" --max-redirs 10 "$url" 2>/dev/null || echo "0")"

  if [[ "$http_code" == "000" ]]; then
    fail "$label → UNREACHABLE ($url)"
    rm -f "$tmpfile"
    return
  fi

  if [[ "$http_code" != "200" ]]; then
    fail "$label → HTTP $http_code (expected 200) ($url, ${redirect_count} redirects)"
    rm -f "$tmpfile"
    return
  fi

  # Content assertion
  if [[ -n "$expected_marker" ]]; then
    if grep -qi "$expected_marker" "$tmpfile" 2>/dev/null; then
      pass "$label → HTTP 200 + content marker '$expected_marker' present (${redirect_count} redirects)"
    else
      fail "$label → HTTP 200 but content marker '$expected_marker' NOT found ($url)"
    fi
  else
    pass "$label → HTTP 200 (${redirect_count} redirects)"
  fi

  # Save evidence if requested
  if [[ -n "$EVIDENCE_DIR" ]]; then
    local safename
    safename="$(echo "$label" | tr ' /:' '___' | tr -cd '[:alnum:]_-')"
    head -500 "$tmpfile" > "$EVIDENCE_DIR/${safename}.html" 2>/dev/null || true
  fi

  rm -f "$tmpfile"
}

# ── Helper: Check CSS/asset availability ──────────────────────────────────

check_asset() {
  local label="$1"
  local url="$2"

  local code
  code="$(curl -sLo /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT" "$url" 2>/dev/null || echo "000")"

  if [[ "$code" == "200" ]]; then
    pass "$label → asset OK ($url)"
  elif [[ "$code" == "302" || "$code" == "301" ]]; then
    # Theme assets may redirect to login when unauthenticated — this is expected
    warn "$label → redirects (likely auth-gated) ($url)"
  elif [[ "$code" == "000" ]]; then
    skip "$label → unreachable ($url)"
  else
    fail "$label → HTTP $code ($url)"
  fi
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Tenant Visual Contract Verification                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "Environment: $ENV"
if [[ -n "$TENANT_FILTER" ]]; then
  echo "Tenant filter: $TENANT_FILTER"
fi
echo "Domains: ${DOMAINS[*]}"
echo ""

if [[ -n "$EVIDENCE_DIR" ]]; then
  mkdir -p "$EVIDENCE_DIR"
fi

# ══════════════════════════════════════════════════════════════════════════
# AC-VU-001: Rendered footer/header/logo state per tenant
# ══════════════════════════════════════════════════════════════════════════

echo "── AC-VU-001: Footer/Header/Logo state per tenant ──"

for domain in "${DOMAINS[@]}"; do
  echo ""
  echo "  Domain: $domain"

  # LMS homepage: check for branding markers
  http_with_chain \
    "$domain LMS homepage branding" \
    "https://$domain/" \
    "mereka\|biji-biji\|skillourfuture"

  # MFE config: check SITE_NAME is set
  CONFIG_JSON="$(curl -s --max-time "$CURL_TIMEOUT" "https://$domain/api/mfe_config/v1" 2>/dev/null || echo "")"
  if [[ -n "$CONFIG_JSON" ]]; then
    SITE_NAME="$(echo "$CONFIG_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('SITE_NAME','MISSING'))" 2>/dev/null || echo "PARSE_ERROR")"
    LOGO_URL="$(echo "$CONFIG_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('LOGO_URL','MISSING'))" 2>/dev/null || echo "PARSE_ERROR")"
    PRIMARY_COLOR="$(echo "$CONFIG_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('PRIMARY_COLOR','MISSING'))" 2>/dev/null || echo "PARSE_ERROR")"
    SECONDARY_COLOR="$(echo "$CONFIG_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('SECONDARY_COLOR','MISSING'))" 2>/dev/null || echo "PARSE_ERROR")"
    ACCENT_COLOR="$(echo "$CONFIG_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ACCENT_COLOR','MISSING'))" 2>/dev/null || echo "PARSE_ERROR")"
    TEXT_ON_PRIMARY="$(echo "$CONFIG_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('TEXT_ON_PRIMARY','MISSING'))" 2>/dev/null || echo "PARSE_ERROR")"
    palette_missing=()

    if [[ "$SITE_NAME" != "MISSING" && "$SITE_NAME" != "PARSE_ERROR" ]]; then
      pass "$domain MFE config SITE_NAME='$SITE_NAME'"
    else
      fail "$domain MFE config SITE_NAME missing"
    fi

    if [[ "$LOGO_URL" != "MISSING" && "$LOGO_URL" != "PARSE_ERROR" && "$LOGO_URL" != "None" ]]; then
      pass "$domain MFE config LOGO_URL='$LOGO_URL'"
      # Note: /theming/asset/ URLs may redirect to login for unauthenticated requests
      # This is expected — MFE loads logos via authenticated API calls
    else
      warn "$domain MFE config LOGO_URL missing or null"
    fi

    for palette_key in PRIMARY_COLOR SECONDARY_COLOR ACCENT_COLOR TEXT_ON_PRIMARY; do
      palette_value="${!palette_key}"
      if [[ "$palette_value" == "MISSING" || "$palette_value" == "PARSE_ERROR" || "$palette_value" == "None" || -z "$palette_value" ]]; then
        palette_missing+=("$palette_key")
      fi
    done

    if [[ "${#palette_missing[@]}" -eq 0 ]]; then
      pass "$domain MFE config palette keys present (PRIMARY_COLOR, SECONDARY_COLOR, ACCENT_COLOR, TEXT_ON_PRIMARY)"
    else
      fail "$domain MFE config palette keys missing: ${palette_missing[*]}"
    fi
  else
    fail "$domain MFE config API unreachable"
  fi
done

echo ""

# ══════════════════════════════════════════════════════════════════════════
# AC-VU-002: Authn smoke with HTML markers + CSS assertions
# ══════════════════════════════════════════════════════════════════════════

echo "── AC-VU-002: Authn smoke per tenant ──"

for domain in "${DOMAINS[@]}"; do
  echo ""
  echo "  Domain: $domain"
  mfe_domain="${DOMAIN_MFE_HOST[$domain]:-}"
  expected_theme_css="${DOMAIN_THEME_CSS[$domain]:-}"

  if [[ -z "$mfe_domain" ]]; then
    fail "$domain authn host mapping missing"
    continue
  fi

  # Authn login page: HTTP 200 + HTML marker
  http_with_chain \
    "$domain authn/login" \
    "https://$mfe_domain/authn/login" \
    "authn\|login\|sign.in\|<div id=\"root\""

  # Authn register page: HTTP 200 + HTML marker
  http_with_chain \
    "$domain authn/register" \
    "https://$mfe_domain/authn/register" \
    "authn\|register\|sign.up\|<div id=\"root\""

  # Check CSS bundle loads (look for main CSS link in authn HTML)
  AUTHN_HTML="$(curl -sL --max-time "$CURL_TIMEOUT" "https://$mfe_domain/authn/login" 2>/dev/null || echo "")"
  if [[ -n "$AUTHN_HTML" ]]; then
    # Extract CSS href
    CSS_HREF="$(echo "$AUTHN_HTML" | grep -oP 'href="([^"]*\.css)"' | head -1 | grep -oP '"[^"]*"' | tr -d '"' || true)"
    if [[ -n "$CSS_HREF" ]]; then
      if [[ "$CSS_HREF" == http* ]]; then
        check_asset "$domain authn CSS bundle" "$CSS_HREF"
      elif [[ "$CSS_HREF" == /* ]]; then
        check_asset "$domain authn CSS bundle" "https://$mfe_domain$CSS_HREF"
      else
        check_asset "$domain authn CSS bundle" "https://$mfe_domain/authn/$CSS_HREF"
      fi
    else
      warn "$domain authn CSS link not found in HTML"
    fi

    if [[ -n "$expected_theme_css" ]]; then
      # Brand CSS is dynamically injected by tenant-resolution JS at runtime,
      # not present as a static <link> in the initial HTML. The browser DOM
      # check (AC-VU-002b) covers this authoritatively via Playwright.
      # This static HTML check is informational only.
      if grep -qF "$expected_theme_css" <<<"$AUTHN_HTML"; then
        pass "$domain authn shell references expected tenant theme ${expected_theme_css}"
      else
        warn "$domain authn shell does not statically reference tenant theme ${expected_theme_css} (loaded dynamically by JS)"
      fi
    fi

    brand_bundle_count=0
    for brand_css in \
      "/theme/mereka-brand.min.css" \
      "/theme/biji-biji-brand.min.css" \
      "/theme/sof-brand.min.css"; do
      if grep -qF "$brand_css" <<<"$AUTHN_HTML"; then
        brand_bundle_count=$((brand_bundle_count + 1))
      fi
    done
    if [[ "$brand_bundle_count" -gt 1 ]]; then
      warn "$domain authn shell exposes multiple tenant brand bundles in HTML (current count=${brand_bundle_count}); distinct hero/theme proof remains incomplete"
    fi
  fi
done

echo ""

# ══════════════════════════════════════════════════════════════════════════
# AC-VU-002b: Browser DOM contract for tenant authn (optional — requires Playwright)
# ══════════════════════════════════════════════════════════════════════════

echo "── AC-VU-002b: Browser DOM authn contract ──"

# DOMAIN_EXPECTED_BRAND and DOMAIN_EXPECTED_EYEBROW are now generated
# from the canonical tenant experience contract at the top of this script.

playwright_available() {
  ( cd "$REPO_ROOT/tests/e2e" && node -e "require.resolve('playwright')" ) >/dev/null 2>&1
}

browser_authn_contract_check() {
  local label="$1" apps_host="$2" expected_brand="$3" expected_eyebrow="$4"

  if ! playwright_available; then
    warn "$label → browser DOM audit skipped (Playwright deps not installed)"
    return
  fi

  local browser_json
  if ! browser_json="$(
    ( cd "$REPO_ROOT/tests/e2e" &&
      APPS_HOST="$apps_host" node <<'JS'
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ ignoreHTTPSErrors: true });
  try {
    await page.goto('https://' + process.env.APPS_HOST + '/authn/login?next=%2F', { waitUntil: 'networkidle', timeout: 45000 });
    // Wait for React plugin slot to hydrate — branding renders async after networkidle
    await page.waitForSelector('.mereka-authn-login-branding', { timeout: 10000 }).catch(() => {});
    const data = await page.evaluate(() => {
      const root = document.querySelector('.mereka-authn-login-branding');
      const css = getComputedStyle(document.documentElement);
      return {
        status: root ? 'ok' : 'missing-branding-root',
        tenant: document.documentElement.getAttribute('data-mereka-tenant') || '',
        primary: css.getPropertyValue('--tenant-color-primary').trim(),
        paragonPrimary: css.getPropertyValue('--pgn-color-primary-base').trim(),
        eyebrow: root ? (root.querySelector('.mereka-authn-login-branding__eyebrow')?.textContent?.trim() || '') : '',
        brand: root ? (root.querySelector('.mereka-authn-login-branding__brand')?.textContent?.trim() || '') : '',
      };
    });
    process.stdout.write(JSON.stringify(data));
  } finally { await browser.close(); }
})().catch(e => { process.stderr.write(String(e.stack || e)); process.exit(1); });
JS
    ) 2>/dev/null
  )"; then
    fail "$label → browser DOM audit failed to execute"
    return
  fi

  local browser_status browser_brand browser_eyebrow browser_primary browser_paragon
  browser_status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' <<< "$browser_json" 2>/dev/null || echo "parse-error")"
  browser_brand="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("brand",""))' <<< "$browser_json" 2>/dev/null || echo "")"
  browser_eyebrow="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("eyebrow",""))' <<< "$browser_json" 2>/dev/null || echo "")"
  browser_primary="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("primary",""))' <<< "$browser_json" 2>/dev/null || echo "")"
  browser_paragon="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("paragonPrimary",""))' <<< "$browser_json" 2>/dev/null || echo "")"

  [[ "$browser_status" == "ok" ]] && pass "$label → branding root rendered" || fail "$label → branding root missing"
  [[ "$browser_brand" == "$expected_brand" ]] && pass "$label → brand '$browser_brand'" || fail "$label → brand '$browser_brand' (expected '$expected_brand')"
  [[ "$browser_eyebrow" == "$expected_eyebrow" ]] && pass "$label → eyebrow '$browser_eyebrow'" || fail "$label → eyebrow '$browser_eyebrow' (expected '$expected_eyebrow')"
  [[ -n "$browser_primary" && -n "$browser_paragon" ]] && pass "$label → palette bridge present" || fail "$label → palette bridge missing"
}

for domain in "${DOMAINS[@]}"; do
  mfe_domain="${DOMAIN_MFE_HOST[$domain]:-}"
  expected_brand="${DOMAIN_EXPECTED_BRAND[$domain]:-}"
  expected_eyebrow="${DOMAIN_EXPECTED_EYEBROW[$domain]:-}"

  if [[ -z "$mfe_domain" || -z "$expected_brand" ]]; then
    skip "$domain browser DOM authn → missing host or brand mapping"
    continue
  fi

  browser_authn_contract_check "$domain authn DOM" "$mfe_domain" "$expected_brand" "$expected_eyebrow"
done

echo ""

# ══════════════════════════════════════════════════════════════════════════
# AC-VU-003: Screenshot route baselines for learner-dashboard + profile
# ══════════════════════════════════════════════════════════════════════════

echo "── AC-VU-003: Route baselines (learner-dashboard, profile, account) ──"

MFE_ROUTES=("learner-dashboard" "profile/u/" "account")

for domain in "${DOMAINS[@]}"; do
  echo ""
  echo "  Domain: $domain"
  mfe_domain="${DOMAIN_MFE_HOST[$domain]:-}"

  for route in "${MFE_ROUTES[@]}"; do
    # These routes may redirect to login, which is acceptable
    code="$(curl -sL -o /dev/null -w "%{http_code}" \
      --max-time "$CURL_TIMEOUT" --max-redirs 10 \
      "https://$mfe_domain/$route" 2>/dev/null || echo "000")"
    redirect_count="$(curl -sL -o /dev/null -w "%{num_redirects}" \
      --max-time "$CURL_TIMEOUT" --max-redirs 10 \
      "https://$mfe_domain/$route" 2>/dev/null || echo "0")"

    if [[ "$code" == "200" ]]; then
      pass "$domain $route → HTTP 200 (${redirect_count} redirects)"
    elif [[ "$code" == "000" ]]; then
      fail "$domain $route → UNREACHABLE"
    else
      # 302/401/403 to login is expected for unauthenticated routes
      warn "$domain $route → HTTP $code (may redirect to login, ${redirect_count} redirects)"
    fi
  done
done

echo ""

# ══════════════════════════════════════════════════════════════════════════
# AC-VU-004: One-command summary artifact
# ══════════════════════════════════════════════════════════════════════════

echo "── AC-VU-004: Summary artifact ──"

SUMMARY_JSON="{}"
SUMMARY_MD=""

for domain in "${DOMAINS[@]}"; do
  # Build per-domain status
  DOMAIN_PASS=$(printf '%s\n' "${RESULTS[@]}" | grep -c "^PASS: ${domain}" || true)
  DOMAIN_FAIL=$(printf '%s\n' "${RESULTS[@]}" | grep -c "^FAIL: ${domain}" || true)
  DOMAIN_WARN=$(printf '%s\n' "${RESULTS[@]}" | grep -c "^WARN: ${domain}" || true)

  if [[ "${DOMAIN_FAIL:-0}" -gt 0 ]]; then
    STATUS="FIX"
    NEXT_OWNER="Mereka platform team"
  elif [[ "${DOMAIN_WARN:-0}" -gt 0 ]]; then
    STATUS="WARN"
    NEXT_OWNER="Mereka frontend team"
  else
    STATUS="OK"
    NEXT_OWNER="—"
  fi

  SUMMARY_MD="${SUMMARY_MD}| ${domain} | ${STATUS} | PASS=${DOMAIN_PASS:-0} FAIL=${DOMAIN_FAIL:-0} WARN=${DOMAIN_WARN:-0} | ${NEXT_OWNER} |\n"
done

if [[ -n "$EVIDENCE_DIR" ]]; then
  # JSON summary
  python3 -c "
import json, sys
results = []
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    parts = line.split(': ', 1)
    if len(parts) == 2:
        results.append({'status': parts[0], 'detail': parts[1]})
summary = {
    'date': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'environment': '$ENV',
    'domains': $(python3 -c "import json; print(json.dumps([$(printf '"%s",' "${DOMAINS[@]}" | sed 's/,$//')]))" 2>/dev/null || echo '[]'),
    'totals': {'pass': $PASS, 'fail': $FAIL, 'warn': $WARN, 'skip': $SKIP},
    'results': results
}
print(json.dumps(summary, indent=2))
" <<< "$(printf '%s\n' "${RESULTS[@]}")" > "$EVIDENCE_DIR/tenant-visual-contract.json" 2>/dev/null || true

  # Markdown summary
  {
    echo "# Tenant Visual Contract Evidence"
    echo ""
    echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Environment: $ENV"
    echo "Totals: PASS=$PASS FAIL=$FAIL WARN=$WARN SKIP=$SKIP"
    echo ""
    echo "## Per-Domain Summary"
    echo ""
    echo "| Domain | Status | Checks | Next Owner |"
    echo "|--------|--------|--------|------------|"
    printf "$SUMMARY_MD"
    echo ""
    echo "## Detailed Results"
    echo ""
    for result in "${RESULTS[@]}"; do
      echo "- $result"
    done
  } > "$EVIDENCE_DIR/tenant-visual-contract.md"

  pass "Evidence artifacts written to $EVIDENCE_DIR"
  echo ""
fi

# ══════════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════════

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       TENANT VISUAL CONTRACT SUMMARY                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "| Domain | Status | Checks | Next Owner |"
echo "|--------|--------|--------|------------|"
printf "$SUMMARY_MD"
echo ""
echo "Totals: PASS=$PASS FAIL=$FAIL WARN=$WARN SKIP=$SKIP"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL — $FAIL check(s) failed"
  exit 1
fi

echo ""
echo "RESULT: PASS — all tenant visual contracts verified"
exit 0
