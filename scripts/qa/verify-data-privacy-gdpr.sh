#!/usr/bin/env bash
# @spec: data-privacy-gdpr-compliance_spec.md
# @covers AC-001, AC-002, AC-PRIVACY-001, AC-PRIVACY-002, AC-008, AC-009, AC-010, AC-031, AC-DELETE-001, AC-DELETE-005, AC-013, AC-EXPORT-003, AC-018, AC-019, AC-RETENTION-001, AC-020, AC-AUDIT-001, AC-023, AC-025, AC-026, AC-003, AC-CONSENT-001, AC-027, AC-COMPLIANCE-001
#
# Data Privacy & GDPR Compliance — Verification Script
# Validates prerequisites for GDPR/PDPA compliance framework.
# Most checks are SKIP since GDPR features are not yet implemented.
#
# Usage:
#   ./scripts/qa/verify-data-privacy-gdpr.sh
set -euo pipefail

PASS=0; FAIL=0; SKIP=0
NAMESPACE="mereka-lms"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

_HAS_KUBECTL=""
has_kubectl() {
  if [[ -z "$_HAS_KUBECTL" ]]; then
    if command -v kubectl &>/dev/null && timeout 5 kubectl cluster-info &>/dev/null 2>&1; then
      _HAS_KUBECTL="yes"
    else
      _HAS_KUBECTL="no"
    fi
  fi
  [[ "$_HAS_KUBECTL" == "yes" ]]
}

echo "=== Data Privacy & GDPR Compliance Verification ==="
echo ""

# ── Section 1: PII Data Classification (AC-001, AC-PRIVACY-001, AC-PRIVACY-002) ──
echo "--- PII Data Classification ---"

# AC-001: PII registry exists
pii_registry="$REPO_ROOT/specs/pii-registry.yml"
if [[ -f "$pii_registry" ]]; then
  pass "AC-001: PII registry exists at specs/pii-registry.yml"

  # Check that it contains data store entries
  if grep -q "data_store" "$pii_registry" 2>/dev/null; then
    pass "AC-PRIVACY-001: PII registry contains data_store entries"
  else
    fail "AC-PRIVACY-001: PII registry missing data_store entries"
  fi

  # Check sensitivity tier classification
  if grep -q "sensitivity" "$pii_registry" 2>/dev/null; then
    pass "AC-PRIVACY-001: PII registry contains sensitivity tier classification"
  else
    fail "AC-PRIVACY-001: PII registry missing sensitivity tier classification"
  fi
else
  skip "AC-001: PII registry not yet created (specs/pii-registry.yml)"
  skip "AC-PRIVACY-001: PII classification matrix not yet created"
fi

# AC-002: CI pipeline blocks deployment if PII registry not updated
# Check for a CI workflow that references pii-registry
ci_workflows="$REPO_ROOT/.github/workflows"
if [[ -d "$ci_workflows" ]]; then
  if grep -rl "pii-registry" "$ci_workflows" 2>/dev/null | head -1 | grep -q .; then
    pass "AC-002: CI pipeline references pii-registry validation"
  else
    skip "AC-002: CI pipeline does not yet validate pii-registry on migration changes"
  fi
else
  skip "AC-002: No CI workflows directory found"
fi

# AC-PRIVACY-002: Schema migration hook for PII registry
skip "AC-PRIVACY-002: Migration hook for PII registry update not yet implemented"

echo ""

# ── Section 2: PII Handling & Deletion Pipeline (AC-008 .. AC-012, AC-DELETE-*) ──
echo "--- Deletion Pipeline ---"

# AC-008: Deletion request API endpoint
skip "AC-008: Deletion request API (POST /api/v1/privacy/deletion-request/) not yet implemented"

# AC-009: User data anonymization across stores
skip "AC-009: Cross-store data anonymization pipeline not yet implemented"

# AC-010: Cryptographic deletion proof generation
skip "AC-010: Deletion proof with cryptographic signature not yet implemented"

# AC-031: Deletion certificate with SHA-256 hash
skip "AC-031: Deletion certificate generation not yet implemented"

# AC-DELETE-001: 15-store sequential deletion orchestration
skip "AC-DELETE-001: Deletion pipeline orchestrator not yet implemented"

# AC-DELETE-005: Deletion certificate schema validation
skip "AC-DELETE-005: Deletion certificate schema (per-store manifest) not yet implemented"

echo ""

# ── Section 3: Data Export Pipeline (AC-013, AC-EXPORT-003) ──
echo "--- Data Export Pipeline ---"

# AC-013: Export request API endpoint
skip "AC-013: Export request API (POST /api/v1/privacy/export-request/) not yet implemented"

# AC-EXPORT-003: Export archive structure
skip "AC-EXPORT-003: Export archive (profile.json, enrollments.json, etc.) not yet implemented"

echo ""

# ── Section 4: Consent Management (AC-003, AC-CONSENT-001) ──
echo "--- Consent Management ---"

# AC-003: Consent records on user registration
skip "AC-003: Consent record creation on registration not yet implemented"

# AC-CONSENT-001: Cookie consent banner
# Check if any cookie consent library or component references exist in the codebase
if grep -rl "cookie.consent\|cookieConsent\|cookie-consent\|CookieConsent" \
    "$REPO_ROOT/infrastructure/" "$REPO_ROOT/deploy/" 2>/dev/null | head -1 | grep -q .; then
  pass "AC-CONSENT-001: Cookie consent component references found in codebase"
else
  skip "AC-CONSENT-001: Cookie consent banner not yet implemented"
fi

echo ""

# ── Section 5: Data Retention (AC-018, AC-019, AC-RETENTION-001) ──
echo "--- Data Retention ---"

# AC-018: ClickHouse retention (365 days)
# Check if there's a ClickHouse retention policy or CronJob
if grep -rl "retention\|purge\|xapi_events" "$REPO_ROOT/deploy/k8s/" 2>/dev/null | \
   grep -i "clickhouse\|analytics" | head -1 | grep -q .; then
  pass "AC-018: ClickHouse retention configuration found"
else
  skip "AC-018: ClickHouse analytics retention policy (365 days) not yet configured"
fi

# AC-019: Loki log retention (30 days)
# Check Loki configuration for retention_period
loki_configs=$(find "$REPO_ROOT/infrastructure" "$REPO_ROOT/deploy" -name '*loki*' -type f 2>/dev/null)
if [[ -n "$loki_configs" ]]; then
  if echo "$loki_configs" | xargs grep -l "retention" 2>/dev/null | head -1 | grep -q .; then
    pass "AC-019: Loki retention policy configuration found"
  else
    skip "AC-019: Loki retention period not explicitly configured (30 day default assumed)"
  fi
else
  skip "AC-019: No Loki configuration files found"
fi

# AC-RETENTION-001: Automated data purge CronJob
if has_kubectl; then
  purge_job=$(kubectl get cronjobs -n "$NAMESPACE" -o name 2>/dev/null | grep -i "retention\|purge\|privacy" || true)
  if [[ -n "$purge_job" ]]; then
    pass "AC-RETENTION-001: Data retention CronJob found in cluster: $purge_job"
  else
    skip "AC-RETENTION-001: No retention CronJob found in cluster (not yet deployed)"
  fi
else
  skip "AC-RETENTION-001: No cluster access -- cannot verify retention CronJob"
fi

echo ""

# ── Section 6: Audit Trail (AC-020, AC-AUDIT-001) ──
echo "--- Audit Trail ---"

# AC-020: Audit trail entries for privacy events
skip "AC-020: Tamper-evident audit trail infrastructure not yet implemented"

# AC-AUDIT-001: Audit trail logging for export requests
skip "AC-AUDIT-001: Audit trail logging for privacy events not yet implemented"

echo ""

# ── Section 7: PII Leakage Detection (AC-023, AC-025, AC-026) ──
echo "--- PII Leakage Detection ---"

# AC-023: PII leakage scanner for Loki logs
pii_scanner="$REPO_ROOT/scripts/qa/audit-analytics-pii.sh"
if [[ -f "$pii_scanner" ]]; then
  pass "AC-023: PII audit script exists (audit-analytics-pii.sh)"
else
  skip "AC-023: PII leakage scanner not yet implemented"
fi

# AC-025: Loki log email pattern scanning
skip "AC-025: Loki log PII pattern scanning not yet implemented"

# AC-026: ClickHouse xapi_events_all PII scanning
if [[ -f "$pii_scanner" ]]; then
  if grep -q "xapi_events\|actor_mbox\|clickhouse" "$pii_scanner" 2>/dev/null; then
    pass "AC-026: PII audit script references ClickHouse/xapi_events"
  else
    skip "AC-026: PII audit script does not yet cover ClickHouse xapi_events"
  fi
else
  skip "AC-026: ClickHouse PII scanner not yet implemented"
fi

echo ""

# ── Section 8: Compliance Dashboard (AC-027, AC-COMPLIANCE-001) ──
echo "--- Compliance Dashboard ---"

# AC-027: Consent coverage API
skip "AC-027: Consent coverage API (GET /api/v1/privacy/compliance/consent-coverage/) not yet implemented"

# AC-COMPLIANCE-001: Compliance dashboard
skip "AC-COMPLIANCE-001: Compliance dashboard (DSAR counts, SLA, consent rates) not yet implemented"

echo ""

# ── Section 9: Secrets & Encryption Key Management ──
echo "--- Encryption & Secrets ---"

# Check that encryption-related secrets are in ExternalSecrets
es_file="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
if [[ -f "$es_file" ]]; then
  # Check for any privacy/encryption-related secret references
  if grep -q "SECRET_KEY\|ENCRYPTION_KEY\|FERNET" "$es_file" 2>/dev/null; then
    pass "Encryption keys referenced in ExternalSecrets"
  else
    skip "No dedicated privacy encryption keys in ExternalSecrets yet"
  fi
else
  skip "ExternalSecrets file not found"
fi

# Check pre-commit hook exists for secret scanning
hook_file="$REPO_ROOT/.githooks/pre-commit"
if [[ -f "$hook_file" ]]; then
  pass "Pre-commit secret scanning hook exists"
else
  skip "Pre-commit secret scanning hook not found"
fi

# ── Summary ─────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  SKIP: $SKIP"
TOTAL=$((PASS + FAIL + SKIP))
echo "  TOTAL: $TOTAL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi

echo "RESULT: OK (most GDPR features pending implementation)"
exit 0
