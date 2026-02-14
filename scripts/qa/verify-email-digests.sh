#!/usr/bin/env bash
# @spec: email-notifications-pipeline_spec.md
# @covers Phase 6: Digests + Analytics (AC-037 to AC-042)
#
# Verification of Email Phase 6: Digests + Analytics spec compliance.
# Static checks run against Django app structure, LMS settings, and config files.
# Runtime ACs (digest delivery, click tracking, analytics queries) are marked SKIP.
#
# Usage:
#   ./scripts/qa/verify-email-digests.sh [--skip-cluster] [--help]
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

Verify Email Phase 6: Digests + Analytics spec compliance.

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
APP_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_email_digests"
LMS_PRODUCTION_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

echo "========================================================"
echo "  Email Phase 6: Digests + Analytics"
echo "  Spec: email-notifications-pipeline_spec.md (Phase 6)"
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
  "migrations/__init__.py"
  "templates/email/digest.html"
  "templates/email/digest.txt"
)

missing_files=()
for f in "${required_files[@]}"; do
  if [ ! -f "$APP_DIR/$f" ]; then
    missing_files+=("$f")
  fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
  pass_ "All ${#required_files[@]} required app files present in openedx_email_digests/"
else
  fail_ "Missing app files: ${missing_files[*]}"
fi

###########################################################################
# SECTION 2: DigestPreference Model (AC-037, AC-038)
###########################################################################
echo "--- DigestPreference Model ---"

if [ -f "$APP_DIR/models.py" ]; then
  if grep -q "class DigestPreference" "$APP_DIR/models.py"; then
    pass_ "AC-037: DigestPreference model class defined"
  else
    fail_ "AC-037: DigestPreference model class missing"
  fi

  # Check required fields
  pref_fields=("user" "frequency" "org_slug" "message_types" "user_timezone" "is_active")
  missing_fields=()
  for field in "${pref_fields[@]}"; do
    if ! grep -q "$field" "$APP_DIR/models.py"; then
      missing_fields+=("$field")
    fi
  done

  if [ ${#missing_fields[@]} -eq 0 ]; then
    pass_ "AC-037: All required DigestPreference fields present (${#pref_fields[@]} fields)"
  else
    fail_ "AC-037: Missing DigestPreference fields: ${missing_fields[*]}"
  fi

  # Check frequency choices
  if grep -q "DIGEST_FREQUENCY_CHOICES" "$APP_DIR/models.py"; then
    pass_ "AC-037: DIGEST_FREQUENCY_CHOICES defined"
  else
    fail_ "AC-037: DIGEST_FREQUENCY_CHOICES missing"
  fi

  freq_values=("none" "daily" "weekly")
  missing_freq=()
  for f in "${freq_values[@]}"; do
    if ! grep -q "'$f'" "$APP_DIR/models.py"; then
      missing_freq+=("$f")
    fi
  done

  if [ ${#missing_freq[@]} -eq 0 ]; then
    pass_ "AC-037: All digest frequencies present (none/daily/weekly)"
  else
    fail_ "AC-037: Missing frequencies: ${missing_freq[*]}"
  fi

  # Check unique_together
  if grep -q "unique_together" "$APP_DIR/models.py"; then
    pass_ "AC-037: DigestPreference unique_together constraint"
  else
    fail_ "AC-037: unique_together constraint missing"
  fi

  # Check suppress immediate method (AC-038)
  if grep -q "should_suppress_immediate" "$APP_DIR/models.py"; then
    pass_ "AC-038: should_suppress_immediate() method for digest suppression"
  else
    fail_ "AC-038: should_suppress_immediate() method missing"
  fi

  # Check default timezone (spec: Asia/Kuala_Lumpur)
  if grep -q "Asia/Kuala_Lumpur" "$APP_DIR/models.py"; then
    pass_ "AC-037: Default timezone set to Asia/Kuala_Lumpur"
  else
    fail_ "AC-037: Default timezone not set to Asia/Kuala_Lumpur"
  fi

  # Check get_users_for_digest
  if grep -q "get_users_for_digest" "$APP_DIR/models.py"; then
    pass_ "AC-037: get_users_for_digest() query method"
  else
    fail_ "AC-037: get_users_for_digest() missing"
  fi
else
  fail_ "models.py not found at $APP_DIR/models.py"
fi

###########################################################################
# SECTION 3: DigestRun Model
###########################################################################
echo "--- DigestRun Model ---"

if [ -f "$APP_DIR/models.py" ]; then
  if grep -q "class DigestRun" "$APP_DIR/models.py"; then
    pass_ "DigestRun model class defined"
  else
    fail_ "DigestRun model class missing"
  fi

  run_fields=("run_id" "frequency" "period_start" "period_end" "org_slug" "status" "total_users" "emails_sent" "emails_skipped" "emails_failed")
  missing_run=()
  for field in "${run_fields[@]}"; do
    if ! grep -q "$field" "$APP_DIR/models.py"; then
      missing_run+=("$field")
    fi
  done

  if [ ${#missing_run[@]} -eq 0 ]; then
    pass_ "All DigestRun fields present (${#run_fields[@]} fields)"
  else
    fail_ "Missing DigestRun fields: ${missing_run[*]}"
  fi

  # Check run status choices
  if grep -q "DIGEST_RUN_STATUS_CHOICES" "$APP_DIR/models.py"; then
    pass_ "DigestRun status choices defined (pending/running/completed/failed)"
  else
    fail_ "DigestRun status choices missing"
  fi

  # Check mark methods
  if grep -q "def mark_running" "$APP_DIR/models.py" && grep -q "def mark_completed" "$APP_DIR/models.py" && grep -q "def mark_failed" "$APP_DIR/models.py"; then
    pass_ "DigestRun lifecycle methods (mark_running/completed/failed)"
  else
    fail_ "DigestRun lifecycle methods missing"
  fi
fi

###########################################################################
# SECTION 4: EmailEvent Model (AC-040, AC-041, AC-042)
###########################################################################
echo "--- EmailEvent Model ---"

if [ -f "$APP_DIR/models.py" ]; then
  if grep -q "class EmailEvent" "$APP_DIR/models.py"; then
    pass_ "AC-040: EmailEvent model class defined"
  else
    fail_ "AC-040: EmailEvent model class missing"
  fi

  # Check event type choices
  if grep -q "EMAIL_EVENT_TYPE_CHOICES" "$APP_DIR/models.py"; then
    pass_ "AC-040: EMAIL_EVENT_TYPE_CHOICES defined"
  else
    fail_ "AC-040: EMAIL_EVENT_TYPE_CHOICES missing"
  fi

  event_types=("send" "delivery" "bounce" "complaint" "open" "click" "reject")
  missing_events=()
  for et in "${event_types[@]}"; do
    if ! grep -q "'$et'" "$APP_DIR/models.py"; then
      missing_events+=("$et")
    fi
  done

  if [ ${#missing_events[@]} -eq 0 ]; then
    pass_ "AC-040: All 7 email event types present"
  else
    fail_ "AC-040: Missing event types: ${missing_events[*]}"
  fi

  # Check required fields
  event_fields=("message_id" "event_type" "user" "campaign_id" "template_category" "org_slug" "tracking_id" "url" "bounce_type" "timestamp")
  missing_efields=()
  for field in "${event_fields[@]}"; do
    if ! grep -q "$field" "$APP_DIR/models.py"; then
      missing_efields+=("$field")
    fi
  done

  if [ ${#missing_efields[@]} -eq 0 ]; then
    pass_ "AC-040: All EmailEvent fields present (${#event_fields[@]} fields)"
  else
    fail_ "AC-040: Missing EmailEvent fields: ${missing_efields[*]}"
  fi

  # Check record_event method
  if grep -q "def record_event" "$APP_DIR/models.py"; then
    pass_ "AC-040: record_event() class method"
  else
    fail_ "AC-040: record_event() missing"
  fi

  # Check get_aggregate_stats (AC-042)
  if grep -q "def get_aggregate_stats" "$APP_DIR/models.py"; then
    pass_ "AC-042: get_aggregate_stats() for analytics dashboard"
  else
    fail_ "AC-042: get_aggregate_stats() missing"
  fi

  # Check computed rates
  rates=("open_rate" "click_rate" "bounce_rate" "delivery_rate" "complaint_rate")
  missing_rates=()
  for rate in "${rates[@]}"; do
    if ! grep -q "$rate" "$APP_DIR/models.py"; then
      missing_rates+=("$rate")
    fi
  done

  if [ ${#missing_rates[@]} -eq 0 ]; then
    pass_ "AC-042: All engagement rates computed (${#rates[@]} rates)"
  else
    fail_ "AC-042: Missing rates: ${missing_rates[*]}"
  fi

  # Check per-tenant isolation (AC-042)
  if grep -q "org_slug=org_slug" "$APP_DIR/models.py"; then
    pass_ "AC-042: Per-tenant analytics isolation via org_slug"
  else
    fail_ "AC-042: Per-tenant analytics isolation missing"
  fi

  # Check purge method (12-month retention)
  if grep -q "def purge_old_events" "$APP_DIR/models.py"; then
    pass_ "12-month data retention purge method"
  else
    fail_ "Data retention purge method missing"
  fi

  if grep -q "retention_months=12" "$APP_DIR/models.py"; then
    pass_ "Default retention period set to 12 months"
  else
    fail_ "Default retention period not 12 months"
  fi
fi

###########################################################################
# SECTION 5: Click/Open Tracking Endpoints (AC-040, AC-041)
###########################################################################
echo "--- Click/Open Tracking ---"

if [ -f "$APP_DIR/views.py" ]; then
  if grep -q "class ClickTrackingView" "$APP_DIR/views.py"; then
    pass_ "AC-041: ClickTrackingView endpoint defined"
  else
    fail_ "AC-041: ClickTrackingView missing"
  fi

  if grep -q "class OpenTrackingView" "$APP_DIR/views.py"; then
    pass_ "AC-040: OpenTrackingView endpoint defined"
  else
    fail_ "AC-040: OpenTrackingView missing"
  fi

  # Check tracking pixel
  if grep -q "TRACKING_PIXEL" "$APP_DIR/views.py"; then
    pass_ "AC-040: 1x1 transparent tracking pixel defined"
  else
    fail_ "AC-040: Tracking pixel missing"
  fi

  # Check redirect behavior
  if grep -q "HttpResponseRedirect" "$APP_DIR/views.py"; then
    pass_ "AC-041: Click tracking redirects to original URL"
  else
    fail_ "AC-041: Click redirect missing"
  fi

  # Check analytics dashboard
  if grep -q "class EmailAnalyticsDashboardView" "$APP_DIR/views.py"; then
    pass_ "AC-042: EmailAnalyticsDashboardView defined"
  else
    fail_ "AC-042: Analytics dashboard view missing"
  fi

  # Check admin-only access
  if grep -q "IsAdminUser" "$APP_DIR/views.py"; then
    pass_ "AC-042: Analytics dashboard requires admin access"
  else
    fail_ "AC-042: Analytics dashboard missing admin access control"
  fi
fi

if [ -f "$APP_DIR/urls.py" ]; then
  if grep -q "track/click" "$APP_DIR/urls.py"; then
    pass_ "AC-041: Click tracking URL route configured"
  else
    fail_ "AC-041: Click tracking URL route missing"
  fi

  if grep -q "track/open" "$APP_DIR/urls.py"; then
    pass_ "AC-040: Open tracking URL route configured"
  else
    fail_ "AC-040: Open tracking URL route missing"
  fi

  if grep -q "analytics" "$APP_DIR/urls.py"; then
    pass_ "AC-042: Analytics dashboard URL route configured"
  else
    fail_ "AC-042: Analytics URL route missing"
  fi
fi

###########################################################################
# SECTION 6: Celery Tasks (AC-037, AC-039)
###########################################################################
echo "--- Celery Tasks ---"

if [ -f "$APP_DIR/tasks.py" ]; then
  if grep -q "def generate_daily_digest" "$APP_DIR/tasks.py"; then
    pass_ "AC-037: generate_daily_digest Celery task defined"
  else
    fail_ "AC-037: generate_daily_digest task missing"
  fi

  if grep -q "def generate_weekly_digest" "$APP_DIR/tasks.py"; then
    pass_ "AC-037: generate_weekly_digest Celery task defined"
  else
    fail_ "AC-037: generate_weekly_digest task missing"
  fi

  if grep -q "def purge_old_events" "$APP_DIR/tasks.py"; then
    pass_ "Engagement data purge task defined"
  else
    fail_ "Engagement data purge task missing"
  fi

  if grep -q "def gdpr_delete_user_data" "$APP_DIR/tasks.py"; then
    pass_ "GDPR user data deletion task defined"
  else
    fail_ "GDPR deletion task missing"
  fi

  # Check timezone-aware scheduling
  if grep -q "_is_digest_time_for_user" "$APP_DIR/tasks.py"; then
    pass_ "AC-037: Timezone-aware digest scheduling"
  else
    fail_ "AC-037: Timezone-aware scheduling missing"
  fi

  # Check course grouping and dedup (AC-039)
  if grep -q "grouped" "$APP_DIR/tasks.py" && grep -q "course" "$APP_DIR/tasks.py"; then
    pass_ "AC-039: Digest groups notifications by course"
  else
    fail_ "AC-039: Course grouping missing"
  fi

  if grep -q "dedup\|count.*new\|new replies" "$APP_DIR/tasks.py"; then
    pass_ "AC-039: Digest deduplicates repeated notifications"
  else
    fail_ "AC-039: Deduplication missing"
  fi

  # Check idempotency
  if grep -q "already exists" "$APP_DIR/tasks.py"; then
    pass_ "Digest run idempotency check"
  else
    fail_ "Digest run idempotency missing"
  fi

  # Check retry config
  if grep -q "max_retries=3" "$APP_DIR/tasks.py"; then
    pass_ "Digest task retry configured"
  else
    fail_ "Digest task retry not configured"
  fi
fi

###########################################################################
# SECTION 7: LMS Settings Configuration
###########################################################################
echo "--- LMS Settings ---"

if [ -f "$LMS_PRODUCTION_PY" ]; then
  if grep -q "ENABLE_EMAIL_DIGESTS" "$LMS_PRODUCTION_PY"; then
    pass_ "ENABLE_EMAIL_DIGESTS feature flag in LMS settings"
  else
    fail_ "ENABLE_EMAIL_DIGESTS missing from LMS settings"
  fi

  if grep -q "ENABLE_EMAIL_ANALYTICS" "$LMS_PRODUCTION_PY"; then
    pass_ "ENABLE_EMAIL_ANALYTICS feature flag in LMS settings"
  else
    fail_ "ENABLE_EMAIL_ANALYTICS missing from LMS settings"
  fi

  if grep -q "NOTIFICATION_CLICK_TRACKING_ENABLED" "$LMS_PRODUCTION_PY"; then
    pass_ "NOTIFICATION_CLICK_TRACKING_ENABLED flag configured"
  else
    fail_ "NOTIFICATION_CLICK_TRACKING_ENABLED missing"
  fi

  if grep -q "DIGEST_DEFAULT_SEND_HOUR" "$LMS_PRODUCTION_PY"; then
    pass_ "DIGEST_DEFAULT_SEND_HOUR configured (09:00)"
  else
    fail_ "DIGEST_DEFAULT_SEND_HOUR missing"
  fi

  if grep -q "DIGEST_DEFAULT_TIMEZONE.*Asia/Kuala_Lumpur" "$LMS_PRODUCTION_PY"; then
    pass_ "DIGEST_DEFAULT_TIMEZONE set to Asia/Kuala_Lumpur"
  else
    fail_ "DIGEST_DEFAULT_TIMEZONE missing or wrong"
  fi

  if grep -q "EMAIL_ANALYTICS_RETENTION_MONTHS.*12" "$LMS_PRODUCTION_PY"; then
    pass_ "EMAIL_ANALYTICS_RETENTION_MONTHS set to 12"
  else
    fail_ "EMAIL_ANALYTICS_RETENTION_MONTHS missing"
  fi

  if grep -q "GDPR_DELETION_DEADLINE_DAYS.*30" "$LMS_PRODUCTION_PY"; then
    pass_ "GDPR_DELETION_DEADLINE_DAYS set to 30"
  else
    fail_ "GDPR_DELETION_DEADLINE_DAYS missing"
  fi

  if grep -q "openedx_email_digests" "$LMS_PRODUCTION_PY"; then
    pass_ "openedx_email_digests in INSTALLED_APPS"
  else
    fail_ "openedx_email_digests missing from INSTALLED_APPS"
  fi

  # Check env var patterns
  if grep -q 'os\.environ\.get.*DIGEST\|os\.environ\.get.*ANALYTICS\|os\.environ\.get.*GDPR' "$LMS_PRODUCTION_PY"; then
    pass_ "Settings use env var pattern (os.environ.get)"
  else
    fail_ "Settings missing env var pattern"
  fi
else
  fail_ "LMS production.py not found at $LMS_PRODUCTION_PY"
fi

# Runtime tests
skip_ "AC-037: User with daily digest receives one email at 09:00 local time (requires runtime test)"
skip_ "AC-038: Immediate email suppressed when user is on daily digest (requires runtime test)"
skip_ "AC-039: 5 replies to same thread show as '5 new replies' in digest (requires runtime test)"
skip_ "AC-040: Open tracking pixel records open event in engagement store (requires runtime test)"
skip_ "AC-041: Click tracking redirects and records click within 200ms (requires runtime test)"
skip_ "AC-042: Per-tenant analytics dashboard shows only tenant data (requires runtime test)"

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
  echo "--- Verification FAILED with $FAIL failed check(s)"
  exit 1
else
  echo "--- Verification PASSED (static checks complete; $SKIP runtime checks skipped)"
  exit 0
fi
