#!/usr/bin/env bash
# validate_monitor_selectors.sh
#
# Cross-references every ServiceMonitor rendered by deploy/k8s/base/monitoring/
# against Services rendered by deploy/k8s/base/.
#
# For each ServiceMonitor, checks:
#   1. The matchLabels selector matches at least one Service
#   2. The endpoint port name exists on that Service
#
# Exit 0 = all checks pass
# Exit 1 = one or more mismatches detected
#
# Requirements: kubectl (with kustomize support), python3
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MONITORING_DIR="${REPO_ROOT}/deploy/k8s/base/monitoring"
BASE_DIR="${REPO_ROOT}/deploy/k8s/base"

PASS=0
FAIL=0
SKIP=0

log_pass() { echo "PASS  $*"; ((PASS++)) || true; }
log_fail() { echo "FAIL  $*"; ((FAIL++)) || true; }
log_skip() { echo "SKIP  $*"; ((SKIP++)) || true; }
log_info() { echo "INFO  $*"; }

echo "=== ServiceMonitor Selector Validation ==="
echo ""

# Render base kustomize to a temp file
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

SERVICES_JSON="${TMPDIR}/services.json"
SERVICEMONITORS_JSON="${TMPDIR}/servicemonitors.json"

log_info "Rendering deploy/k8s/base/monitoring/ ..."
kubectl kustomize "${MONITORING_DIR}" 2>/dev/null \
  | python3 -c "
import sys, json, yaml
docs = list(yaml.safe_load_all(sys.stdin))
sms = [d for d in docs if d and d.get('kind') == 'ServiceMonitor']
print(json.dumps(sms))
" > "${SERVICEMONITORS_JSON}"

log_info "Rendering deploy/k8s/base/ for Services ..."
kubectl kustomize "${BASE_DIR}" 2>/dev/null \
  | python3 -c "
import sys, json, yaml
docs = list(yaml.safe_load_all(sys.stdin))
svcs = [d for d in docs if d and d.get('kind') == 'Service']
print(json.dumps(svcs))
" > "${SERVICES_JSON}"

SM_COUNT=$(python3 -c "import json,sys; print(len(json.load(sys.stdin)))" < "${SERVICEMONITORS_JSON}")
SVC_COUNT=$(python3 -c "import json,sys; print(len(json.load(sys.stdin)))" < "${SERVICES_JSON}")
log_info "Found ${SM_COUNT} ServiceMonitors, ${SVC_COUNT} Services"
echo ""

python3 - "${SERVICEMONITORS_JSON}" "${SERVICES_JSON}" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    monitors = json.load(f)
with open(sys.argv[2]) as f:
    services = json.load(f)

PASS = 0
FAIL = 0
SKIP = 0

for sm in monitors:
    name = sm["metadata"]["name"]
    spec = sm.get("spec", {})
    selector = spec.get("selector", {}).get("matchLabels", {})
    endpoints = spec.get("endpoints", [])

    if not selector:
        print(f"SKIP  {name}: no matchLabels selector (unusual)")
        SKIP += 1
        continue

    # Find matching services
    matched_svcs = []
    for svc in services:
        svc_labels = svc.get("metadata", {}).get("labels", {})
        if all(svc_labels.get(k) == v for k, v in selector.items()):
            matched_svcs.append(svc)

    if not matched_svcs:
        print(f"FAIL  {name}: selector {selector} matches NO Service")
        FAIL += 1
        continue

    # Check port names
    port_issues = []
    for ep in endpoints:
        port_name = ep.get("port")
        if not port_name:
            continue  # numeric port — skip name check
        for svc in matched_svcs:
            svc_ports = svc.get("spec", {}).get("ports", [])
            port_names = [p.get("name") for p in svc_ports]
            if port_name not in port_names:
                svc_name = svc["metadata"]["name"]
                port_issues.append(
                    f"port '{port_name}' not found on Service '{svc_name}' "
                    f"(has: {port_names})"
                )

    if port_issues:
        print(f"FAIL  {name}: " + "; ".join(port_issues))
        FAIL += 1
    else:
        matched_names = [s["metadata"]["name"] for s in matched_svcs]
        print(f"PASS  {name}: matches {matched_names}")
        PASS += 1

print()
print(f"=== Results: {PASS} PASS, {FAIL} FAIL, {SKIP} SKIP ===")
sys.exit(1 if FAIL > 0 else 0)
PYEOF

STATUS=$?
echo ""
if [[ $STATUS -eq 0 ]]; then
  echo "All ServiceMonitor selectors are valid."
else
  echo "One or more ServiceMonitor selectors are broken. Fix before deploying."
fi
exit $STATUS
