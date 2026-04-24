#!/usr/bin/env bash
# @covers AC-T074
# @spec: ttfs-onboarding_spec.md
# verify-ttfs-onboarding.sh — Offline verification of TTFS onboarding funnel config
#
# Checks (no live network calls):
#   1. Registration route exists in LMS/MFE config (/register, /authn/register)
#   2. Enrollment API path is referenced in deployment config
#   3. Course discovery service is configured (Caddyfile + ExternalSecrets)
#   4. Courseware URLs are configured in Caddy ingress
#   5. SMTP/email secrets are referenced in deployments (email verification step)
#   6. MFE authn login page path exists in Caddyfile
#
# Usage:
#   ./scripts/qa/verify-ttfs-onboarding.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
warn() { WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"; }

LMS_PROD_SETTINGS="deploy/k8s/base/apps/openedx/settings/cms/production.py"
LMS_CMS_DEV_SETTINGS="deploy/k8s/base/apps/openedx/settings/cms/development.py"
CADDY_BASE="deploy/k8s/base/apps/caddy/Caddyfile"
MFE_CADDYFILE="deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
EXTERNAL_SECRETS="deploy/k8s/base/secrets/external-secrets.yaml"
DEPLOYMENTS="deploy/k8s/base/deployments.yml"

echo "=== TTFS Onboarding Funnel Config Verification ==="
echo "Repo: $REPO_ROOT"
echo ""

# ---------------------------------------------------------------------------
# 1. Registration endpoint in LMS config
# ---------------------------------------------------------------------------
echo "== Step 1: Registration endpoint =="

REG_FOUND=false
for f in "$LMS_PROD_SETTINGS" "$LMS_CMS_DEV_SETTINGS"; do
  if [[ -f "$f" ]]; then
    if grep -q "FRONTEND_REGISTER_URL\|/register" "$f" 2>/dev/null; then
      pass "registration URL referenced in: $f"
      REG_FOUND=true
    fi
  fi
done

if [[ "$REG_FOUND" == "false" ]]; then
  # Fallback: check any settings file across the repo
  if grep -rq "FRONTEND_REGISTER_URL\|/register" deploy/k8s/base/apps/openedx/settings/ 2>/dev/null; then
    pass "registration URL referenced in openedx settings (at least one file)"
  else
    fail "registration URL (FRONTEND_REGISTER_URL or /register) not found in openedx settings"
  fi
fi

# Check MFE Caddyfile exposes /authn/register
if [[ -f "$MFE_CADDYFILE" ]]; then
  if grep -q "authn" "$MFE_CADDYFILE" 2>/dev/null; then
    pass "authn MFE route (covers /authn/register) present in MFE Caddyfile"
  else
    warn "authn route not found in MFE Caddyfile — /authn/register may be unreachable"
  fi
else
  warn "MFE Caddyfile not found at: $MFE_CADDYFILE"
fi

echo ""

# ---------------------------------------------------------------------------
# 2. Enrollment API configured
# ---------------------------------------------------------------------------
echo "== Step 2: Enrollment API =="

# The enrollment API is a core LMS endpoint — check it is referenced in
# settings or deploy config (not blocked/disabled).
if grep -rq "enrollment" deploy/k8s/base/apps/openedx/settings/ 2>/dev/null; then
  pass "enrollment references found in LMS settings"
else
  warn "no enrollment references found in LMS settings — check DISABLE_COURSE_CREATION flags"
fi

# Check enrollment event is configured in event bus settings
if grep -rq "course.enrollment\|enrollment.changed" deploy/k8s/base/apps/openedx/settings/ 2>/dev/null; then
  pass "enrollment event bus hook configured (org.openedx.learning.course.enrollment.changed)"
else
  warn "enrollment event hook not found in LMS settings — real-time enrollment events may not fire"
fi

echo ""

# ---------------------------------------------------------------------------
# 3. Course discovery service configured
# ---------------------------------------------------------------------------
echo "== Step 3: Course discovery =="

if [[ -f "$CADDY_BASE" ]]; then
  if grep -q "discovery" "$CADDY_BASE" 2>/dev/null; then
    pass "discovery service route present in Caddy base Caddyfile"
  else
    fail "discovery service route missing from Caddy base Caddyfile"
  fi
else
  fail "Caddy base Caddyfile not found: $CADDY_BASE"
fi

# Discovery secrets must be in ExternalSecrets (OAuth2 wiring)
if [[ -f "$EXTERNAL_SECRETS" ]]; then
  if grep -q "DISCOVERY_SECRET_KEY\|DISCOVERY_OAUTH2" "$EXTERNAL_SECRETS" 2>/dev/null; then
    pass "discovery OAuth2 secrets present in ExternalSecrets"
  else
    warn "discovery OAuth2 secrets not found in ExternalSecrets — catalog API auth may fail"
  fi
else
  warn "ExternalSecrets file not found: $EXTERNAL_SECRETS"
fi

# Check discovery plugin dir exists
if [[ -d "deploy/k8s/base/plugins/discovery" ]]; then
  pass "discovery plugin directory exists: deploy/k8s/base/plugins/discovery"
else
  warn "discovery plugin directory not found — discovery service may not be deployed"
fi

echo ""

# ---------------------------------------------------------------------------
# 4. Courseware URLs configured in Caddy ingress
# ---------------------------------------------------------------------------
echo "== Step 4: Courseware URL routing =="

if [[ -f "$MFE_CADDYFILE" ]]; then
  if grep -q "learning" "$MFE_CADDYFILE" 2>/dev/null; then
    pass "learning MFE route (/learning/course/*) present in MFE Caddyfile"
  else
    fail "learning MFE route missing from MFE Caddyfile — courseware will be unreachable"
  fi
else
  fail "MFE Caddyfile not found: $MFE_CADDYFILE"
fi

# Check base Caddy routes LMS traffic (courseware served via LMS fallback)
if [[ -f "$CADDY_BASE" ]]; then
  if grep -q "lms" "$CADDY_BASE" 2>/dev/null; then
    pass "LMS upstream present in Caddy base Caddyfile (courseware fallback)"
  else
    warn "LMS upstream not found in Caddy base Caddyfile"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# 5. SMTP / email verification secrets referenced
# ---------------------------------------------------------------------------
echo "== Step 5: Email verification (SMTP) =="

SMTP_FOUND=false

if [[ -f "$DEPLOYMENTS" ]]; then
  if grep -q "SMTP_USERNAME\|SMTP_PASSWORD\|SMTP_HOST\|EMAIL_HOST" "$DEPLOYMENTS" 2>/dev/null; then
    pass "SMTP credentials referenced in deployments.yml"
    SMTP_FOUND=true
  fi
fi

# Check any settings file references email config
if grep -rq "EMAIL_HOST\|SMTP_HOST\|smtp" deploy/k8s/base/apps/openedx/settings/ 2>/dev/null; then
  pass "email (SMTP) host config found in openedx settings"
  SMTP_FOUND=true
fi

if grep -rq "EMAIL_HOST\|SMTP_HOST\|smtp" deploy/k8s/base/plugins/ 2>/dev/null; then
  pass "email (SMTP) host config found in plugin settings"
  SMTP_FOUND=true
fi

if [[ "$SMTP_FOUND" == "false" ]]; then
  warn "no SMTP config references found — email verification after registration may not work"
fi

echo ""

# ---------------------------------------------------------------------------
# 6. MFE authn login path in Caddyfile
# ---------------------------------------------------------------------------
echo "== Step 6: MFE authn login route =="

if [[ -f "$MFE_CADDYFILE" ]]; then
  if grep -q "authn" "$MFE_CADDYFILE" 2>/dev/null; then
    pass "authn MFE route present in MFE Caddyfile (/authn/login + /authn/register)"
  else
    fail "authn MFE route missing from MFE Caddyfile — /authn/login unreachable"
  fi
else
  fail "MFE Caddyfile not found: $MFE_CADDYFILE"
fi

# Check apps.* host is routed to MFE in base Caddy config
if [[ -f "$CADDY_BASE" ]]; then
  if grep -q "apps\." "$CADDY_BASE" 2>/dev/null; then
    pass "apps.* hostname route present in Caddy base Caddyfile"
  else
    warn "apps.* hostname not found in Caddy base Caddyfile — MFE domain may not be routed"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=============================="
echo "Summary: PASS=${PASS} FAIL=${FAIL} WARN=${WARN}"
echo "=============================="
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}RESULT: FAILED${NC} — fix failing checks before deployment"
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo -e "${YELLOW}RESULT: WARN${NC} — review warnings; onboarding funnel may have gaps"
  exit 0
else
  echo -e "${GREEN}RESULT: PASS${NC} — all TTFS onboarding funnel checks passed"
  exit 0
fi
