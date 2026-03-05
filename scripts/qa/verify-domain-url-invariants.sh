#!/usr/bin/env bash
# verify-domain-url-invariants.sh — Ensures ALL domain/URL references across
# Django settings, CSP directives, Caddy configs, and K8s overlays are
# consistent with the canonical domain registry in config.sh.
#
# @covers AC-SEC-001, AC-SEC-003
# @spec: specs/security-hardening_spec.md
#
# This is a static repo check — no running cluster required.
# Catches: stale domains, missing auth/service URLs in CSP, env-specific
# domain mismatches between overlays, and wildcard CSP sources.
#
# Usage: ./scripts/qa/verify-domain-url-invariants.sh
#   Set STRICT=1 to treat WARNs as FAILs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
STRICT="${STRICT:-0}"

case "$STRICT" in
  0|1) ;;
  *)
    echo "Invalid STRICT='$STRICT' (expected 0 or 1)" >&2
    exit 1
    ;;
esac

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_warn() {
  if [[ "$STRICT" == "1" ]]; then
    FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} (strict) $1"
  else
    WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"
  fi
}

# Key files
PROD_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
CMS_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"
MFE_CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
NONPROD_DOMAIN_PATCH="$REPO_ROOT/deploy/k8s/overlays/rke2-nonprod/patches/domain-env.yaml"
LOCAL_DOMAIN_PATCH="$REPO_ROOT/deploy/k8s/overlays/local/patches/domain-env.yaml"

printf "${BLUE}=== Domain & URL Invariant Gate ===${NC}\n\n"

# ── 1. Canonical domain variables exist in config.sh ─────────────────────
printf "${BLUE}── 1. Canonical domain registry (config.sh) ──${NC}\n"

REQUIRED_PROD_DOMAINS=(
  LMS_DOMAIN STUDIO_DOMAIN MFE_DOMAIN AUTHENTIK_DOMAIN PREVIEW_DOMAIN
  DISCOVERY_DOMAIN NOTES_DOMAIN CREDENTIALS_DOMAIN FORUM_DOMAIN
  ENTERPRISE_ADMIN_DOMAIN ENTERPRISE_PORTAL_DOMAIN
  BIJI_DOMAIN BIJI_STUDIO_DOMAIN BIJI_MFE_DOMAIN
  SKILLOURFUTURE_DOMAIN PURCHASE_GATEWAY_DOMAIN
)
REQUIRED_DEV_DOMAINS=(
  DEV_LMS_DOMAIN DEV_STUDIO_DOMAIN DEV_MFE_DOMAIN DEV_AUTHENTIK_DOMAIN
  DEV_PREVIEW_DOMAIN DEV_DISCOVERY_DOMAIN DEV_NOTES_DOMAIN
  DEV_CREDENTIALS_DOMAIN DEV_FORUM_DOMAIN DEV_PURCHASE_GATEWAY_DOMAIN
)

for var in "${REQUIRED_PROD_DOMAINS[@]}" "${REQUIRED_DEV_DOMAINS[@]}"; do
  if [[ -n "${!var:-}" ]]; then
    do_pass "config.sh exports $var=${!var}"
  else
    do_fail "config.sh missing or empty: $var"
  fi
done

# ── 2. Production.py has all MEREKA_*_DOMAIN variables ───────────────────
printf "\n${BLUE}── 2. Django production.py domain variables ──${NC}\n"

REQUIRED_PY_DOMAINS=(
  MEREKA_LMS_DOMAIN MEREKA_STUDIO_DOMAIN MEREKA_MFE_DOMAIN
  MEREKA_DISCOVERY_DOMAIN MEREKA_NOTES_DOMAIN MEREKA_CREDENTIALS_DOMAIN
  MEREKA_PREVIEW_DOMAIN MEREKA_AUTH_DOMAIN
  MEREKA_DEV_DOMAIN MEREKA_DEV_STUDIO_DOMAIN MEREKA_DEV_MFE_DOMAIN
)
REQUIRED_PY_URLS=(
  MEREKA_LMS_BASE_URL MEREKA_STUDIO_BASE_URL MEREKA_MFE_BASE_URL
  MEREKA_AUTH_BASE_URL
)

if [[ -f "$PROD_PY" ]]; then
  for var in "${REQUIRED_PY_DOMAINS[@]}"; do
    if grep -qF "$var" "$PROD_PY"; then
      do_pass "production.py defines $var"
    else
      do_fail "production.py missing $var"
    fi
  done
  for var in "${REQUIRED_PY_URLS[@]}"; do
    if grep -qF "$var" "$PROD_PY"; then
      do_pass "production.py defines $var"
    else
      do_fail "production.py missing $var"
    fi
  done
else
  do_fail "production.py not found: $PROD_PY"
fi

# ── 3. CSP directives reference correct domains ─────────────────────────
printf "\n${BLUE}── 3. CSP directive URL integrity ──${NC}\n"

check_csp_no_wildcard() {
  local file="$1"
  local label="$2"
  local directive="$3"

  if [[ ! -f "$file" ]]; then
    do_fail "$label: file not found"
    return
  fi

  # Extract the directive block (multi-line tuple or single-line string)
  local block
  block=$(sed -n "/^${directive}/,/^)/p" "$file" 2>/dev/null || true)
  if [[ -z "$block" ]]; then
    # Try single-line (Caddyfile style) — just check the whole file
    block=$(cat "$file")
  fi

  # Check for overly broad wildcards
  if echo "$block" | grep -qE '"https:"'; then
    do_fail "$label $directive contains wildcard 'https:' — use explicit domains"
  else
    do_pass "$label $directive: no wildcard https:"
  fi
}

# Django CSP (plugin settings)
for directive in CSP_IMG_SRC CSP_CONNECT_SRC CSP_FRAME_SRC; do
  check_csp_no_wildcard "$PROD_PY" "production.py" "$directive"
done

# Plugin settings (Tutor path)
PLUGIN_FILES=()
while IFS= read -r f; do
  PLUGIN_FILES+=("$f")
done < <(mereka_plugin_contract_files "$REPO_ROOT")

for pf in "${PLUGIN_FILES[@]}"; do
  if grep -qF "CSP_IMG_SRC" "$pf" 2>/dev/null; then
    for directive in CSP_IMG_SRC CSP_CONNECT_SRC CSP_FRAME_SRC; do
      check_csp_no_wildcard "$pf" "plugin($(basename "$pf"))" "$directive"
    done
    break
  fi
done

# MFE Caddyfile — check for wildcard in img-src
if [[ -f "$MFE_CADDYFILE" ]]; then
  csp_line=$(grep -o 'Content-Security-Policy "[^"]*"' "$MFE_CADDYFILE" || true)
  if [[ -n "$csp_line" ]]; then
    # Extract img-src value
    img_src=$(echo "$csp_line" | grep -oP 'img-src [^;]+' || true)
    if echo "$img_src" | grep -qE '\bhttps:\b'; then
      do_fail "Caddyfile img-src contains wildcard 'https:'"
    else
      do_pass "Caddyfile img-src: no wildcard https:"
    fi

    # Check connect-src isn't bare wildcard https: (https://*.domain is OK)
    connect_src=$(echo "$csp_line" | grep -oP 'connect-src [^;]+' || true)
    if echo "$connect_src" | grep -qP '(?<!/)\bhttps:\s' 2>/dev/null || \
       echo "$connect_src" | grep -qP "connect-src 'self' https:;" 2>/dev/null; then
      do_fail "Caddyfile connect-src is wildcard 'https:' — use domain patterns"
    else
      do_pass "Caddyfile connect-src: not wildcard https:"
    fi

    # Check frame-src isn't bare wildcard https:
    frame_src=$(echo "$csp_line" | grep -oP 'frame-src [^;]+' || true)
    if echo "$frame_src" | grep -qP '(?<!/)\bhttps:\s' 2>/dev/null || \
       echo "$frame_src" | grep -qP "frame-src 'self' https:;" 2>/dev/null; then
      do_fail "Caddyfile frame-src is wildcard 'https:' — use domain patterns"
    else
      do_pass "Caddyfile frame-src: not wildcard https:"
    fi
  else
    do_fail "Caddyfile CSP header not found"
  fi
fi

# ── 4. CSP has auth domain (OIDC requires connect-src + frame-src) ───────
printf "\n${BLUE}── 4. CSP auth domain presence ──${NC}\n"

if [[ -f "$PROD_PY" ]]; then
  csp_connect_block=$(sed -n '/^CSP_CONNECT_SRC/,/^)/p' "$PROD_PY")
  csp_frame_block=$(sed -n '/^CSP_FRAME_SRC/,/^)/p' "$PROD_PY")

  if echo "$csp_connect_block" | grep -qF "_auth_url"; then
    do_pass "CSP_CONNECT_SRC includes auth URL (production.py)"
  else
    do_fail "CSP_CONNECT_SRC missing auth URL — OIDC flows will break"
  fi

  if echo "$csp_frame_block" | grep -qF "_auth_url"; then
    do_pass "CSP_FRAME_SRC includes auth URL (production.py)"
  else
    do_fail "CSP_FRAME_SRC missing auth URL — OIDC iframe will break"
  fi
fi

# ── 5. Nonprod overlay domain consistency ────────────────────────────────
printf "\n${BLUE}── 5. Nonprod overlay domain consistency ──${NC}\n"

check_overlay_domain() {
  local file="$1"
  local env_var="$2"
  local expected_value="$3"
  local label="$4"

  if [[ ! -f "$file" ]]; then
    do_warn "$label: overlay file not found: $file"
    return
  fi

  if grep -qF "$expected_value" "$file"; then
    do_pass "$label: $env_var=$expected_value"
  else
    if grep -qF "$env_var" "$file"; then
      actual=$(grep -A1 "name: $env_var" "$file" | grep 'value:' | head -1 | awk '{print $2}' || true)
      do_fail "$label: $env_var expected=$expected_value actual=$actual"
    else
      do_warn "$label: $env_var not overridden in overlay"
    fi
  fi
}

if [[ -f "$NONPROD_DOMAIN_PATCH" ]]; then
  check_overlay_domain "$NONPROD_DOMAIN_PATCH" "MEREKA_LMS_DOMAIN" "academyv2.mereka.dev" "rke2-nonprod"
  check_overlay_domain "$NONPROD_DOMAIN_PATCH" "MEREKA_AUTH_DOMAIN" "auth0.mereka.dev" "rke2-nonprod"
  check_overlay_domain "$NONPROD_DOMAIN_PATCH" "MEREKA_CREDENTIALS_DOMAIN" "credentials.academyv2.mereka.dev" "rke2-nonprod"

  # Ensure no production domains leaked into nonprod
  if grep -qF "mereka.io" "$NONPROD_DOMAIN_PATCH"; then
    do_fail "rke2-nonprod overlay contains .mereka.io domain — should be .mereka.dev"
  else
    do_pass "rke2-nonprod overlay: no .mereka.io leak"
  fi

  # Verify all deployments that need MEREKA_LMS_DOMAIN have it
  deploy_count=$(grep -c "name: MEREKA_LMS_DOMAIN" "$NONPROD_DOMAIN_PATCH" || true)
  if [[ "$deploy_count" -ge 4 ]]; then
    do_pass "rke2-nonprod: MEREKA_LMS_DOMAIN set in $deploy_count deployments (lms/cms/workers)"
  else
    do_fail "rke2-nonprod: MEREKA_LMS_DOMAIN only in $deploy_count deployments (expected >=4)"
  fi

  # MEREKA_AUTH_DOMAIN must be in all LMS/CMS deployments
  auth_count=$(grep -c "name: MEREKA_AUTH_DOMAIN" "$NONPROD_DOMAIN_PATCH" || true)
  if [[ "$auth_count" -ge 4 ]]; then
    do_pass "rke2-nonprod: MEREKA_AUTH_DOMAIN set in $auth_count deployments"
  else
    do_fail "rke2-nonprod: MEREKA_AUTH_DOMAIN only in $auth_count deployments (expected >=4)"
  fi
else
  do_warn "rke2-nonprod domain overlay not found"
fi

# ── 6. Local overlay domain consistency ──────────────────────────────────
printf "\n${BLUE}── 6. Local overlay domain consistency ──${NC}\n"

if [[ -f "$LOCAL_DOMAIN_PATCH" ]]; then
  check_overlay_domain "$LOCAL_DOMAIN_PATCH" "MEREKA_LMS_DOMAIN" "academyv2.mereka.dev" "local"

  if grep -qF "mereka.io" "$LOCAL_DOMAIN_PATCH"; then
    do_fail "local overlay contains .mereka.io domain — should be .mereka.dev"
  else
    do_pass "local overlay: no .mereka.io leak"
  fi
else
  do_warn "local domain overlay not found"
fi

# ── 7. Production defaults match config.sh ───────────────────────────────
printf "\n${BLUE}── 7. Production defaults match config.sh ──${NC}\n"

if [[ -f "$PROD_PY" ]]; then
  # Check that production.py defaults match config.sh canonical values
  check_py_default() {
    local py_var="$1"
    local expected="$2"
    local label="$3"

    if grep -qF "\"$expected\"" "$PROD_PY"; then
      do_pass "$label: default matches config.sh ($expected)"
    else
      do_fail "$label: default does not match config.sh (expected $expected)"
    fi
  }

  check_py_default "MEREKA_LMS_DOMAIN" "$LMS_DOMAIN" "LMS_DOMAIN"
  check_py_default "MEREKA_AUTH_DOMAIN" "$AUTHENTIK_DOMAIN" "AUTHENTIK_DOMAIN"
  check_py_default "MEREKA_BIJI_DOMAIN" "$BIJI_DOMAIN" "BIJI_DOMAIN"
fi

# ── 8. CSP directives sync between plugin and production.py ──────────────
printf "\n${BLUE}── 8. CSP parity: plugin vs production.py ──${NC}\n"

if [[ -f "$PROD_PY" ]]; then
  # Both must have CSPMiddleware
  if grep -qF "csp.middleware.CSPMiddleware" "$PROD_PY"; then
    do_pass "production.py activates CSPMiddleware"
  else
    do_fail "production.py missing CSPMiddleware activation"
  fi

  # Both must have nonce config
  if grep -qF "CSP_INCLUDE_NONCE_IN" "$PROD_PY"; then
    do_pass "production.py has CSP_INCLUDE_NONCE_IN"
  else
    do_fail "production.py missing CSP_INCLUDE_NONCE_IN"
  fi
fi

plugin_has_csp_mid=false
plugin_has_nonce=false
for pf in "${PLUGIN_FILES[@]}"; do
  if grep -qF "csp.middleware.CSPMiddleware" "$pf" 2>/dev/null; then
    plugin_has_csp_mid=true
  fi
  if grep -qF "CSP_INCLUDE_NONCE_IN" "$pf" 2>/dev/null; then
    plugin_has_nonce=true
  fi
done

if $plugin_has_csp_mid; then
  do_pass "plugin activates CSPMiddleware"
else
  do_fail "plugin missing CSPMiddleware activation"
fi

if $plugin_has_nonce; then
  do_pass "plugin has CSP_INCLUDE_NONCE_IN"
else
  do_fail "plugin missing CSP_INCLUDE_NONCE_IN"
fi

# ── 9. Service domains in ALLOWED_HOSTS ──────────────────────────────────
printf "\n${BLUE}── 9. ALLOWED_HOSTS coverage ──${NC}\n"

if [[ -f "$PROD_PY" ]]; then
  for domain in "$BIJI_DOMAIN" "$SKILLOURFUTURE_DOMAIN"; do
    if grep -qF "$domain" "$PROD_PY"; then
      do_pass "ALLOWED_HOSTS/config includes $domain"
    else
      do_fail "production.py does not reference $domain"
    fi
  done

  # Dev domains should be present for nonprod compatibility
  if grep -qF "MEREKA_DEV_DOMAIN" "$PROD_PY"; then
    do_pass "production.py defines MEREKA_DEV_DOMAIN for nonprod"
  else
    do_fail "production.py missing MEREKA_DEV_DOMAIN"
  fi
fi

# ── 10. Kustomize overlays render cleanly ────────────────────────────────
printf "\n${BLUE}── 10. Kustomize overlay rendering ──${NC}\n"

for overlay in local production rke2-nonprod; do
  overlay_dir="$REPO_ROOT/deploy/k8s/overlays/$overlay"
  if [[ -d "$overlay_dir" ]]; then
    if kubectl kustomize "$overlay_dir" > /dev/null 2>&1; then
      do_pass "kustomize renders: $overlay"
    else
      do_fail "kustomize render failed: $overlay"
    fi
  else
    do_warn "overlay directory not found: $overlay"
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "\n${RED}GATE FAILED${NC} — $FAIL check(s) failed."
  exit 1
fi

echo -e "\n${GREEN}GATE PASSED${NC}"
exit 0
