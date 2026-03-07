#!/usr/bin/env bash
# verify-topology-selectors.sh — Verify that expected workloads exist per lane.
#
# Cross-references config/lane-identity.yaml internal_services against
# the live cluster to detect deployment_not_found issues before they
# surface in smoke tests or migration Jobs.
#
# Usage:
#   scripts/qa/verify-topology-selectors.sh --lane <lane> [--namespace <ns>]
#   scripts/qa/verify-topology-selectors.sh --offline  # validate config only
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../lib/lane-normalize.sh
source "$REPO_ROOT/scripts/lib/lane-normalize.sh"

LANE=""
NAMESPACE=""
OFFLINE=false
PASS=0
FAIL=0
SKIP=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lane)      LANE="$(normalize_lane_to_canonical "$2")"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --offline)   OFFLINE=true; shift ;;
    -h|--help)   echo "Usage: $0 --lane <lane> [--namespace <ns>] | --offline"; exit 0 ;;
    *)           echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

LANE_IDENTITY="$REPO_ROOT/config/lane-identity.yaml"
CONTRACT="$REPO_ROOT/deploy/k8s/contract.json"

echo "Topology Selector Verification"
echo "=============================="

# 1. Validate that lane-identity internal_services match contract.json workloads
if [[ -f "$LANE_IDENTITY" && -f "$CONTRACT" ]]; then
  echo ""
  echo "Cross-referencing lane-identity <-> contract.json..."

  contract_workloads="$(python3 -c "
import json
with open('$CONTRACT') as f:
    c = json.load(f)
for w in c.get('workloads', []):
    print(w['name'])
" | sort)"

  identity_services="$(python3 -c "
import yaml
with open('$LANE_IDENTITY') as f:
    d = yaml.safe_load(f)
for s in d.get('internal_services', []):
    print(s['name'])
" | sort)"

  while IFS= read -r svc; do
    [[ -z "$svc" ]] && continue
    if echo "$contract_workloads" | grep -qx "$svc"; then
      pass "service '$svc' in contract.json workloads"
    else
      fail "service '$svc' in lane-identity but NOT in contract.json workloads"
    fi
  done <<< "$identity_services"

  while IFS= read -r wl; do
    [[ -z "$wl" ]] && continue
    if ! echo "$identity_services" | grep -qx "$wl"; then
      case "$wl" in
        mysql|redis|elasticsearch|meilisearch|smtp|postgresql-payments)
          pass "workload '$wl' is infrastructure (not in internal_services)" ;;
        mfe|enterprise-admin-portal|enterprise-learner-portal|preview-redirect|mux-delivery-monitor)
          pass "workload '$wl' is non-schema auxiliary (not in internal_services)" ;;
        enterprise-access-worker|enterprise-catalog-worker)
          pass "workload '$wl' is worker (not in internal_services)" ;;
        xqueue)
          pass "workload '$wl' is disabled (not in internal_services)" ;;
        *)
          warn "workload '$wl' in contract.json but not in lane-identity" ;;
      esac
    fi
  done <<< "$contract_workloads"
fi

if [[ "$OFFLINE" == "true" ]]; then
  echo ""
  echo "Result: $PASS passed, $FAIL failed, $SKIP skipped, $WARN warnings (offline)"
  [[ "$FAIL" -eq 0 ]] || exit 1
  exit 0
fi

if [[ -z "$LANE" ]]; then
  echo ""
  echo "No --lane specified. Use --offline for config-only or --lane for live checks."
  exit 0
fi

[[ -z "$NAMESPACE" ]] && NAMESPACE="$(normalize_lane_to_namespace "$LANE")"

echo ""
echo "Live cluster checks (lane: $LANE, namespace: $NAMESPACE)..."

while IFS= read -r svc_json; do
  name="$(echo "$svc_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")"
  kind="$(echo "$svc_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('k8s_kind','Deployment'))")"
  release_critical="$(echo "$svc_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('release_critical', False))")"

  if kubectl get "$kind" "$name" -n "$NAMESPACE" &>/dev/null 2>&1; then
    ready="$(kubectl get "$kind" "$name" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
    desired="$(kubectl get "$kind" "$name" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")"
    if [[ "${ready:-0}" -gt 0 ]]; then
      pass "$name ($kind): $ready/$desired ready"
    elif [[ "${desired:-0}" -eq 0 ]]; then
      skip "$name ($kind): scaled to 0"
    else
      if [[ "$release_critical" == "True" ]]; then
        fail "$name ($kind): 0 ready replicas (release-critical)"
      else
        warn "$name ($kind): 0 ready replicas"
      fi
    fi
  else
    if [[ "$release_critical" == "True" ]]; then
      fail "$name ($kind): deployment_not_found (release-critical)"
    else
      warn "$name ($kind): deployment_not_found (non-critical)"
    fi
  fi
done < <(python3 -c "
import yaml, json
with open('$LANE_IDENTITY') as f:
    d = yaml.safe_load(f)
for s in d.get('internal_services', []):
    print(json.dumps(s))
")

echo ""
echo "Result: $PASS passed, $FAIL failed, $SKIP skipped, $WARN warnings"
[[ "$FAIL" -eq 0 ]] || exit 1
