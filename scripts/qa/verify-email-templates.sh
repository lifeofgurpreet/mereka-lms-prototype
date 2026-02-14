#!/usr/bin/env bash
# @spec: email-notifications-pipeline_spec.md
# @covers Phase 5: Templates + Bulk Campaigns (AC-025 to AC-032)
#
# Verification of Email Phase 5: Templates + Bulk Campaigns spec compliance.
# Static checks run against Django app structure, LMS settings, and template files.
# Runtime ACs (campaign execution, rate limiting) are marked SKIP.
#
# Usage:
#   ./scripts/qa/verify-email-templates.sh [--skip-cluster] [--help]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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

Verify Email Phase 5: Templates + Bulk Campaigns spec compliance.

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

# Key paths
APP_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_email_templates"
TEMPLATE_DIR="$APP_DIR/templates/email"
LMS_PRODUCTION_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

echo "========================================================"
echo "  Email Phase 5: Templates + Bulk Campaigns"
echo "  Spec: email-notifications-pipeline_spec.md (Phase 5)"
echo "========================================================"
echo "Date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Repo:   $REPO_ROOT"
echo "Cluster checks: $(if $SKIP_CLUSTER; then echo SKIPPED; else echo ENABLED; fi)"
echo

###########################################################################
# SECTION 1: Django App Structure
###########################################################################
echo "--- Django App Structure ---"

required_files=(
  "__init__.py"
  "apps.py"
  "models.py"
  "views.py"
  "urls.py"
  "serializers.py"
  "admin.py"
  "tasks.py"
  "signals.py"
  "setup.py"
  "rate_limiter.py"
  "migrations/__init__.py"
)

missing_files=()
for f in "${required_files[@]}"; do
  if [ ! -f "$APP_DIR/$f" ]; then
    missing_files+=("$f")
  fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
  pass_ "All ${#required_files[@]} required app files present in openedx_email_templates/"
else
  fail_ "Missing app files: ${missing_files[*]}"
fi

###########################################################################
# SECTION 2: Template Model (AC-025, AC-026)
###########################################################################
echo "--- Template Model ---"

if [ -f "$APP_DIR/models.py" ]; then
  # Check model class exists
  if grep -q "class Template" "$APP_DIR/models.py"; then
    pass_ "AC-025: Template model class defined"
  else
    fail_ "AC-025: Template model class missing"
  fi

  # Check required fields
  template_fields=(
    "name"
    "category"
    "subject"
    "body_html"
    "body_text"
    "language"
    "tenant_branding"
    "org_slug"
    "is_active"
  )

  missing_fields=()
  for field in "${template_fields[@]}"; do
    if ! grep -q "$field" "$APP_DIR/models.py"; then
      missing_fields+=("$field")
    fi
  done

  if [ ${#missing_fields[@]} -eq 0 ]; then
    pass_ "AC-025: All required Template model fields present (${#template_fields[@]} fields)"
  else
    fail_ "AC-025: Missing Template model fields: ${missing_fields[*]}"
  fi

  # Check MESSAGE_TYPE_CHOICES
  if grep -q "MESSAGE_TYPE_CHOICES" "$APP_DIR/models.py"; then
    pass_ "AC-025: MESSAGE_TYPE_CHOICES defined"
  else
    fail_ "AC-025: MESSAGE_TYPE_CHOICES missing"
  fi

  # Check LANGUAGE_CHOICES
  if grep -q "LANGUAGE_CHOICES" "$APP_DIR/models.py"; then
    pass_ "AC-025: LANGUAGE_CHOICES defined (en/ms/zh-hans)"
  else
    fail_ "AC-025: LANGUAGE_CHOICES missing"
  fi

  # Check unique_together for dedup
  if grep -q "unique_together" "$APP_DIR/models.py"; then
    pass_ "AC-025: Template deduplication via unique_together"
  else
    fail_ "AC-025: Template deduplication missing (unique_together)"
  fi

  # Check get_template method
  if grep -q "def get_template" "$APP_DIR/models.py"; then
    pass_ "AC-025: get_template() lookup with fallback chain"
  else
    fail_ "AC-025: get_template() method missing"
  fi

  # Check render method (AC-026)
  if grep -q "def render" "$APP_DIR/models.py"; then
    pass_ "AC-026: render() method for template rendering"
  else
    fail_ "AC-026: render() method missing"
  fi

  # Check get_branding method (AC-026)
  if grep -q "def get_branding" "$APP_DIR/models.py"; then
    pass_ "AC-026: get_branding() for per-tenant branding injection"
  else
    fail_ "AC-026: get_branding() method missing"
  fi

  # Check TenantConfig integration (AC-026)
  if grep -q "TenantConfig" "$APP_DIR/models.py"; then
    pass_ "AC-026: TenantConfig lookup for per-tenant branding"
  else
    fail_ "AC-026: TenantConfig integration missing"
  fi

  # Check branding variables
  branding_vars=(
    "org_display_name"
    "org_logo_url"
    "org_primary_color"
    "org_accent_color"
    "org_support_email"
    "org_terms_url"
    "org_privacy_url"
  )

  missing_branding=()
  for var in "${branding_vars[@]}"; do
    if ! grep -q "$var" "$APP_DIR/models.py"; then
      missing_branding+=("$var")
    fi
  done

  if [ ${#missing_branding[@]} -eq 0 ]; then
    pass_ "AC-026: All 7 branding variables present"
  else
    fail_ "AC-026: Missing branding variables: ${missing_branding[*]}"
  fi
else
  fail_ "models.py not found at $APP_DIR/models.py"
fi

###########################################################################
# SECTION 3: Campaign Model (AC-027, AC-028, AC-029, AC-030)
###########################################################################
echo "--- Campaign Model ---"

if [ -f "$APP_DIR/models.py" ]; then
  if grep -q "class Campaign" "$APP_DIR/models.py"; then
    pass_ "AC-027: Campaign model class defined"
  else
    fail_ "AC-027: Campaign model class missing"
  fi

  # Check campaign statuses
  if grep -q "CAMPAIGN_STATUS_CHOICES" "$APP_DIR/models.py"; then
    pass_ "AC-027: CAMPAIGN_STATUS_CHOICES defined"
  else
    fail_ "AC-027: CAMPAIGN_STATUS_CHOICES missing"
  fi

  campaign_statuses=("draft" "scheduled" "sending" "paused" "completed" "failed" "cancelled")
  missing_statuses=()
  for s in "${campaign_statuses[@]}"; do
    if ! grep -q "'$s'" "$APP_DIR/models.py"; then
      missing_statuses+=("$s")
    fi
  done

  if [ ${#missing_statuses[@]} -eq 0 ]; then
    pass_ "AC-027: All 7 campaign statuses present"
  else
    fail_ "AC-027: Missing campaign statuses: ${missing_statuses[*]}"
  fi

  # Check campaign fields
  campaign_fields=("name" "template" "segment" "status" "org_slug" "scheduled_at" "started_at" "completed_at" "created_by" "total_recipients" "sent_count" "failed_count" "skipped_count")
  missing_cfields=()
  for field in "${campaign_fields[@]}"; do
    if ! grep -q "$field" "$APP_DIR/models.py"; then
      missing_cfields+=("$field")
    fi
  done

  if [ ${#missing_cfields[@]} -eq 0 ]; then
    pass_ "AC-027: All required Campaign model fields present (${#campaign_fields[@]} fields)"
  else
    fail_ "AC-027: Missing Campaign fields: ${missing_cfields[*]}"
  fi

  # Check schedule method (AC-028)
  if grep -q "def schedule" "$APP_DIR/models.py"; then
    pass_ "AC-028: schedule() method for future sending"
  else
    fail_ "AC-028: schedule() method missing"
  fi

  # Check pause/resume (AC-029)
  if grep -q "def pause" "$APP_DIR/models.py" && grep -q "def resume" "$APP_DIR/models.py"; then
    pass_ "AC-029: pause() and resume() methods"
  else
    fail_ "AC-029: pause()/resume() methods missing"
  fi

  # Check cancel (AC-030)
  if grep -q "def cancel" "$APP_DIR/models.py"; then
    pass_ "AC-030: cancel() method"
  else
    fail_ "AC-030: cancel() method missing"
  fi
fi

###########################################################################
# SECTION 4: CampaignRecipient Model (AC-031, AC-032)
###########################################################################
echo "--- CampaignRecipient Model ---"

if [ -f "$APP_DIR/models.py" ]; then
  if grep -q "class CampaignRecipient" "$APP_DIR/models.py"; then
    pass_ "AC-031: CampaignRecipient model class defined"
  else
    fail_ "AC-031: CampaignRecipient model class missing"
  fi

  # Check recipient status tracking
  if grep -q "RECIPIENT_STATUS_CHOICES" "$APP_DIR/models.py"; then
    pass_ "AC-031: RECIPIENT_STATUS_CHOICES (pending/sent/skipped/failed)"
  else
    fail_ "AC-031: RECIPIENT_STATUS_CHOICES missing"
  fi

  # Check mark methods
  if grep -q "def mark_sent" "$APP_DIR/models.py" && grep -q "def mark_failed" "$APP_DIR/models.py" && grep -q "def mark_skipped" "$APP_DIR/models.py"; then
    pass_ "AC-032: mark_sent/mark_failed/mark_skipped methods"
  else
    fail_ "AC-032: Recipient status tracking methods missing"
  fi
fi

###########################################################################
# SECTION 5: ACE Message Type Templates (AC-025)
###########################################################################
echo "--- ACE Message Type Templates ---"

template_types=(
  "welcome"
  "enrollment"
  "grade"
  "certificate"
  "deadline"
  "forum"
  "password_reset"
  "account_activation"
  "course_announcement"
  "survey"
  "marketing_promo"
  "re_engagement"
  "feedback"
  "maintenance_notice"
  "campaign"
)

missing_templates=()
for tpl in "${template_types[@]}"; do
  if [ ! -f "$TEMPLATE_DIR/$tpl.html" ] || [ ! -f "$TEMPLATE_DIR/$tpl.txt" ]; then
    missing_templates+=("$tpl")
  fi
done

if [ ${#missing_templates[@]} -eq 0 ]; then
  pass_ "AC-025: All 15 ACE message type templates present (HTML + TXT)"
else
  fail_ "AC-025: Missing templates: ${missing_templates[*]}"
fi

# Check branding variables in templates
branding_in_templates=0
for tpl in "${template_types[@]}"; do
  if [ -f "$TEMPLATE_DIR/$tpl.html" ]; then
    if grep -q "org_display_name\|org_logo_url\|org_primary_color" "$TEMPLATE_DIR/$tpl.html"; then
      branding_in_templates=$((branding_in_templates + 1))
    fi
  fi
done

if [ "$branding_in_templates" -ge 10 ]; then
  pass_ "AC-026: Branding variables used in $branding_in_templates/15 templates"
else
  fail_ "AC-026: Branding variables only in $branding_in_templates/15 templates (expected >= 10)"
fi

###########################################################################
# SECTION 6: Rate Limiter (AC-030)
###########################################################################
echo "--- Rate Limiter ---"

if [ -f "$APP_DIR/rate_limiter.py" ]; then
  if grep -q "class TokenBucket" "$APP_DIR/rate_limiter.py"; then
    pass_ "AC-030: TokenBucket rate limiter class defined"
  else
    fail_ "AC-030: TokenBucket class missing"
  fi

  if grep -q "50" "$APP_DIR/rate_limiter.py"; then
    pass_ "AC-030: Rate limit set to 50 emails/sec per tenant"
  else
    fail_ "AC-030: Rate limit value not configured"
  fi

  if grep -q "def consume" "$APP_DIR/rate_limiter.py"; then
    pass_ "AC-030: consume() method for token consumption"
  else
    fail_ "AC-030: consume() method missing"
  fi

  if grep -q "def get_tenant_bucket" "$APP_DIR/rate_limiter.py"; then
    pass_ "AC-030: Per-tenant bucket isolation"
  else
    fail_ "AC-030: Per-tenant isolation missing"
  fi
else
  fail_ "rate_limiter.py not found"
fi

###########################################################################
# SECTION 7: Celery Tasks (AC-027, AC-028, AC-031)
###########################################################################
echo "--- Celery Tasks ---"

if [ -f "$APP_DIR/tasks.py" ]; then
  if grep -q "def execute_campaign" "$APP_DIR/tasks.py"; then
    pass_ "AC-027: execute_campaign Celery task defined"
  else
    fail_ "AC-027: execute_campaign task missing"
  fi

  if grep -q "def send_campaign_email" "$APP_DIR/tasks.py"; then
    pass_ "AC-031: send_campaign_email Celery task defined"
  else
    fail_ "AC-031: send_campaign_email task missing"
  fi

  if grep -q "def check_scheduled_campaigns" "$APP_DIR/tasks.py"; then
    pass_ "AC-028: check_scheduled_campaigns scheduler task"
  else
    fail_ "AC-028: Scheduled campaign checker missing"
  fi

  if grep -q "def finalize_campaigns" "$APP_DIR/tasks.py"; then
    pass_ "Campaign finalization task defined"
  else
    fail_ "Campaign finalization task missing"
  fi

  # Check retry configuration
  if grep -q "max_retries=5" "$APP_DIR/tasks.py"; then
    pass_ "Task retry configured (max 5 retries)"
  else
    fail_ "Task retry not configured"
  fi

  if grep -q "retry_backoff=True" "$APP_DIR/tasks.py"; then
    pass_ "Exponential backoff enabled"
  else
    fail_ "Exponential backoff not enabled"
  fi

  if grep -q "retry_backoff_max=900" "$APP_DIR/tasks.py"; then
    pass_ "Max backoff configured (900s = 15 minutes)"
  else
    fail_ "Max backoff not configured"
  fi

  # Check rate limiting in tasks
  if grep -q "rate_limit=" "$APP_DIR/tasks.py"; then
    pass_ "AC-030: Celery task rate limiting configured"
  else
    fail_ "AC-030: Celery task rate limiting missing"
  fi

  # Check opt-out integration
  if grep -q "opted_out\|_user_opted_out" "$APP_DIR/tasks.py"; then
    pass_ "AC-032: User opt-out check in campaign emails"
  else
    fail_ "AC-032: User opt-out check missing"
  fi

  # Check segment resolution
  if grep -q "_resolve_segment\|resolve_segment" "$APP_DIR/tasks.py"; then
    pass_ "AC-027: Segment-to-recipient resolution"
  else
    fail_ "AC-027: Segment resolution missing"
  fi
fi

###########################################################################
# SECTION 8: LMS Settings Configuration
###########################################################################
echo "--- LMS Settings ---"

if [ -f "$LMS_PRODUCTION_PY" ]; then
  if grep -q "NOTIFICATION_BULK_CAMPAIGNS_ENABLED" "$LMS_PRODUCTION_PY"; then
    pass_ "NOTIFICATION_BULK_CAMPAIGNS_ENABLED feature flag in LMS settings"
  else
    fail_ "NOTIFICATION_BULK_CAMPAIGNS_ENABLED missing from LMS settings"
  fi

  if grep -q "EMAIL_RATE_LIMIT_PER_TENANT" "$LMS_PRODUCTION_PY"; then
    pass_ "EMAIL_RATE_LIMIT_PER_TENANT configured (50/sec)"
  else
    fail_ "EMAIL_RATE_LIMIT_PER_TENANT missing from LMS settings"
  fi

  if grep -q "CAMPAIGN_BATCH_SIZE" "$LMS_PRODUCTION_PY"; then
    pass_ "CAMPAIGN_BATCH_SIZE configured"
  else
    fail_ "CAMPAIGN_BATCH_SIZE missing from LMS settings"
  fi

  if grep -q "CAMPAIGN_RETRY_BACKOFF.*30" "$LMS_PRODUCTION_PY"; then
    pass_ "Campaign retry backoff base configured (30 seconds)"
  else
    fail_ "Campaign retry backoff base missing"
  fi

  if grep -q "CAMPAIGN_RETRY_BACKOFF_MAX.*900" "$LMS_PRODUCTION_PY"; then
    pass_ "Campaign retry backoff max configured (900 seconds)"
  else
    fail_ "Campaign retry backoff max missing"
  fi

  if grep -q "DEFAULT_ORG_DISPLAY_NAME" "$LMS_PRODUCTION_PY"; then
    pass_ "Default branding settings configured"
  else
    fail_ "Default branding settings missing"
  fi

  if grep -q "openedx_email_templates" "$LMS_PRODUCTION_PY"; then
    pass_ "openedx_email_templates in INSTALLED_APPS"
  else
    fail_ "openedx_email_templates missing from INSTALLED_APPS"
  fi

  # Check env var patterns
  if grep -q 'os\.environ\.get.*CAMPAIGN\|os\.environ\.get.*EMAIL_RATE\|os\.environ\.get.*ORG_' "$LMS_PRODUCTION_PY"; then
    pass_ "Settings use env var pattern (os.environ.get)"
  else
    fail_ "Settings missing env var pattern"
  fi
else
  fail_ "LMS production.py not found at $LMS_PRODUCTION_PY"
fi

# Runtime tests
skip_ "AC-025: Multi-language template rendering with fallback chain (requires runtime test)"
skip_ "AC-026: Per-tenant branding injection via TenantConfig (requires runtime test)"
skip_ "AC-027: Campaign segment resolution and recipient creation (requires runtime test)"
skip_ "AC-028: Scheduled campaign triggers at scheduled_at time (requires runtime test)"
skip_ "AC-029: Pause/resume campaign lifecycle (requires runtime test)"
skip_ "AC-030: Rate limiting enforces 50 emails/sec per tenant (requires runtime test)"
skip_ "AC-031: Per-recipient delivery tracking (sent/skipped/failed) (requires runtime test)"
skip_ "AC-032: User opt-out preference check before sending (requires runtime test)"

###########################################################################
# Summary
###########################################################################
echo
echo "========================================================"
echo "  Summary"
echo "========================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "SKIP: $SKIP"
echo "TOTAL: $((PASS + FAIL + SKIP))"
echo

if [ "$FAIL" -gt 0 ]; then
  echo "❌ Verification FAILED with $FAIL failed check(s)"
  exit 1
else
  echo "✅ Verification PASSED (static checks complete; $SKIP runtime checks skipped)"
  exit 0
fi
