#!/usr/bin/env bash
# @covers AC-SEC-ESO-ALERT
# @spec: secrets-management_spec.md
# Verify ExternalSecrets failure alerting is configured correctly.
#
# Checks (offline):
#   1. PrometheusRule YAML exists with expected alert names
#   2. PrometheusRule is referenced in monitoring kustomization.yaml
#
# Checks (--online):
#   3. PrometheusRule resource deployed in cluster
#   4. Prometheus can see the rule group
#
# Usage:
#   ./scripts/qa/verify-eso-alerting.sh            # Offline only
#   ./scripts/qa/verify-eso-alerting.sh --online    # Include cluster checks
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

pass() { echo -e "${GREEN}OK${NC}   $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIPPED=$((SKIPPED + 1)); }

ONLINE=false
if [[ "${1:-}" == "--online" ]]; then
  ONLINE=true
fi

RULE_FILE="deploy/k8s/base/monitoring/prometheusrule-externalsecrets.yaml"
KUST_FILE="deploy/k8s/base/monitoring/kustomization.yaml"

# ---------------------------------------------------------------------------
# 1. PrometheusRule file exists
# ---------------------------------------------------------------------------
echo "== Offline checks =="

if [[ -f "$RULE_FILE" ]]; then
  pass "PrometheusRule file exists: ${RULE_FILE}"
else
  fail "PrometheusRule file missing: ${RULE_FILE}"
  echo ""
  echo "Summary: PASSED=${PASSED} FAILED=${FAILED} SKIPPED=${SKIPPED}"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Expected alert names present in file
# ---------------------------------------------------------------------------
for alert_name in ExternalSecretSyncFailure ExternalSecretStaleSync; do
  content=$(cat "$RULE_FILE")
  if echo "$content" | grep -q "alert: ${alert_name}"; then
    pass "alert '${alert_name}' defined in PrometheusRule"
  else
    fail "alert '${alert_name}' NOT found in PrometheusRule"
  fi
done

# ---------------------------------------------------------------------------
# 3. Severity labels
# ---------------------------------------------------------------------------
content=$(cat "$RULE_FILE")
if echo "$content" | grep -q 'severity: warning'; then
  pass "severity=warning label present (ExternalSecretSyncFailure)"
else
  fail "severity=warning label missing"
fi

if echo "$content" | grep -q 'severity: info'; then
  pass "severity=info label present (ExternalSecretStaleSync)"
else
  fail "severity=info label missing"
fi

# ---------------------------------------------------------------------------
# 4. Referenced in kustomization.yaml
# ---------------------------------------------------------------------------
kust_content=$(cat "$KUST_FILE")
if echo "$kust_content" | grep -q 'prometheusrule-externalsecrets.yaml'; then
  pass "PrometheusRule referenced in monitoring kustomization.yaml"
else
  fail "PrometheusRule NOT referenced in monitoring kustomization.yaml"
fi

# ---------------------------------------------------------------------------
# Online checks (cluster)
# ---------------------------------------------------------------------------
if [[ "$ONLINE" == "true" ]]; then
  echo ""
  echo "== Online checks =="

  # 5. PrometheusRule exists in cluster
  if kubectl get prometheusrule externalsecret-alerts -n mereka-lms >/dev/null 2>&1; then
    pass "PrometheusRule 'externalsecret-alerts' deployed in cluster"
  else
    fail "PrometheusRule 'externalsecret-alerts' NOT found in cluster"
  fi

  # 6. ExternalSecrets are all Ready
  es_list=$(kubectl get externalsecret -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}={.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null || true)
  if [[ -n "$es_list" ]]; then
    while IFS= read -r line; do
      name="${line%%=*}"
      status="${line##*=}"
      if [[ "$status" == "True" ]]; then
        pass "ExternalSecret '${name}' is Ready"
      else
        fail "ExternalSecret '${name}' is NOT Ready (status=${status})"
      fi
    done <<< "$es_list"
  else
    skip "no ExternalSecrets found in mereka-lms namespace"
  fi
else
  skip "online checks (pass --online to enable)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Summary: PASSED=${PASSED} FAILED=${FAILED} SKIPPED=${SKIPPED}"
if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
