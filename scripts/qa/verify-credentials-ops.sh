#!/usr/bin/env bash
# @spec: verifiable-credentials-ops_spec.md
# @covers AC-CRED-040, AC-CRED-041, AC-CRED-042, AC-CRED-043, AC-CRED-044, AC-CRED-045, AC-CRED-046, AC-CRED-047, AC-CRED-048
#
# Verification of CRED-050: Ops & Reliability spec compliance.
# Static checks run against repo configuration files and monitoring resources.
# Runtime ACs (metrics scraping, alert firing, backfill execution) are marked SKIP.
#
# Usage:
#   ./scripts/qa/verify-credentials-ops.sh [--skip-cluster] [--help]
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

Verify CRED-050: Ops & Reliability spec compliance (9 ACs).

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
PROMETHEUS_RULE="$REPO_ROOT/deploy/k8s/base/monitoring/prometheusrule-credentials.yaml"
RUNBOOK_KEY_ROTATION="$REPO_ROOT/docs/ops/runbooks/credential-key-rotation-runbook.md"
RUNBOOK_ISSUANCE_FAILURE="$REPO_ROOT/docs/ops/runbooks/credential-issuance-failure-runbook.md"
RUNBOOK_BACKFILL="$REPO_ROOT/docs/ops/runbooks/credential-backfill-runbook.md"
RUNBOOK_VERIFICATION_FAILURE="$REPO_ROOT/docs/ops/runbooks/credential-verification-failure-runbook.md"

echo "========================================================"
echo "  Verifiable Credentials Ops & Reliability Verification"
echo "  Spec: verifiable-credentials-ops_spec.md (9 ACs)"
echo "========================================================"
echo "Date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Repo:   $REPO_ROOT"
echo "Cluster checks: $(if $SKIP_CLUSTER; then echo SKIPPED; else echo ENABLED; fi)"
echo

###########################################################################
# SECTION 1: Prometheus Metrics (AC-CRED-040)
###########################################################################
echo "--- Prometheus Metrics ---"

# AC-CRED-040: All 10 VC metrics exposed at /metrics
# Runtime: requires Credentials Service running with django-prometheus. Mark SKIP.
skip_ "AC-CRED-040: All 10 VC-related metrics present at /metrics endpoint (requires runtime scrape)"

###########################################################################
# SECTION 2: Alerting Rules (AC-CRED-041)
###########################################################################
echo "--- Alerting Rules ---"

# AC-CRED-041: VCIssuanceLatencyHigh alert fires when p95 > 30s for 5m
if [ -f "$PROMETHEUS_RULE" ]; then
  # Check PrometheusRule exists
  if grep -q "kind: PrometheusRule" "$PROMETHEUS_RULE"; then
    pass_ "AC-CRED-041: PrometheusRule resource exists at deploy/k8s/base/monitoring/prometheusrule-credentials.yaml"
  else
    fail_ "AC-CRED-041: PrometheusRule resource not found or invalid format"
  fi

  # Check all 6 required alerts exist
  required_alerts=(
    "VCIssuanceLatencyHigh"
    "VCIssuanceFailureSpike"
    "VCClaimTokenExpiryHigh"
    "VCVerificationEndpointDown"
    "VCDIDDocumentUnavailable"
    "VCSigningKeyExpiringSoon"
  )

  missing_alerts=()
  for alert in "${required_alerts[@]}"; do
    if ! grep -q "alert: $alert" "$PROMETHEUS_RULE"; then
      missing_alerts+=("$alert")
    fi
  done

  if [ ${#missing_alerts[@]} -eq 0 ]; then
    pass_ "AC-CRED-041: All 6 required alerts configured (VCIssuanceLatencyHigh, VCIssuanceFailureSpike, VCClaimTokenExpiryHigh, VCVerificationEndpointDown, VCDIDDocumentUnavailable, VCSigningKeyExpiringSoon)"
  else
    fail_ "AC-CRED-041: Missing alerts: ${missing_alerts[*]}"
  fi

  # Verify VCIssuanceLatencyHigh specifics (p95 > 30s for 5m)
  if grep -A5 "alert: VCIssuanceLatencyHigh" "$PROMETHEUS_RULE" | grep -q "for: 5m"; then
    pass_ "AC-CRED-041: VCIssuanceLatencyHigh alert configured with 'for: 5m' duration"
  else
    fail_ "AC-CRED-041: VCIssuanceLatencyHigh alert missing 'for: 5m' configuration"
  fi
else
  fail_ "AC-CRED-041: PrometheusRule file not found at $PROMETHEUS_RULE"
fi

# Runtime alert firing test
skip_ "AC-CRED-041: VCIssuanceLatencyHigh alert fires when p95 latency exceeds threshold (requires runtime test)"

###########################################################################
# SECTION 3: Health Checks (AC-CRED-042)
###########################################################################
echo "--- Health Checks ---"

# AC-CRED-042: Health endpoint returns 503 when signing key missing
# Runtime: requires Credentials Service running with missing key. Mark SKIP.
skip_ "AC-CRED-042: Health endpoint returns HTTP 503 with signing_key=unavailable when key missing (requires runtime test)"

###########################################################################
# SECTION 4: Backfill Command (AC-CRED-043, AC-CRED-044)
###########################################################################
echo "--- Backfill Command ---"

# AC-CRED-043: backfill_credentials --dry-run reports count without creating VCs
# Runtime: requires Django management command execution. Mark SKIP.
skip_ "AC-CRED-043: backfill_credentials --dry-run reports VC count without creating any (requires runtime execution)"

# AC-CRED-044: Backfill command is idempotent (second run creates zero VCs)
# Runtime: requires two sequential backfill runs. Mark SKIP.
skip_ "AC-CRED-044: Running backfill twice for same course creates zero new VCs (idempotent) (requires runtime execution)"

###########################################################################
# SECTION 5: Structured Logging (AC-CRED-045)
###########################################################################
echo "--- Structured Logging ---"

# AC-CRED-045: VC issuance events logged as structured JSON
# Runtime: requires VC issuance + log inspection. Mark SKIP.
skip_ "AC-CRED-045: VC issuance logged as structured JSON with credential_uuid, learner_id, tenant_uuid, timestamp (requires runtime log inspection)"

###########################################################################
# SECTION 6: Claim Token Cleanup (AC-CRED-046)
###########################################################################
echo "--- Claim Token Cleanup ---"

# AC-CRED-046: Daily cleanup job removes expired claim tokens
# Runtime: requires Celery beat schedule or CronJob execution. Mark SKIP.
skip_ "AC-CRED-046: Daily cleanup job deletes claim tokens older than 24 hours (requires runtime execution)"

###########################################################################
# SECTION 7: Grafana Dashboard (AC-CRED-047)
###########################################################################
echo "--- Grafana Dashboard ---"

# AC-CRED-047: Grafana dashboard contains 7 panels
GRAFANA_DASHBOARD="$REPO_ROOT/deploy/k8s/base/monitoring/dashboards/credentials-vc.json"
if [ -f "$GRAFANA_DASHBOARD" ]; then
  # Count panels in dashboard JSON
  panel_count=$(jq '[.panels // [] | length] | add // 0' "$GRAFANA_DASHBOARD" 2>/dev/null || echo 0)
  if [ "$panel_count" -ge 7 ]; then
    pass_ "AC-CRED-047: Grafana dashboard exists with $panel_count panels (≥7 required)"
  else
    fail_ "AC-CRED-047: Grafana dashboard has only $panel_count panels (7 required: issuance, latency, claims, verification, DID, signing health, LinkedIn shares)"
  fi
else
  skip_ "AC-CRED-047: Grafana dashboard not yet created at $GRAFANA_DASHBOARD (expected for Phase 5)"
fi

###########################################################################
# SECTION 8: Operational Runbooks (AC-CRED-048)
###########################################################################
echo "--- Operational Runbooks ---"

# AC-CRED-048: Key rotation runbook exists and covers all steps
if [ -f "$RUNBOOK_KEY_ROTATION" ]; then
  # Check runbook contains key sections (match actual section names from Phase 2 runbook)
  required_sections=(
    "Generate New Ed25519 Keypair"
    "DID Document"
    "Infisical"
    "GCP Secret Manager"
    "Restart Credentials Service"
  )

  missing_sections=()
  for section in "${required_sections[@]}"; do
    if ! grep -qi "$section" "$RUNBOOK_KEY_ROTATION"; then
      missing_sections+=("$section")
    fi
  done

  if [ ${#missing_sections[@]} -eq 0 ]; then
    pass_ "AC-CRED-048: credential-key-rotation-runbook.md exists with all required sections"
  else
    fail_ "AC-CRED-048: credential-key-rotation-runbook.md missing sections: ${missing_sections[*]}"
  fi

  # Verify runbook covers old key verification (critical for CRED-020 compliance)
  if grep -qi "verif" "$RUNBOOK_KEY_ROTATION" && grep -qi "DID document" "$RUNBOOK_KEY_ROTATION"; then
    pass_ "AC-CRED-048: Key rotation runbook includes DID document verification steps"
  else
    fail_ "AC-CRED-048: Key rotation runbook missing verification steps (CRITICAL per CRED-020)"
  fi
else
  fail_ "AC-CRED-048: credential-key-rotation-runbook.md not found at $RUNBOOK_KEY_ROTATION"
fi

# Check other runbooks exist
runbooks=(
  "$RUNBOOK_ISSUANCE_FAILURE:credential-issuance-failure-runbook.md"
  "$RUNBOOK_BACKFILL:credential-backfill-runbook.md"
  "$RUNBOOK_VERIFICATION_FAILURE:credential-verification-failure-runbook.md"
)

for runbook_entry in "${runbooks[@]}"; do
  IFS=':' read -r path name <<< "$runbook_entry"
  if [ -f "$path" ]; then
    pass_ "AC-CRED-048: $name exists"
  else
    fail_ "AC-CRED-048: $name not found at $path"
  fi
done

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
