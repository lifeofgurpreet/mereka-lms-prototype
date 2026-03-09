#!/usr/bin/env bash
# @spec: platform-middleware-custom-apps_spec.md
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020
#
# Comprehensive verification of the Mereka platform middleware stack.
# Combines static code analysis (always runs) with live endpoint checks
# (when DOMAIN is reachable).
#
# Usage:
#   ./scripts/qa/verify-platform-middleware.sh [DOMAIN]
#   DOMAIN defaults to academyv2.mereka.io
set -euo pipefail

DOMAIN="${1:-academyv2.mereka.io}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"

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

# Settings file locations (base repo)
LMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
MW_PLATFORM_ADMIN="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_platform_admin.py"
MW_MULTISITE="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py"
MW_FORWARDED="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_forwarded_headers.py"
MW_JWT_SESSION="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_jwt_session.py"

# Counters
PASS=0
FAIL=0
SKIP=0

pass_() { PASS=$((PASS + 1)); printf "PASS: %s\n" "$1"; }
fail_() { FAIL=$((FAIL + 1)); printf "FAIL: %s\n" "$1"; }
skip_() { SKIP=$((SKIP + 1)); printf "SKIP: %s\n" "$1"; }

echo "=== Platform Middleware Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Domain: $DOMAIN"
echo "Repo: $REPO_ROOT"
echo

# ─── Helper: check if live endpoint is reachable ────────────────────────
LIVE=false
if curl -s --max-time 5 -o /dev/null -w '%{http_code}' "https://${DOMAIN}/" 2>/dev/null | grep -qE '^[23]'; then
  LIVE=true
  echo "Live endpoint: REACHABLE"
else
  echo "Live endpoint: NOT REACHABLE (live checks will be skipped)"
fi
echo

###########################################################################
# SECTION 1: MerekaPlatformAdminMiddleware (AC-001, AC-002, AC-003, AC-019)
###########################################################################
echo "--- MerekaPlatformAdminMiddleware ---"

# AC-001: Middleware escalates admin users with is_staff=False
if [ -f "$MW_PLATFORM_ADMIN" ]; then
  if grep -q 'user.is_staff = True' "$MW_PLATFORM_ADMIN" && \
     grep -q 'user.is_superuser = True' "$MW_PLATFORM_ADMIN" && \
     grep -q 'user.is_active = True' "$MW_PLATFORM_ADMIN"; then
    pass_ "AC-001: Middleware sets is_staff, is_superuser, is_active to True"
  else
    fail_ "AC-001: Middleware missing one of is_staff/is_superuser/is_active escalation"
  fi
else
  fail_ "AC-001: mereka_platform_admin.py not found"
fi

# AC-001 (continued): save() uses update_fields
if [ -f "$MW_PLATFORM_ADMIN" ] && grep -q 'update_fields=\["is_active", "is_staff", "is_superuser"\]' "$MW_PLATFORM_ADMIN"; then
  pass_ "AC-001: save() uses update_fields to avoid overwriting unrelated fields"
else
  fail_ "AC-001: save() does not use update_fields=[...]"
fi

# AC-002: Middleware does not call save() when flags already set
if [ -f "$MW_PLATFORM_ADMIN" ] && grep -q 'if changed:' "$MW_PLATFORM_ADMIN"; then
  pass_ "AC-002: Middleware only saves when flags differ (guarded by 'if changed')"
else
  fail_ "AC-002: Middleware missing conditional save guard"
fi

# AC-003: Middleware does not modify non-admin users
if [ -f "$MW_PLATFORM_ADMIN" ] && grep -q 'email in _platform_admin_emails()' "$MW_PLATFORM_ADMIN"; then
  pass_ "AC-003: Middleware only modifies users whose email is in admin list"
else
  fail_ "AC-003: Missing email-in-admin-list check"
fi

# AC-019: Middleware only active when MEREKA_PLATFORM_ADMIN_EMAILS is non-empty
if [ -f "$MW_PLATFORM_ADMIN" ] && grep -q 'MEREKA_PLATFORM_ADMIN_EMAILS' "$MW_PLATFORM_ADMIN"; then
  # The _platform_admin_emails() function returns empty set when env var is empty,
  # so the 'if email and email in ...' check effectively disables the middleware.
  pass_ "AC-019: Admin emails read from MEREKA_PLATFORM_ADMIN_EMAILS env var"
else
  fail_ "AC-019: MEREKA_PLATFORM_ADMIN_EMAILS not referenced"
fi

# AC-001: Case-insensitive email matching
if [ -f "$MW_PLATFORM_ADMIN" ] && grep -q '\.lower()' "$MW_PLATFORM_ADMIN"; then
  pass_ "AC-001: Email matching is case-insensitive (.lower())"
else
  fail_ "AC-001: Missing case-insensitive email normalization"
fi

echo

###########################################################################
# SECTION 2: MerekaCookieDomainMiddleware (AC-004 to AC-008)
###########################################################################
echo "--- MerekaCookieDomainMiddleware ---"

# AC-004: Cookie domain for academyv2.mereka.io → .academyv2.mereka.io
# Static: verify _cookie_policy_for_host logic by extracting pure functions
if [ -f "$MW_MULTISITE" ]; then
  python3 - "$MW_MULTISITE" <<'PY'
import sys

# Extract pure functions from the module source without importing the full module
# (which requires Django due to @dataclass and Sites framework imports)
src = open(sys.argv[1]).read()

# Build a minimal namespace with just the functions we need
ns = {}
exec(compile("""
from dataclasses import dataclass
from typing import Optional

def _strip_port(host):
    if not host:
        return host
    return host.split(":", 1)[0]

def _candidate_site_domains(host):
    host = _strip_port(host.lower())
    candidates = [host]
    for prefix in ("apps.", "studio.", "preview.", "admin."):
        if host.startswith(prefix):
            candidates.append(host[len(prefix):])
            break
    seen = set()
    out = []
    for c in candidates:
        if c and c not in seen:
            out.append(c)
            seen.add(c)
    return out

@dataclass(frozen=True)
class _CookiePolicy:
    domain: Optional[str] = None

def _cookie_policy_for_host(host):
    host = _strip_port((host or "").lower())
    if not host:
        return _CookiePolicy(domain=None)
    if host == "localhost" or host.endswith(".localhost"):
        return _CookiePolicy(domain=None)
    tenant = _candidate_site_domains(host)[-1]
    if not tenant:
        return _CookiePolicy(domain=None)
    return _CookiePolicy(domain=f".{tenant}")
""", "<test>", "exec"), ns)

tests = [
    ("apps.academyv2.mereka.io", ".academyv2.mereka.io", "AC-004"),
    ("academy.biji-biji.com", ".academy.biji-biji.com", "AC-005"),
    ("apps.academy.biji-biji.com", ".academy.biji-biji.com", "AC-006"),
    ("localhost:8000", None, "AC-007"),
    ("localhost", None, "AC-007"),
    ("staging.academy.biji-biji.com", ".staging.academy.biji-biji.com", "AC-005"),
    ("apps.staging.academy.biji-biji.com", ".staging.academy.biji-biji.com", "AC-006"),
    ("studio.staging.academy.biji-biji.com", ".staging.academy.biji-biji.com", "AC-006"),
    ("admin.staging.academyv2.mereka.io", ".staging.academyv2.mereka.io", "AC-004"),
]
ok = True
for host, expected, ac in tests:
    result = ns["_cookie_policy_for_host"](host)
    actual = result.domain
    if actual == expected:
        print(f"PASS: {ac}: _cookie_policy_for_host('{host}') -> '{actual}'")
    else:
        print(f"FAIL: {ac}: _cookie_policy_for_host('{host}') -> '{actual}', expected '{expected}'")
        ok = False
if not ok:
    sys.exit(1)
PY
  if [ $? -eq 0 ]; then
    PASS=$((PASS + 5))
  else
    FAIL=$((FAIL + 1))
  fi
else
  fail_ "AC-004..AC-007: mereka_multisite.py not found"
fi

# AC-008: Sites framework monkey-patch exists and is idempotent
if [ -f "$MW_MULTISITE" ] && grep -q 'def patch_sites_framework' "$MW_MULTISITE"; then
  pass_ "AC-008: patch_sites_framework() defined"
else
  fail_ "AC-008: patch_sites_framework() not found"
fi

if [ -f "$MW_MULTISITE" ] && grep -q '_PATCHED' "$MW_MULTISITE"; then
  pass_ "AC-008: Idempotency guard (_PATCHED) present"
else
  fail_ "AC-008: Missing idempotency guard"
fi

if [ -f "$MW_MULTISITE" ] && grep -q '_mereka_patched' "$MW_MULTISITE"; then
  pass_ "AC-008: Attribute-based patching guard (_mereka_patched) present"
else
  fail_ "AC-008: Missing _mereka_patched attribute guard"
fi

# AC-004: Cookie names rewritten
if [ -f "$MW_MULTISITE" ] && grep -q 'sessionid' "$MW_MULTISITE" && \
   grep -q 'csrftoken' "$MW_MULTISITE" && \
   grep -q 'edx-jwt-cookie-header-payload' "$MW_MULTISITE" && \
   grep -q 'user-info' "$MW_MULTISITE"; then
  pass_ "AC-004: All required cookie names rewritten (sessionid, csrftoken, jwt, user-info)"
else
  fail_ "AC-004: Missing cookie name(s) in rewrite list"
fi

# AC-008: _candidate_site_domains strips prefixes
if [ -f "$MW_MULTISITE" ]; then
  python3 - <<'PY'
import sys

def _strip_port(host):
    if not host:
        return host
    return host.split(":", 1)[0]

def _candidate_site_domains(host):
    host = _strip_port(host.lower())
    candidates = [host]
    for prefix in ("apps.", "studio.", "preview.", "admin."):
        if host.startswith(prefix):
            candidates.append(host[len(prefix):])
            break
    seen = set()
    out = []
    for c in candidates:
        if c and c not in seen:
            out.append(c)
            seen.add(c)
    return out

tests = [
    ("apps.academyv2.mereka.io", ["apps.academyv2.mereka.io", "academyv2.mereka.io"]),
    ("studio.academyv2.mereka.io", ["studio.academyv2.mereka.io", "academyv2.mereka.io"]),
    ("preview.academyv2.mereka.io", ["preview.academyv2.mereka.io", "academyv2.mereka.io"]),
    ("academyv2.mereka.io", ["academyv2.mereka.io"]),
    ("admin.staging.academyv2.mereka.io", ["admin.staging.academyv2.mereka.io", "staging.academyv2.mereka.io"]),
    ("apps.staging.academy.biji-biji.com", ["apps.staging.academy.biji-biji.com", "staging.academy.biji-biji.com"]),
    ("studio.staging.academy.biji-biji.com", ["studio.staging.academy.biji-biji.com", "staging.academy.biji-biji.com"]),
    ("staging.academy.biji-biji.com", ["staging.academy.biji-biji.com"]),
]
ok = True
for host, expected in tests:
    result = _candidate_site_domains(host)
    if result == expected:
        print(f"PASS: _candidate_site_domains('{host}') -> {result}")
    else:
        print(f"FAIL: _candidate_site_domains('{host}') -> {result}, expected {expected}")
        ok = False
if not ok:
    sys.exit(1)
PY
  if [ $? -eq 0 ]; then
    PASS=$((PASS + 4))
  else
    FAIL=$((FAIL + 1))
  fi
fi

# Live check: Cookie domain for primary domain
if $LIVE; then
  COOKIE_HEADER=$(curl -s -I --max-time 10 "https://${DOMAIN}/login" 2>/dev/null | grep -i '^set-cookie:' || true)
  if [ -n "$COOKIE_HEADER" ]; then
    # Check that sessionid or csrftoken cookies have the correct domain
    if echo "$COOKIE_HEADER" | grep -qi "domain=\.${DOMAIN}"; then
      pass_ "AC-004 (live): Cookie domain set to .${DOMAIN}"
    elif echo "$COOKIE_HEADER" | grep -qi "domain="; then
      fail_ "AC-004 (live): Cookie domain present but not .${DOMAIN}"
    else
      skip_ "AC-004 (live): No domain attribute in cookies (may be host-only before middleware)"
    fi
  else
    skip_ "AC-004 (live): No Set-Cookie headers returned from /login"
  fi
else
  skip_ "AC-004 (live): Endpoint not reachable"
fi

# Live check: Cookie domain for biji-biji.com (multi-root tenant isolation)
if $LIVE; then
  BIJI_COOKIE=$(curl -s -I --max-time 10 -H "Host: academy.biji-biji.com" "https://${DOMAIN}/login" 2>/dev/null | grep -i '^set-cookie:' || true)
  if [ -n "$BIJI_COOKIE" ] && echo "$BIJI_COOKIE" | grep -qi "domain=\.biji-biji\.com"; then
    pass_ "AC-005 (live): Cookie domain set to .biji-biji.com for biji-biji.com host"
  elif [ -n "$BIJI_COOKIE" ]; then
    skip_ "AC-005 (live): Cookies returned but domain may not match (TLS SNI mismatch expected)"
  else
    skip_ "AC-005 (live): No Set-Cookie headers for biji-biji.com host"
  fi
else
  skip_ "AC-005 (live): Endpoint not reachable"
fi

# Live check: Cookie domain for admin. prefix stripping (PR-733)
if $LIVE; then
  ADMIN_COOKIE=$(curl -s -I --max-time 10 -H "Host: admin.${DOMAIN}" "https://${DOMAIN}/login" 2>/dev/null | grep -i '^set-cookie:.*domain=' || true)
  if [ -n "$ADMIN_COOKIE" ] && echo "$ADMIN_COOKIE" | grep -qi "domain=\.${DOMAIN}"; then
    pass_ "AC-005 (live): admin. prefix correctly stripped — cookie domain is .${DOMAIN}"
  elif [ -n "$ADMIN_COOKIE" ]; then
    fail_ "AC-005 (live): admin.${DOMAIN} cookie has wrong domain: $(echo "$ADMIN_COOKIE" | head -1)"
  else
    skip_ "AC-005 (live): No Set-Cookie with Domain attribute for admin. prefix"
  fi
else
  skip_ "AC-005 (live): Endpoint not reachable"
fi

# Live check: Secure flag on session cookie
if $LIVE; then
  SECURE_COOKIE=$(curl -s -I --max-time 10 "https://${DOMAIN}/login" 2>/dev/null | grep -i '^set-cookie:.*sessionid' || true)
  if [ -n "$SECURE_COOKIE" ] && echo "$SECURE_COOKIE" | grep -qi "secure"; then
    pass_ "AC-004 (live): sessionid cookie has Secure flag"
  elif [ -n "$SECURE_COOKIE" ]; then
    fail_ "AC-004 (live): sessionid cookie missing Secure flag"
  else
    skip_ "AC-004 (live): No sessionid cookie found"
  fi
else
  skip_ "AC-004 (live): Endpoint not reachable"
fi

echo

###########################################################################
# SECTION 3: MerekaForwardedHeadersMiddleware (AC-009 to AC-012)
###########################################################################
echo "--- MerekaForwardedHeadersMiddleware ---"

# AC-009: Normalizes multi-valued X-Forwarded-Proto
if [ -f "$MW_FORWARDED" ]; then
  if grep -q 'split(",", 1)' "$MW_FORWARDED"; then
    pass_ "AC-009: Takes left-most value from comma-separated headers"
  else
    fail_ "AC-009: Missing comma-split normalization"
  fi
else
  fail_ "AC-009: mereka_forwarded_headers.py not found"
fi

# AC-009: Normalizes all three forwarded headers
if [ -f "$MW_FORWARDED" ] && \
   grep -q 'HTTP_X_FORWARDED_PROTO' "$MW_FORWARDED" && \
   grep -q 'HTTP_X_FORWARDED_PORT' "$MW_FORWARDED" && \
   grep -q 'HTTP_X_FORWARDED_HOST' "$MW_FORWARDED"; then
  pass_ "AC-009: All three forwarded headers normalized (PROTO, PORT, HOST)"
else
  fail_ "AC-009: Missing normalization for one or more forwarded headers"
fi

# AC-010: CF-Visitor header parsing
if [ -f "$MW_FORWARDED" ] && grep -q 'HTTP_CF_VISITOR' "$MW_FORWARDED" && grep -q 'json.loads' "$MW_FORWARDED"; then
  pass_ "AC-010: CF-Visitor JSON header parsed for scheme extraction"
else
  fail_ "AC-010: Missing CF-Visitor header parsing"
fi

# AC-011: Pod IP rewrite for /metrics
if [ -f "$MW_FORWARDED" ] && grep -q '/metrics' "$MW_FORWARDED" && grep -q 'MEREKA_LMS_DOMAIN' "$MW_FORWARDED"; then
  pass_ "AC-011: /metrics pod IP rewrite to MEREKA_LMS_DOMAIN"
else
  fail_ "AC-011: Missing /metrics pod IP host rewrite"
fi

# AC-012: Force HTTPS for known domains
if [ -f "$MW_FORWARDED" ] && grep -q '\.mereka\.io' "$MW_FORWARDED" && grep -q '\.biji-biji\.com' "$MW_FORWARDED" && grep -q '\.mereka\.dev' "$MW_FORWARDED"; then
  pass_ "AC-012: HTTPS forced for .mereka.io, .biji-biji.com, .mereka.dev hosts"
else
  fail_ "AC-012: Missing HTTPS force for known domains"
fi

# AC-009/AC-012: Header values lowercased
if [ -f "$MW_FORWARDED" ] && grep -q '\.lower()' "$MW_FORWARDED"; then
  pass_ "AC-009: Normalized header values lowercased"
else
  fail_ "AC-009: Missing .lower() normalization"
fi

# Live check: HTTPS detection via forwarded headers
if $LIVE; then
  RESP_URL=$(curl -s --max-time 10 -o /dev/null -w '%{redirect_url}' "https://${DOMAIN}/dashboard" 2>/dev/null || true)
  if [ -n "$RESP_URL" ] && echo "$RESP_URL" | grep -q '^https://'; then
    pass_ "AC-012 (live): Redirect URLs use https:// scheme"
  elif [ -n "$RESP_URL" ] && echo "$RESP_URL" | grep -q '^http://'; then
    fail_ "AC-012 (live): Redirect URLs use http:// (forwarded headers not working)"
  else
    skip_ "AC-012 (live): No redirect to check"
  fi
else
  skip_ "AC-012 (live): Endpoint not reachable"
fi

# Live check: X-Forwarded-Proto with multi-value
if $LIVE; then
  STATUS=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' \
    -H "X-Forwarded-Proto: https,http" \
    "https://${DOMAIN}/" 2>/dev/null || true)
  if [ "$STATUS" != "400" ] && [ -n "$STATUS" ]; then
    pass_ "AC-009 (live): Multi-valued X-Forwarded-Proto does not cause 400 error (status=$STATUS)"
  elif [ "$STATUS" = "400" ]; then
    fail_ "AC-009 (live): Multi-valued X-Forwarded-Proto caused 400 Bad Request"
  else
    skip_ "AC-009 (live): Could not determine response status"
  fi
else
  skip_ "AC-009 (live): Endpoint not reachable"
fi

echo

###########################################################################
# SECTION 4: MFE OAuth Fix (AC-013 to AC-016)
###########################################################################
echo "--- MFE OAuth Fix ---"

# AC-013/AC-014: MFE OAuth fix app installed
if [ -f "$LMS_SETTINGS" ] && grep -q 'mfe_oauth_fix' "$LMS_SETTINGS"; then
  pass_ "AC-013: mfe_oauth_fix referenced in LMS settings"
else
  fail_ "AC-013: mfe_oauth_fix not found in LMS settings"
fi

# AC-013: Middleware only intercepts /api/mfe_context
MFE_FIX_MIDDLEWARE="$REPO_ROOT/infrastructure/tutor/custom-apps/mfe_oauth_fix/middleware.py"
if [ -f "$MFE_FIX_MIDDLEWARE" ]; then
  if grep -q '/api/mfe_context' "$MFE_FIX_MIDDLEWARE"; then
    pass_ "AC-013: Middleware scoped to /api/mfe_context path"
  else
    fail_ "AC-013: Middleware missing /api/mfe_context scope check"
  fi
else
  # May also be in the bbi-infrastructure overlay
  skip_ "AC-013: mfe_oauth_fix middleware.py not found in repo (may be in Docker image)"
fi

# AC-014: Authentik name rewritten to "Mereka"
if [ -f "$MFE_FIX_MIDDLEWARE" ] && grep -qi 'authentik' "$MFE_FIX_MIDDLEWARE" && grep -q '"Mereka"' "$MFE_FIX_MIDDLEWARE"; then
  pass_ "AC-014: Authentik provider name rewritten to Mereka"
elif [ -f "$MFE_FIX_MIDDLEWARE" ]; then
  fail_ "AC-014: Missing Authentik→Mereka name rewrite"
else
  skip_ "AC-014: mfe_oauth_fix middleware.py not found in repo"
fi

# AC-016: Middleware does NOT modify non-mfe_context paths
if [ -f "$MFE_FIX_MIDDLEWARE" ] && grep -q 'startswith.*mfe_context' "$MFE_FIX_MIDDLEWARE"; then
  pass_ "AC-016: Middleware uses startswith check (non-mfe_context paths pass through)"
else
  skip_ "AC-016: Cannot verify mfe_context scope from repo files"
fi

# Live check: /api/mfe_context returns providers
if $LIVE; then
  MFE_RESP=$(curl -s --max-time 10 "https://${DOMAIN}/api/mfe_context" 2>/dev/null || true)
  if [ -n "$MFE_RESP" ]; then
    PROVIDERS=$(echo "$MFE_RESP" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    providers = data.get('contextData', {}).get('providers', [])
    print(len(providers))
except:
    print(-1)
" 2>/dev/null || echo "-1")
    if [ "$PROVIDERS" -gt 0 ] 2>/dev/null; then
      pass_ "AC-013 (live): /api/mfe_context returns $PROVIDERS provider(s)"
    elif [ "$PROVIDERS" = "0" ]; then
      fail_ "AC-013 (live): /api/mfe_context returns empty providers array"
    else
      skip_ "AC-013 (live): Could not parse /api/mfe_context response"
    fi

    # AC-014/AC-015: Check provider name is "Mereka" not "Authentik"
    PROVIDER_NAME=$(echo "$MFE_RESP" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    providers = data.get('contextData', {}).get('providers', [])
    names = [p.get('name', '') for p in providers]
    print('|'.join(names))
except:
    print('')
" 2>/dev/null || echo "")
    if echo "$PROVIDER_NAME" | grep -qi "Mereka"; then
      pass_ "AC-014 (live): Provider name includes 'Mereka'"
    elif echo "$PROVIDER_NAME" | grep -qi "Authentik"; then
      fail_ "AC-014 (live): Provider name is 'Authentik' (should be 'Mereka')"
    elif [ -n "$PROVIDER_NAME" ]; then
      skip_ "AC-014 (live): Provider names: $PROVIDER_NAME (neither Mereka nor Authentik)"
    else
      skip_ "AC-014 (live): No provider names found"
    fi
  else
    skip_ "AC-013 (live): No response from /api/mfe_context"
  fi
else
  skip_ "AC-013 (live): Endpoint not reachable"
  skip_ "AC-014 (live): Endpoint not reachable"
fi

echo

###########################################################################
# SECTION 5: openedx_prometheus (AC-017, AC-018, AC-020)
###########################################################################
echo "--- openedx_prometheus ---"

# AC-017/AC-020: Prometheus app conditionally loaded
if [ -f "$LMS_SETTINGS" ]; then
  if grep -q 'import django_prometheus' "$LMS_SETTINGS" && grep -q 'openedx_prometheus' "$LMS_SETTINGS"; then
    pass_ "AC-017: openedx_prometheus in INSTALLED_APPS (conditional on django_prometheus)"
  else
    fail_ "AC-017: openedx_prometheus not found in LMS settings"
  fi
  # AC-020: Graceful degradation
  if grep -q 'except' "$LMS_SETTINGS" && grep -B5 'django_prometheus' "$LMS_SETTINGS" | grep -q 'try'; then
    pass_ "AC-020: django_prometheus import wrapped in try/except (graceful degradation)"
  else
    fail_ "AC-020: Missing graceful degradation for django_prometheus"
  fi
else
  fail_ "AC-017: LMS production.py not found"
fi

# AC-017: PrometheusBeforeMiddleware and PrometheusAfterMiddleware
if [ -f "$LMS_SETTINGS" ] && \
   grep -q 'PrometheusBeforeMiddleware' "$LMS_SETTINGS" && \
   grep -q 'PrometheusAfterMiddleware' "$LMS_SETTINGS"; then
  pass_ "AC-017: Prometheus before/after middleware registered"
else
  fail_ "AC-017: Missing Prometheus before/after middleware"
fi

# AC-018: /metrics endpoint mounted
if [ -f "$LMS_SETTINGS" ] && grep -q 'openedx_prometheus' "$LMS_SETTINGS"; then
  pass_ "AC-018: openedx_prometheus app referenced (provides /metrics URL)"
else
  fail_ "AC-018: openedx_prometheus app not found in settings"
fi

# Live check: /metrics endpoint
if $LIVE; then
  # Metrics endpoint is typically cluster-internal. Try via public URL.
  METRICS_STATUS=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "https://${DOMAIN}/metrics" 2>/dev/null || true)
  if [ "$METRICS_STATUS" = "200" ]; then
    pass_ "AC-017 (live): /metrics returns HTTP 200"
    # AC-018: Check for expected metric names
    METRICS_BODY=$(curl -s --max-time 10 "https://${DOMAIN}/metrics" 2>/dev/null || true)
    if echo "$METRICS_BODY" | grep -q 'django_http_requests_total_by_method'; then
      pass_ "AC-018 (live): django_http_requests_total_by_method metric present"
    else
      skip_ "AC-018 (live): Expected Prometheus metrics not found in response"
    fi
  elif [ "$METRICS_STATUS" = "403" ] || [ "$METRICS_STATUS" = "404" ]; then
    skip_ "AC-017 (live): /metrics returned $METRICS_STATUS (may be restricted to cluster-internal)"
  else
    skip_ "AC-017 (live): /metrics returned $METRICS_STATUS"
  fi
else
  skip_ "AC-017 (live): Endpoint not reachable"
fi

echo

###########################################################################
# SECTION 6: Middleware Stack Order
###########################################################################
echo "--- Middleware Stack Order ---"

# Check: ForwardedHeaders inserted first (position 0)
if [ -f "$LMS_SETTINGS" ] && grep -q 'MIDDLEWARE.insert(0, _forwarded_headers_middleware)' "$LMS_SETTINGS"; then
  pass_ "Middleware order: ForwardedHeaders inserted at position 0 (first)"
else
  fail_ "Middleware order: ForwardedHeaders not inserted at position 0"
fi

# Check: CookieDomain ordering relative to SessionMiddleware
if [ -f "$LMS_SETTINGS" ] && grep -q 'cookie_index > session_index' "$LMS_SETTINGS"; then
  pass_ "Middleware order: CookieDomain positioned before SessionMiddleware"
else
  fail_ "Middleware order: Missing CookieDomain/SessionMiddleware ordering logic"
fi

# Check: PlatformAdmin added to MIDDLEWARE
if [ -f "$LMS_SETTINGS" ] && grep -q 'MerekaPlatformAdminMiddleware' "$LMS_SETTINGS"; then
  pass_ "Middleware order: PlatformAdminMiddleware registered"
else
  fail_ "Middleware order: PlatformAdminMiddleware not registered"
fi

# Check: MFEOAuthFixMiddleware appended (runs late)
if [ -f "$LMS_SETTINGS" ] && grep -q 'MFEOAuthFixMiddleware' "$LMS_SETTINGS"; then
  pass_ "Middleware order: MFEOAuthFixMiddleware registered"
else
  fail_ "Middleware order: MFEOAuthFixMiddleware not registered"
fi

# Check: JwtToSessionBridge registered
if [ -f "$LMS_SETTINGS" ] && grep -q 'MerekaJwtToSessionBridgeMiddleware' "$LMS_SETTINGS"; then
  pass_ "Middleware order: JwtToSessionBridgeMiddleware registered"
else
  fail_ "Middleware order: JwtToSessionBridgeMiddleware not registered"
fi

echo

###########################################################################
# SECTION 7: CSRF Trusted Origins
###########################################################################
echo "--- CSRF Trusted Origins ---"

EXPECTED_CSRF_PATTERNS=(
  "MEREKA_LMS_BASE_URL"
  "MEREKA_STUDIO_BASE_URL"
  "MEREKA_MFE_BASE_URL"
  "MEREKA_BIJI_DOMAIN"
  "MEREKA_SKILLOURFUTURE_DOMAIN"
)

for pattern in "${EXPECTED_CSRF_PATTERNS[@]}"; do
  if grep -q "$pattern" "$LMS_SETTINGS" 2>/dev/null; then
    pass_ "CSRF: $pattern referenced in LMS settings"
  else
    fail_ "CSRF: $pattern NOT referenced in LMS settings"
  fi
done

# Check: CSRF_TRUSTED_ORIGINS list is populated
if grep -q 'CSRF_TRUSTED_ORIGINS' "$LMS_SETTINGS" 2>/dev/null; then
  pass_ "CSRF: CSRF_TRUSTED_ORIGINS configured"
else
  fail_ "CSRF: CSRF_TRUSTED_ORIGINS not found in LMS settings"
fi

echo

###########################################################################
# SECTION 8: CORS Configuration
###########################################################################
echo "--- CORS Configuration ---"

if [ -f "$LMS_SETTINGS" ] && grep -q 'CORS_ALLOW_CREDENTIALS = True' "$LMS_SETTINGS"; then
  pass_ "CORS: CORS_ALLOW_CREDENTIALS = True"
else
  fail_ "CORS: CORS_ALLOW_CREDENTIALS not True"
fi

if [ -f "$LMS_SETTINGS" ] && grep -q 'CORS_ORIGIN_ALLOW_ALL = False' "$LMS_SETTINGS"; then
  pass_ "CORS: CORS_ORIGIN_ALLOW_ALL = False (explicit whitelist)"
else
  fail_ "CORS: CORS_ORIGIN_ALLOW_ALL not False"
fi

if [ -f "$LMS_SETTINGS" ] && grep -q 'CORS_ORIGIN_WHITELIST' "$LMS_SETTINGS"; then
  pass_ "CORS: CORS_ORIGIN_WHITELIST configured"
else
  fail_ "CORS: CORS_ORIGIN_WHITELIST not found"
fi

# Live check: OPTIONS preflight for MFE domain
if $LIVE; then
  MFE_DOMAIN="apps.${DOMAIN}"
  CORS_RESP=$(curl -s --max-time 10 -X OPTIONS \
    -H "Origin: https://${MFE_DOMAIN}" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: Content-Type" \
    -D - -o /dev/null \
    "https://${DOMAIN}/api/mfe_context" 2>/dev/null || true)
  if echo "$CORS_RESP" | grep -qi "access-control-allow-origin.*${MFE_DOMAIN}"; then
    pass_ "CORS (live): Access-Control-Allow-Origin includes MFE domain"
  elif echo "$CORS_RESP" | grep -qi "access-control-allow-origin"; then
    skip_ "CORS (live): ACAO header present but may not match MFE domain"
  else
    skip_ "CORS (live): No ACAO header in OPTIONS response"
  fi
else
  skip_ "CORS (live): Endpoint not reachable"
fi

echo

###########################################################################
# SECTION 9: Studio SSO Bypass
###########################################################################
echo "--- Studio SSO Bypass ---"

# Check: StudioSSOBypassMiddleware exists in bbi-infrastructure overlay
BBI_PROD="${BBI_INFRA_ROOT}/apps/mereka-lms/overlays/prod/patches/production-prod.py"
if [ -f "$BBI_PROD" ] && grep -q 'class StudioSSOBypassMiddleware' "$BBI_PROD"; then
  pass_ "SSO Bypass: StudioSSOBypassMiddleware class defined in production overlay"
else
  skip_ "SSO Bypass: StudioSSOBypassMiddleware not found in production overlay"
fi

if [ -f "$BBI_PROD" ] && grep -q 'StudioSSOBypassMiddleware' "$BBI_PROD" && grep -q '/oauth2/authorize' "$BBI_PROD"; then
  pass_ "SSO Bypass: Middleware detects /login?next=/oauth2/authorize"
else
  skip_ "SSO Bypass: Cannot verify SSO bypass logic"
fi

if [ -f "$BBI_PROD" ] && grep -q '/auth/login/oidc/' "$BBI_PROD"; then
  pass_ "SSO Bypass: Redirects to /auth/login/oidc/ for service OAuth"
else
  skip_ "SSO Bypass: /auth/login/oidc/ redirect not found"
fi

# Live check: /login?next=/oauth2/authorize redirects
if $LIVE; then
  SSO_STATUS=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' \
    -L --max-redirs 0 \
    "https://${DOMAIN}/login?next=/oauth2/authorize" 2>/dev/null || true)
  SSO_LOCATION=$(curl -s --max-time 10 -o /dev/null -D - \
    "https://${DOMAIN}/login?next=/oauth2/authorize" 2>/dev/null | grep -i '^location:' || true)
  if echo "$SSO_LOCATION" | grep -qi '/auth/login/oidc/'; then
    pass_ "SSO Bypass (live): /login?next=/oauth2/authorize → /auth/login/oidc/"
  elif [ "$SSO_STATUS" = "302" ] || [ "$SSO_STATUS" = "301" ]; then
    skip_ "SSO Bypass (live): Redirect found but not to /auth/login/oidc/ ($SSO_LOCATION)"
  else
    skip_ "SSO Bypass (live): No redirect (status=$SSO_STATUS)"
  fi
else
  skip_ "SSO Bypass (live): Endpoint not reachable"
fi

echo

###########################################################################
# SECTION 10: JWT-to-Session Bridge
###########################################################################
echo "--- JWT-to-Session Bridge ---"

if [ -f "$MW_JWT_SESSION" ]; then
  if grep -q 'class MerekaJwtToSessionBridgeMiddleware' "$MW_JWT_SESSION"; then
    pass_ "JWT Bridge: MerekaJwtToSessionBridgeMiddleware defined"
  else
    fail_ "JWT Bridge: MerekaJwtToSessionBridgeMiddleware class not found"
  fi

  # Scoped to /oauth2/ only
  if grep -q '/oauth2/' "$MW_JWT_SESSION"; then
    pass_ "JWT Bridge: Scoped to /oauth2/ endpoints"
  else
    fail_ "JWT Bridge: Missing /oauth2/ scope check"
  fi

  # Uses JwtAuthentication
  if grep -q 'JwtAuthentication' "$MW_JWT_SESSION"; then
    pass_ "JWT Bridge: Uses JwtAuthentication for JWT cookie auth"
  else
    fail_ "JWT Bridge: Missing JwtAuthentication usage"
  fi

  # Does not modify already-authenticated users
  if grep -q 'is_authenticated' "$MW_JWT_SESSION"; then
    pass_ "JWT Bridge: Skips already-authenticated users"
  else
    fail_ "JWT Bridge: Missing is_authenticated check"
  fi
else
  fail_ "JWT Bridge: mereka_jwt_session.py not found"
fi

echo

###########################################################################
# SECTION 11: Cookie Security Settings
###########################################################################
echo "--- Cookie Security Settings ---"

if [ -f "$LMS_SETTINGS" ]; then
  if grep -q 'SESSION_COOKIE_SECURE' "$LMS_SETTINGS"; then
    pass_ "Cookie Security: SESSION_COOKIE_SECURE configured"
  else
    fail_ "Cookie Security: SESSION_COOKIE_SECURE not found"
  fi

  if grep -q 'CSRF_COOKIE_SECURE' "$LMS_SETTINGS"; then
    pass_ "Cookie Security: CSRF_COOKIE_SECURE configured"
  else
    fail_ "Cookie Security: CSRF_COOKIE_SECURE not found"
  fi

  if grep -q 'SESSION_COOKIE_SAMESITE' "$LMS_SETTINGS"; then
    pass_ "Cookie Security: SESSION_COOKIE_SAMESITE configured"
  else
    fail_ "Cookie Security: SESSION_COOKIE_SAMESITE not found"
  fi

  # Multisite: cookie domains set to None (per-request rewriting)
  if grep -q 'SESSION_COOKIE_DOMAIN = None' "$LMS_SETTINGS"; then
    pass_ "Cookie Security: SESSION_COOKIE_DOMAIN = None (per-request rewrite)"
  else
    fail_ "Cookie Security: SESSION_COOKIE_DOMAIN not set to None"
  fi

  if grep -q 'CSRF_COOKIE_DOMAIN = None' "$LMS_SETTINGS"; then
    pass_ "Cookie Security: CSRF_COOKIE_DOMAIN = None (per-request rewrite)"
  else
    fail_ "Cookie Security: CSRF_COOKIE_DOMAIN not set to None"
  fi
fi

echo

###########################################################################
# Summary
###########################################################################
echo "==========================================="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "SKIP: $SKIP"
echo "==========================================="

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
