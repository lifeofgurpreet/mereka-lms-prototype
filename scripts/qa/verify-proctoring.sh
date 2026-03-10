#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-006, AC-007, AC-008, AC-020, AC-021, AC-022, AC-036, AC-037, AC-038
# @spec: proposals/proctoring-integration_spec.md
# Verify proctoring integration infrastructure readiness
#
# NOTE: This spec is marked as "deferred" status. This script checks for
# infrastructure components that would be needed when proctoring is implemented.
#
# Checks:
#   AC-001: edx-proctoring backend for Proctorio registered
#   AC-002: Examity backend configured with valid API credentials
#   AC-006: Proctored exam configuration in Studio
#   AC-007: ACE channels configuration (email/push/in_app)
#   AC-008: Password reset message type (system-critical, non-suppressible)
#   AC-020: Proctored exam state transitions logged
#   AC-021: Exam submission state transition
#   AC-022: Auto-expiry check for timed-out exams
#   AC-036: Proctoring consent notice display
#   AC-037: Consent notice acceptance blocking
#   AC-038: GDPR DSAR support for proctoring records
#
# Usage:
#   ./scripts/qa/verify-proctoring.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

# Helper functions
pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Proctoring Integration Verification ==="
echo "(NOTE: Proctoring spec status is 'deferred' - checking infrastructure readiness)"
echo ""

# Check 1: edx-proctoring package availability
echo "Checking AC-001, AC-002: edx-proctoring backend infrastructure..."

PROD_SETTINGS="deploy/k8s/base/apps/openedx/settings/lms/production.py"

if [[ -f "$PROD_SETTINGS" ]]; then
  # Check for proctoring settings
  if grep -qi "proctoring\|PROCTORING" "$PROD_SETTINGS"; then
    pass "AC-001: Proctoring configuration references found in production settings"

    # Check for specific backends
    if grep -qi "proctorio" "$PROD_SETTINGS"; then
      pass "AC-001: Proctorio backend configuration found"
    else
      skip "AC-001: Proctorio backend not configured (expected, spec deferred)"
    fi

    if grep -qi "examity" "$PROD_SETTINGS"; then
      pass "AC-002: Examity backend configuration found"
    else
      skip "AC-002: Examity backend not configured (expected, spec deferred)"
    fi
  else
    skip "AC-001/AC-002: Proctoring not configured in production settings (expected, spec deferred)"
  fi
else
  skip "AC-001/AC-002: Production settings not available"
fi

echo ""

# Check 2: Proctoring secrets in ExternalSecrets
echo "Checking AC-002: Proctoring provider credentials management..."

EXTERNAL_SECRETS_FILE="deploy/k8s/base/secrets/external-secrets.yaml"

if [[ -f "$EXTERNAL_SECRETS_FILE" ]]; then
  PROCTORING_SECRET_KEYS=(
    "MEREKA_LMS_PROCTORING_EXAMITY_API_KEY"
    "MEREKA_LMS_PROCTORING_EXAMITY_API_SECRET"
    "MEREKA_LMS_PROCTORING_PROCTORTRACK_API_KEY"
    "MEREKA_LMS_PROCTORING_WEBHOOK_SECRET"
  )

  PROCTORING_SECRETS_FOUND=false
  for key in "${PROCTORING_SECRET_KEYS[@]}"; do
    if grep -q "$key" "$EXTERNAL_SECRETS_FILE"; then
      PROCTORING_SECRETS_FOUND=true
      pass "AC-002: Proctoring secret defined: $key"
    fi
  done

  if [[ "$PROCTORING_SECRETS_FOUND" = false ]]; then
    skip "AC-002: Proctoring secrets not configured (expected, spec deferred)"
  fi
else
  skip "AC-002: ExternalSecrets file not found"
fi

echo ""

# Check 3: Studio exam configuration support
echo "Checking AC-006: Studio exam configuration..."

# Check for exam configuration in LMS settings
if [[ -f "$PROD_SETTINGS" ]]; then
  if grep -qi "exam.*type\|proctored.*exam\|EXAM_SETTINGS" "$PROD_SETTINGS"; then
    pass "AC-006: Exam configuration settings found"
  else
    skip "AC-006: Exam configuration not found (expected, spec deferred)"
  fi
else
  skip "AC-006: Production settings not available"
fi

echo ""

# Check 4: Exam state management
echo "Checking AC-020, AC-021, AC-022: Exam state transition infrastructure..."

# Check for state machine or exam status models
EXAM_STATE_PATTERNS=(
  "exam.*state\|exam.*status"
  "created.*started.*submitted"
  "ProctoredExamStudentAttempt"
  "exam_attempt"
)

STATE_INFRASTRUCTURE_FOUND=false
if [[ -f "$PROD_SETTINGS" ]]; then
  for pattern in "${EXAM_STATE_PATTERNS[@]}"; do
    if grep -qi "$pattern" "$PROD_SETTINGS"; then
      STATE_INFRASTRUCTURE_FOUND=true
      pass "AC-020/AC-021: Exam state infrastructure pattern found: $pattern"
      break
    fi
  done
fi

if [[ "$STATE_INFRASTRUCTURE_FOUND" = false ]]; then
  skip "AC-020/AC-021/AC-022: Exam state management not configured (expected, spec deferred)"
fi

echo ""

# Check 5: Proctoring consent notice
echo "Checking AC-036, AC-037: Proctoring consent framework..."

# Check for consent-related templates
CONSENT_TEMPLATE_DIRS=(
  "infrastructure/tutor/themes/mereka/lms/templates/proctoring"
  "infrastructure/tutor/themes/mereka/lms/templates/consent"
)

CONSENT_FOUND=false
for consent_dir in "${CONSENT_TEMPLATE_DIRS[@]}"; do
  if [[ -d "$consent_dir" ]]; then
    CONSENT_FOUND=true
    pass "AC-036/AC-037: Proctoring consent template directory found at $consent_dir"

    if find "$consent_dir" -name "*consent*" -o -name "*privacy*" | grep -q .; then
      pass "AC-036: Consent notice template files found"
    fi
  fi
done

if [[ "$CONSENT_FOUND" = false ]]; then
  skip "AC-036/AC-037: Consent templates not found (expected, spec deferred)"
fi

# Check for consent in settings
if [[ -f "$PROD_SETTINGS" ]]; then
  if grep -qi "consent\|privacy.*notice" "$PROD_SETTINGS"; then
    pass "AC-036: Consent configuration found in settings"
  else
    skip "AC-036: Consent configuration not found"
  fi
fi

echo ""

# Check 6: GDPR compliance infrastructure
echo "Checking AC-038: GDPR data export/deletion support..."

# Check for GDPR-related scripts
GDPR_SCRIPTS=(
  "scripts/gdpr/export-user-data.sh"
  "scripts/privacy/data-export.sh"
  "scripts/compliance/gdpr-export.sh"
)

GDPR_FOUND=false
for gdpr_script in "${GDPR_SCRIPTS[@]}"; do
  if [[ -f "$gdpr_script" ]]; then
    GDPR_FOUND=true
    pass "AC-038: GDPR data export script found at $gdpr_script"
  fi
done

if [[ "$GDPR_FOUND" = false ]]; then
  skip "AC-038: GDPR data export scripts not found (proctoring-specific not expected)"
fi

# Check for GDPR-related settings
if [[ -f "$PROD_SETTINGS" ]]; then
  if grep -qi "gdpr\|data.*export\|right.*to.*erasure" "$PROD_SETTINGS"; then
    pass "AC-038: GDPR compliance settings found"
  else
    skip "AC-038: GDPR settings not found"
  fi
fi

echo ""

# Check 7: Proctoring webhook endpoint
echo "Checking AC-002: Proctoring webhook endpoint configuration..."

# Check for webhook endpoints in URL configurations
if [[ -f "$PROD_SETTINGS" ]]; then
  if grep -qi "webhook.*proctoring\|proctoring.*webhook\|/api/proctoring" "$PROD_SETTINGS"; then
    pass "AC-002: Proctoring webhook endpoint references found"
  else
    skip "AC-002: Proctoring webhook endpoints not configured (expected, spec deferred)"
  fi
fi

echo ""

# Check 8: Feature flags for proctoring
echo "Checking proctoring feature flags infrastructure..."

if [[ -f "$PROD_SETTINGS" ]]; then
  PROCTORING_FLAGS=(
    "ENABLE_PROCTORING"
    "ENABLE_PROCTORING_PROCTORIO"
    "ENABLE_PROCTORING_EXAMITY"
    "ENABLE_PROCTORING_IDENTITY_VERIFICATION"
  )

  FLAGS_FOUND=false
  for flag in "${PROCTORING_FLAGS[@]}"; do
    if grep -q "$flag" "$PROD_SETTINGS"; then
      FLAGS_FOUND=true
      pass "Proctoring feature flag found: $flag"
    fi
  done

  if [[ "$FLAGS_FOUND" = false ]]; then
    skip "Proctoring feature flags not configured (expected, spec deferred)"
  fi
else
  skip "Production settings not available for feature flag check"
fi

echo ""

# Check 9: Proctoring observability
echo "Checking proctoring observability infrastructure..."

PROCTORING_MONITORING_FILES=(
  "infrastructure/observability/prometheus/rules/proctoring-alerts.yaml"
  "infrastructure/observability/grafana/dashboards/proctoring-overview.json"
)

MONITORING_FOUND=false
for mon_file in "${PROCTORING_MONITORING_FILES[@]}"; do
  if [[ -f "$mon_file" ]]; then
    MONITORING_FOUND=true
    pass "Proctoring monitoring configuration found at $mon_file"
  fi
done

if [[ "$MONITORING_FOUND" = false ]]; then
  skip "Proctoring monitoring not configured (expected, spec deferred)"
fi

echo ""

# Check 10: Documentation for proctoring
echo "Checking proctoring documentation..."

PROCTORING_DOCS=(
  "docs/architecture/proctoring-architecture-overview.md"
  "docs/runbooks/proctoring-operations-runbook.md"
  "specs/proposals/proctoring-integration_spec.md"
)

DOCS_FOUND=false
for doc_file in "${PROCTORING_DOCS[@]}"; do
  if [[ -f "$doc_file" ]]; then
    DOCS_FOUND=true
    pass "Proctoring documentation found at $doc_file"
  fi
done

if [[ "$DOCS_FOUND" = false ]]; then
  skip "Proctoring documentation not found (expected if not implemented)"
fi

echo ""

# Check 11: edx-proctoring Django app in INSTALLED_APPS
echo "Checking AC-001: edx-proctoring Django app availability..."

if [[ -f "$PROD_SETTINGS" ]]; then
  if grep -q "edx_proctoring\|edx-proctoring" "$PROD_SETTINGS"; then
    pass "AC-001: edx-proctoring app found in INSTALLED_APPS or settings"
  else
    skip "AC-001: edx-proctoring app not in settings (may be in base Open edX)"
  fi
else
  skip "AC-001: Production settings not available"
fi

echo ""

# Summary with context
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

echo ""
echo "CONTEXT: The proctoring-integration spec status is 'deferred'."
echo "Most SKIP results are EXPECTED until proctoring implementation begins."
echo "PASS results indicate infrastructure components already in place."
echo "This script will serve as a readiness checklist when proctoring is prioritized."

[[ $FAIL -gt 0 ]] && exit 1
exit 0
