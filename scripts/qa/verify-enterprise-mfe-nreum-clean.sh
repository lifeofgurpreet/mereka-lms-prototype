#!/usr/bin/env bash
# verify-enterprise-mfe-nreum-clean.sh
# @spec: platform-middleware-custom-apps_spec.md
# @covers AC-UX-142, AC-UX-145
#
# Regression guard: enterprise admin/learner portal HTML must NOT contain
# NREUM browser agent with undefined_license_key placeholder.
#
# Root cause docs: docs/operations/evidence/3evf-5xcl-enterprise-mfe-nreum-fix.md
# Fix: sanitize-enterprise-index-html initContainer in admin/learner-portal-deployment.yaml
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

# --- AC-UX-142: Admin portal HTML must not contain undefined_license_key ---
echo "--- AC-UX-142: Admin portal HTML clean ---"
ADMIN_HTML=$(curl -s --max-time "$TIMEOUT" "$ADMIN_URL" 2>/dev/null || true)

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

# --- AC-UX-142: Enterprise learner portal HTML ---
echo "--- AC-UX-142: Enterprise learner portal HTML clean ---"
ENTERPRISE_HTML=$(curl -s --max-time "$TIMEOUT" "$ENTERPRISE_URL" 2>/dev/null | head -c 2048 || true)

if [ -z "$ENTERPRISE_HTML" ]; then
  skip_check "Enterprise portal unreachable ($ENTERPRISE_URL) — skip NREUM check"
else
  if echo "$ENTERPRISE_HTML" | grep -q 'undefined_license_key'; then
    fail_check "Enterprise portal HTML contains 'undefined_license_key'"
    echo "    Fix: argocd app sync mereka-lms --resource apps:Deployment:enterprise-learner-portal"
  else
    pass_check "Enterprise portal HTML has no 'undefined_license_key'"
  fi
fi

echo ""

# --- AC-UX-145: Regression guard — initContainer present in manifests ---
echo "--- AC-UX-145: sanitize initContainer present in deployment manifests ---"
ADMIN_DEPLOY="deploy/k8s/base/apps/enterprise/mfe/admin-portal-deployment.yaml"
LEARNER_DEPLOY="deploy/k8s/base/apps/enterprise/mfe/learner-portal-deployment.yaml"

if [ -f "$ADMIN_DEPLOY" ] && grep -q 'sanitize-enterprise-index-html' "$ADMIN_DEPLOY"; then
  pass_check "sanitize-enterprise-index-html initContainer present in admin-portal-deployment.yaml"
else
  fail_check "sanitize-enterprise-index-html initContainer MISSING from admin-portal-deployment.yaml"
fi

if [ -f "$LEARNER_DEPLOY" ] && grep -q 'sanitize-enterprise-index-html' "$LEARNER_DEPLOY"; then
  pass_check "sanitize-enterprise-index-html initContainer present in learner-portal-deployment.yaml"
else
  fail_check "sanitize-enterprise-index-html initContainer MISSING from learner-portal-deployment.yaml"
fi

# --- AC-UX-145: LMS footer guard against undefined_license_key ---
echo ""
echo "--- AC-UX-145: LMS footer.html guards against undefined_license_key ---"
FOOTER_TEMPLATE="infrastructure/tutor/themes/mereka/lms/templates/footer.html"
if [ -f "$FOOTER_TEMPLATE" ] && grep -q 'undefined_license_key' "$FOOTER_TEMPLATE"; then
  pass_check "LMS footer.html has guard against undefined_license_key (skips analytics include)"
else
  fail_check "LMS footer.html missing guard for undefined_license_key"
fi

# --- AC-UX-145: Caddyfile routes mfe_config/v1 to LMS (not enterprise portal) ---
echo ""
echo "--- AC-UX-145: Caddyfile routes /api/mfe_config/v1 to LMS ---"
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
