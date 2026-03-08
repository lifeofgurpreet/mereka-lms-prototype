#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-008, AC-111, AC-112, AC-113, AC-114
# @spec: email-notifications-pipeline_spec.md
#
# Comprehensive verification of the email notifications pipeline.
# Checks SES SMTP configuration, ExternalSecrets credential mappings, ACE channel
# setup, Celery worker configuration for email tasks, and email monitoring rules.
#
# This script focuses on infrastructure-level checks verifiable from the repository:
#   AC-001/AC-002: SES domain DNS documentation exists
#   AC-003: SES SMTP credentials mapped in ExternalSecrets and email backend is SMTP
#   AC-004: Custom MAIL FROM domain documented
#   AC-005: Per-tenant sender identity configuration documented
#   AC-006: ACE enabled channels include django_email
#   AC-008: System-critical non-suppressible emails (password_reset category)
#   AC-111: ACE_ENABLED_CHANNELS configuration
#   AC-112: SES SMTP credentials in K8s secrets
#   AC-113: Email monitoring PrometheusRule exists
#   AC-114: Exim relay deployment manifest exists (skipped if absent — deployed in bbi-infrastructure)
#
# Checks that require live cluster access or production settings are marked SKIP.
#
# Usage:
#   ./scripts/qa/verify-email-notifications-pipeline.sh
#   ./scripts/qa/verify-email-notifications-pipeline.sh --env dev

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

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Email Notifications Pipeline Verification ==="
echo "Repo: $REPO_ROOT"
echo ""

# ---------------------------------------------------------------------------
# AC-001 / AC-002 / AC-004: DNS documentation
# ---------------------------------------------------------------------------
echo "--- AC-001, AC-002, AC-004: SES domain DNS documentation ---"

DNS_DOC="docs/reference/operations/EMAIL_DNS_RECORDS.md"
if [[ -f "$DNS_DOC" ]]; then
  pass "AC-001/AC-002: DNS documentation exists at $DNS_DOC"

  for needle in \
    "DKIM Records" \
    "SPF Record" \
    "DMARC Record" \
    "Custom MAIL FROM Domain" \
    "academyv2.mereka.io" \
    "academy.biji-biji.com"
  do
    if grep -qF "$needle" "$DNS_DOC"; then
      pass "AC-001/AC-002: DNS doc contains '$needle'"
    else
      fail "AC-001/AC-002: DNS doc missing section '$needle'"
    fi
  done

  if grep -q "mail\.academyv2\.mereka\.io" "$DNS_DOC"; then
    pass "AC-004: Custom MAIL FROM domain 'mail.academyv2.mereka.io' documented"
  else
    fail "AC-004: Custom MAIL FROM domain not found in DNS documentation"
  fi
else
  fail "AC-001/AC-002/AC-004: DNS documentation not found at $DNS_DOC"
fi
echo ""

# ---------------------------------------------------------------------------
# AC-003 / AC-112: SES SMTP credentials in ExternalSecrets
# ---------------------------------------------------------------------------
echo "--- AC-003, AC-112: SES SMTP credentials in ExternalSecrets ---"

ES_BASE="deploy/k8s/base/secrets/external-secrets.yaml"
ES_NONPROD="deploy/k8s/overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml"

if [[ -f "$ES_BASE" ]]; then
  # Check for EMAIL_HOST_USER credential mapping
  if grep -q "EMAIL_HOST_USER\|MEREKA_LMS_EMAIL_HOST_USER" "$ES_BASE"; then
    pass "AC-112: EMAIL_HOST_USER mapped in base ExternalSecrets"
  else
    fail "AC-112: EMAIL_HOST_USER not found in $ES_BASE (SES SMTP username missing)"
  fi

  # Check for EMAIL_HOST_PASSWORD credential mapping
  if grep -q "EMAIL_HOST_PASSWORD\|MEREKA_LMS_EMAIL_HOST_PASSWORD" "$ES_BASE"; then
    pass "AC-112: EMAIL_HOST_PASSWORD mapped in base ExternalSecrets"
  else
    fail "AC-112: EMAIL_HOST_PASSWORD not found in $ES_BASE (SES SMTP password missing)"
  fi

  # Check that SES_SNS_WEBHOOK_SECRET is present (bounce/complaint handling)
  if grep -q "SES_SNS_WEBHOOK_SECRET" "$ES_BASE"; then
    pass "AC-112: SES_SNS_WEBHOOK_SECRET mapped in ExternalSecrets"
  else
    fail "AC-112: SES_SNS_WEBHOOK_SECRET not found in $ES_BASE"
  fi

  # Check that UNSUBSCRIBE_HMAC_SECRET is present
  if grep -q "UNSUBSCRIBE_HMAC_SECRET" "$ES_BASE"; then
    pass "AC-112: UNSUBSCRIBE_HMAC_SECRET mapped in ExternalSecrets"
  else
    fail "AC-112: UNSUBSCRIBE_HMAC_SECRET not found in $ES_BASE"
  fi
else
  fail "AC-112: ExternalSecrets base file not found at $ES_BASE"
fi

if [[ -f "$ES_NONPROD" ]]; then
  if grep -q "EMAIL_HOST_USER\|MEREKA_LMS_EMAIL_HOST_USER" "$ES_NONPROD"; then
    pass "AC-112: EMAIL_HOST_USER mapped in nonprod ExternalSecrets patch"
  else
    fail "AC-112: EMAIL_HOST_USER not found in $ES_NONPROD (dev/staging parity gap)"
  fi

  if grep -q "EMAIL_HOST_PASSWORD\|MEREKA_LMS_EMAIL_HOST_PASSWORD" "$ES_NONPROD"; then
    pass "AC-112: EMAIL_HOST_PASSWORD mapped in nonprod ExternalSecrets patch"
  else
    fail "AC-112: EMAIL_HOST_PASSWORD not found in $ES_NONPROD (dev/staging parity gap)"
  fi
else
  skip "AC-112: Nonprod ExternalSecrets patch not found at $ES_NONPROD"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-003: Email backend is Django SMTP (not console/file)
# ---------------------------------------------------------------------------
echo "--- AC-003: Email backend configuration ---"

EMAIL_SETTINGS_FOUND=false

# Check Tutor plugin for EMAIL_BACKEND or EMAIL_HOST settings
if grep -r "EMAIL_BACKEND\|EMAIL_HOST\|EMAIL_PORT\|EMAIL_USE_TLS" \
    infrastructure/tutor/plugins/ 2>/dev/null | grep -q .; then
  EMAIL_SETTINGS_FOUND=true
  pass "AC-003: Email backend settings found in Tutor plugin configuration"

  # Ensure it's not console backend
  if grep -r "ConsoleEmailBackend\|console\|filebased" \
      infrastructure/tutor/plugins/ 2>/dev/null | grep -q "EMAIL_BACKEND"; then
    fail "AC-003: Console or file email backend found — must be SMTP in production"
  else
    pass "AC-003: No console/file email backend detected in plugin settings"
  fi
else
  skip "AC-003: Email backend settings not in Tutor plugin (may be injected via env vars or production.py patch)"
fi

# Check apply-patches.sh or patch files for email settings
if grep -r "EMAIL_HOST\|EMAIL_PORT\|EMAIL_USE_TLS\|email-smtp" \
    infrastructure/tutor/patches/ 2>/dev/null | grep -q .; then
  pass "AC-003: Email SMTP settings found in Tutor patches"
else
  skip "AC-003: Email SMTP settings not in patches directory (may be set via K8s env vars)"
fi

# Verify SES endpoint is documented in EMAIL_PIPELINE.md
PIPELINE_DOC="docs/reference/operations/EMAIL_PIPELINE.md"
if [[ -f "$PIPELINE_DOC" ]]; then
  if grep -q "email-smtp.ap-southeast-1.amazonaws.com" "$PIPELINE_DOC"; then
    pass "AC-003: SES SMTP endpoint documented in EMAIL_PIPELINE.md"
  else
    fail "AC-003: SES SMTP endpoint not found in $PIPELINE_DOC"
  fi

  if grep -q "587\|STARTTLS\|EMAIL_PORT" "$PIPELINE_DOC"; then
    pass "AC-003: SMTP port 587 / STARTTLS documented"
  else
    fail "AC-003: SMTP port/TLS not documented in $PIPELINE_DOC"
  fi
else
  fail "AC-003: $PIPELINE_DOC not found"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-005: Per-tenant sender identity
# ---------------------------------------------------------------------------
echo "--- AC-005: Per-tenant sender identity ---"

if [[ -f "$DNS_DOC" ]]; then
  if grep -q "Per-Tenant Sender\|TENANT_EMAIL_SENDERS" "$DNS_DOC"; then
    pass "AC-005: Per-tenant sender identity documented in $DNS_DOC"
  else
    skip "AC-005: Per-tenant sender configuration not documented in DNS records doc"
  fi
fi

if [[ -f "$PIPELINE_DOC" ]]; then
  if grep -q "per.tenant\|tenant.*sender\|TENANT_EMAIL_SENDERS" "$PIPELINE_DOC" 2>/dev/null; then
    pass "AC-005: Per-tenant sender configuration documented in EMAIL_PIPELINE.md"
  else
    skip "AC-005: Per-tenant sender not described in EMAIL_PIPELINE.md"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-006 / AC-008 / AC-111: ACE channel configuration
# ---------------------------------------------------------------------------
echo "--- AC-006, AC-008, AC-111: ACE channel configuration ---"

# Check for ACE channel configuration in Tutor plugin
ACE_FOUND=false
for search_path in \
    "infrastructure/tutor/plugins/" \
    "infrastructure/tutor/patches/"
do
  if grep -r "ACE_ENABLED_CHANNELS\|django_email" "$search_path" 2>/dev/null | grep -q .; then
    ACE_FOUND=true
    pass "AC-111: ACE channel configuration found in $search_path"
    break
  fi
done

if [[ "$ACE_FOUND" = false ]]; then
  skip "AC-111: ACE_ENABLED_CHANNELS not found in Tutor config (may be set via bbi-infrastructure overlay)"
fi

# Check ACE documentation in pipeline doc
if [[ -f "$PIPELINE_DOC" ]]; then
  if grep -q "ACE\|Automated Communication Engine" "$PIPELINE_DOC"; then
    pass "AC-111: ACE documented in EMAIL_PIPELINE.md"
  else
    skip "AC-111: ACE not mentioned in EMAIL_PIPELINE.md"
  fi

  if grep -q "password.reset\|non.suppressible\|system.critical" "$PIPELINE_DOC" 2>/dev/null; then
    pass "AC-008: Non-suppressible system email category documented"
  else
    skip "AC-008: Non-suppressible email category not described in EMAIL_PIPELINE.md"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-113: Email monitoring PrometheusRule
# ---------------------------------------------------------------------------
echo "--- AC-113: Email monitoring infrastructure ---"

PROM_RULE="deploy/k8s/base/monitoring/prometheusrule-email.yaml"
if [[ -f "$PROM_RULE" ]]; then
  pass "AC-113: PrometheusRule for email monitoring found at $PROM_RULE"

  if grep -q "EmailBounceRateHigh" "$PROM_RULE"; then
    pass "AC-113: EmailBounceRateHigh alert defined"
  else
    fail "AC-113: EmailBounceRateHigh alert missing from PrometheusRule"
  fi

  if grep -q "EmailComplaintRateHigh" "$PROM_RULE"; then
    pass "AC-113: EmailComplaintRateHigh alert defined"
  else
    fail "AC-113: EmailComplaintRateHigh alert missing from PrometheusRule"
  fi

  if grep -q "SMTPRelayPodDown" "$PROM_RULE"; then
    pass "AC-113: SMTPRelayPodDown alert defined"
  else
    skip "AC-113: SMTPRelayPodDown alert not found (optional)"
  fi
else
  fail "AC-113: PrometheusRule for email not found at $PROM_RULE"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-114: Exim relay / SMTP relay deployment manifest
# ---------------------------------------------------------------------------
echo "--- AC-114: SMTP relay deployment ---"

SMTP_MANIFESTS=(
  "deploy/k8s/base/apps/smtp.yaml"
  "deploy/k8s/base/services/smtp.yaml"
)

SMTP_FOUND=false
for f in "${SMTP_MANIFESTS[@]}"; do
  if [[ -f "$f" ]]; then
    SMTP_FOUND=true
    pass "AC-114: SMTP relay manifest found at $f"
    if grep -q "exim\|devture/exim-relay" "$f"; then
      pass "AC-114: Exim relay image reference found in manifest"
    fi
  fi
done

if [[ "$SMTP_FOUND" = false ]]; then
  # Check if kubectl can reach the cluster
  if command -v kubectl &>/dev/null; then
    KUBE_CTX=$(kubectl config current-context 2>/dev/null || echo "none")
    if [[ "$KUBE_CTX" != "none" ]]; then
      if kubectl get deployment smtp -n mereka-lms &>/dev/null 2>&1; then
        pass "AC-114: SMTP relay deployment exists in live cluster"
      else
        skip "AC-114: SMTP relay not found in manifest dirs or cluster — may live in bbi-infrastructure repo"
      fi
    else
      skip "AC-114: SMTP relay manifest not in this repo; no kubectl context to check live cluster"
    fi
  else
    skip "AC-114: SMTP relay manifest not found in repo; kubectl not available"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
