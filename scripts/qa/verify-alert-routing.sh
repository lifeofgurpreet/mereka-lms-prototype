#!/usr/bin/env bash
# Verify alert routing end-to-end (repo contracts + runtime policies/channels).
#
# Usage:
#   ./scripts/qa/verify-alert-routing.sh
#   STRICT_WEBHOOK=1 ./scripts/qa/verify-alert-routing.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PROJECT="${GCP_PROJECT:-mereka-lms}"
K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
STRICT_RUNTIME="${STRICT_RUNTIME:-1}"
STRICT_WEBHOOK="${STRICT_WEBHOOK:-1}"
RUN_ATLAS_VPS_AUDIT="${RUN_ATLAS_VPS_AUDIT:-1}"

failures=0
warnings=0

run_check() {
  local name="$1"; shift
  local tmp rc out
  tmp="$(mktemp -t verify-alert-routing.XXXXXX)"

  set +e
  "$@" >"$tmp" 2>&1
  rc=$?
  set -e

  out="$(cat "$tmp")"
  rm -f "$tmp"

  if [[ "$rc" -eq 0 ]]; then
    echo "OK   $name"
  else
    failures=$((failures + 1))
    echo "FAIL $name"
    if [[ -n "$out" ]]; then
      echo "$out" | sed 's/^/  /'
    fi
  fi
}

warn_msg() {
  warnings=$((warnings + 1))
  echo "WARN $*"
}

check_repo_high_severity_policies_have_channels() {
  command -v python3 >/dev/null

  python3 - <<'PY'
import json
import pathlib
import sys

alerts_dir = pathlib.Path("infrastructure/monitoring/alerts")
unsupported = {"velero-restore-test-stale.json"}
errors = []
required_severities = {"ERROR", "CRITICAL"}

for path in sorted(alerts_dir.glob("*.json")):
    if path.name in unsupported:
        continue
    obj = json.loads(path.read_text(encoding="utf-8"))
    severity = (obj.get("severity") or "").strip().upper()
    if severity not in required_severities:
        continue
    channels = obj.get("notificationChannels") or []
    if not channels:
        errors.append(
            f"{path.name}: {severity} policy has no notificationChannels"
        )

if errors:
    for e in errors:
        print(e)
    sys.exit(1)
PY
}

check_runtime_high_severity_policies_and_channels() {
  command -v gcloud >/dev/null
  command -v python3 >/dev/null

  local account
  account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
  if [[ -z "$account" ]]; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "No active gcloud account. Run: gcloud auth login"
      return 1
    fi
    warn_msg "Skipping runtime GCP routing check (no active gcloud account)."
    return 0
  fi

  local policies channels
  policies="$(gcloud monitoring policies list --project="$PROJECT" --format=json)"
  channels=""
  if channels="$(gcloud monitoring channels list --project="$PROJECT" --format=json 2>/dev/null)"; then
    :
  elif channels="$(gcloud alpha monitoring channels list --project="$PROJECT" --format=json 2>/dev/null)"; then
    :
  elif channels="$(gcloud beta monitoring channels list --project="$PROJECT" --format=json 2>/dev/null)"; then
    :
  else
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Unable to list Monitoring notification channels (tried stable/alpha/beta commands)"
      return 1
    fi
    warn_msg "Skipping runtime channel validation (gcloud monitoring channels API unavailable in this environment)."
    return 0
  fi

  python3 - "$policies" "$channels" <<'PY'
import json
import pathlib
import sys

runtime_policies = json.loads(sys.argv[1])
runtime_channels = json.loads(sys.argv[2])

unsupported = {"velero-restore-test-stale.json"}
required_severities = {"ERROR", "CRITICAL"}
expected_high_severity_policy_names = []
for path in sorted(pathlib.Path("infrastructure/monitoring/alerts").glob("*.json")):
    if path.name in unsupported:
        continue
    obj = json.loads(path.read_text(encoding="utf-8"))
    if (obj.get("severity") or "").strip().upper() in required_severities:
        expected_high_severity_policy_names.append(obj.get("displayName", ""))

runtime_by_name = {p.get("displayName", ""): p for p in runtime_policies}
channel_by_name = {c.get("name", ""): c for c in runtime_channels}

errors = []
for display_name in expected_high_severity_policy_names:
    policy = runtime_by_name.get(display_name)
    if not policy:
        errors.append(f"Missing runtime high-severity policy: {display_name}")
        continue
    if not policy.get("enabled", False):
        errors.append(f"Runtime high-severity policy disabled: {display_name}")
    policy_channels = policy.get("notificationChannels") or []
    if not policy_channels:
        errors.append(
            f"Runtime high-severity policy has no routing channels: {display_name}"
        )
        continue
    for ch in policy_channels:
        channel = channel_by_name.get(ch)
        if not channel:
            errors.append(f"Policy {display_name} references missing channel: {ch}")
            continue
        if not channel.get("enabled", False):
            errors.append(f"Policy {display_name} references disabled channel: {ch}")

if errors:
    for e in errors:
        print(e)
    sys.exit(1)
PY
}

echo "Verify: alert routing"
echo "  project:              $PROJECT"
echo "  context:              $K8S_CONTEXT"
echo "  strict runtime:       $STRICT_RUNTIME"
echo "  strict webhook:       $STRICT_WEBHOOK"
echo "  run atlas vps audit:  $RUN_ATLAS_VPS_AUDIT"
echo ""

run_check "repo: high-severity alert templates declare notification channels" \
  check_repo_high_severity_policies_have_channels

run_check "runtime: high-severity policies + channels are enabled" \
  check_runtime_high_severity_policies_and_channels

run_check "runtime: observability audit" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" \
  ./scripts/qa/audit-observability.sh --mode runtime

run_check "runtime: velero alert pipeline audit" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" \
  ./scripts/qa/audit-velero-alert-pipeline.sh

if [[ "$RUN_ATLAS_VPS_AUDIT" == "1" ]]; then
  run_check "runtime: atlas allowlist monitor routing" \
    env STRICT_WEBHOOK="$STRICT_WEBHOOK" ./scripts/qa/audit-atlas-allowlist-monitor.sh
fi

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "OK"
else
  echo "FAILED ($failures checks failed)"
fi

if [[ "$warnings" -gt 0 ]]; then
  echo "WARNINGS ($warnings)"
fi

[[ "$failures" -eq 0 ]]
