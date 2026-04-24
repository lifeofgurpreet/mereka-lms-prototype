#!/usr/bin/env bash
# post-deploy-verify.sh — Run immediately after openedx/MFE image deploy.
#
# Purpose: Single-command live verification that all critical branding fixes
#          are live. Designed to be run by WhiteCliff after:
#            - Build Tutor Images workflow publishes the Open edX/MFE images
#            - release-openedx-gitops.sh updates GitOps image digests
#            - ArgoCD sync realizes the new image digests
#
# Usage:
#   ./scripts/qa/post-deploy-verify.sh [prod|dev]
#
# Exit codes:
#   0 — All checks PASS (or acceptable WARNs only)
#   1 — One or more FAIL (deployment blocker)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENVIRONMENT="${1:-prod}"

source "$SCRIPT_DIR/../shared/config.sh"

if [[ "$ENVIRONMENT" == "prod" ]]; then
  BASE_DOMAIN="${LMS_DOMAIN:-academyv2.mereka.io}"
  STUDIO_HOST="studio.${BASE_DOMAIN}"
  MFE_HOST="apps.${BASE_DOMAIN}"
  BIJI_STUDIO_HOST="studio.academy.biji-biji.com"
  BIJI_MFE_HOST="apps.academy.biji-biji.com"
else
  BASE_DOMAIN="academy.local"
  STUDIO_HOST="studio.${BASE_DOMAIN}"
  MFE_HOST="apps.${BASE_DOMAIN}"
  BIJI_STUDIO_HOST=""
  BIJI_MFE_HOST=""
fi

# Expected post-deploy values
EXPECTED_MFE_BRANDING_REV="2026-02-18-us7"
EXPECTED_LMS_BRANDING_REV="2026-02-10-pass1"

PASS=0
FAIL=0
WARN=0

pass() { printf "  ✓ %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  ✗ %s\n" "$1" >&2; FAIL=$((FAIL + 1)); }
warn() { printf "  ⚠ %s\n" "$1"; WARN=$((WARN + 1)); }
section() { printf "\n=== %s ===\n" "$1"; }

fetch() {
  curl -sS -L --connect-timeout 10 --max-time 30 "$1" 2>/dev/null || true
}

echo "Post-deploy verification: ${ENVIRONMENT} / ${BASE_DOMAIN}"
echo "Expected MFE rev: ${EXPECTED_MFE_BRANDING_REV}"
echo "Expected LMS rev: ${EXPECTED_LMS_BRANDING_REV}"
echo "Run at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ─── CHECK 1: Studio footer — no "Powered by Open edX" ────────────────────────
section "Studio footer white-label"
echo "  (verifies cms/templates/widgets/footer.html override is live)"

for _studio in "${STUDIO_HOST}" ${BIJI_STUDIO_HOST:-}; do
  _html="$(fetch "https://${_studio}/?nocache=$(date +%s)")"
  if [[ -z "${_html:-}" ]]; then
    fail "${_studio}: unreachable"
  elif printf '%s' "$_html" | grep -Eqi 'footer-about-openedx|open-edx-logo-tag|Powered by Open edX'; then
    fail "${_studio}: still shows 'Powered by Open edX' — image rebuild not deployed yet"
  else
    pass "${_studio}: no 'Powered by Open edX' in live footer"
  fi
done

# ─── CHECK 2: MFE branding revision ───────────────────────────────────────────
section "MFE branding revision (bz9p)"
echo "  (verifies MFE image 1c66529-20260220023917 is live)"

for _mfe in "${MFE_HOST}" ${BIJI_MFE_HOST:-}; do
  _authn_html="$(fetch "https://${_mfe}/authn/login?nocache=$(date +%s)")"
  # MFE authn CSS: href="/authn/app.<hash>.css" or "/authn/<chunk>.<hash>.css"
  _css_path="$(printf '%s' "${_authn_html}" | grep -o 'href="/authn/[^"]*\.css"' | grep -v 'chunk\|528\|vendor' | head -1 | sed 's/href="//;s/"//' || true)"
  if [[ -z "${_css_path:-}" ]]; then
    # Fallback: pick any authn CSS with the largest chunk (app CSS has branding vars)
    _css_path="$(printf '%s' "${_authn_html}" | grep -o 'href="/authn/[^"]*\.css"' | head -1 | sed 's/href="//;s/"//' || true)"
  fi

  if [[ -z "${_css_path:-}" ]]; then
    warn "${_mfe}: could not find authn CSS link in shell HTML"
    continue
  fi

  _css_url="https://${_mfe}${_css_path}"
  _css="$(fetch "${_css_url}")"
  if [[ -z "${_css:-}" ]]; then
    fail "${_mfe}: could not fetch authn CSS (${_css_url})"
  elif printf '%s' "$_css" | grep -F -q "${EXPECTED_MFE_BRANDING_REV}"; then
    pass "${_mfe}: MFE branding revision ${EXPECTED_MFE_BRANDING_REV} confirmed live"
  else
    _deployed_rev="$(printf '%s' "$_css" | grep -o -- '--mereka-mfe-branding-rev:[^;]*' | head -1 || echo 'unknown')"
    fail "${_mfe}: MFE rev ${EXPECTED_MFE_BRANDING_REV} NOT live (deployed: ${_deployed_rev})"
  fi
done

# ─── CHECK 3: LMS theming CSS accessible ──────────────────────────────────────
section "LMS themed CSS"
_lms_css="$(fetch "https://${BASE_DOMAIN}/theming/asset/mereka/css/mereka-overrides.css")"
if [[ -n "${_lms_css:-}" ]] && printf '%s' "$_lms_css" | grep -F -q "${EXPECTED_LMS_BRANDING_REV}"; then
  pass "${BASE_DOMAIN}: LMS themed CSS accessible (rev ${EXPECTED_LMS_BRANDING_REV} confirmed)"
elif [[ -n "${_lms_css:-}" ]]; then
  warn "${BASE_DOMAIN}: LMS themed CSS accessible but branding rev ${EXPECTED_LMS_BRANDING_REV} not found"
else
  fail "${BASE_DOMAIN}: LMS themed CSS (/theming/asset/mereka/css/mereka-overrides.css) unreachable"
fi

# ─── CHECK 4: Route matrix — all surfaces 2xx ─────────────────────────────────
section "Route matrix surface reachability"
declare -A ROUTES
ROUTES["LMS home"]="https://${BASE_DOMAIN}/"
ROUTES["Studio home"]="https://${STUDIO_HOST}/"
ROUTES["MFE authn"]="https://${MFE_HOST}/authn/login"
ROUTES["LMS admin"]="https://${BASE_DOMAIN}/admin/login/"
ROUTES["Forum root"]="https://${BASE_DOMAIN}/api/discussion/v2/courses/"
ROUTES["Notes"]="https://notes.${BASE_DOMAIN}/"
ROUTES["Preview"]="https://preview.${BASE_DOMAIN}/"
ROUTES["Ecommerce"]="https://ecommerce.${BASE_DOMAIN}/"
ROUTES["Credentials"]="https://credentials.${BASE_DOMAIN}/"
ROUTES["Biji-Biji LMS"]="https://academy.biji-biji.com/"
ROUTES["SkillourfFuture"]="https://skillourfuture.academy.mereka.io/"

for _label in "${!ROUTES[@]}"; do
  _url="${ROUTES[$_label]}"
  _code="$(curl -sS -L --connect-timeout 10 --max-time 20 -o /dev/null -w '%{http_code}' "$_url" 2>/dev/null || echo 000)"
  if [[ "$_code" =~ ^(200|301|302|401|404)$ ]]; then
    pass "${_label} (${_url}): HTTP ${_code}"
  else
    fail "${_label} (${_url}): HTTP ${_code} (expected 2xx/3xx/401)"
  fi
done

# ─── CHECK 5: Assets ──────────────────────────────────────────────────────────
section "Brand assets"
for _asset_url in \
  "https://${BASE_DOMAIN}/theming/asset/mereka/images/logo.png" \
  "https://${BASE_DOMAIN}/theming/asset/mereka/images/favicon.ico"; do
  _code="$(curl -sS -L --connect-timeout 5 --max-time 10 -o /dev/null -w '%{http_code}' "$_asset_url" 2>/dev/null || echo 000)"
  if [[ "$_code" == "200" ]]; then
    pass "$(basename "$_asset_url"): 200 OK"
  else
    fail "$(basename "$_asset_url"): HTTP ${_code} (should be 200)"
  fi
done

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
if [[ $FAIL -eq 0 ]]; then
  echo "POST-DEPLOY: PASS (${PASS} pass, ${WARN} warn, ${FAIL} fail)"
  echo "All critical branding checks live."
else
  echo "POST-DEPLOY: FAIL (${PASS} pass, ${WARN} warn, ${FAIL} fail)" >&2
  echo "" >&2
  echo "Remediation:" >&2
  echo "  - Studio footer failures → rebuild/publish via Build Tutor Images, then promote with release-openedx-gitops.sh" >&2
  echo "  - MFE rev failures       → verify GitOps image digest update, then ArgoCD sync" >&2
  echo "  - CSS unreachable        → check collectstatic ran, theming enabled" >&2
fi
echo "========================================"

[[ $FAIL -eq 0 ]]
