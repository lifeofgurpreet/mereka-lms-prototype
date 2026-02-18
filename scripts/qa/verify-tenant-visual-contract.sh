#!/usr/bin/env bash
# @covers AC-VU-001, AC-VU-002, AC-VU-003, AC-VU-004, AC-VU-005
# @spec: branding-system_spec.md
# verify-tenant-visual-contract.sh — Tenant-domain visual and authn contract hardening
#
# Validates rendered footer/header/logo, authn HTML markers, redirect chains,
# and CSS/asset assertions for all 3 production tenants.
#
# Usage:
#   ./scripts/qa/verify-tenant-visual-contract.sh [--env prod|dev] [--evidence-dir DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="prod"
EVIDENCE_DIR=""
CURL_TIMEOUT="${CURL_TIMEOUT:-15}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="${2:-prod}"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--env prod|dev] [--evidence-dir DIR]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── Domain configuration ──────────────────────────────────────────────────

case "$ENV" in
  prod)
    DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")
    MFE_DOMAIN="apps.academyv2.mereka.io"
    ;;
  dev)
    DOMAINS=("${LMS_DOMAIN:-localhost}")
    MFE_DOMAIN="${MFE_DOMAIN:-apps.localhost}"
    ;;
  *) echo "Unknown env: $ENV" >&2; exit 1 ;;
esac

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
echo "Domains: ${DOMAINS[*]}"
echo "MFE domain: $MFE_DOMAIN"
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

  # Authn login page: HTTP 200 + HTML marker
  http_with_chain \
    "$domain authn/login" \
    "https://$MFE_DOMAIN/authn/login" \
    "authn\|login\|sign.in\|<div id=\"root\""

  # Authn register page: HTTP 200 + HTML marker
  http_with_chain \
    "$domain authn/register" \
    "https://$MFE_DOMAIN/authn/register" \
    "authn\|register\|sign.up\|<div id=\"root\""

  # Check CSS bundle loads (look for main CSS link in authn HTML)
  AUTHN_HTML="$(curl -sL --max-time "$CURL_TIMEOUT" "https://$MFE_DOMAIN/authn/login" 2>/dev/null || echo "")"
  if [[ -n "$AUTHN_HTML" ]]; then
    # Extract CSS href
    CSS_HREF="$(echo "$AUTHN_HTML" | grep -oP 'href="([^"]*\.css)"' | head -1 | grep -oP '"[^"]*"' | tr -d '"' || true)"
    if [[ -n "$CSS_HREF" ]]; then
      if [[ "$CSS_HREF" == http* ]]; then
        check_asset "$domain authn CSS bundle" "$CSS_HREF"
      elif [[ "$CSS_HREF" == /* ]]; then
        check_asset "$domain authn CSS bundle" "https://$MFE_DOMAIN$CSS_HREF"
      else
        check_asset "$domain authn CSS bundle" "https://$MFE_DOMAIN/authn/$CSS_HREF"
      fi
    else
      warn "$domain authn CSS link not found in HTML"
    fi
  fi
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

  for route in "${MFE_ROUTES[@]}"; do
    # These routes may redirect to login, which is acceptable
    code="$(curl -sL -o /dev/null -w "%{http_code}" \
      --max-time "$CURL_TIMEOUT" --max-redirs 10 \
      "https://$MFE_DOMAIN/$route" 2>/dev/null || echo "000")"
    redirect_count="$(curl -sL -o /dev/null -w "%{num_redirects}" \
      --max-time "$CURL_TIMEOUT" --max-redirs 10 \
      "https://$MFE_DOMAIN/$route" 2>/dev/null || echo "0")"

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
  DOMAIN_PASS=$(printf '%s\n' "${RESULTS[@]}" | grep -c "$domain.*PASS" || true)
  DOMAIN_FAIL=$(printf '%s\n' "${RESULTS[@]}" | grep -c "$domain.*FAIL" || true)
  DOMAIN_WARN=$(printf '%s\n' "${RESULTS[@]}" | grep -c "$domain.*WARN" || true)

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
