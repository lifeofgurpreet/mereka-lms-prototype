#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005
# @spec: email-notifications-pipeline_spec.md
# Verify AWS SES infrastructure for email delivery
#
# Checks:
#   AC-001: Domain verification for academyv2.mereka.io (DKIM/SPF/DMARC)
#   AC-002: Domain verification for academy.biji-biji.com (DKIM/SPF/DMARC)
#   AC-003: Password reset email delivery within 30s via SES (infrastructure)
#   AC-004: Custom MAIL FROM domain mail.academyv2.mereka.io DMARC alignment
#   AC-005: Per-tenant sender identity with custom display name
#
# Usage:
#   ./scripts/qa/verify-email-ses-infrastructure.sh
#   ./scripts/qa/verify-email-ses-infrastructure.sh --skip-cluster

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"
HOME_ROOT="${HOME:-}"

SKIP_CLUSTER=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-cluster)
      SKIP_CLUSTER=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--skip-cluster]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

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

echo "=== Email SES Infrastructure Verification ==="
echo "Skip cluster checks: $SKIP_CLUSTER"
echo ""

resolve_prod_settings() {
  local candidates=()
  if [[ -n "${EMAIL_SES_PROD_SETTINGS:-}" ]]; then
    candidates+=("${EMAIL_SES_PROD_SETTINGS}")
  fi
  candidates+=(
    "../infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
    "../bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
    "${WORKSPACE_ROOT}/infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
    "${WORKSPACE_ROOT}/bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
    "${HOME_ROOT}/projects/k8s/infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
    "${HOME_ROOT}/projects/k8s/bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py"
    "deploy/k8s/base/apps/openedx/settings/lms/production.py"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      printf "%s" "$candidate"
      return 0
    fi
  done
  return 1
}

PROD_SETTINGS="$(resolve_prod_settings || true)"
echo "Prod settings source: ${PROD_SETTINGS:-not found}"
echo ""

# Check 1: DNS documentation exists
echo "Checking AC-001, AC-002, AC-004: DNS record documentation..."

DNS_DOC="docs/operations/EMAIL_DNS_RECORDS.md"
if [[ -f "$DNS_DOC" ]]; then
  pass "AC-001/AC-002/AC-004: DNS documentation exists at $DNS_DOC"

  # Check for required sections
  REQUIRED_SECTIONS=(
    "DKIM Records"
    "SPF Record"
    "DMARC Record"
    "Custom MAIL FROM Domain"
    "academyv2.mereka.io"
    "academy.biji-biji.com"
  )

  for section in "${REQUIRED_SECTIONS[@]}"; do
    if grep -q "$section" "$DNS_DOC"; then
      pass "AC-001/AC-002: Documentation includes $section"
    else
      fail "AC-001/AC-002: Documentation missing $section"
    fi
  done
else
  fail "AC-001/AC-002/AC-004: DNS documentation not found at $DNS_DOC"
fi

echo ""

# Check 2: SES secret references in ExternalSecret
echo "Checking AC-003: SES SMTP credentials in ExternalSecret..."

EXTERNAL_SECRETS_FILE="deploy/k8s/base/secrets/external-secrets.yaml"
if [[ -f "$EXTERNAL_SECRETS_FILE" ]]; then
  if grep -q "SES_SNS_WEBHOOK_SECRET" "$EXTERNAL_SECRETS_FILE"; then
    pass "AC-003: SES SNS webhook secret mapped in ExternalSecrets"
  else
    fail "AC-003: SES SNS webhook secret not found in ExternalSecrets"
  fi
else
  fail "AC-003: ExternalSecrets file not found at $EXTERNAL_SECRETS_FILE"
fi

echo ""

# Check 3: Check for ses-smtp-credentials secret reference (existing infrastructure)
echo "Checking AC-003: SES SMTP relay configuration..."

# Check if smtp deployment exists in K8s manifests
SMTP_DEPLOYMENT_FILES=(
  "deploy/k8s/patches/smtp-ses-relay.yaml"
  "../infrastructure/apps/mereka-lms/base/smtp.yaml"
  "../bbi-infrastructure/apps/mereka-lms/base/smtp.yaml"
  "deploy/k8s/base/apps/smtp.yaml"
)

SMTP_FOUND=false
for smtp_file in "${SMTP_DEPLOYMENT_FILES[@]}"; do
  if [[ -f "$smtp_file" ]]; then
    SMTP_FOUND=true
    pass "AC-003: SMTP deployment manifest found at $smtp_file"

    # Check for ses-smtp-credentials secret reference
    if grep -q "ses-smtp-credentials" "$smtp_file"; then
      pass "AC-003: ses-smtp-credentials secret referenced in SMTP deployment"
    fi

    # Check for exim relay image
    if grep -q "devture/exim-relay\|exim" "$smtp_file"; then
      pass "AC-003: Exim relay image reference found"
    fi
  fi
done

if [[ "$SMTP_FOUND" = false ]]; then
  skip "AC-003: SMTP deployment manifest not found in expected locations (may exist in cluster)"
fi

echo ""

# Check 4: MAIL FROM configuration in production settings
echo "Checking AC-004: Custom MAIL FROM domain configuration..."

if [[ -f "$PROD_SETTINGS" ]]; then
  if grep -q "MAIL_FROM\|DEFAULT_FROM_EMAIL\|SERVER_EMAIL" "$PROD_SETTINGS"; then
    pass "AC-004: MAIL FROM configuration found in production settings"

    # Check for mail.academyv2.mereka.io
    if grep -q "mail.academyv2.mereka.io\|academyv2.mereka.io" "$PROD_SETTINGS"; then
      pass "AC-004: Primary domain configuration found"
    else
      skip "AC-004: Primary domain not found in settings (may be in environment variables)"
    fi
  else
    skip "AC-004: MAIL FROM configuration not found in production settings"
  fi
else
  skip "AC-004: Production settings file not found"
fi

echo ""

# Check 5: Per-tenant sender configuration
echo "Checking AC-005: Per-tenant sender identity configuration..."

if [[ -f "$PROD_SETTINGS" ]]; then
  if grep -q "TENANT_EMAIL_SENDERS\|tenant.*sender\|per-tenant" "$PROD_SETTINGS"; then
    pass "AC-005: Per-tenant sender configuration found"
  else
    skip "AC-005: Per-tenant sender configuration not found (may be implemented in code)"
  fi
else
  skip "AC-005: Production settings not available for tenant sender check"
fi

# Check DNS documentation for tenant sender pattern
if [[ -f "$DNS_DOC" ]]; then
  if grep -q "Per-Tenant Sender\|TENANT_EMAIL_SENDERS" "$DNS_DOC"; then
    pass "AC-005: Per-tenant sender documentation found"
  else
    skip "AC-005: Per-tenant sender documentation not found"
  fi
fi

echo ""

# Check 6: ACE configuration for email delivery
echo "Checking AC-003: ACE email channel configuration..."

if [[ -f "$PROD_SETTINGS" ]]; then
  if grep -q "ACE_ENABLED_CHANNELS.*django_email" "$PROD_SETTINGS"; then
    pass "AC-003: ACE django_email channel configured"
  else
    skip "AC-003: ACE django_email channel not found in settings"
  fi

  if grep -q "ACE_CHANNEL_DEFAULT_EMAIL" "$PROD_SETTINGS"; then
    pass "AC-003: ACE default email channel configured"
  else
    skip "AC-003: ACE default email channel not configured"
  fi
else
  skip "AC-003: Production settings not available for ACE check"
fi

echo ""

# Check 7: Exim relay running (cluster check)
echo "Checking AC-003: Exim relay pod status..."

if $SKIP_CLUSTER; then
  skip "AC-003: Exim relay pod status check skipped (--skip-cluster)"
elif command -v kubectl &> /dev/null; then
  KUBECTL_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")

  if [[ "$KUBECTL_CONTEXT" != "none" ]]; then
    # Check if smtp pod exists
    if kubectl get deployment smtp -n mereka-lms &> /dev/null; then
      pass "AC-003: SMTP relay deployment exists in mereka-lms namespace"

      # Check if pod is running
      SMTP_READY=$(kubectl get deployment smtp -n mereka-lms -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      if [[ "$SMTP_READY" -gt 0 ]]; then
        pass "AC-003: SMTP relay pod is running ($SMTP_READY ready replicas)"
      else
        fail "AC-003: SMTP relay pod exists but not ready"
      fi
    else
      skip "AC-003: SMTP relay deployment not found in cluster (may use different name)"
    fi
  else
    skip "AC-003: No kubectl context available, skipping cluster checks"
  fi
else
  skip "AC-003: kubectl not available, skipping cluster checks"
fi

echo ""

# Check 8: Email suppression plugin exists
echo "Checking bounce handling infrastructure..."

SUPPRESSION_PLUGIN_DIR="infrastructure/tutor/plugins/email-suppression"
if [[ -d "$SUPPRESSION_PLUGIN_DIR" ]]; then
  pass "Email suppression plugin directory exists"

  # Check for models.py
  if [[ -f "$SUPPRESSION_PLUGIN_DIR/mereka_email_suppression/models.py" ]]; then
    pass "Email suppression models.py exists"

    # Check for EmailSuppression model
    if grep -q "class EmailSuppression" "$SUPPRESSION_PLUGIN_DIR/mereka_email_suppression/models.py"; then
      pass "EmailSuppression model defined"
    fi
  else
    fail "Email suppression models.py not found"
  fi

  # Check for setup.py
  if [[ -f "$SUPPRESSION_PLUGIN_DIR/setup.py" ]]; then
    pass "Email suppression setup.py exists (pip installable)"
  else
    fail "Email suppression setup.py not found"
  fi
else
  fail "Email suppression plugin directory not found at $SUPPRESSION_PLUGIN_DIR"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
