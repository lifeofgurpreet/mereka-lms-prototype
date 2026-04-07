#!/usr/bin/env bash
# @covers AC-002
# @spec: disaster-recovery-business-continuity_spec.md
# List Bound PVCs covered by the "hourly critical databases" Velero schedule.
#
# Purpose:
# - Provides a deterministic inventory of stateful data that must be snapshotted.
# - Helps tune/validate backup-verification thresholds (e.g., MIN_HOURLY_PVCS).
#
# Usage:
#   ./scripts/qa/list-critical-backup-pvcs.sh
#   ./scripts/qa/list-critical-backup-pvcs.sh --context rke2-prod
#   ./scripts/qa/list-critical-backup-pvcs.sh --schedule velero-local-hourly-critical-databases
#   ./scripts/qa/list-critical-backup-pvcs.sh --json
#
set -euo pipefail

K8S_CONTEXT="${K8S_CONTEXT:-${K8S_CONTEXT_PROD:-rke2-prod}}"
VELERO_NS="${VELERO_NS:-velero}"
SCHEDULE_NAME="${SCHEDULE_NAME:-velero-local-hourly-critical-databases}"
JSON_OUT=0

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/list-critical-backup-pvcs.sh [--context CONTEXT] [--velero-namespace NS] [--schedule NAME] [--json]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) K8S_CONTEXT="${2:-}"; shift 2 ;;
    --velero-namespace) VELERO_NS="${2:-}"; shift 2 ;;
    --schedule) SCHEDULE_NAME="${2:-}"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

schedule_json="$(kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get schedule.velero.io "$SCHEDULE_NAME" -o json)"

ns_list="$(
  python3 -c 'import json,sys; d=json.load(sys.stdin); ns=(d.get("spec") or {}).get("template", {}).get("includedNamespaces") or []; print(" ".join([n for n in ns if isinstance(n,str) and n.strip()]))' \
    <<<"$schedule_json"
)"

if [[ -z "${ns_list:-}" ]]; then
  echo "No includedNamespaces found for schedule $SCHEDULE_NAME (namespace=$VELERO_NS)" >&2
  exit 1
fi

tmpdir="$(mktemp -d -t list-critical-pvcs.XXXXXX)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

items=()
total_bound=0

for ns in $ns_list; do
  pvc_json_path="$tmpdir/pvc_${ns}.json"
  kubectl --context "$K8S_CONTEXT" -n "$ns" get pvc -o json >"$pvc_json_path" 2>/dev/null || echo '{"items":[]}' >"$pvc_json_path"

  # Emit either JSON objects or TSV rows.
  if [[ "$JSON_OUT" -eq 1 ]]; then
    python3 - "$ns" "$pvc_json_path" <<'PY'
import json, sys
ns = sys.argv[1]
path = sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

out = []
for pvc in data.get("items", []):
    st = pvc.get("status") or {}
    if st.get("phase") != "Bound":
        continue
    meta = pvc.get("metadata") or {}
    spec = pvc.get("spec") or {}
    out.append({
        "namespace": ns,
        "name": meta.get("name"),
        "storage_class": spec.get("storageClassName"),
        "volume_name": spec.get("volumeName"),
        "capacity": (st.get("capacity") or {}).get("storage"),
    })
print(json.dumps(out))
PY
  else
    python3 - "$ns" "$pvc_json_path" <<'PY'
import json, sys
ns = sys.argv[1]
path = sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

for pvc in data.get("items", []):
    st = pvc.get("status") or {}
    if st.get("phase") != "Bound":
        continue
    meta = pvc.get("metadata") or {}
    spec = pvc.get("spec") or {}
    cap = (st.get("capacity") or {}).get("storage") or ""
    sc = spec.get("storageClassName") or ""
    vn = spec.get("volumeName") or ""
    name = meta.get("name") or ""
    print(f"{ns}\t{name}\t{cap}\t{sc}\t{vn}")
PY
  fi
done >"$tmpdir/out"

if [[ "$JSON_OUT" -eq 1 ]]; then
  # Merge per-namespace JSON arrays into one.
  K8S_CONTEXT="$K8S_CONTEXT" VELERO_NS="$VELERO_NS" SCHEDULE_NAME="$SCHEDULE_NAME" NS_LIST="$ns_list" \
    python3 - "$tmpdir/out" <<'PY'
import os
import json, sys
path = sys.argv[1]
items = []
with open(path, "r", encoding="utf-8") as f:
  for line in f:
    line = line.strip()
    if not line:
        continue
    try:
        arr = json.loads(line)
        if isinstance(arr, list):
            items.extend(arr)
    except Exception:
        pass
print(json.dumps({
    "context": os.environ.get("K8S_CONTEXT", ""),
    "velero_namespace": os.environ.get("VELERO_NS", ""),
    "schedule": os.environ.get("SCHEDULE_NAME", ""),
    "included_namespaces": [n for n in (os.environ.get("NS_LIST", "").split()) if n],
    "bound_pvcs": items,
    "bound_pvc_count": len(items),
}, indent=2, sort_keys=True))
PY
else
  echo -e "namespace\tpvc\tcapacity\tstorageclass\tpv"
  cat "$tmpdir/out"
  total_bound="$(wc -l <"$tmpdir/out" | tr -d ' ')"
  echo ""
  echo "Bound PVCs total: $total_bound"
fi
