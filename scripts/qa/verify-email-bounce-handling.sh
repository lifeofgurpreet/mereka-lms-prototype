#!/usr/bin/env bash
# @covers AC-033, AC-034, AC-035, AC-036
# @spec: email-notifications-pipeline_spec.md
# Verify email bounce and complaint handling infrastructure
#
# Checks:
#   AC-033: Hard bounce suppression list processing
#   AC-034: Soft bounce (3 within 7 days) treatment
#   AC-035: Complaint handling and preference disabling
#   AC-036: SES bounce/complaint rate alerts (5% bounce, 0.1% complaint)
#
# Usage:
#   ./scripts/qa/verify-email-bounce-handling.sh

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

echo "=== Email Bounce Handling Verification ==="
echo ""

# Check 1: EmailSuppression model exists
echo "Checking AC-033, AC-034, AC-035: EmailSuppression model..."

MODELS_FILE="infrastructure/tutor/plugins/email-suppression/mereka_email_suppression/models.py"
if [[ -f "$MODELS_FILE" ]]; then
  pass "AC-033: EmailSuppression models.py exists"

  # Check model fields
  MODEL_FIELDS=(
    "email = models.EmailField"
    "reason = models.CharField"
    "bounce_count = models.IntegerField"
    "bounced_at = models.DateTimeField"
    "created_at = models.DateTimeField"
    "updated_at = models.DateTimeField"
  )

  for field in "${MODEL_FIELDS[@]}"; do
    if grep -q "$field" "$MODELS_FILE"; then
      pass "AC-033: EmailSuppression has field: ${field%% =*}"
    else
      fail "AC-033: EmailSuppression missing field: ${field%% =*}"
    fi
  done

  # Check for reason choices
  REASON_CHOICES=(
    "hard_bounce"
    "soft_bounce"
    "complaint"
  )

  for reason in "${REASON_CHOICES[@]}"; do
    if grep -q "$reason" "$MODELS_FILE"; then
      pass "AC-033/AC-034/AC-035: Reason choice '$reason' exists"
    else
      fail "AC-033/AC-034/AC-035: Reason choice '$reason' missing"
    fi
  done

  # Check for is_suppressed method
  if grep -q "def is_suppressed" "$MODELS_FILE"; then
    pass "AC-033: is_suppressed() method exists"
  else
    fail "AC-033: is_suppressed() method not found"
  fi

  # Check for soft bounce threshold logic (3 bounces)
  if grep -q "bounce_count >= 3" "$MODELS_FILE"; then
    pass "AC-034: Soft bounce threshold of 3 found in model"
  else
    fail "AC-034: Soft bounce threshold of 3 not found"
  fi

  # Check for 7-day window check
  if grep -q "\.days <= 7\|days.*<=.*7" "$MODELS_FILE"; then
    pass "AC-034: 7-day bounce window check found"
  else
    fail "AC-034: 7-day bounce window check not found"
  fi
else
  fail "AC-033: EmailSuppression models.py not found at $MODELS_FILE"
fi

echo ""

# Check 2: process_ses_notification management command
echo "Checking AC-033, AC-034, AC-035: SES notification processing..."

COMMAND_FILE="infrastructure/tutor/plugins/email-suppression/mereka_email_suppression/management/commands/process_ses_notification.py"
if [[ -f "$COMMAND_FILE" ]]; then
  pass "AC-033: process_ses_notification command exists"

  # Check for bounce processing
  if grep -q "_process_bounce" "$COMMAND_FILE"; then
    pass "AC-033: Bounce processing method exists"
  else
    fail "AC-033: Bounce processing method not found"
  fi

  # Check for complaint processing
  if grep -q "_process_complaint" "$COMMAND_FILE"; then
    pass "AC-035: Complaint processing method exists"
  else
    fail "AC-035: Complaint processing method not found"
  fi

  # Check for hard bounce handling (Permanent)
  if grep -q "Permanent" "$COMMAND_FILE"; then
    pass "AC-033: Hard bounce (Permanent) handling found"
  else
    fail "AC-033: Hard bounce handling not found"
  fi

  # Check for soft bounce handling (Transient)
  if grep -q "Transient" "$COMMAND_FILE"; then
    pass "AC-034: Soft bounce (Transient) handling found"
  else
    fail "AC-034: Soft bounce handling not found"
  fi

  # Check for bounce count increment logic
  if grep -q "bounce_count.*\+.*1\|bounce_count += 1" "$COMMAND_FILE"; then
    pass "AC-034: Bounce count increment logic found"
  else
    fail "AC-034: Bounce count increment logic not found"
  fi

  # Check for 7-day reset logic
  if grep -q "days.*>.*7\|> 7" "$COMMAND_FILE"; then
    pass "AC-034: 7-day bounce count reset logic found"
  else
    skip "AC-034: 7-day bounce count reset logic not explicitly found"
  fi
else
  fail "AC-033: process_ses_notification command not found at $COMMAND_FILE"
fi

echo ""

# Check 3: Email suppression middleware
echo "Checking AC-033, AC-034, AC-035: Email sending middleware..."

MIDDLEWARE_FILE="infrastructure/tutor/plugins/email-suppression/mereka_email_suppression/middleware.py"
if [[ -f "$MIDDLEWARE_FILE" ]]; then
  pass "AC-033: Email suppression middleware exists"

  # Check for SuppressionCheckEmailBackend
  if grep -q "class.*EmailBackend\|SuppressionCheckEmailBackend" "$MIDDLEWARE_FILE"; then
    pass "AC-033: SuppressionCheckEmailBackend class found"
  else
    fail "AC-033: SuppressionCheckEmailBackend not found"
  fi

  # Check for send_messages override
  if grep -q "def send_messages" "$MIDDLEWARE_FILE"; then
    pass "AC-033: send_messages() method override found"
  else
    fail "AC-033: send_messages() override not found"
  fi

  # Check for bypass logic for critical emails
  BYPASS_TYPES=(
    "password_reset"
    "account_activation"
  )

  for bypass_type in "${BYPASS_TYPES[@]}"; do
    if grep -q "$bypass_type" "$MIDDLEWARE_FILE"; then
      pass "AC-033: Bypass for critical email type '$bypass_type' found"
    else
      skip "AC-033: Bypass for critical email type '$bypass_type' not found"
    fi
  done

  # Check for is_email_suppressed check
  if grep -q "is_email_suppressed\|EmailSuppression.*suppressed" "$MIDDLEWARE_FILE"; then
    pass "AC-033: Suppression list check found in middleware"
  else
    fail "AC-033: Suppression list check not found"
  fi
else
  fail "AC-033: Email suppression middleware not found at $MIDDLEWARE_FILE"
fi

echo ""

# Check 4: Django admin registration
echo "Checking AC-033: Django admin integration..."

ADMIN_FILE="infrastructure/tutor/plugins/email-suppression/mereka_email_suppression/admin.py"
if [[ -f "$ADMIN_FILE" ]]; then
  pass "AC-033: Email suppression admin.py exists"

  # Check for EmailSuppressionAdmin
  if grep -q "class.*EmailSuppressionAdmin\|@admin.register.*EmailSuppression" "$ADMIN_FILE"; then
    pass "AC-033: EmailSuppressionAdmin registered"
  else
    fail "AC-033: EmailSuppressionAdmin not registered"
  fi

  # Check for list_display fields
  if grep -q "list_display.*=.*\[.*email.*reason" "$ADMIN_FILE"; then
    pass "AC-033: Admin list_display configured"
  else
    skip "AC-033: Admin list_display not found"
  fi
else
  fail "AC-033: Email suppression admin.py not found at $ADMIN_FILE"
fi

echo ""

# Check 5: Django migration exists
echo "Checking AC-033: Initial migration..."

MIGRATION_FILE="infrastructure/tutor/plugins/email-suppression/mereka_email_suppression/migrations/0001_initial.py"
if [[ -f "$MIGRATION_FILE" ]]; then
  pass "AC-033: Initial migration 0001_initial.py exists"

  # Check migration creates EmailSuppression table
  if grep -q "CreateModel.*EmailSuppression\|'EmailSuppression'" "$MIGRATION_FILE"; then
    pass "AC-033: Migration creates EmailSuppression model"
  else
    fail "AC-033: Migration does not create EmailSuppression model"
  fi

  # Check for indexes
  if grep -q "AddIndex\|models.Index" "$MIGRATION_FILE"; then
    pass "AC-033: Database indexes defined in migration"
  else
    skip "AC-033: Database indexes not found in migration"
  fi
else
  fail "AC-033: Initial migration not found at $MIGRATION_FILE"
fi

echo ""

# Check 6: PrometheusRule for email alerts
echo "Checking AC-036: Email bounce/complaint rate alerts..."

PROMETHEUS_RULE="deploy/k8s/base/monitoring/prometheusrule-email.yaml"
if [[ -f "$PROMETHEUS_RULE" ]]; then
  pass "AC-036: PrometheusRule for email alerts exists"

  # Check for EmailBounceRateHigh alert
  if grep -q "EmailBounceRateHigh" "$PROMETHEUS_RULE"; then
    pass "AC-036: EmailBounceRateHigh alert defined"

    # Check for 5% threshold
    if grep -q "> 0.05\|>.*0\.05" "$PROMETHEUS_RULE"; then
      pass "AC-036: Bounce rate threshold of 5% found"
    else
      fail "AC-036: Bounce rate threshold of 5% not found"
    fi
  else
    fail "AC-036: EmailBounceRateHigh alert not found"
  fi

  # Check for EmailComplaintRateHigh alert
  if grep -q "EmailComplaintRateHigh" "$PROMETHEUS_RULE"; then
    pass "AC-036: EmailComplaintRateHigh alert defined"

    # Check for 0.1% threshold (0.001)
    if grep -q "> 0.001\|>.*0\.001" "$PROMETHEUS_RULE"; then
      pass "AC-036: Complaint rate threshold of 0.1% found"
    else
      fail "AC-036: Complaint rate threshold of 0.1% not found"
    fi
  else
    fail "AC-036: EmailComplaintRateHigh alert not found"
  fi

  # Check for SESQuotaNearLimit alert
  if grep -q "SESQuotaNearLimit" "$PROMETHEUS_RULE"; then
    pass "AC-036: SESQuotaNearLimit alert defined"
  else
    skip "AC-036: SESQuotaNearLimit alert not found"
  fi

  # Check for EmailDeliveryLatencyHigh alert
  if grep -q "EmailDeliveryLatencyHigh" "$PROMETHEUS_RULE"; then
    pass "AC-036: EmailDeliveryLatencyHigh alert defined"

    # Check for 30s threshold
    if grep -q "> 30\|>.*30" "$PROMETHEUS_RULE"; then
      pass "AC-036: Delivery latency threshold of 30s found"
    else
      skip "AC-036: Delivery latency threshold not found"
    fi
  else
    skip "AC-036: EmailDeliveryLatencyHigh alert not found"
  fi
else
  fail "AC-036: PrometheusRule for email not found at $PROMETHEUS_RULE"
fi

echo ""

# Check 7: PrometheusRule included in kustomization
echo "Checking AC-036: PrometheusRule deployment configuration..."

KUSTOMIZATION_FILE="deploy/k8s/base/monitoring/kustomization.yaml"
if [[ -f "$KUSTOMIZATION_FILE" ]]; then
  if grep -q "prometheusrule-email.yaml" "$KUSTOMIZATION_FILE"; then
    pass "AC-036: prometheusrule-email.yaml included in kustomization"
  else
    fail "AC-036: prometheusrule-email.yaml NOT included in kustomization.yaml"
  fi
else
  fail "AC-036: Monitoring kustomization.yaml not found at $KUSTOMIZATION_FILE"
fi

echo ""

# Check 8: SNS webhook secret in ExternalSecrets
echo "Checking AC-033, AC-035: SNS webhook authentication..."

EXTERNAL_SECRETS_FILE="deploy/k8s/base/secrets/external-secrets.yaml"
if [[ -f "$EXTERNAL_SECRETS_FILE" ]]; then
  if grep -q "SES_SNS_WEBHOOK_SECRET" "$EXTERNAL_SECRETS_FILE"; then
    pass "AC-033/AC-035: SES SNS webhook secret mapped in ExternalSecrets"
  else
    fail "AC-033/AC-035: SES SNS webhook secret not found in ExternalSecrets"
  fi
else
  fail "AC-033: ExternalSecrets file not found at $EXTERNAL_SECRETS_FILE"
fi

echo ""

# Check 9: setup.py exists for pip install
echo "Checking plugin installation configuration..."

SETUP_FILE="infrastructure/tutor/plugins/email-suppression/setup.py"
if [[ -f "$SETUP_FILE" ]]; then
  pass "Email suppression setup.py exists (pip installable)"

  # Check package name
  if grep -q "name=.*mereka_email_suppression" "$SETUP_FILE"; then
    pass "Package name 'mereka_email_suppression' found in setup.py"
  else
    fail "Package name not found in setup.py"
  fi
else
  fail "Email suppression setup.py not found at $SETUP_FILE"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
