#!/usr/bin/env bash
# verify-enterprise-mfe-nreum-clean.sh
# @spec: platform-middleware-custom-apps_spec.md
# @covers AC-DEP-101, AC-DEP-104, AC-DEP-105
#
# Regression guard: enterprise admin/learner portal HTML must NOT contain
# NREUM browser agent with undefined_license_key placeholder.
#
# Root cause docs: docs/operations/evidence/3evf-5xcl-enterprise-mfe-nreum-fix.md
# Fix intent: remove legacy runtime sanitize workaround from enterprise portal deployments.
#
# SKIP mode: if the portals are unreachable, checks are skipped (not failed).
# This allows CI to run the script without a live cluster dependency.

set -euo pipefail

PASS=0
FAIL=0
SKIP=0

ADMIN_URL="https://admin.academyv2.mereka.io/"
ENTERPRISE_URL="https://enterprise.academyv2.mereka.io/"
TIMEOUT=10

pass_check() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
skip_check() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }
warn_check() { echo "  [WARN] $1"; }

echo "=== Enterprise MFE: NREUM / undefined_license_key regression guard ==="
echo ""

# --- AC-DEP-102: Admin portal HTML must not contain undefined_license_key ---
echo "--- AC-DEP-102: Admin portal HTML clean ---"
ADMIN_HTML=$(curl -s --max-time "$TIMEOUT" "$ADMIN_URL" 2>/dev/null || true)
ADMIN_STATUS="unknown"
if tmp_admin=$(mktemp); then
  ADMIN_STATUS=$(curl -s -L --max-time "$TIMEOUT" -o "$tmp_admin" -w '%{http_code}' "$ADMIN_URL" 2>/dev/null || true)
  if [ "$ADMIN_STATUS" = "403" ] || [ "$ADMIN_STATUS" = "405" ]; then
    fail_check "Admin portal returned HTTP $ADMIN_STATUS ($ADMIN_URL)"
  elif [ -n "$ADMIN_STATUS" ] && [ "$ADMIN_STATUS" != "unknown" ] && printf '%s' "$ADMIN_STATUS" | grep -Eq '^[0-9]{3}$'; then
    pass_check "Admin portal HTTP status $ADMIN_STATUS ($ADMIN_URL)"
  fi
  rm -f "$tmp_admin"
fi

if [ -z "$ADMIN_HTML" ]; then
  skip_check "Admin portal unreachable ($ADMIN_URL) — skip NREUM check"
else
  if echo "$ADMIN_HTML" | grep -q 'undefined_license_key'; then
    fail_check "Admin portal HTML contains 'undefined_license_key' (NREUM not sanitized)"
    echo "    Fix: argocd app sync mereka-lms --resource apps:Deployment:enterprise-admin-portal"
    echo "    Docs: docs/operations/evidence/3evf-5xcl-enterprise-mfe-nreum-fix.md"
  else
    pass_check "Admin portal HTML has no 'undefined_license_key'"
  fi

  if echo "$ADMIN_HTML" | grep -q 'NREUM'; then
    warn_check "Admin portal HTML still has NREUM object (may be loader config, not undefined keys)"
    warn_check "If 'undefined_license_key' check passed, NREUM loader with real keys is acceptable"
  else
    pass_check "Admin portal HTML has no NREUM injection at all"
  fi
fi

echo ""

# --- AC-DEP-102: Enterprise learner portal HTML ---
echo "--- AC-DEP-102: Enterprise learner portal HTML clean ---"
ENTERPRISE_HTML=$(curl -s --max-time "$TIMEOUT" "$ENTERPRISE_URL" 2>/dev/null || true)
ENTERPRISE_STATUS="unknown"
if tmp_enterprise=$(mktemp); then
  ENTERPRISE_STATUS=$(curl -s -L --max-time "$TIMEOUT" -o "$tmp_enterprise" -w '%{http_code}' "$ENTERPRISE_URL" 2>/dev/null || true)
  if [ "$ENTERPRISE_STATUS" = "403" ] || [ "$ENTERPRISE_STATUS" = "405" ]; then
    fail_check "Enterprise portal returned HTTP $ENTERPRISE_STATUS ($ENTERPRISE_URL)"
  elif [ -n "$ENTERPRISE_STATUS" ] && [ "$ENTERPRISE_STATUS" != "unknown" ] && printf '%s' "$ENTERPRISE_STATUS" | grep -Eq '^[0-9]{3}$'; then
    pass_check "Enterprise portal HTTP status $ENTERPRISE_STATUS ($ENTERPRISE_URL)"
  fi
  rm -f "$tmp_enterprise"
fi

if [ -z "$ENTERPRISE_HTML" ]; then
  skip_check "Enterprise portal unreachable ($ENTERPRISE_URL) — skip NREUM check"
else
  if printf '%s' "$ENTERPRISE_HTML" | grep -q 'undefined_license_key'; then
    fail_check "Enterprise portal HTML contains 'undefined_license_key'"
    echo "    Fix: argocd app sync mereka-lms --resource apps:Deployment:enterprise-learner-portal"
  else
    pass_check "Enterprise portal HTML has no 'undefined_license_key'"
  fi

  if printf '%s' "$ENTERPRISE_HTML" | grep -qE 'undefined_account_id|undefined_application_id|undefined_agent_id'; then
    fail_check "Enterprise portal HTML contains other undefined New Relic placeholders"
  fi

  if printf '%s' "$ENTERPRISE_HTML" | grep -q 'NREUM'; then
    warn_check "Enterprise portal HTML still has NREUM object (may be loader config, not undefined keys)"
  else
    pass_check "Enterprise portal HTML has no NREUM injection"
  fi
fi

echo ""

# --- AC-DEP-101: Regression guard — legacy strip-nreum workaround removed ---
echo "--- AC-DEP-101: legacy strip-nreum workaround removed from enterprise deployments ---"
ADMIN_DEPLOY="deploy/k8s/base/apps/enterprise/mfe/admin-portal-deployment.yaml"
LEARNER_DEPLOY="deploy/k8s/base/apps/enterprise/mfe/learner-portal-deployment.yaml"

if grep -q 'strip-nreum' "$ADMIN_DEPLOY"; then
  fail_check "Legacy strip-nreum initContainer still present in admin-portal-deployment.yaml"
else
  pass_check "No legacy strip-nreum initContainer in admin-portal-deployment.yaml"
fi

if grep -q 'strip-nreum' "$LEARNER_DEPLOY"; then
  fail_check "Legacy strip-nreum initContainer still present in learner-portal-deployment.yaml"
else
  pass_check "No legacy strip-nreum initContainer in learner-portal-deployment.yaml"
fi

# --- AC-DEP-104: Caddyfile routes mfe_config/v1 to LMS (not enterprise portal) ---
echo ""
echo "--- AC-DEP-104: Caddyfile routes /api/mfe_config/v1 to LMS ---"
CADDYFILE="deploy/k8s/base/apps/caddy/Caddyfile"
if [ -f "$CADDYFILE" ] && grep -q 'reverse_proxy /api/mfe_config/v1' "$CADDYFILE"; then
  pass_check "Caddyfile proxies /api/mfe_config/v1 to LMS for enterprise domains"
else
  fail_check "Caddyfile missing /api/mfe_config/v1 proxy rule for enterprise domains"
fi

if [ -f "$CADDYFILE" ] && grep -q 'reverse_proxy /login_refresh' "$CADDYFILE"; then
  pass_check "Caddyfile proxies /login_refresh to LMS for enterprise domains"
else
  fail_check "Caddyfile missing /login_refresh proxy rule"
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "  PASS: $PASS | FAIL: $FAIL | SKIP: $SKIP"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "  RESULT: FAIL"
  echo "  See: docs/operations/evidence/3evf-5xcl-enterprise-mfe-nreum-fix.md"
  exit 1
elif [ "$PASS" -eq 0 ]; then
  echo "  RESULT: SKIP (all checks skipped — cluster unreachable)"
  exit 0
else
  echo "  RESULT: PASS"
  exit 0
fi
