#!/usr/bin/env bash
# @spec: email-notifications-pipeline_spec.md
# @covers Phase 4: Push Notifications (AC-015 to AC-019)
#
# Verification of Email Phase 4: Push Notifications spec compliance.
# Static checks run against Django app structure, LMS settings, and config files.
# Runtime ACs (FCM delivery, batch sending) are marked SKIP.
#
# Usage:
#   ./scripts/qa/verify-push-notifications.sh [--skip-cluster] [--help]
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

Verify Email Phase 4: Push Notifications via FCM spec compliance.

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
APP_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_push_notifications"
LMS_PRODUCTION_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

echo "========================================================"
echo "  Email Phase 4: Push Notifications via FCM"
echo "  Spec: email-notifications-pipeline_spec.md (Phase 4)"
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
  "ace_channel.py"
  "tasks.py"
  "signals.py"
  "setup.py"
  "migrations/__init__.py"
)

missing_files=()
for f in "${required_files[@]}"; do
  if [ ! -f "$APP_DIR/$f" ]; then
    missing_files+=("$f")
  fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
  pass_ "All ${#required_files[@]} required app files present in openedx_push_notifications/"
else
  fail_ "Missing app files: ${missing_files[*]}"
fi

###########################################################################
# SECTION 2: DeviceRegistration Model (AC-015, AC-016, AC-017)
###########################################################################
echo "--- DeviceRegistration Model ---"

if [ -f "$APP_DIR/models.py" ]; then
  # Check model class exists
  if grep -q "class DeviceRegistration" "$APP_DIR/models.py"; then
    pass_ "AC-015: DeviceRegistration model class defined"
  else
    fail_ "AC-015: DeviceRegistration model class missing"
  fi

  # Check required fields
  model_fields=(
    "user"
    "device_token"
    "platform"
    "app_version"
    "org_slug"
    "is_active"
    "registered_at"
    "last_seen_at"
  )

  missing_fields=()
  for field in "${model_fields[@]}"; do
    if ! grep -q "$field" "$APP_DIR/models.py"; then
      missing_fields+=("$field")
    fi
  done

  if [ ${#missing_fields[@]} -eq 0 ]; then
    pass_ "AC-015: All required model fields present (${#model_fields[@]} fields)"
  else
    fail_ "AC-015: Missing model fields: ${missing_fields[*]}"
  fi

  # Check platform choices
  if grep -q "PLATFORM_IOS" "$APP_DIR/models.py" && grep -q "PLATFORM_ANDROID" "$APP_DIR/models.py"; then
    pass_ "AC-015: Platform choices defined (ios/android)"
  else
    fail_ "AC-015: Platform choices missing"
  fi

  # Check deduplication (unique_together)
  if grep -q "unique_together" "$APP_DIR/models.py"; then
    pass_ "AC-015: Device token deduplication via unique_together"
  else
    fail_ "AC-015: Device token deduplication missing (unique_together)"
  fi

  # Check deactivation method (AC-016)
  if grep -q "def deactivate" "$APP_DIR/models.py"; then
    pass_ "AC-016: deactivate() method for UNREGISTERED tokens"
  else
    fail_ "AC-016: deactivate() method missing"
  fi

  # Check register_or_update (dedup on re-registration)
  if grep -q "def register_or_update" "$APP_DIR/models.py"; then
    pass_ "AC-015: register_or_update() for idempotent registration"
  else
    fail_ "AC-015: register_or_update() missing"
  fi

  # Check unregister method (AC-017)
  if grep -q "def unregister" "$APP_DIR/models.py"; then
    pass_ "AC-017: unregister() method for logout flow"
  else
    fail_ "AC-017: unregister() method missing"
  fi

  # Check org_slug filtering (AC-019)
  if grep -q "def get_active_tokens" "$APP_DIR/models.py"; then
    pass_ "AC-019: get_active_tokens() with org_slug filtering"
  else
    fail_ "AC-019: get_active_tokens() missing"
  fi
else
  fail_ "models.py not found at $APP_DIR/models.py"
fi

###########################################################################
# SECTION 3: Device Registration API
###########################################################################
echo "--- Device Registration API ---"

if [ -f "$APP_DIR/views.py" ]; then
  # Check POST handler
  if grep -q "def post" "$APP_DIR/views.py"; then
    pass_ "AC-015: POST endpoint for device registration"
  else
    fail_ "AC-015: POST endpoint missing"
  fi

  # Check DELETE handler
  if grep -q "def delete" "$APP_DIR/views.py"; then
    pass_ "AC-017: DELETE endpoint for device unregistration"
  else
    fail_ "AC-017: DELETE endpoint missing"
  fi

  # Check authentication required
  if grep -q "IsAuthenticated" "$APP_DIR/views.py"; then
    pass_ "Device registration API requires authentication"
  else
    fail_ "Device registration API missing authentication"
  fi
fi

if [ -f "$APP_DIR/urls.py" ]; then
  if grep -q "register" "$APP_DIR/urls.py"; then
    pass_ "URL routing configured for /register/ endpoint"
  else
    fail_ "URL routing missing for /register/ endpoint"
  fi
fi

###########################################################################
# SECTION 4: ACE Push Channel
###########################################################################
echo "--- ACE Push Channel ---"

if [ -f "$APP_DIR/ace_channel.py" ]; then
  if grep -q "class PushChannel" "$APP_DIR/ace_channel.py"; then
    pass_ "ACE PushChannel class defined"
  else
    fail_ "ACE PushChannel class missing"
  fi

  if grep -q "ChannelType.PUSH" "$APP_DIR/ace_channel.py"; then
    pass_ "Channel type set to PUSH"
  else
    fail_ "Channel type not set to PUSH"
  fi

  if grep -q "def deliver" "$APP_DIR/ace_channel.py"; then
    pass_ "deliver() method implemented"
  else
    fail_ "deliver() method missing"
  fi

  if grep -q "NOTIFICATION_PUSH_ENABLED" "$APP_DIR/ace_channel.py"; then
    pass_ "Push channel respects NOTIFICATION_PUSH_ENABLED flag"
  else
    fail_ "Push channel does not check NOTIFICATION_PUSH_ENABLED flag"
  fi
fi

###########################################################################
# SECTION 5: Batch Sender (AC-018)
###########################################################################
echo "--- Batch Sender ---"

if [ -f "$APP_DIR/tasks.py" ]; then
  if grep -q "def send_push_notification" "$APP_DIR/tasks.py"; then
    pass_ "AC-018: send_push_notification Celery task defined"
  else
    fail_ "AC-018: send_push_notification task missing"
  fi

  if grep -q "FCM_BATCH_SIZE" "$APP_DIR/tasks.py" || grep -q "500" "$APP_DIR/tasks.py"; then
    pass_ "AC-018: Batch size configured (500 per FCM request)"
  else
    fail_ "AC-018: Batch size not configured"
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

  # Check UNREGISTERED token handling (AC-016)
  if grep -q "UNREGISTERED" "$APP_DIR/tasks.py"; then
    pass_ "AC-016: UNREGISTERED token deactivation in batch sender"
  else
    fail_ "AC-016: UNREGISTERED token handling missing"
  fi

  # Check idempotency (notification_id dedup)
  if grep -q "notification_id" "$APP_DIR/tasks.py"; then
    pass_ "Idempotency via notification_id deduplication"
  else
    fail_ "Idempotency mechanism missing"
  fi

  # Check org_slug isolation (AC-019)
  if grep -q "org_slug" "$APP_DIR/tasks.py"; then
    pass_ "AC-019: org_slug isolation in push dispatch"
  else
    fail_ "AC-019: org_slug isolation missing"
  fi

  # Check FCM HTTP v1 API URL
  if grep -q "fcm.googleapis.com/v1" "$APP_DIR/tasks.py"; then
    pass_ "FCM HTTP v1 API endpoint configured"
  else
    fail_ "FCM HTTP v1 API endpoint missing"
  fi
fi

###########################################################################
# SECTION 6: LMS Settings Configuration
###########################################################################
echo "--- LMS Settings ---"

if [ -f "$LMS_PRODUCTION_PY" ]; then
  if grep -q "NOTIFICATION_PUSH_ENABLED" "$LMS_PRODUCTION_PY"; then
    pass_ "NOTIFICATION_PUSH_ENABLED feature flag in LMS settings"
  else
    fail_ "NOTIFICATION_PUSH_ENABLED missing from LMS settings"
  fi

  if grep -q "FCM_PROJECT_ID" "$LMS_PRODUCTION_PY"; then
    pass_ "FCM_PROJECT_ID configured from env var"
  else
    fail_ "FCM_PROJECT_ID missing from LMS settings"
  fi

  if grep -q "FCM_SERVICE_ACCOUNT_KEY" "$LMS_PRODUCTION_PY"; then
    pass_ "FCM_SERVICE_ACCOUNT_KEY configured from env var"
  else
    fail_ "FCM_SERVICE_ACCOUNT_KEY missing from LMS settings"
  fi

  if grep -q "PUSH_NOTIFICATION_RETRY_BACKOFF.*30" "$LMS_PRODUCTION_PY"; then
    pass_ "Push retry backoff base configured (30 seconds)"
  else
    fail_ "Push retry backoff base missing"
  fi

  if grep -q "PUSH_NOTIFICATION_RETRY_BACKOFF_MAX.*900" "$LMS_PRODUCTION_PY"; then
    pass_ "Push retry backoff max configured (900 seconds)"
  else
    fail_ "Push retry backoff max missing"
  fi

  if grep -q "PUSH_NOTIFICATION_BATCH_SIZE.*500" "$LMS_PRODUCTION_PY"; then
    pass_ "Push batch size configured (500)"
  else
    fail_ "Push batch size missing"
  fi

  if grep -q "openedx_push_notifications" "$LMS_PRODUCTION_PY"; then
    pass_ "openedx_push_notifications in INSTALLED_APPS"
  else
    fail_ "openedx_push_notifications missing from INSTALLED_APPS"
  fi

  # Check env var patterns
  if grep -q 'os\.environ\.get.*FCM' "$LMS_PRODUCTION_PY"; then
    pass_ "FCM settings use env var pattern (os.environ.get)"
  else
    fail_ "FCM settings missing env var pattern"
  fi
else
  fail_ "LMS production.py not found at $LMS_PRODUCTION_PY"
fi

# Runtime tests
skip_ "AC-015: Device registers and receives push via FCM within 60 seconds (requires runtime test)"
skip_ "AC-016: UNREGISTERED token deactivated on FCM error (requires runtime test)"
skip_ "AC-017: Unregistered device receives no further pushes (requires runtime test)"
skip_ "AC-018: 1000 notifications sent as 2 FCM batches of 500 (requires runtime test)"
skip_ "AC-019: Cross-tenant push isolation (org_slug filtering) (requires runtime test)"

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
