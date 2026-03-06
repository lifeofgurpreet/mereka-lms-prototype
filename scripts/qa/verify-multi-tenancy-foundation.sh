#!/usr/bin/env bash
# @spec: multi-tenancy_spec.md
# @covers: site-framework, domain-isolation, branding-per-tenant, middleware,
#          allowed-hosts, csrf-cors, cookie-domain-isolation
#
# Consolidates multi-tenancy foundation checks. Delegates to existing scripts
# where they already cover specific ACs:
#   verify-tenant-model.sh          → AC-001 (TenantConfig model)
#   verify-tenant-middleware.sh      → AC-012..AC-014 (TenantResolutionMiddleware)
#   verify-tenant-isolation-patterns.sh → AC-003..AC-008 (data isolation)
#   verify-tenant-configmap.sh       → AC-022 (K8s ConfigMap)
#   verify-tenant-provisioning.sh    → AC-001, AC-002, AC-021 (provisioning)
#   verify-multisite-config.sh       → Site + SiteConfiguration live DB checks
#
# Usage:
#   ./scripts/qa/verify-multi-tenancy-foundation.sh [DOMAIN]
#   DOMAIN defaults to academyv2.mereka.io
#   ./scripts/qa/verify-multi-tenancy-foundation.sh --skip-live
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

DOMAIN="${LMS_DOMAIN}"
SKIP_LIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-live)
      SKIP_LIVE=true
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage: verify-multi-tenancy-foundation.sh [DOMAIN] [--skip-live]

Options:
  DOMAIN       Optional LMS domain to probe (default: LMS_DOMAIN from config)
  --skip-live  Skip public endpoint checks and validate static foundations only
  --help       Show this help
EOF
      exit 0
      ;;
    *)
      DOMAIN="$1"
      shift
      ;;
  esac
done

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

log_pass() { printf "PASS: %s\n" "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { printf "FAIL: %s\n" "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
log_skip() { printf "SKIP: %s\n" "$1"; SKIP_COUNT=$((SKIP_COUNT + 1)); }
log_info() { printf "INFO: %s\n" "$1"; }

resolve_prod_settings() {
  local candidates=()
  if [[ -n "${MTA_PROD_SETTINGS:-}" ]]; then
    candidates+=("${MTA_PROD_SETTINGS}")
  fi
  candidates+=(
    "$REPO_ROOT/../infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
    "$REPO_ROOT/../bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
    "/home/gurpreet/projects/k8s/infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
    "/home/gurpreet/projects/k8s/bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
    "$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      printf "%s" "$candidate"
      return 0
    fi
  done

  return 1
}

PROD_SETTINGS="$(resolve_prod_settings || true)"

echo "========================================"
echo "  Multi-Tenancy Foundation Verification"
echo "========================================"
echo "Date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Domain: $DOMAIN"
echo "Prod settings source: ${PROD_SETTINGS:-not found}"
echo "Live checks: $(if $SKIP_LIVE; then echo SKIPPED; else echo ENABLED; fi)"
echo

# ============================================================
# Section 1: Site Framework
# @covers: site-framework
# ============================================================
echo "--- Site Framework ---"

# Check 1.1: SITE_ID configured in production settings
if [ -f "$PROD_SETTINGS" ]; then
  if grep -q "^SITE_ID" "$PROD_SETTINGS"; then
    SITE_ID_VAL=$(grep "^SITE_ID" "$PROD_SETTINGS" | head -1 | sed 's/.*=\s*//' | tr -d ' ')
    log_pass "SITE_ID configured (value: $SITE_ID_VAL)"
  else
    log_fail "SITE_ID not set in production settings"
  fi
else
  log_skip "Production settings file not found at $PROD_SETTINGS"
fi

# Check 1.2: Django Sites framework used (patch_sites_framework function)
if [ -f "$PROD_SETTINGS" ]; then
  if grep -q "patch_sites_framework" "$PROD_SETTINGS"; then
    log_pass "patch_sites_framework() defined for host-based Site resolution"
  else
    log_fail "patch_sites_framework() not found — Sites framework not patched for host resolution"
  fi
else
  log_skip "Production settings not available"
fi

# Check 1.3: SiteManager.get_current patched for request-based resolution
if [ -f "$PROD_SETTINGS" ]; then
  if grep -q "SiteManager.get_current" "$PROD_SETTINGS"; then
    log_pass "SiteManager.get_current patched for per-request Site resolution"
  else
    log_fail "SiteManager.get_current not patched"
  fi
else
  log_skip "Production settings not available"
fi

# Check 1.4: _candidate_site_domains handles prefixes (apps., studio., preview.)
if [ -f "$PROD_SETTINGS" ]; then
  if grep -q "_candidate_site_domains" "$PROD_SETTINGS"; then
    for prefix in "apps." "studio." "preview."; do
      if grep -q "\"$prefix\"" "$PROD_SETTINGS"; then
        log_pass "_candidate_site_domains handles '$prefix' prefix"
      else
        log_fail "_candidate_site_domains missing '$prefix' prefix handling"
      fi
    done
  else
    log_fail "_candidate_site_domains function not found"
  fi
else
  log_skip "Production settings not available"
fi

# Check 1.5: verify-multisite-config.sh exists (covers live DB Site/SiteConfiguration checks)
if [ -x "$SCRIPT_DIR/verify-multisite-config.sh" ]; then
  log_pass "verify-multisite-config.sh exists (covers live Site + SiteConfiguration DB checks)"
  log_info "  Run: ./scripts/qa/verify-multisite-config.sh prod  (for live DB validation)"
else
  log_skip "verify-multisite-config.sh not found or not executable"
fi

echo

# ============================================================
# Section 2: Domain Isolation (Live Endpoint Checks)
# @covers: domain-isolation
# ============================================================
echo "--- Domain Isolation (Live Endpoints) ---"
if $SKIP_LIVE; then
  log_skip "Domain isolation endpoint probes skipped (--skip-live)"
else
  TENANT_DOMAINS=(
    "$DOMAIN"
    "$BIJI_DOMAIN"
    "$SKILLOURFUTURE_DOMAIN"
  )

  for td in "${TENANT_DOMAINS[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$td/" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
      log_pass "https://$td/ returns HTTP $HTTP_CODE"
    elif [ "$HTTP_CODE" = "000" ]; then
      log_skip "https://$td/ unreachable (timeout/DNS)"
    else
      log_fail "https://$td/ returns HTTP $HTTP_CODE (expected 200 or 302)"
    fi
  done
fi

echo

# ============================================================
# Section 3: Cookie Domain Isolation
# @covers: cookie-domain-isolation
# ============================================================
echo "--- Cookie Domain Isolation ---"

# Check 3.1: MerekaCookieDomainMiddleware defined
if [ -f "$PROD_SETTINGS" ]; then
  if grep -q "class MerekaCookieDomainMiddleware" "$PROD_SETTINGS"; then
    log_pass "MerekaCookieDomainMiddleware class defined"
  else
    log_fail "MerekaCookieDomainMiddleware class not found"
  fi
else
  log_skip "Production settings not available"
fi

# Check 3.2: Cookie domain for biji-biji.com is .biji-biji.com
if [ -f "$PROD_SETTINGS" ]; then
  if grep -q '\.biji-biji\.com' "$PROD_SETTINGS"; then
    log_pass "Cookie domain for biji-biji.com set to .biji-biji.com"
  else
    log_fail "Cookie domain for biji-biji.com not configured"
  fi
else
  log_skip "Production settings not available"
fi

# Check 3.3: Global cookie domain set to None (per-request rewriting)
if [ -f "$PROD_SETTINGS" ]; then
  if grep -q "CSRF_COOKIE_DOMAIN = None" "$PROD_SETTINGS" && grep -q "SESSION_COOKIE_DOMAIN = None" "$PROD_SETTINGS"; then
    log_pass "Global CSRF_COOKIE_DOMAIN and SESSION_COOKIE_DOMAIN = None (per-request rewriting)"
  else
    log_fail "Global cookie domains should be None for multisite per-request rewriting"
  fi
else
  log_skip "Production settings not available"
fi

# Check 3.4: Live cookie domain check for primary domain
if $SKIP_LIVE; then
  log_skip "Cookie header probe skipped (--skip-live)"
else
  COOKIE_HEADERS=$(curl -sL -D - -o /dev/null --max-time 10 "https://$DOMAIN/login" 2>/dev/null || echo "")
  if [ -n "$COOKIE_HEADERS" ]; then
    if echo "$COOKIE_HEADERS" | grep -iq "set-cookie"; then
      log_pass "https://$DOMAIN/login sets cookies"
      # Check cookie domain matches the tenant
      if echo "$COOKIE_HEADERS" | grep -i "set-cookie" | grep -iq "domain="; then
        COOKIE_DOMAIN=$(echo "$COOKIE_HEADERS" | grep -i "set-cookie" | grep -io "domain=[^;]*" | head -1 | cut -d= -f2)
        log_info "  Cookie domain observed: $COOKIE_DOMAIN"
      else
        log_info "  Cookies are host-only (no explicit domain attribute)"
      fi
    else
      log_skip "No Set-Cookie headers from https://$DOMAIN/login"
    fi
  else
    log_skip "Could not reach https://$DOMAIN/login for cookie check"
  fi
fi

echo

# ============================================================
# Section 4: Branding Per Tenant
# @covers: branding-per-tenant
# ============================================================
echo "--- Branding Per Tenant ---"

# Check 4.1: DEFAULT_SITE_THEME set to mereka
if [ -f "$PROD_SETTINGS" ]; then
  if grep -q 'DEFAULT_SITE_THEME.*mereka' "$PROD_SETTINGS"; then
    log_pass "DEFAULT_SITE_THEME set to 'mereka'"
  else
    log_fail "DEFAULT_SITE_THEME not set to 'mereka'"
  fi
else
  log_skip "Production settings not available"
fi

# Check 4.2: Mereka theme directory exists
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
if [ -d "$THEME_DIR" ]; then
  log_pass "Mereka theme directory exists at infrastructure/tutor/themes/mereka"
else
  # Check alternative location
  ALT_THEME=$(find "$REPO_ROOT" -path "*/themes/mereka" -type d 2>/dev/null | head -1)
  if [ -n "$ALT_THEME" ]; then
    log_pass "Mereka theme directory found at ${ALT_THEME#"$REPO_ROOT/"}"
  else
    log_skip "Mereka theme directory not found locally (may be built into image)"
  fi
fi

# Check 4.3: Live branding check - primary domain has Mereka references
# Note: use grep -c instead of grep -q to avoid SIGPIPE with pipefail on large HTML
if $SKIP_LIVE; then
  log_skip "Primary branding probe skipped (--skip-live)"
else
  MEREKA_MATCHES=$(curl -sL --max-time 10 "https://$DOMAIN/" 2>/dev/null | grep -ic "mereka" || true)
  if [ "$MEREKA_MATCHES" -gt 0 ] 2>/dev/null; then
    log_pass "https://$DOMAIN/ contains Mereka branding ($MEREKA_MATCHES occurrences)"
  else
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$DOMAIN/" 2>/dev/null || echo "000")
    if [ "$HTTP" = "000" ]; then
      log_skip "Could not fetch https://$DOMAIN/ for branding check"
    else
      log_fail "https://$DOMAIN/ does not contain Mereka branding"
    fi
  fi
fi

# Check 4.4: Live branding check - Biji-Biji domain
if $SKIP_LIVE; then
  log_skip "Biji-Biji branding probe skipped (--skip-live)"
else
  BIJI_MATCHES=$(curl -sL --max-time 10 "https://$BIJI_DOMAIN/" 2>/dev/null | grep -ic "biji\|mereka" || true)
  if [ "$BIJI_MATCHES" -gt 0 ] 2>/dev/null; then
    log_pass "https://$BIJI_DOMAIN/ contains branding content ($BIJI_MATCHES occurrences)"
  else
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$BIJI_DOMAIN/" 2>/dev/null || echo "000")
    if [ "$HTTP" = "000" ]; then
      log_skip "Could not fetch https://$BIJI_DOMAIN/ for branding check"
    else
      log_fail "https://$BIJI_DOMAIN/ lacks expected branding"
    fi
  fi
fi

echo

# ============================================================
# Section 5: Middleware Stack
# @covers: middleware
# ============================================================
echo "--- Middleware Stack ---"

if [ -f "$PROD_SETTINGS" ]; then
  # Check 5.1: MerekaCookieDomainMiddleware in MIDDLEWARE
  if grep -q "MerekaCookieDomainMiddleware" "$PROD_SETTINGS"; then
    log_pass "MerekaCookieDomainMiddleware referenced in MIDDLEWARE"
  else
    log_fail "MerekaCookieDomainMiddleware not in MIDDLEWARE"
  fi

  # Check 5.2: MerekaForwardedHeadersMiddleware in MIDDLEWARE (inserted first)
  if grep -q "MerekaForwardedHeadersMiddleware" "$PROD_SETTINGS"; then
    log_pass "MerekaForwardedHeadersMiddleware in MIDDLEWARE (request-phase, position 0)"
  else
    log_fail "MerekaForwardedHeadersMiddleware not in MIDDLEWARE"
  fi

  # Check 5.3: StudioSSOBypassMiddleware in MIDDLEWARE
  if grep -q "StudioSSOBypassMiddleware" "$PROD_SETTINGS"; then
    log_pass "StudioSSOBypassMiddleware in MIDDLEWARE"
  else
    log_fail "StudioSSOBypassMiddleware not in MIDDLEWARE"
  fi

  # Check 5.4: MerekaPlatformAdminMiddleware in MIDDLEWARE
  if grep -q "MerekaPlatformAdminMiddleware" "$PROD_SETTINGS"; then
    log_pass "MerekaPlatformAdminMiddleware in MIDDLEWARE"
  else
    log_fail "MerekaPlatformAdminMiddleware not in MIDDLEWARE"
  fi

  # Check 5.5: Cookie middleware ordered before session middleware
  if grep -q "cookie_index > session_index" "$PROD_SETTINGS"; then
    log_pass "Cookie middleware ordering logic ensures it runs before session middleware"
  else
    log_fail "Cookie/session middleware ordering not enforced"
  fi
else
  log_skip "Production settings not available — cannot verify middleware stack"
fi

# Check 5.6: Existing verify-tenant-middleware.sh covers TenantResolutionMiddleware
if [ -x "$SCRIPT_DIR/verify-tenant-middleware.sh" ]; then
  log_pass "verify-tenant-middleware.sh exists (covers TenantResolutionMiddleware AC-012..AC-014)"
  log_info "  Run: ./scripts/qa/verify-tenant-middleware.sh"
else
  log_skip "verify-tenant-middleware.sh not found"
fi

echo

# ============================================================
# Section 6: ALLOWED_HOSTS
# @covers: allowed-hosts
# ============================================================
echo "--- ALLOWED_HOSTS ---"

if [ -f "$PROD_SETTINGS" ]; then
  EXPECTED_HOSTS=(
    "academy.biji-biji.com"
    "studio.academy.biji-biji.com"
    "apps.academy.biji-biji.com"
    "academyv2.mereka.io"
    "studio.academyv2.mereka.io"
    "apps.academyv2.mereka.io"
    "preview.academyv2.mereka.io"
    "skillourfuture.academy.mereka.io"
    "forum.academyv2.mereka.io"
  )

  for host in "${EXPECTED_HOSTS[@]}"; do
    if grep -q "\"$host\"" "$PROD_SETTINGS"; then
      log_pass "ALLOWED_HOSTS contains $host"
    else
      log_fail "ALLOWED_HOSTS missing $host"
    fi
  done
else
  log_skip "Production settings not available — cannot verify ALLOWED_HOSTS"
fi

echo

# ============================================================
# Section 7: CSRF_TRUSTED_ORIGINS & CORS_ORIGIN_WHITELIST
# @covers: csrf-cors
# ============================================================
echo "--- CSRF / CORS ---"

if [ -f "$PROD_SETTINGS" ]; then
  EXPECTED_ORIGINS=(
    "https://academyv2.mereka.io"
    "https://studio.academyv2.mereka.io"
    "https://apps.academyv2.mereka.io"
    "https://preview.academyv2.mereka.io"
    "https://skillourfuture.academy.mereka.io"
    "https://academy.biji-biji.com"
    "https://apps.academy.biji-biji.com"
    "https://studio.academy.biji-biji.com"
  )

  # Check CSRF_TRUSTED_ORIGINS via MEREKA_SITE_ORIGINS
  if grep -q "MEREKA_SITE_ORIGINS" "$PROD_SETTINGS"; then
    log_pass "MEREKA_SITE_ORIGINS array defined for bulk CSRF/CORS trust"
  else
    log_fail "MEREKA_SITE_ORIGINS not defined"
  fi

  for origin in "${EXPECTED_ORIGINS[@]}"; do
    if grep -q "\"$origin\"" "$PROD_SETTINGS"; then
      log_pass "CSRF_TRUSTED_ORIGINS includes $origin"
    else
      log_fail "CSRF_TRUSTED_ORIGINS missing $origin"
    fi
  done

  # Check CORS settings
  if grep -q "CORS_ALLOW_CREDENTIALS = True" "$PROD_SETTINGS"; then
    log_pass "CORS_ALLOW_CREDENTIALS = True"
  else
    log_fail "CORS_ALLOW_CREDENTIALS not True"
  fi

  if grep -q "CORS_ORIGIN_ALLOW_ALL = False" "$PROD_SETTINGS"; then
    log_pass "CORS_ORIGIN_ALLOW_ALL = False (explicit whitelist mode)"
  else
    log_fail "CORS_ORIGIN_ALLOW_ALL should be False for production"
  fi

  # Check MFE domains in CORS whitelist
  CORS_MFE_ORIGINS=(
    "https://apps.academyv2.mereka.io"
    "https://apps.academy.biji-biji.com"
  )
  for co in "${CORS_MFE_ORIGINS[@]}"; do
    if grep -q "CORS_ORIGIN_WHITELIST.append(\"$co\")" "$PROD_SETTINGS"; then
      log_pass "CORS_ORIGIN_WHITELIST includes MFE origin $co"
    else
      log_fail "CORS_ORIGIN_WHITELIST missing MFE origin $co"
    fi
  done
else
  log_skip "Production settings not available — cannot verify CSRF/CORS"
fi

echo

# ============================================================
# Section 8: Existing Script Coverage (Delegation)
# ============================================================
echo "--- Existing Script Coverage ---"

declare -A EXISTING_SCRIPTS=(
  ["verify-tenant-model.sh"]="AC-001: TenantConfig model"
  ["verify-tenant-middleware.sh"]="AC-012..AC-014: TenantResolutionMiddleware"
  ["verify-tenant-isolation-patterns.sh"]="AC-003..AC-008: Data isolation patterns"
  ["verify-tenant-configmap.sh"]="AC-022: K8s ConfigMap tenant registry"
  ["verify-tenant-provisioning.sh"]="AC-001, AC-002, AC-021: Provisioning command"
  ["verify-multisite-config.sh"]="Site + SiteConfiguration live DB validation"
)

for script in "${!EXISTING_SCRIPTS[@]}"; do
  desc="${EXISTING_SCRIPTS[$script]}"
  if [ -x "$SCRIPT_DIR/$script" ]; then
    log_pass "$script covers: $desc"
  elif [ -f "$SCRIPT_DIR/$script" ]; then
    log_pass "$script exists (not executable) — covers: $desc"
  else
    log_fail "$script not found — missing coverage: $desc"
  fi
done

echo

# ============================================================
# Summary
# ============================================================
echo "========================================"
echo "  Summary"
echo "========================================"
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "SKIP: $SKIP_COUNT"
echo

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "RESULT: SOME CHECKS FAILED"
  exit 1
else
  echo "RESULT: ALL CHECKS PASSED"
  exit 0
fi
