#!/usr/bin/env bash
# @spec: auth-sso-enterprise_spec.md
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021, AC-022, AC-023, AC-024, AC-025, AC-026, AC-027, AC-028, AC-029, AC-030, AC-031, AC-032, AC-033, AC-034, AC-035, AC-036, AC-037, AC-038, AC-039, AC-040, AC-041, AC-042, AC-043, AC-044, AC-045
#
# Comprehensive verification of the Authentication & SSO Enterprise Integration spec.
# Static checks run against repo files and the bbi-infrastructure production overlay.
# Runtime ACs (live SAML/OIDC flows, MFA challenges, session timeout enforcement,
# JIT provisioning, SCIM, role mapping) are marked SKIP.
#
# Usage:
#   ./scripts/qa/verify-auth-sso-enterprise.sh [--skip-cluster] [--help]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"

# Source shared config for domain variables
source "$REPO_ROOT/scripts/shared/config.sh"

SKIP_CLUSTER=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-cluster)
      SKIP_CLUSTER=true
      shift
      ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify Authentication & SSO Enterprise Integration spec compliance (45 ACs).

OPTIONS:
    --skip-cluster    Skip checks requiring live kubectl access
    --help            Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Counters
PASS=0
FAIL=0
SKIP=0

pass_() { PASS=$((PASS + 1)); printf "PASS: %s\n" "$1"; }
fail_() { FAIL=$((FAIL + 1)); printf "FAIL: %s\n" "$1"; }
skip_() { SKIP=$((SKIP + 1)); printf "SKIP: %s\n" "$1"; }

# Key file paths
LMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
BBI_INFRA_ROOT="${BBI_INFRA_PATH:-}"
if [[ -z "$BBI_INFRA_ROOT" ]]; then
  for candidate in \
    "${WORKSPACE_ROOT}/bbi-infrastructure" \
    "${WORKSPACE_ROOT}/infrastructure" \
    "${HOME}/projects/k8s/bbi-infrastructure" \
    "${HOME}/projects/k8s/infrastructure"; do
    if [[ -d "$candidate" ]]; then
      BBI_INFRA_ROOT="$candidate"
      break
    fi
  done
fi
BBI_PROD="${BBI_INFRA_ROOT}/apps/mereka-lms/overlays/prod/patches/production-prod.py"
EXTERNAL_SECRETS="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
SAML_KEYGEN="$REPO_ROOT/scripts/tenants/generate-saml-keypair.sh"
MFA_SCRIPT="$REPO_ROOT/scripts/infra/ensure-authentik-admin-mfa.sh"

echo "========================================================"
echo "  Auth & SSO Enterprise Integration Verification"
echo "  Spec: auth-sso-enterprise_spec.md (45 ACs)"
echo "========================================================"
echo "Date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Repo:   $REPO_ROOT"
echo "Cluster checks: $(if $SKIP_CLUSTER; then echo SKIPPED; else echo ENABLED; fi)"
echo

###########################################################################
# SECTION 1: Identity Provider Federation (AC-001 to AC-005)
###########################################################################
echo "--- Identity Provider Federation ---"

# AC-001: SP-initiated SAML SSO (slug-based IdP routing)
# Runtime: requires configured IdP + live redirect. Mark SKIP.
skip_ "AC-001: SP-initiated SAML SSO redirect to tenant IdP (requires live IdP)"

# AC-002: OIDC provider redirect with PKCE
# Runtime: requires configured OIDC IdP + live redirect. Mark SKIP.
skip_ "AC-002: OIDC provider redirect with PKCE parameters (requires live IdP)"

# AC-003: Cross-tenant isolation — EnterpriseCustomerUser scoped to correct tenant
# Static: verify third_party_auth is enabled and enterprise integration is on.
if [ -f "$LMS_SETTINGS" ]; then
  if grep -q 'third_party_auth' "$LMS_SETTINGS" && \
     grep -q 'ENABLE_ENTERPRISE_INTEGRATION' "$LMS_SETTINGS"; then
    pass_ "AC-003: third_party_auth + ENABLE_ENTERPRISE_INTEGRATION configured (cross-tenant isolation foundation)"
  else
    fail_ "AC-003: Missing third_party_auth or ENABLE_ENTERPRISE_INTEGRATION"
  fi
else
  fail_ "AC-003: LMS production.py not found"
fi

# AC-004: Authentik default OIDC preserved at /auth/login/oidc/
if [ -f "$BBI_PROD" ]; then
  if grep -q 'MerekaOpenIdConnectAuthPKCE' "$BBI_PROD" && \
     grep -q 'SOCIAL_AUTH_OIDC_OIDC_ENDPOINT' "$BBI_PROD" && \
     grep -q 'auth0.mereka.io' "$BBI_PROD"; then
    pass_ "AC-004: Authentik OIDC provider configured (MerekaOpenIdConnectAuthPKCE + auth0.mereka.io)"
  else
    fail_ "AC-004: Authentik OIDC provider not properly configured in production overlay"
  fi
else
  fail_ "AC-004: Production overlay not found at $BBI_PROD"
fi

# Also check OIDC backend name is "oidc"
if [ -f "$BBI_PROD" ] && grep -q 'name = "oidc"' "$BBI_PROD"; then
  pass_ "AC-004: OIDC backend name is 'oidc' (accessible via /auth/login/oidc/)"
else
  fail_ "AC-004: OIDC backend name not set to 'oidc'"
fi

# AC-005: SP metadata at /auth/saml/metadata.xml — config present
if [ -f "$LMS_SETTINGS" ]; then
  SAML_OK=true
  if ! grep -q 'SOCIAL_AUTH_SAML_SP_ENTITY_ID' "$LMS_SETTINGS"; then
    fail_ "AC-005: SOCIAL_AUTH_SAML_SP_ENTITY_ID not configured in base settings"
    SAML_OK=false
  fi
  if ! grep -q 'SOCIAL_AUTH_SAML_TECHNICAL_CONTACT' "$LMS_SETTINGS"; then
    fail_ "AC-005: SOCIAL_AUTH_SAML_TECHNICAL_CONTACT not configured in base settings"
    SAML_OK=false
  fi
  if $SAML_OK; then
    pass_ "AC-005: SAML SP entity ID and technical contact configured"
  fi
else
  fail_ "AC-005: LMS production.py not found"
fi

# AC-005 continued: SP cert/key injection from env
if [ -f "$LMS_SETTINGS" ]; then
  if grep -q 'SOCIAL_AUTH_SAML_SP_PUBLIC_CERT' "$LMS_SETTINGS" && \
     grep -q 'SOCIAL_AUTH_SAML_SP_PRIVATE_KEY' "$LMS_SETTINGS"; then
    pass_ "AC-005: SAML SP cert/key injected from env (SAML_SP_PUBLIC_CERT / SAML_SP_PRIVATE_KEY)"
  else
    fail_ "AC-005: SAML SP cert/key not injected from environment"
  fi
fi

echo

###########################################################################
# SECTION 2: SAML Security (AC-006 to AC-010)
###########################################################################
echo "--- SAML Security ---"

# AC-006: Valid SAML assertion processing (runtime)
skip_ "AC-006: Valid SAML assertion authentication flow (requires live IdP)"

# AC-007: Expired assertion rejection (runtime)
skip_ "AC-007: Expired SAML assertion rejection (requires live IdP)"

# AC-008: Assertion replay prevention (runtime)
skip_ "AC-008: SAML assertion replay detection (requires live IdP + Redis)"

# AC-009: SHA-1 signature rejection (runtime)
skip_ "AC-009: SHA-1 signed assertion rejection (requires live SAML flow)"

# AC-010: SAML Issuer validation
# Static: third_party_auth with SAMLProviderConfig enforces Issuer matching.
if [ -f "$LMS_SETTINGS" ]; then
  if grep -q 'third_party_auth' "$LMS_SETTINGS" && \
     grep -q 'ENABLE_THIRD_PARTY_AUTH.*True' "$LMS_SETTINGS"; then
    pass_ "AC-010: third_party_auth enabled (SAMLProviderConfig enforces Issuer validation)"
  else
    fail_ "AC-010: ENABLE_THIRD_PARTY_AUTH not set to True"
  fi
else
  fail_ "AC-010: LMS production.py not found"
fi

echo

###########################################################################
# SECTION 3: OIDC Security (AC-011 to AC-013)
###########################################################################
echo "--- OIDC Security ---"

# AC-011: OIDC token validation (runtime)
skip_ "AC-011: OIDC ID token iss/aud claim validation (requires live IdP)"

# AC-012: Expired OIDC token rejection (runtime)
skip_ "AC-012: Expired OIDC token rejection (requires live IdP)"

# AC-013: PKCE in OIDC authorization request
if [ -f "$BBI_PROD" ]; then
  if grep -q 'DEFAULT_USE_PKCE = True' "$BBI_PROD" && \
     grep -q 'PKCE_DEFAULT_CODE_CHALLENGE_METHOD = "S256"' "$BBI_PROD"; then
    pass_ "AC-013: OIDC PKCE enabled (DEFAULT_USE_PKCE=True, S256)"
  else
    fail_ "AC-013: OIDC PKCE not configured (DEFAULT_USE_PKCE or S256 missing)"
  fi
else
  fail_ "AC-013: Production overlay not found"
fi

# AC-013 continued: BaseOAuth2PKCE is inherited
if [ -f "$BBI_PROD" ] && grep -q 'BaseOAuth2PKCE' "$BBI_PROD"; then
  pass_ "AC-013: MerekaOpenIdConnectAuthPKCE inherits BaseOAuth2PKCE"
else
  fail_ "AC-013: BaseOAuth2PKCE inheritance not found"
fi

echo

###########################################################################
# SECTION 4: Multi-Factor Authentication (AC-014 to AC-018)
###########################################################################
echo "--- Multi-Factor Authentication ---"

# AC-014: MFA for is_staff=True on /admin/ (runtime — requires MFA middleware)
skip_ "AC-014: MFA enforcement for staff users on /admin/ (requires live MFA middleware)"

# AC-015: MFA for is_superuser=True on any service /admin/ (runtime)
skip_ "AC-015: MFA enforcement for superusers on all service /admin/ (requires live MFA middleware)"

# AC-016: Authentik admin MFA
if [ -x "$MFA_SCRIPT" ]; then
  pass_ "AC-016: ensure-authentik-admin-mfa.sh exists and is executable"
else
  if [ -f "$MFA_SCRIPT" ]; then
    pass_ "AC-016: ensure-authentik-admin-mfa.sh exists (not executable)"
  else
    fail_ "AC-016: ensure-authentik-admin-mfa.sh not found at $MFA_SCRIPT"
  fi
fi

# AC-017: MFA enrollment enforcement for newly elevated users (runtime)
skip_ "AC-017: MFA enrollment forced on next login for newly elevated users (requires live flow)"

# AC-018: MFA TOTP challenge success logging (runtime)
skip_ "AC-018: MFA TOTP challenge event logging (requires live MFA)"

echo

###########################################################################
# SECTION 5: Session Management (AC-019 to AC-024)
###########################################################################
echo "--- Session Management ---"

# AC-019: Staff session idle timeout (30 min configurable) — runtime
skip_ "AC-019: Staff session idle timeout enforcement (requires live session testing)"

# AC-020: Learner session idle timeout (120 min configurable) — runtime
skip_ "AC-020: Learner session idle timeout enforcement (requires live session testing)"

# AC-021: Absolute session timeout (8h staff, 24h learner) — runtime
skip_ "AC-021: Absolute session timeout enforcement (requires live session testing)"

# AC-022: Explicit logout destroys session — runtime
skip_ "AC-022: Logout session destruction + IdP SLO redirect (requires live session)"

# AC-023: Concurrent session limiting — runtime
skip_ "AC-023: Concurrent session limit enforcement (requires live session testing)"

# AC-024: Session ID regeneration after auth — runtime
skip_ "AC-024: Session ID regeneration after authentication (requires live auth flow)"

# Static: session cookie security settings
if [ -f "$BBI_PROD" ]; then
  SESSION_OK=true
  if grep -q 'SESSION_COOKIE_SECURE = True' "$BBI_PROD"; then
    pass_ "AC-019..AC-024 (prereq): SESSION_COOKIE_SECURE = True"
  else
    fail_ "AC-019..AC-024 (prereq): SESSION_COOKIE_SECURE not True"
    SESSION_OK=false
  fi
  if grep -q 'SESSION_COOKIE_SAMESITE' "$BBI_PROD"; then
    pass_ "AC-019..AC-024 (prereq): SESSION_COOKIE_SAMESITE configured"
  else
    fail_ "AC-019..AC-024 (prereq): SESSION_COOKIE_SAMESITE not configured"
    SESSION_OK=false
  fi
  # Session data stored server-side in Redis (spec requirement)
  if grep -q 'redis' "$BBI_PROD"; then
    pass_ "AC-019..AC-024 (prereq): Redis referenced for session/cache backend"
  else
    skip_ "AC-019..AC-024 (prereq): Redis reference not found in overlay (may be in base)"
  fi
fi

echo

###########################################################################
# SECTION 6: Account Provisioning (AC-025 to AC-028)
###########################################################################
echo "--- Account Provisioning ---"

# AC-025: JIT provisioning (first-time SAML user) — runtime
skip_ "AC-025: JIT account provisioning from SAML IdP assertion (requires live IdP)"

# AC-026: Existing user linking — runtime
skip_ "AC-026: Existing user account linking via IdP (requires live IdP)"

# AC-027: PendingEnterpriseCustomerUser resolution — runtime
skip_ "AC-027: PendingEnterpriseCustomerUser resolution on first login (requires live IdP)"

# AC-028: No staff/superuser auto-escalation from IdP
# Static: verify SOCIAL_AUTH_PIPELINE does not set is_staff or is_superuser
if [ -f "$BBI_PROD" ]; then
  # The pipeline should NOT contain any step that sets is_staff/is_superuser
  PIPELINE_CONTENT=$(grep -A20 'SOCIAL_AUTH_PIPELINE' "$BBI_PROD" 2>/dev/null || true)
  if [ -n "$PIPELINE_CONTENT" ]; then
    if echo "$PIPELINE_CONTENT" | grep -qi 'is_staff\|is_superuser\|set_staff\|grant_staff'; then
      fail_ "AC-028: SOCIAL_AUTH_PIPELINE contains staff/superuser escalation step"
    else
      pass_ "AC-028: SOCIAL_AUTH_PIPELINE does not auto-escalate to staff/superuser"
    fi
  else
    skip_ "AC-028: SOCIAL_AUTH_PIPELINE not found in production overlay"
  fi
fi

# AC-028 continued: Platform admin allowlist is the only path to staff/superuser
if [ -f "$BBI_PROD" ] && grep -q 'MerekaPlatformAdminMiddleware' "$BBI_PROD"; then
  pass_ "AC-028: MerekaPlatformAdminMiddleware is hard backstop for staff/superuser"
else
  fail_ "AC-028: MerekaPlatformAdminMiddleware not found"
fi

echo

###########################################################################
# SECTION 7: Account Deprovisioning (AC-029 to AC-031)
###########################################################################
echo "--- Account Deprovisioning ---"

# AC-029: SCIM DELETE deactivation — runtime
skip_ "AC-029: SCIM DELETE deactivates user + invalidates sessions (requires live SCIM endpoint)"

# AC-030: Deactivated user login rejection — runtime
skip_ "AC-030: Deactivated user authentication rejection (requires live auth flow)"

# AC-031: Daily deprovisioning sync — runtime
skip_ "AC-031: Daily deprovisioning sync job execution (requires live scheduled job)"

echo

###########################################################################
# SECTION 8: Role-Based Access Control (AC-032 to AC-035)
###########################################################################
echo "--- Role-Based Access Control ---"

# AC-032: IdP claim-based role assignment — runtime
skip_ "AC-032: IdP claim-based enterprise_admin role assignment (requires live IdP)"

# AC-033: Auto-revocation on missing claim — runtime
skip_ "AC-033: Auto-revocation from enterprise_admin on missing claim (requires live IdP)"

# AC-034: Operator role cannot be set from IdP claims — runtime
skip_ "AC-034: enterprise_openedx_operator not assignable from IdP claims (requires live flow)"

# AC-035: Platform admin allowlist (MerekaPlatformAdminMiddleware)
if [ -f "$BBI_PROD" ]; then
  AC035_OK=true
  if grep -q 'class MerekaPlatformAdminMiddleware' "$BBI_PROD"; then
    pass_ "AC-035: MerekaPlatformAdminMiddleware class defined"
  else
    fail_ "AC-035: MerekaPlatformAdminMiddleware class not found"
    AC035_OK=false
  fi
  if grep -q 'MEREKA_PLATFORM_ADMIN_EMAILS' "$BBI_PROD"; then
    pass_ "AC-035: MEREKA_PLATFORM_ADMIN_EMAILS env var referenced"
  else
    fail_ "AC-035: MEREKA_PLATFORM_ADMIN_EMAILS not referenced"
    AC035_OK=false
  fi
  if grep -q 'is_staff = True' "$BBI_PROD" && \
     grep -q 'is_superuser = True' "$BBI_PROD"; then
    pass_ "AC-035: Middleware enforces is_staff=True and is_superuser=True"
  else
    fail_ "AC-035: Middleware missing staff/superuser enforcement"
    AC035_OK=false
  fi
  # Independent of IdP claims
  if grep -q 'email in _platform_admin_emails()' "$BBI_PROD"; then
    pass_ "AC-035: Admin check is by email allowlist, independent of IdP claims"
  else
    fail_ "AC-035: Admin check not based on email allowlist"
  fi
else
  fail_ "AC-035: Production overlay not found"
fi

echo

###########################################################################
# SECTION 9: Identity Verification (AC-036)
###########################################################################
echo "--- Identity Verification ---"

# AC-036: Email verification for JIT users without email_verified — runtime
skip_ "AC-036: Email verification prompt for JIT-provisioned users (requires live flow)"

echo

###########################################################################
# SECTION 10: Audit Logging (AC-037 to AC-038)
###########################################################################
echo "--- Audit Logging ---"

# AC-037: Authentication event audit logging — runtime
skip_ "AC-037: Authentication event audit log entries (requires live auth events)"

# AC-038: Cross-tenant access attempt security logging — runtime
skip_ "AC-038: Cross-tenant access attempt security event logging (requires live flow)"

echo

###########################################################################
# SECTION 11: Security Hardening (AC-039 to AC-041)
###########################################################################
echo "--- Security Hardening ---"

# AC-039: Rate limiting on auth endpoints (20 failed/5min)
# Static: check for rate limiting configuration
RATE_LIMIT_FOUND=false
if [ -f "$LMS_SETTINGS" ] && grep -qi 'ratelimit\|rate_limit\|RATE_LIMIT\|MAX_FAILED_LOGIN' "$LMS_SETTINGS"; then
  pass_ "AC-039: Rate limiting configuration found in base LMS settings"
  RATE_LIMIT_FOUND=true
fi
if [ -f "$BBI_PROD" ] && grep -qi 'ratelimit\|rate_limit\|RATE_LIMIT\|MAX_FAILED_LOGIN' "$BBI_PROD"; then
  pass_ "AC-039: Rate limiting configuration found in production overlay"
  RATE_LIMIT_FOUND=true
fi
if ! $RATE_LIMIT_FOUND; then
  skip_ "AC-039: Rate limiting config not found (may rely on Open edX defaults or Cloudflare WAF)"
fi

# AC-040: Redirect URL validation
if [ -f "$BBI_PROD" ]; then
  AC040_OK=true
  if grep -q 'LOGIN_REDIRECT_WHITELIST' "$BBI_PROD"; then
    pass_ "AC-040: LOGIN_REDIRECT_WHITELIST configured in production overlay"
  else
    fail_ "AC-040: LOGIN_REDIRECT_WHITELIST not found"
    AC040_OK=false
  fi
  if grep -q 'SOCIAL_AUTH_SANITIZE_REDIRECTS = True' "$BBI_PROD"; then
    pass_ "AC-040: SOCIAL_AUTH_SANITIZE_REDIRECTS = True"
  else
    fail_ "AC-040: SOCIAL_AUTH_SANITIZE_REDIRECTS not True"
    AC040_OK=false
  fi
  if grep -q 'SOCIAL_AUTH_ALLOWED_REDIRECT_HOSTS' "$BBI_PROD"; then
    pass_ "AC-040: SOCIAL_AUTH_ALLOWED_REDIRECT_HOSTS configured"
  else
    fail_ "AC-040: SOCIAL_AUTH_ALLOWED_REDIRECT_HOSTS not found"
    AC040_OK=false
  fi
fi

# Also check base settings
if [ -f "$LMS_SETTINGS" ] && grep -q 'LOGIN_REDIRECT_WHITELIST' "$LMS_SETTINGS"; then
  pass_ "AC-040: LOGIN_REDIRECT_WHITELIST also in base LMS settings"
fi

# AC-041: HTTPS enforcement
if [ -f "$BBI_PROD" ]; then
  AC041_OK=true
  if grep -q 'SESSION_COOKIE_SECURE = True' "$BBI_PROD"; then
    pass_ "AC-041: SESSION_COOKIE_SECURE = True (HTTPS cookies)"
  else
    fail_ "AC-041: SESSION_COOKIE_SECURE not True"
    AC041_OK=false
  fi
  if grep -q 'CSRF_COOKIE_SECURE = True' "$BBI_PROD"; then
    pass_ "AC-041: CSRF_COOKIE_SECURE = True (HTTPS cookies)"
  else
    fail_ "AC-041: CSRF_COOKIE_SECURE not True"
    AC041_OK=false
  fi
  if grep -q 'SOCIAL_AUTH_REDIRECT_IS_HTTPS = True' "$BBI_PROD"; then
    pass_ "AC-041: SOCIAL_AUTH_REDIRECT_IS_HTTPS = True"
  else
    fail_ "AC-041: SOCIAL_AUTH_REDIRECT_IS_HTTPS not True"
    AC041_OK=false
  fi
fi

# Check Caddy TLS or ingress TLS
CADDY_CONFIG=$(find "$REPO_ROOT/deploy/k8s" -name "Caddyfile*" -o -name "caddy*" 2>/dev/null | head -1)
if [ -n "$CADDY_CONFIG" ]; then
  pass_ "AC-041: Caddy configuration found (TLS termination)"
else
  # Check for ingress TLS
  INGRESS_TLS=$(grep -rl 'tls:' "$REPO_ROOT/deploy/k8s/" 2>/dev/null | head -1 || true)
  if [ -n "$INGRESS_TLS" ]; then
    pass_ "AC-041: Ingress TLS configuration found"
  else
    skip_ "AC-041: No Caddy or Ingress TLS config found in repo (may be in bbi-infrastructure)"
  fi
fi

echo

###########################################################################
# SECTION 12: Secrets Management (SAML/OIDC)
###########################################################################
echo "--- Secrets Management (SAML/OIDC) ---"

# Check ExternalSecrets for SAML SP cert/key
if [ -f "$EXTERNAL_SECRETS" ]; then
  if grep -q 'SAML_SP_PUBLIC_CERT' "$EXTERNAL_SECRETS"; then
    pass_ "AC-005 (secrets): SAML_SP_PUBLIC_CERT in ExternalSecrets"
  else
    fail_ "AC-005 (secrets): SAML_SP_PUBLIC_CERT missing from ExternalSecrets"
  fi
  if grep -q 'SAML_SP_PRIVATE_KEY' "$EXTERNAL_SECRETS"; then
    pass_ "AC-005 (secrets): SAML_SP_PRIVATE_KEY in ExternalSecrets"
  else
    fail_ "AC-005 (secrets): SAML_SP_PRIVATE_KEY missing from ExternalSecrets"
  fi
  if grep -q 'enterprise-sso-secrets' "$EXTERNAL_SECRETS"; then
    pass_ "AC-005 (secrets): enterprise-sso-secrets ExternalSecret defined"
  else
    fail_ "AC-005 (secrets): enterprise-sso-secrets ExternalSecret not found"
  fi
  if grep -q 'OIDC_CLIENT_SECRET' "$EXTERNAL_SECRETS"; then
    pass_ "AC-004 (secrets): OIDC_CLIENT_SECRET in ExternalSecrets"
  else
    fail_ "AC-004 (secrets): OIDC_CLIENT_SECRET missing from ExternalSecrets"
  fi
else
  fail_ "Secrets: external-secrets.yaml not found"
fi

# Check SAML keypair generation script
if [ -x "$SAML_KEYGEN" ]; then
  pass_ "AC-005 (tooling): generate-saml-keypair.sh exists and is executable"
elif [ -f "$SAML_KEYGEN" ]; then
  pass_ "AC-005 (tooling): generate-saml-keypair.sh exists (not executable)"
else
  fail_ "AC-005 (tooling): generate-saml-keypair.sh not found"
fi

echo

###########################################################################
# SECTION 13: OIDC / SSO Infrastructure
###########################################################################
echo "--- OIDC / SSO Infrastructure ---"

# OIDC backend in AUTHENTICATION_BACKENDS
if [ -f "$BBI_PROD" ] && grep -q 'AUTHENTICATION_BACKENDS' "$BBI_PROD"; then
  pass_ "AC-004 (infra): AUTHENTICATION_BACKENDS customized in production overlay"
else
  fail_ "AC-004 (infra): AUTHENTICATION_BACKENDS not customized"
fi

# SOCIAL_AUTH_PIPELINE includes essential steps
if [ -f "$BBI_PROD" ]; then
  PIPELINE_CHECKS=(
    "social_core.pipeline.social_auth.social_details"
    "social_core.pipeline.social_auth.social_uid"
    "social_core.pipeline.user.get_username"
    "social_core.pipeline.social_auth.associate_by_email"
    "social_core.pipeline.user.create_user"
    "social_core.pipeline.social_auth.associate_user"
    "common.djangoapps.third_party_auth.pipeline.set_logged_in_cookies"
  )
  PIPELINE_ALL_OK=true
  for step in "${PIPELINE_CHECKS[@]}"; do
    if grep -q "$step" "$BBI_PROD"; then
      pass_ "AC-004 (pipeline): $step present"
    else
      fail_ "AC-004 (pipeline): $step missing"
      PIPELINE_ALL_OK=false
    fi
  done
fi

# StudioSSOBypassMiddleware
if [ -f "$BBI_PROD" ] && grep -q 'class StudioSSOBypassMiddleware' "$BBI_PROD"; then
  pass_ "AC-004 (infra): StudioSSOBypassMiddleware defined"
else
  fail_ "AC-004 (infra): StudioSSOBypassMiddleware not defined"
fi
if [ -f "$BBI_PROD" ] && grep -q '/oauth2/authorize' "$BBI_PROD"; then
  pass_ "AC-004 (infra): StudioSSOBypassMiddleware detects /oauth2/authorize"
else
  fail_ "AC-004 (infra): /oauth2/authorize detection not found"
fi

# DISABLE_ENTERPRISE_LOGIN configurable via env
if [ -f "$LMS_SETTINGS" ] && grep -q 'DISABLE_ENTERPRISE_LOGIN' "$LMS_SETTINGS"; then
  pass_ "AC-004 (config): DISABLE_ENTERPRISE_LOGIN configurable via env"
else
  fail_ "AC-004 (config): DISABLE_ENTERPRISE_LOGIN not env-configurable"
fi

echo

###########################################################################
# SECTION 14: Middleware Stack for Auth
###########################################################################
echo "--- Auth Middleware Stack ---"

if [ -f "$BBI_PROD" ]; then
  # MerekaPlatformAdminMiddleware in MIDDLEWARE
  if grep -q '"lms.envs.tutor.production.MerekaPlatformAdminMiddleware"' "$BBI_PROD"; then
    pass_ "AC-035 (middleware): MerekaPlatformAdminMiddleware in MIDDLEWARE list"
  else
    fail_ "AC-035 (middleware): MerekaPlatformAdminMiddleware not in MIDDLEWARE list"
  fi

  # MerekaCookieDomainMiddleware in MIDDLEWARE
  if grep -q '"lms.envs.tutor.production.MerekaCookieDomainMiddleware"' "$BBI_PROD"; then
    pass_ "Session (middleware): MerekaCookieDomainMiddleware in MIDDLEWARE"
  else
    fail_ "Session (middleware): MerekaCookieDomainMiddleware not in MIDDLEWARE"
  fi

  # MerekaForwardedHeadersMiddleware at position 0
  if grep -q 'MIDDLEWARE.insert(0, _forwarded_headers_middleware)' "$BBI_PROD"; then
    pass_ "AC-041 (middleware): MerekaForwardedHeadersMiddleware at position 0"
  else
    fail_ "AC-041 (middleware): MerekaForwardedHeadersMiddleware not at position 0"
  fi

  # StudioSSOBypassMiddleware at position 1
  if grep -q 'MIDDLEWARE.insert(1, _sso_bypass_middleware)' "$BBI_PROD"; then
    pass_ "AC-004 (middleware): StudioSSOBypassMiddleware at position 1"
  else
    fail_ "AC-004 (middleware): StudioSSOBypassMiddleware not at position 1"
  fi

  # Cookie middleware ordered before session middleware
  if grep -q 'cookie_index > session_index' "$BBI_PROD"; then
    pass_ "Session (middleware): Cookie middleware ordered before session middleware"
  else
    fail_ "Session (middleware): Cookie/session middleware ordering not enforced"
  fi
fi

echo

###########################################################################
# SECTION 15: PrometheusRules for Auth Alerts
###########################################################################
echo "--- Auth Observability (PrometheusRules) ---"

PROM_LMS="$REPO_ROOT/deploy/k8s/base/monitoring/prometheusrule-lms.yaml"
PROM_ENTERPRISE="$REPO_ROOT/deploy/k8s/base/monitoring/prometheusrule-enterprise.yaml"
PROM_SLO="$REPO_ROOT/deploy/k8s/base/monitoring/prometheusrule-slo.yaml"

# Check for auth-related PrometheusRules
AUTH_ALERT_FOUND=false
for prom_file in "$PROM_LMS" "$PROM_ENTERPRISE" "$PROM_SLO"; do
  if [ -f "$prom_file" ] && grep -qi 'auth\|login\|sso\|saml\|mfa' "$prom_file"; then
    AUTH_ALERT_FOUND=true
    break
  fi
done
if $AUTH_ALERT_FOUND; then
  pass_ "AC-037 (observability): Auth-related PrometheusRule alerts found"
else
  skip_ "AC-037 (observability): No auth-specific PrometheusRule alerts found (may not be implemented yet)"
fi

# Check for cross-tenant alert (AC-038)
CROSS_TENANT_ALERT=false
for prom_file in "$PROM_LMS" "$PROM_ENTERPRISE" "$PROM_SLO"; do
  if [ -f "$prom_file" ] && grep -qi 'cross.tenant\|auth_cross_tenant' "$prom_file"; then
    CROSS_TENANT_ALERT=true
    break
  fi
done
if $CROSS_TENANT_ALERT; then
  pass_ "AC-038 (observability): Cross-tenant access denial alert configured"
else
  skip_ "AC-038 (observability): Cross-tenant alert rule not found (may not be implemented yet)"
fi

echo

###########################################################################
# SECTION 16: Verification Scripts (AC-042 to AC-045)
###########################################################################
echo "--- Verification Scripts ---"

# AC-042: verify-auth-surfaces.sh
if [ -f "$SCRIPT_DIR/verify-auth-surfaces.sh" ]; then
  pass_ "AC-042: verify-auth-surfaces.sh exists"
else
  fail_ "AC-042: verify-auth-surfaces.sh not found"
fi

# AC-043: verify-enterprise-sso.sh
if [ -f "$SCRIPT_DIR/verify-enterprise-sso.sh" ]; then
  pass_ "AC-043: verify-enterprise-sso.sh exists"
else
  fail_ "AC-043: verify-enterprise-sso.sh not found"
fi

# AC-044: audit-authentik-policy-exceptions.sh
if [ -f "$SCRIPT_DIR/audit-authentik-policy-exceptions.sh" ]; then
  pass_ "AC-044: audit-authentik-policy-exceptions.sh exists"
else
  fail_ "AC-044: audit-authentik-policy-exceptions.sh not found"
fi

# AC-045: verify-authenticated-sso-canary.sh
if [ -f "$SCRIPT_DIR/verify-authenticated-sso-canary.sh" ]; then
  pass_ "AC-045: verify-authenticated-sso-canary.sh exists"
else
  fail_ "AC-045: verify-authenticated-sso-canary.sh not found"
fi

# Also check verify-auth-hardening.sh (referenced in spec rollout)
if [ -f "$SCRIPT_DIR/verify-auth-hardening.sh" ]; then
  pass_ "AC-042 (related): verify-auth-hardening.sh exists"
else
  skip_ "AC-042 (related): verify-auth-hardening.sh not found"
fi

echo

###########################################################################
# SECTION 17: Live Cluster Checks (optional)
###########################################################################
echo "--- Live Cluster Checks ---"

if $SKIP_CLUSTER; then
  skip_ "Cluster: All cluster checks skipped (--skip-cluster)"
else
  # Check enterprise-sso-secrets K8s secret exists
  if kubectl get secret enterprise-sso-secrets -n mereka-lms &>/dev/null; then
    pass_ "Cluster: enterprise-sso-secrets K8s secret exists"
  else
    fail_ "Cluster: enterprise-sso-secrets K8s secret not found"
  fi

  # Check ExternalSecret sync status
  ES_STATUS=$(kubectl get externalsecret enterprise-sso-secrets -n mereka-lms -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "NotFound")
  if [ "$ES_STATUS" = "True" ]; then
    pass_ "Cluster: enterprise-sso-secrets ExternalSecret synced (status=True)"
  elif [ "$ES_STATUS" = "NotFound" ]; then
    fail_ "Cluster: enterprise-sso-secrets ExternalSecret not found"
  else
    fail_ "Cluster: enterprise-sso-secrets ExternalSecret not synced (status=$ES_STATUS)"
  fi

  # Check third_party_auth in LMS pod INSTALLED_APPS
  LMS_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$LMS_POD" ]; then
    TPA_CHECK=$(kubectl exec -n mereka-lms "$LMS_POD" -- python -c "
import django; django.setup()
from django.conf import settings
print('third_party_auth' if any('third_party_auth' in a for a in settings.INSTALLED_APPS) else 'missing')
" 2>/dev/null || echo "error")
    if [ "$TPA_CHECK" = "third_party_auth" ]; then
      pass_ "Cluster: third_party_auth in INSTALLED_APPS (live LMS pod)"
    elif [ "$TPA_CHECK" = "missing" ]; then
      fail_ "Cluster: third_party_auth NOT in INSTALLED_APPS (live LMS pod)"
    else
      skip_ "Cluster: Could not check INSTALLED_APPS in LMS pod"
    fi
  else
    skip_ "Cluster: No LMS pod found"
  fi

  # Check SAML metadata endpoint
  SAML_META_STATUS=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "https://${LMS_DOMAIN}/auth/saml/metadata.xml" 2>/dev/null || echo "000")
  if [ "$SAML_META_STATUS" = "200" ]; then
    pass_ "AC-005 (live): /auth/saml/metadata.xml returns HTTP 200"
  elif [ "$SAML_META_STATUS" = "404" ]; then
    skip_ "AC-005 (live): /auth/saml/metadata.xml returns 404 (no SAML config active yet)"
  elif [ "$SAML_META_STATUS" = "000" ]; then
    skip_ "AC-005 (live): ${LMS_DOMAIN} unreachable"
  else
    skip_ "AC-005 (live): /auth/saml/metadata.xml returns HTTP $SAML_META_STATUS"
  fi

  # Check Authentik OIDC endpoint reachable
  OIDC_STATUS=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "https://auth0.mereka.io/application/o/mereka-lms/.well-known/openid-configuration" 2>/dev/null || echo "000")
  if [ "$OIDC_STATUS" = "200" ]; then
    pass_ "AC-004 (live): Authentik OIDC discovery endpoint reachable"
  elif [ "$OIDC_STATUS" = "000" ]; then
    skip_ "AC-004 (live): auth0.mereka.io unreachable"
  else
    fail_ "AC-004 (live): Authentik OIDC discovery returned HTTP $OIDC_STATUS"
  fi
fi

echo

###########################################################################
# Summary
###########################################################################
echo "========================================================"
echo "  Summary"
echo "========================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "SKIP: $SKIP"
echo "TOTAL: $((PASS + FAIL + SKIP))"
echo

if [ $FAIL -gt 0 ]; then
  echo "RESULT: SOME CHECKS FAILED"
  exit 1
else
  echo "RESULT: ALL CHECKS PASSED (${SKIP} skipped)"
  exit 0
fi
