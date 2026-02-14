#!/usr/bin/env bash
# @spec: enterprise-microservices_spec.md
# @covers Phase 4: SSO/SAML + Integrated Channels (AC-027 to AC-033)
#
# Verification of Enterprise Phase 4 spec compliance.
# Static checks run against LMS settings and configuration files.
# Runtime ACs (SAML authentication, channel sync) are marked SKIP.
#
# Usage:
#   ./scripts/qa/verify-enterprise-sso.sh [--skip-cluster] [--help]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

Verify Enterprise Phase 4: SSO/SAML + Integrated Channels spec compliance.

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

# Key file paths
LMS_PRODUCTION_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
ENTERPRISE_CHANNELS_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_enterprise_channels.py"

echo "========================================================"
echo "  Enterprise Phase 4: SSO/SAML + Integrated Channels"
echo "  Spec: enterprise-microservices_spec.md (Phase 4)"
echo "========================================================"
echo "Date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Repo:   $REPO_ROOT"
echo "Cluster checks: $(if $SKIP_CLUSTER; then echo SKIPPED; else echo ENABLED; fi)"
echo


###########################################################################
# SECTION 1: SAML Backend Configuration (AC-027, AC-028, AC-029, AC-030)
###########################################################################
echo "--- SAML Backend Configuration ---"

# Check third_party_auth is enabled
if [ -f "$LMS_PRODUCTION_PY" ]; then
  # AC-027: SAML backend configured with python-social-auth
  if grep -q "SOCIAL_AUTH_SAML_PIPELINE" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-027: python-social-auth SAML backend configured (SOCIAL_AUTH_SAML_PIPELINE present)"
  else
    fail_ "AC-027: python-social-auth SAML backend not configured (SOCIAL_AUTH_SAML_PIPELINE missing)"
  fi

  # Check SAML security settings
  if grep -q "SOCIAL_AUTH_SAML_SECURITY_CONFIG" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-027: SAML security config present (authnRequestsSigned, wantAssertionsSigned)"
  else
    fail_ "AC-027: SAML security config missing"
  fi

  # Check SAML clock skew tolerance (120 seconds per edge case spec)
  if grep -q "SOCIAL_AUTH_SAML_ASSERTION_EXPIRATION.*120" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-029: SAML clock skew tolerance configured (120 seconds)"
  else
    fail_ "AC-029: SAML clock skew tolerance not configured correctly (should be 120 seconds)"
  fi

  # Check SAML retry/backoff configuration
  if grep -q "SOCIAL_AUTH_SAML_METADATA_RETRY_BACKOFF.*30" "$LMS_PRODUCTION_PY"; then
    pass_ "SAML retry backoff base configured (30 seconds)"
  else
    fail_ "SAML retry backoff base not configured (should be 30 seconds)"
  fi

  if grep -q "SOCIAL_AUTH_SAML_METADATA_RETRY_BACKOFF_MAX.*900" "$LMS_PRODUCTION_PY"; then
    pass_ "SAML retry backoff max configured (900 seconds = 15 minutes)"
  else
    fail_ "SAML retry backoff max not configured (should be 900 seconds / 15 minutes)"
  fi

  if grep -q "SOCIAL_AUTH_SAML_METADATA_RETRY_MAX.*5" "$LMS_PRODUCTION_PY"; then
    pass_ "SAML retry max attempts configured (5 retries)"
  else
    fail_ "SAML retry max attempts not configured (should be 5 retries)"
  fi

  # Check SAML SP entity ID configured
  if grep -q "SOCIAL_AUTH_SAML_SP_ENTITY_ID" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-027: SAML SP entity ID configured"
  else
    fail_ "AC-027: SAML SP entity ID not configured"
  fi

  # Check SAML organization info
  if grep -q "SOCIAL_AUTH_SAML_ORG_INFO" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-027: SAML organization info configured"
  else
    fail_ "AC-027: SAML organization info not configured"
  fi

  # Check third_party_auth feature flag
  if grep -q "ENABLE_THIRD_PARTY_AUTH" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-027: ENABLE_THIRD_PARTY_AUTH feature flag present"
  else
    fail_ "AC-027: ENABLE_THIRD_PARTY_AUTH feature flag missing"
  fi

  # Check ENABLE_ENTERPRISE_INTEGRATION feature flag
  if grep -q "ENABLE_ENTERPRISE_INTEGRATION" "$LMS_PRODUCTION_PY" || grep -q "ENABLE_ENTERPRISE_INTEGRATION" "$ENTERPRISE_CHANNELS_PY"; then
    pass_ "AC-027: ENABLE_ENTERPRISE_INTEGRATION feature flag present"
  else
    fail_ "AC-027: ENABLE_ENTERPRISE_INTEGRATION feature flag missing"
  fi
else
  fail_ "LMS production.py not found at $LMS_PRODUCTION_PY"
fi

# Runtime SAML authentication tests
skip_ "AC-027: Slug-based login redirects to correct IdP (/enterprise/login/{slug}) (requires runtime test)"
skip_ "AC-028: Auto-provisioning creates new user from SAML assertion (requires runtime test)"
skip_ "AC-029: SAML assertion rejected if NotOnOrAfter is in the past (requires runtime test)"
skip_ "AC-030: Cross-tenant authentication prevention (requires runtime test with multiple IdPs)"

###########################################################################
# SECTION 2: Integrated Channels Apps (AC-031, AC-032, AC-033)
###########################################################################
echo "--- Integrated Channels Configuration ---"

if [ -f "$ENTERPRISE_CHANNELS_PY" ]; then
  # Check integrated_channels apps are enabled
  channel_apps=(
    "integrated_channels.integrated_channel"
    "integrated_channels.degreed"
    "integrated_channels.degreed2"
    "integrated_channels.cornerstone"
    "integrated_channels.sap_success_factors"
    "integrated_channels.blackboard"
    "integrated_channels.canvas"
    "integrated_channels.moodle"
  )

  missing_apps=()
  for app in "${channel_apps[@]}"; do
    if ! grep -q "$app" "$ENTERPRISE_CHANNELS_PY"; then
      missing_apps+=("$app")
    fi
  done

  if [ ${#missing_apps[@]} -eq 0 ]; then
    pass_ "AC-031: All integrated_channels apps enabled in INSTALLED_APPS (8 apps)"
  else
    fail_ "AC-031: Missing integrated_channels apps: ${missing_apps[*]}"
  fi

  # Check channel sync retry configuration
  if grep -q "retry_backoff.*30" "$ENTERPRISE_CHANNELS_PY"; then
    pass_ "AC-033: Channel sync retry backoff base configured (30 seconds)"
  else
    fail_ "AC-033: Channel sync retry backoff base not configured (should be 30 seconds)"
  fi

  if grep -q "retry_backoff_max.*900" "$ENTERPRISE_CHANNELS_PY"; then
    pass_ "AC-033: Channel sync retry backoff max configured (900 seconds = 15 minutes)"
  else
    fail_ "AC-033: Channel sync retry backoff max not configured (should be 900 seconds / 15 minutes)"
  fi

  if grep -q "max_retries.*5" "$ENTERPRISE_CHANNELS_PY"; then
    pass_ "AC-033: Channel sync max retries configured (5 retries)"
  else
    fail_ "AC-033: Channel sync max retries not configured (should be 5 retries)"
  fi

  # Check Celery beat schedule for periodic sync
  if grep -q "CELERYBEAT_SCHEDULE" "$ENTERPRISE_CHANNELS_PY"; then
    pass_ "AC-031: Celery beat schedule configured for periodic channel sync"
  else
    fail_ "AC-031: Celery beat schedule not configured"
  fi

  # Check content metadata sync task
  if grep -q "transmit_content_metadata" "$ENTERPRISE_CHANNELS_PY"; then
    pass_ "AC-031: Content metadata sync task configured"
  else
    fail_ "AC-031: Content metadata sync task not configured"
  fi

  # Check learner data sync task
  if grep -q "transmit_learner_data" "$ENTERPRISE_CHANNELS_PY"; then
    pass_ "AC-031: Learner data sync task configured"
  else
    fail_ "AC-031: Learner data sync task not configured"
  fi

  # Check event bus configuration
  if grep -q "EVENT_BUS_PRODUCER_CONFIG" "$ENTERPRISE_CHANNELS_PY"; then
    pass_ "AC-031: Event bus producer config present (for COURSE_COMPLETION events)"
  else
    fail_ "AC-031: Event bus producer config missing"
  fi

  # Check course completion event publishing
  if grep -q "course.passing.status.updated" "$ENTERPRISE_CHANNELS_PY"; then
    pass_ "AC-031: Course completion event configured for event bus"
  else
    fail_ "AC-031: Course completion event not configured"
  fi

  # Check enrollment event publishing
  if grep -q "course.enrollment.changed" "$ENTERPRISE_CHANNELS_PY"; then
    pass_ "AC-031: Enrollment event configured for event bus"
  else
    fail_ "AC-031: Enrollment event not configured"
  fi
else
  fail_ "Enterprise channels config not found at $ENTERPRISE_CHANNELS_PY"
fi

###########################################################################
# SECTION 3: Channel Connector Configurations
###########################################################################
echo "--- Channel Connector Configurations ---"

if [ -f "$LMS_PRODUCTION_PY" ]; then
  # Check Degreed connector config
  if grep -q "DEGREED_API_BASE_URL" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-031: Degreed connector configured (DEGREED_API_BASE_URL present)"
  else
    fail_ "AC-031: Degreed connector not configured"
  fi

  if grep -q "DEGREED_SYNC_RETRY_BACKOFF.*30" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-033: Degreed sync retry backoff configured (30 seconds)"
  else
    fail_ "AC-033: Degreed sync retry backoff not configured"
  fi

  if grep -q "DEGREED_SYNC_RETRY_BACKOFF_MAX.*900" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-033: Degreed sync retry max configured (15 minutes)"
  else
    fail_ "AC-033: Degreed sync retry max not configured"
  fi

  if grep -q "DEGREED_SYNC_BATCH_SIZE" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-031: Degreed batch size configured (pagination for large learner sets)"
  else
    fail_ "AC-031: Degreed batch size not configured"
  fi

  # Check Cornerstone connector config
  if grep -q "CORNERSTONE_API_BASE_URL" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-031: Cornerstone connector configured (CORNERSTONE_API_BASE_URL present)"
  else
    fail_ "AC-031: Cornerstone connector not configured"
  fi

  if grep -q "CORNERSTONE_SYNC_RETRY_BACKOFF.*30" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-033: Cornerstone sync retry backoff configured (30 seconds)"
  else
    fail_ "AC-033: Cornerstone sync retry backoff not configured"
  fi

  if grep -q "CORNERSTONE_SYNC_RETRY_BACKOFF_MAX.*900" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-033: Cornerstone sync retry max configured (15 minutes)"
  else
    fail_ "AC-033: Cornerstone sync retry max not configured"
  fi

  if grep -q "CORNERSTONE_SYNC_BATCH_SIZE" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-031: Cornerstone batch size configured (pagination for large learner sets)"
  else
    fail_ "AC-031: Cornerstone batch size not configured"
  fi

  # Check global integrated channels config
  if grep -q "INTEGRATED_CHANNELS_API_CHUNK_SIZE" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-031: Integrated channels global chunk size configured"
  else
    fail_ "AC-031: Integrated channels global chunk size not configured"
  fi

  if grep -q "INTEGRATED_CHANNELS_LOG_PII.*False" "$LMS_PRODUCTION_PY"; then
    pass_ "AC-031: PII logging disabled for integrated channels (GDPR/PDPA compliance)"
  else
    fail_ "AC-031: PII logging config missing or not set to False"
  fi
else
  fail_ "LMS production.py not found at $LMS_PRODUCTION_PY"
fi

# Runtime channel sync tests
skip_ "AC-031: Degreed sync transmits completion data for consenting learners (requires runtime test)"
skip_ "AC-032: Channel sync dry-run mode does not transmit data (requires runtime test)"
skip_ "AC-033: Channel sync retries on transient API errors (HTTP 503) with exponential backoff (requires runtime test)"

###########################################################################
# SECTION 4: Environment Variable Patterns
###########################################################################
echo "--- Environment Variable Patterns ---"

if [ -f "$LMS_PRODUCTION_PY" ]; then
  # Check all configs use os.environ.get() pattern (no hardcoded secrets)
  if grep -q 'os\.environ\.get.*DEGREED' "$LMS_PRODUCTION_PY"; then
    pass_ "Degreed connector uses env var pattern (os.environ.get)"
  else
    fail_ "Degreed connector missing env var pattern"
  fi

  if grep -q 'os\.environ\.get.*CORNERSTONE' "$LMS_PRODUCTION_PY"; then
    pass_ "Cornerstone connector uses env var pattern (os.environ.get)"
  else
    fail_ "Cornerstone connector missing env var pattern"
  fi

  if grep -q 'os\.environ\.get.*SAML' "$LMS_PRODUCTION_PY"; then
    pass_ "SAML config uses env var pattern (os.environ.get)"
  else
    fail_ "SAML config missing env var pattern"
  fi
else
  fail_ "LMS production.py not found at $LMS_PRODUCTION_PY"
fi

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
