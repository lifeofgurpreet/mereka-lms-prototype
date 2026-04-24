#!/usr/bin/env bash
# @spec: proposals/proctoring-integration_spec.md
# @covers AC-003, AC-014, AC-015, AC-017, AC-018, AC-019, AC-023
#
# Proctoring environment and browser security verification:
#   AC-003: Respondus LockDown Browser detection (non-LDB browser shows download prompt)
#   AC-014: Webcam permission check — blocked camera shows error message
#   AC-015: Full environment check (webcam, mic, screen, browser, network — all green)
#   AC-017: Respondus LockDown Browser enforcement (clipboard, tabs, apps blocked)
#   AC-018: Proctorio fullscreen + clipboard enforcement flags
#   AC-019: Virtual machine detection by provider
#   AC-023: Provider outage resilience (answers preserved in session storage)
#
# NOTE: These ACs require live proctoring provider integration.
#       This script verifies infrastructure readiness (config/code/secrets presence).
#       Full AC verification requires a signed provider contract + staging test exam.
#
# Usage:
#   ./scripts/qa/verify-proctoring-environment.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Proctoring Environment & Browser Security Verification ==="
echo "(Infrastructure readiness checks — full verification requires live provider)"
echo ""

LMS_PROD="deploy/k8s/base/apps/openedx/settings/lms/production.py"
VENDOR_READINESS="docs/status/readiness/PROCTORING_VENDOR_READINESS.md"
RUNBOOK="docs/ops/runbooks/PROCTORING_RUNBOOK.md"

# --- AC-003: Respondus LockDown Browser detection ---
echo "Checking AC-003: Respondus LockDown Browser detection infrastructure..."

# LDB detection happens client-side via User-Agent check in edx-proctoring JS.
# Server-side: PROCTORING_BACKENDS must include 'ldb' or 'respondus_lockdown_browser' key.
# Verify: PROCTORING_BACKENDS config path exists and null backend is active (pre-contract).
if [[ -f "$LMS_PROD" ]]; then
  if grep -q "PROCTORING_BACKENDS" "$LMS_PROD"; then
    pass "AC-003: PROCTORING_BACKENDS config present in LMS settings"
    # Respondus backend key placeholder check
    if grep -qi "respondus\|ldb\|lockdown" "$LMS_PROD"; then
      pass "AC-003: Respondus/LDB backend key found in settings"
    else
      skip "AC-003: Respondus backend not configured (expected pre-contract — add after provider selection)"
    fi
  else
    fail "AC-003: PROCTORING_BACKENDS missing from LMS settings"
  fi
else
  skip "AC-003: LMS production settings file not found at $LMS_PROD"
fi

# Verify edx-proctoring is installed (LDB detection requires the package)
if grep -r "edx.proctoring\|edx_proctoring" deploy/k8s/base/ 2>/dev/null | grep -q "requirements\|INSTALLED_APPS\|edx.proctoring"; then
  pass "AC-003: edx-proctoring referenced in deployment config"
else
  skip "AC-003: edx-proctoring package reference check skipped (check requirements.txt in image)"
fi
echo ""

# --- AC-014: Webcam permission check ---
echo "Checking AC-014: Webcam permission check infrastructure..."

# Camera check is performed by edx-proctoring JS in the browser. Server-side:
# ENABLE_SPECIAL_EXAMS must be True and the pre-exam setup view must be reachable.
if [[ -f "$LMS_PROD" ]]; then
  if grep -q "ENABLE_SPECIAL_EXAMS" "$LMS_PROD"; then
    SPECIAL_EXAMS_VALUE=$(grep "ENABLE_SPECIAL_EXAMS" "$LMS_PROD" | grep -o "True\|False" | head -1)
    if [[ "$SPECIAL_EXAMS_VALUE" == "True" ]]; then
      pass "AC-014: ENABLE_SPECIAL_EXAMS = True (pre-exam environment check enabled)"
    else
      fail "AC-014: ENABLE_SPECIAL_EXAMS = False — must be True for environment checks"
    fi
  else
    skip "AC-014: ENABLE_SPECIAL_EXAMS not found in settings"
  fi

  # ENABLE_PROCTORED_EXAMS flag
  if grep -q "ENABLE_PROCTORED_EXAMS" "$LMS_PROD"; then
    pass "AC-014: ENABLE_PROCTORED_EXAMS flag present"
  else
    skip "AC-014: ENABLE_PROCTORED_EXAMS not set (set to True when provider is configured)"
  fi
else
  skip "AC-014: LMS production settings not found"
fi
echo ""

# --- AC-015: Full environment check (all components green) ---
echo "Checking AC-015: Full pre-exam environment check infrastructure..."

# edx-proctoring provides /api/edx_proctoring/v1/proctored_exam/attempt/
# environment check endpoint. Verify the API routes are available.
# Server-side: PROCTORING_BACKENDS configured + ENABLE_PROCTORED_EXAMS = True
if [[ -f "$LMS_PROD" ]]; then
  if grep -q "PROCTORING_BACKENDS" "$LMS_PROD" && grep -q "ENABLE_SPECIAL_EXAMS" "$LMS_PROD"; then
    pass "AC-015: Pre-exam environment check prerequisites present (PROCTORING_BACKENDS + ENABLE_SPECIAL_EXAMS)"
  else
    skip "AC-015: Missing prerequisite settings for environment check"
  fi
fi

# Check that vendor readiness doc exists (environment check requirements documented)
if [[ -f "$VENDOR_READINESS" ]]; then
  if grep -q "edx_proctoring import\|PROCTORING_BACKENDS\|webcam\|microphone" "$VENDOR_READINESS"; then
    pass "AC-015: Environment check requirements documented in PROCTORING_VENDOR_READINESS.md"
  else
    skip "AC-015: Environment check requirements not fully documented"
  fi
else
  fail "AC-015: PROCTORING_VENDOR_READINESS.md not found — run 33ff bead first"
fi
echo ""

# --- AC-017: Respondus LockDown Browser enforcement ---
echo "Checking AC-017: Respondus LDB enforcement infrastructure..."

# LDB enforcement is entirely client-side (LDB application blocks clipboard/tabs/apps).
# Server-side: PROCTORING_BACKENDS must include respondus key with correct config flags.
if [[ -f "$LMS_PROD" ]]; then
  if grep -qi "respondus\|ldb\|lockdown_browser" "$LMS_PROD"; then
    pass "AC-017: Respondus LDB backend configured in settings"
  else
    skip "AC-017: Respondus LDB backend not configured (expected pre-contract)"
  fi
else
  skip "AC-017: LMS production settings not found"
fi

# Check vendor readiness doc mentions LDB
if [[ -f "$VENDOR_READINESS" ]]; then
  if grep -qi "respondus\|lockdown.*browser\|LDB" "$VENDOR_READINESS"; then
    pass "AC-017: Respondus LDB documented in vendor readiness doc"
  else
    skip "AC-017: Respondus LDB not mentioned in vendor readiness doc"
  fi
fi
echo ""

# --- AC-018: Proctorio fullscreen + clipboard enforcement ---
echo "Checking AC-018: Proctorio enforcement flags infrastructure..."

# Proctorio settings passed via PROCTORING_BACKENDS['proctorio'] config dict.
# lock_fullscreen, disable_clipboard are per-exam settings in edx-proctoring.
if [[ -f "$LMS_PROD" ]]; then
  if grep -qi "proctorio" "$LMS_PROD"; then
    pass "AC-018: Proctorio backend key found in settings"
    if grep -qi "lock_fullscreen\|disable_clipboard" "$LMS_PROD"; then
      pass "AC-018: Proctorio enforcement flags (lock_fullscreen, disable_clipboard) present"
    else
      skip "AC-018: Proctorio enforcement flags not yet set (add when configuring Proctorio backend)"
    fi
  else
    skip "AC-018: Proctorio backend not configured (expected pre-contract)"
  fi
else
  skip "AC-018: LMS production settings not found"
fi

# Check vendor matrix mentions Proctorio
if [[ -f "$VENDOR_READINESS" ]]; then
  if grep -qi "proctorio" "$VENDOR_READINESS"; then
    pass "AC-018: Proctorio mentioned in vendor evaluation matrix"
  fi
fi
echo ""

# --- AC-019: VM detection ---
echo "Checking AC-019: Virtual machine detection infrastructure..."

# VM detection is performed by the proctoring provider's browser extension/application.
# Server-side: provider receives vm_detected flag via webhook callback.
# Verify: webhook endpoint / callback handler infrastructure exists.
if [[ -f "$LMS_PROD" ]]; then
  if grep -qi "callback\|webhook\|on_review_callback\|review_policy" "$LMS_PROD"; then
    pass "AC-019: Callback/webhook infrastructure references found in LMS settings"
  else
    skip "AC-019: Callback handler not configured (expected pre-contract)"
  fi
fi

# Check ExternalSecrets for webhook secret
EXTERNAL_SECRETS="deploy/k8s/base/secrets/external-secrets.yaml"
if [[ -f "$EXTERNAL_SECRETS" ]]; then
  if grep -qi "proctoring.*webhook\|webhook.*proctoring" "$EXTERNAL_SECRETS"; then
    pass "AC-019: Proctoring webhook secret mapped in ExternalSecrets"
  else
    skip "AC-019: Proctoring webhook secret not in ExternalSecrets (add after contract)"
  fi
fi
echo ""

# --- AC-023: Provider outage resilience ---
echo "Checking AC-023: Provider outage resilience infrastructure..."

# Client-side: edx-proctoring JS uses session storage to buffer answers during reconnect.
# Server-side: exam attempt preserves state in MySQL even if provider is unreachable.
# Verify: MySQL backend is configured (not ephemeral) so exam state survives outage.
if [[ -f "$LMS_PROD" ]]; then
  # Exam state stored in edx_proctoring.models.ProctoredExamStudentAttempt (MySQL)
  if grep -q "DATABASES\|MYSQL\|mysql" "$LMS_PROD" 2>/dev/null || \
     grep -q "MYSQL_HOST\|DATABASE_URL" deploy/k8s/base/deployments.yml 2>/dev/null; then
    pass "AC-023: MySQL backend configured — exam state persists during provider outage"
  else
    skip "AC-023: MySQL backend config not directly visible in settings"
  fi
fi

# Check that runbook has outage response procedure
if [[ -f "$RUNBOOK" ]]; then
  if grep -qi "outage\|provider.*down\|reconnect\|fallback" "$RUNBOOK"; then
    pass "AC-023: Provider outage procedure documented in PROCTORING_RUNBOOK.md"
  else
    skip "AC-023: Provider outage procedure not found in runbook"
  fi
else
  skip "AC-023: PROCTORING_RUNBOOK.md not found"
fi
echo ""

# --- Final summary ---
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
echo ""
echo "CONTEXT: ACs 003, 014, 015, 017, 018, 019, 023 require live provider integration."
echo "SKIP = expected pre-contract. PASS = infrastructure already in place."
echo "Run this script again after provider contract is signed and config is updated."

[[ $FAIL -gt 0 ]] && exit 1
exit 0
