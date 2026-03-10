#!/usr/bin/env bash
# verify-legacy-courseware.sh — Audit legacy courseware migration status
#
# Checks that the Mereka LMS is correctly wired for the Learning MFE
# (replacing server-rendered legacy courseware) per Tutor Ulmo deprecation.
#
# Checks:
#   1. LEARNING_MICROFRONTEND_URL is configured in LMS production settings
#   2. MFE_CONFIG["LEARNING_BASE_URL"] is set
#   3. ENABLE_COURSEWARE_MICROFRONTEND is not explicitly disabled in production
#   4. coursewarehistoryextended app is removed (CSMH cleanup)
#   5. Development settings do not disable the MFE (warn if they do)
#   6. No legacy courseware redirect exists in Caddyfile (document-only, not blocking)
#   7. openedx_assessment_bulk middleware uses a legacy URL pattern (warn, not fail)
#
# Exit codes:
#   0 — all checks pass (WARNs are non-blocking)
#   1 — one or more checks FAIL
#
# Usage:
#   ./scripts/qa/verify-legacy-courseware.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
SKIP=0

pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
warn() { WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"; }
skip() { SKIP=$((SKIP + 1)); echo -e "${BLUE}[SKIP]${NC} $1"; }

LMS_PROD="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
LMS_DEV="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/development.py"
CADDYFILE="$REPO_ROOT/deploy/k8s/base/apps/caddy/Caddyfile"
ASSESSMENT_BULK_MW="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_assessment_bulk/middleware.py"
AUDIT_DOC="$REPO_ROOT/reports/2026/audits/LEGACY_COURSEWARE_AUDIT.md"

echo -e "${BLUE}=== Legacy Courseware Migration Audit ===${NC}"
echo "  Checks Tutor Ulmo (v21) Learning MFE wiring"
echo "  Reference: reports/2026/audits/LEGACY_COURSEWARE_AUDIT.md"
echo ""

# ── Check 1: LEARNING_MICROFRONTEND_URL configured ───────────────────
echo "-- Check 1: LEARNING_MICROFRONTEND_URL configured in production"
if [[ ! -f "$LMS_PROD" ]]; then
  fail "LMS production settings not found: $LMS_PROD"
elif grep -q "LEARNING_MICROFRONTEND_URL" "$LMS_PROD"; then
  pass "LEARNING_MICROFRONTEND_URL is set in LMS production settings"
else
  fail "LEARNING_MICROFRONTEND_URL missing from $LMS_PROD — Learning MFE URL not wired"
fi

# ── Check 2: MFE_CONFIG["LEARNING_BASE_URL"] set ─────────────────────
echo "-- Check 2: MFE_CONFIG[\"LEARNING_BASE_URL\"] configured"
if [[ -f "$LMS_PROD" ]] && grep -q 'MFE_CONFIG\["LEARNING_BASE_URL"\]' "$LMS_PROD"; then
  pass "MFE_CONFIG[\"LEARNING_BASE_URL\"] is set in LMS production settings"
else
  fail "MFE_CONFIG[\"LEARNING_BASE_URL\"] missing from $LMS_PROD — MFE runtime config incomplete"
fi

# ── Check 3: Production does not explicitly disable the MFE flag ──────
echo "-- Check 3: ENABLE_COURSEWARE_MICROFRONTEND not disabled in production"
if [[ ! -f "$LMS_PROD" ]]; then
  skip "LMS production settings not found — cannot check"
elif grep -q 'ENABLE_COURSEWARE_MICROFRONTEND.*False' "$LMS_PROD"; then
  fail "Production settings explicitly disable ENABLE_COURSEWARE_MICROFRONTEND — learners will see legacy courseware"
else
  pass "ENABLE_COURSEWARE_MICROFRONTEND not disabled in production (Ulmo default: True)"
fi

# ── Check 4: coursewarehistoryextended removed ────────────────────────
echo "-- Check 4: coursewarehistoryextended removed from INSTALLED_APPS"
if [[ ! -f "$LMS_PROD" ]]; then
  skip "LMS production settings not found — cannot check"
elif grep -q 'INSTALLED_APPS.remove.*coursewarehistoryextended' "$LMS_PROD"; then
  pass "coursewarehistoryextended removed from INSTALLED_APPS (CSMH cleanup done)"
else
  warn "coursewarehistoryextended not explicitly removed — may still be loaded (not blocking)"
fi

# ── Check 5: Development settings do not disable the MFE ─────────────
echo "-- Check 5: ENABLE_COURSEWARE_MICROFRONTEND in development settings"
if [[ ! -f "$LMS_DEV" ]]; then
  skip "LMS development settings not found at $LMS_DEV"
elif grep -q 'ENABLE_COURSEWARE_MICROFRONTEND.*False' "$LMS_DEV"; then
  warn "development.py disables ENABLE_COURSEWARE_MICROFRONTEND — dev environment uses legacy courseware. Flip to True when dev environment is MFE-ready."
else
  pass "ENABLE_COURSEWARE_MICROFRONTEND not disabled in development settings"
fi

# ── Check 6: No legacy courseware redirect in Caddyfile (informational) ──
echo "-- Check 6: Caddyfile legacy courseware redirect status"
if [[ ! -f "$CADDYFILE" ]]; then
  skip "Caddyfile not found at $CADDYFILE"
elif grep -q 'courseware' "$CADDYFILE"; then
  pass "Caddyfile contains courseware-related routing (manual review recommended)"
else
  # Not having a Caddy redirect is the expected state — Django handles it
  pass "No legacy courseware routes in Caddyfile (Django-level redirect is the expected mechanism)"
fi

# ── Check 7: openedx_assessment_bulk uses legacy URL pattern ─────────
echo "-- Check 7: openedx_assessment_bulk middleware legacy URL pattern"
if [[ ! -f "$ASSESSMENT_BULK_MW" ]]; then
  skip "openedx_assessment_bulk middleware not found at $ASSESSMENT_BULK_MW"
elif grep -q "courses/.*/courseware" "$ASSESSMENT_BULK_MW"; then
  warn "openedx_assessment_bulk/middleware.py uses legacy /courses/.*/courseware/.* URL pattern for exam detection. Update to Learning MFE URL pattern after full migration."
else
  pass "openedx_assessment_bulk middleware does not use legacy courseware URL pattern"
fi

# ── Check 8: Audit document exists ───────────────────────────────────
echo "-- Check 8: Audit document present"
if [[ -f "$AUDIT_DOC" ]]; then
  pass "Legacy courseware audit document present at reports/2026/audits/LEGACY_COURSEWARE_AUDIT.md"
else
  fail "Audit document missing: $AUDIT_DOC — create it to document migration decisions"
fi

# ── Summary ───────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${BLUE}SKIP${NC}: $SKIP"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}Legacy courseware migration issues found. See FAIL items above.${NC}"
  exit 1
elif [[ $WARN -gt 0 ]]; then
  echo -e "${YELLOW}Migration in progress. See WARN items above for remaining steps.${NC}"
  exit 0
else
  echo -e "${GREEN}Learning MFE wiring verified. Legacy courseware migration complete.${NC}"
  exit 0
fi
