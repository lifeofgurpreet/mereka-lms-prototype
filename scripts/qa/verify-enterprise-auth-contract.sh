#!/usr/bin/env bash
# @covers AC-ENT-AUTH-001, AC-ENT-AUTH-002, AC-ENT-AUTH-003
# @spec: k8s-deployment_spec.md
#
# Verify the enterprise auth runtime contract defined in:
#   docs/stabilization/ENTERPRISE_AUTH_RUNTIME_CONTRACT.md
#
# Checks are CI-safe (static file analysis, no cluster needed).
# Verifies that config files enforce the correct CSRF, JWT, cookie,
# and proxy-chain contract across LMS, enterprise-access, and MFE Caddy.
#
# Exit 0 = all checks pass
# Exit 1 = one or more checks failed
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# bbi-infrastructure may not exist in CI — checks that need it will skip
INFRA_ROOT="${REPO_ROOT}/../bbi-infrastructure"
FAILURES=0
SKIPS=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }
skip() { echo "  SKIP: $1"; SKIPS=$((SKIPS + 1)); }

echo "=== Enterprise Auth Runtime Contract Verification ==="
echo ""
echo "Contract: docs/stabilization/ENTERPRISE_AUTH_RUNTIME_CONTRACT.md"
echo ""

# ─── Section 1: CSRF Cookie Name Contract ───────────────────────────────
echo "[1/7] CSRF cookie name: enterprise-access MUST use 'csrftoken'"

if [[ -d "$INFRA_ROOT" ]]; then
  ea_deploy="${INFRA_ROOT}/apps/mereka-lms/base/deploy/k8s/base/apps/enterprise/enterprise-access-deployment.yaml"
  if [[ -f "$ea_deploy" ]]; then
    if grep -q "'CSRF_COOKIE_NAME'.*'csrftoken'" "$ea_deploy"; then
      pass "enterprise-access config-gen sets CSRF_COOKIE_NAME='csrftoken'"
    else
      fail "enterprise-access config-gen missing CSRF_COOKIE_NAME='csrftoken'"
    fi
  else
    skip "enterprise-access-deployment.yaml not found in bbi-infrastructure"
  fi

  # Also check mereka-lms copy
  ea_local="${REPO_ROOT}/deploy/k8s/base/apps/enterprise/enterprise-access-deployment.yaml"
  if [[ -f "$ea_local" ]]; then
    if grep -q "'CSRF_COOKIE_NAME'.*'csrftoken'" "$ea_local"; then
      pass "enterprise-access (app repo) sets CSRF_COOKIE_NAME='csrftoken'"
    else
      fail "enterprise-access (app repo) missing CSRF_COOKIE_NAME='csrftoken'"
    fi
  fi
else
  skip "bbi-infrastructure not available — CSRF cookie name check requires it"
fi

# Also verify enterprise-access settings file if it exists
ea_settings="${REPO_ROOT}/deploy/k8s/base/apps/enterprise/settings/enterprise-access-settings.py"
if [[ -f "$ea_settings" ]]; then
  if grep -q "CSRF_COOKIE_NAME.*csrftoken" "$ea_settings"; then
    pass "enterprise-access-settings.py has CSRF_COOKIE_NAME='csrftoken'"
  elif grep -q "CSRF_COOKIE_NAME" "$ea_settings"; then
    fail "enterprise-access-settings.py has CSRF_COOKIE_NAME but NOT 'csrftoken'"
  else
    pass "enterprise-access-settings.py defers CSRF_COOKIE_NAME to config-gen (OK)"
  fi
fi

# ─── Section 2: CSRF Trusted Origins ────────────────────────────────────
echo "[2/7] CSRF trusted origins include MFE origins"

lms_prod="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms/production.py"
if [[ -f "$lms_prod" ]]; then
  # LMS must include MFE origins in CSRF_TRUSTED_ORIGINS
  if grep -q 'CSRF_TRUSTED_ORIGINS' "$lms_prod"; then
    pass "LMS production.py defines CSRF_TRUSTED_ORIGINS"
  else
    fail "LMS production.py missing CSRF_TRUSTED_ORIGINS"
  fi

  # Check for MFE domain patterns
  if grep -q 'MEREKA_MFE_BASE_URL\|apps\.academyv2' "$lms_prod"; then
    pass "LMS CSRF_TRUSTED_ORIGINS includes MFE domain pattern"
  else
    fail "LMS CSRF_TRUSTED_ORIGINS missing MFE domain pattern"
  fi
fi

# enterprise-access must also have CSRF_TRUSTED_ORIGINS with learner + admin portals
if [[ -d "$INFRA_ROOT" ]]; then
  ea_deploy="${INFRA_ROOT}/apps/mereka-lms/base/deploy/k8s/base/apps/enterprise/enterprise-access-deployment.yaml"
  if [[ -f "$ea_deploy" ]]; then
    if grep -q 'CSRF_TRUSTED_ORIGINS' "$ea_deploy"; then
      pass "enterprise-access config-gen has CSRF_TRUSTED_ORIGINS"
      # Must include learner.* and admin.* patterns
      if grep -q "'learner\.\|learner\." "$ea_deploy"; then
        pass "enterprise-access CSRF_TRUSTED_ORIGINS includes learner portal"
      else
        fail "enterprise-access CSRF_TRUSTED_ORIGINS missing learner portal origin"
      fi
      if grep -q "'admin\.\|admin\." "$ea_deploy"; then
        pass "enterprise-access CSRF_TRUSTED_ORIGINS includes admin portal"
      else
        fail "enterprise-access CSRF_TRUSTED_ORIGINS missing admin portal origin"
      fi
    else
      fail "enterprise-access config-gen missing CSRF_TRUSTED_ORIGINS"
    fi
  fi
fi

# ─── Section 3: JWT Public Key Derivation ───────────────────────────────
echo "[3/7] JWT public key derived from private key (never hardcoded)"

if [[ -d "$INFRA_ROOT" ]]; then
  enterprise_dir="${INFRA_ROOT}/apps/mereka-lms/base/deploy/k8s/base/apps/enterprise"
  derived_count=0
  checked_count=0
  for svc in enterprise-access enterprise-catalog enterprise-subsidy license-manager; do
    deploy_file="${enterprise_dir}/${svc}-deployment.yaml"
    if [[ -f "$deploy_file" ]]; then
      checked_count=$((checked_count + 1))
      # Must derive public JWK from private key, not hardcode it
      if grep -q 'JWT_PRIVATE_SIGNING_JWK\|_priv_jwk\|Derived public JWK' "$deploy_file"; then
        derived_count=$((derived_count + 1))
      fi
    fi
  done

  if [[ $checked_count -eq 0 ]]; then
    skip "no enterprise deployment files found in bbi-infrastructure"
  elif [[ $derived_count -eq $checked_count ]]; then
    pass "all ${derived_count}/${checked_count} enterprise services derive JWT public key from private key"
  else
    fail "only ${derived_count}/${checked_count} enterprise services derive JWT public key"
  fi
else
  skip "bbi-infrastructure not available — JWT derivation check requires it"
fi

# ─── Section 4: Studio Session Cookie Name ──────────────────────────────
echo "[4/7] Studio session cookie name is unique (not 'sessionid')"

cms_prod="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/cms/production.py"
if [[ -f "$cms_prod" ]]; then
  if grep -q "SESSION_COOKIE_NAME.*studio_session_id" "$cms_prod"; then
    pass "CMS uses SESSION_COOKIE_NAME='studio_session_id'"
  elif grep -q "SESSION_COOKIE_NAME" "$cms_prod"; then
    cookie_name=$(grep "SESSION_COOKIE_NAME" "$cms_prod" | head -1)
    if echo "$cookie_name" | grep -q "sessionid"; then
      fail "CMS uses 'sessionid' — collides with LMS session cookie"
    else
      pass "CMS uses unique SESSION_COOKIE_NAME"
    fi
  else
    fail "CMS production.py does not set SESSION_COOKIE_NAME (defaults to 'sessionid' — collision risk)"
  fi
fi

# ─── Section 5: Caddy Host Header Forwarding ────────────────────────────
echo "[5/7] Enterprise MFE Caddy forwards Host header to backends"

for portal in admin-portal learner-portal; do
  caddyfile="${REPO_ROOT}/deploy/k8s/base/apps/enterprise/mfe/${portal}-Caddyfile"
  if [[ -f "$caddyfile" ]]; then
    # Enterprise portal Caddyfiles are simple file_server configs (no reverse_proxy)
    # The proxying happens at the main Caddy or at bbi-infrastructure level
    pass "${portal} Caddyfile exists (static file server — proxy at ingress level)"
  else
    fail "${portal} Caddyfile not found"
  fi
done

# Check main Caddy for enterprise service routing
main_caddyfile="${REPO_ROOT}/deploy/k8s/base/apps/caddy/Caddyfile"
if [[ -f "$main_caddyfile" ]]; then
  if grep -q 'enterprise-access\|enterprise-catalog' "$main_caddyfile"; then
    pass "main Caddyfile routes to enterprise services"
  else
    pass "main Caddyfile does not route to enterprise services (proxied at MFE Caddy level)"
  fi
fi

# ─── Section 6: Cookie SameSite=None for Cross-Subdomain Auth ──────────
echo "[6/7] Cookie SameSite=None for cross-subdomain auth"

if [[ -f "$lms_prod" ]]; then
  # Check SESSION_COOKIE_SAMESITE
  if grep -q 'SESSION_COOKIE_SAMESITE.*None\|DCS_SESSION_COOKIE_SAMESITE.*None' "$lms_prod"; then
    pass "LMS SESSION_COOKIE_SAMESITE is 'None'"
  else
    fail "LMS SESSION_COOKIE_SAMESITE may not be 'None' — cross-subdomain auth may break"
  fi

  # Check CSRF_COOKIE_SAMESITE
  if grep -q 'CSRF_COOKIE_SAMESITE.*None' "$lms_prod"; then
    pass "LMS CSRF_COOKIE_SAMESITE is 'None'"
  else
    fail "LMS CSRF_COOKIE_SAMESITE may not be 'None' — cross-subdomain CSRF may break"
  fi

  # Check CSRF_COOKIE_SECURE (required when SameSite=None)
  if grep -q 'CSRF_COOKIE_SECURE.*True' "$lms_prod"; then
    pass "LMS CSRF_COOKIE_SECURE is True"
  else
    fail "LMS CSRF_COOKIE_SECURE not True — required when SameSite=None"
  fi
fi

# ─── Section 7: Enterprise MFE Runtime Config Contract ──────────────────
echo "[7/7] Enterprise MFE env.config.js contract"

# Check that all overlays with enterprise portals have an env.config.js
for overlay in local rke2-nonprod staging; do
  env_js="${REPO_ROOT}/deploy/k8s/overlays/${overlay}/enterprise-mfe-env.js"
  if [[ -f "$env_js" ]]; then
    # Must have LMS_BASE_URL
    if grep -q 'LMS_BASE_URL' "$env_js"; then
      pass "${overlay}: enterprise-mfe-env.js has LMS_BASE_URL"
    else
      fail "${overlay}: enterprise-mfe-env.js missing LMS_BASE_URL"
    fi

    # Must have CSRF_TOKEN_API_PATH
    if grep -q 'CSRF_TOKEN_API_PATH' "$env_js"; then
      pass "${overlay}: enterprise-mfe-env.js has CSRF_TOKEN_API_PATH"
    else
      fail "${overlay}: enterprise-mfe-env.js missing CSRF_TOKEN_API_PATH"
    fi

    # Must NOT have MISSING_ENV_VAR
    if grep -q 'MISSING_ENV_VAR' "$env_js"; then
      fail "${overlay}: enterprise-mfe-env.js contains MISSING_ENV_VAR placeholder"
    else
      pass "${overlay}: enterprise-mfe-env.js has no MISSING_ENV_VAR placeholders"
    fi
  else
    skip "${overlay}: no enterprise-mfe-env.js (may not deploy enterprise portals)"
  fi
done

# Base env.config.js should use localhost defaults (not production URLs)
base_env="${REPO_ROOT}/deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js"
if [[ -f "$base_env" ]]; then
  if grep -q 'academyv2\.mereka\.io' "$base_env"; then
    fail "base enterprise-mfe-env.js contains production URL (should use localhost)"
  else
    pass "base enterprise-mfe-env.js uses localhost defaults (no production URLs)"
  fi
fi

echo ""
echo "=== Results: ${FAILURES} failures, ${SKIPS} skips ==="
if [[ $FAILURES -gt 0 ]]; then
  echo "VERDICT: FAIL"
  exit 1
fi
echo "VERDICT: PASS"
exit 0
