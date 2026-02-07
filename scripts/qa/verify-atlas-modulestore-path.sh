#!/usr/bin/env bash
# Verify Atlas modulestore path contracts (repo + runtime).
#
# Usage:
#   ./scripts/qa/verify-atlas-modulestore-path.sh
#   ./scripts/qa/verify-atlas-modulestore-path.sh --mode local
#   STRICT_RUNTIME=1 ./scripts/qa/verify-atlas-modulestore-path.sh --mode runtime
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"
FAIL_ON_LEGACY_MONGODB="${FAIL_ON_LEGACY_MONGODB:-0}"
MODE="all" # local | runtime | all

usage() {
  cat <<'USAGE'
Usage: ./scripts/qa/verify-atlas-modulestore-path.sh [--mode local|runtime|all]
Env:
  STRICT_RUNTIME=1         Fail if runtime checks cannot be executed
  FAIL_ON_LEGACY_MONGODB=1 Fail if in-cluster mongodb deployment still exists
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$MODE" != "local" && "$MODE" != "runtime" && "$MODE" != "all" ]]; then
  echo "Invalid --mode: $MODE" >&2
  usage
  exit 1
fi

failures=0
warnings=0

run_check() {
  local name="$1"; shift
  local tmp rc out
  tmp="$(mktemp -t atlas-modulestore-check.XXXXXX)"

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

check_local_modulestore_contract() {
  command -v python3 >/dev/null

  python3 - <<'PY'
import pathlib
import re
import sys

repo = pathlib.Path(".")

deployments = (repo / "deploy/k8s/base/deployments.yml").read_text(encoding="utf-8")
external_secrets = (repo / "deploy/k8s/base/secrets/external-secrets.yaml").read_text(encoding="utf-8")
lms_settings = (repo / "deploy/k8s/base/apps/openedx/settings/lms/production.py").read_text(encoding="utf-8")
cms_settings = (repo / "deploy/k8s/base/apps/openedx/settings/cms/production.py").read_text(encoding="utf-8")

errors = []

raw_docs = re.split(r"(?m)^---\s*$", deployments)
docs = {}
for doc in raw_docs:
    if not re.search(r"(?m)^kind:\s*Deployment\s*$", doc):
        continue
    m = re.search(r"(?m)^metadata:\s*$([\s\S]*?)^spec:\s*$", doc)
    if not m:
        continue
    name_match = re.search(r"(?m)^\s*name:\s*([a-zA-Z0-9-]+)\s*$", m.group(1))
    if not name_match:
        continue
    docs[name_match.group(1)] = doc

expected_deployments = ["lms", "cms", "lms-worker", "cms-worker"]
pat = re.compile(
    r"-\s*name:\s*MONGODB_HOST\s+valueFrom:\s+secretKeyRef:\s+name:\s*openedx-secrets\s+key:\s*FORUM_MONGODB_SRV",
    re.S,
)
for dep in expected_deployments:
    doc = docs.get(dep)
    if not doc:
        errors.append(f"Deployment '{dep}' missing from deploy/k8s/base/deployments.yml")
        continue
    if not pat.search(doc):
        errors.append(
            f"Deployment '{dep}' missing MONGODB_HOST -> openedx-secrets/FORUM_MONGODB_SRV contract"
        )

secret_pat = re.compile(
    r"-\s*secretKey:\s*FORUM_MONGODB_SRV\s+remoteRef:\s+key:\s*MEREKA_LMS_FORUM_MONGODB_SRV",
    re.S,
)
if not secret_pat.search(external_secrets):
    errors.append(
        "ExternalSecret contract missing FORUM_MONGODB_SRV <- MEREKA_LMS_FORUM_MONGODB_SRV mapping"
    )

for name, content in (("lms", lms_settings), ("cms", cms_settings)):
    required_tokens = [
        "_mongodb_is_atlas = _mongodb_host_lower.startswith(\"mongodb+srv://\") or \".mongodb.net\" in _mongodb_host_lower",
        "if _mongodb_is_atlas:",
        "\"host\": MONGODB_HOST",
        "\"ssl\": bool(_mongodb_is_atlas)",
    ]
    for token in required_tokens:
        if token not in content:
            errors.append(f"{name} settings missing token: {token}")

if errors:
    for err in errors:
        print(err)
    sys.exit(1)
PY
}

check_runtime_env_contract() {
  command -v kubectl >/dev/null
  command -v python3 >/dev/null

  if ! kubectl --context "$K8S_CONTEXT" get namespace "$APP_NS" >/dev/null 2>&1; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Cannot reach context/namespace: $K8S_CONTEXT / $APP_NS"
      return 1
    fi
    echo "SKIP: cannot reach context/namespace: $K8S_CONTEXT / $APP_NS"
    return 0
  fi

  local dep json
  for dep in lms cms lms-worker cms-worker; do
    json="$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy "$dep" -o json)"
    python3 - "$dep" "$json" <<'PY'
import json
import sys

dep = sys.argv[1]
obj = json.loads(sys.argv[2])
containers = (obj.get("spec") or {}).get("template", {}).get("spec", {}).get("containers") or []
if not containers:
    raise SystemExit(f"Deployment {dep}: no containers")

env = containers[0].get("env") or []
entry = next((x for x in env if x.get("name") == "MONGODB_HOST"), None)
if not entry:
    raise SystemExit(f"Deployment {dep}: missing MONGODB_HOST env var")

ref = ((entry.get("valueFrom") or {}).get("secretKeyRef") or {})
name = ref.get("name")
key = ref.get("key")
if name != "openedx-secrets" or key != "FORUM_MONGODB_SRV":
    raise SystemExit(
        f"Deployment {dep}: expected MONGODB_HOST from openedx-secrets/FORUM_MONGODB_SRV, got {name}/{key}"
    )
PY
  done
}

check_runtime_modulestore_is_atlas() {
  command -v kubectl >/dev/null

  if ! kubectl --context "$K8S_CONTEXT" get namespace "$APP_NS" >/dev/null 2>&1; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Cannot reach context/namespace: $K8S_CONTEXT / $APP_NS"
      return 1
    fi
    echo "SKIP: cannot reach context/namespace: $K8S_CONTEXT / $APP_NS"
    return 0
  fi

  local svc out
  for svc in lms cms; do
    out="$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" exec "deploy/$svc" -- \
      python -c 'import os; h=os.environ.get("MONGODB_HOST", ""); print("atlas" if (h.startswith("mongodb+srv://") or ".mongodb.net" in h) else "non_atlas")' \
      2>/dev/null || true)"

    if [[ "$out" != "atlas" ]]; then
      echo "Deployment $svc is not using Atlas via MONGODB_HOST"
      return 1
    fi
  done
}

check_runtime_legacy_mongodb_presence() {
  command -v kubectl >/dev/null
  command -v python3 >/dev/null

  if ! kubectl --context "$K8S_CONTEXT" get namespace "$APP_NS" >/dev/null 2>&1; then
    if [[ "$STRICT_RUNTIME" == "1" ]]; then
      echo "Cannot reach context/namespace: $K8S_CONTEXT / $APP_NS"
      return 1
    fi
    echo "SKIP: cannot reach context/namespace: $K8S_CONTEXT / $APP_NS"
    return 0
  fi

  if ! kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy mongodb >/dev/null 2>&1; then
    echo "legacy mongodb deployment not present"
    return 0
  fi

  local volumes
  volumes="$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy mongodb -o jsonpath='{.spec.template.spec.volumes}')"

  set +e
  python3 - "$volumes" <<'PY'
import json
import sys

raw = (sys.argv[1] or "").strip()
if not raw:
    raise SystemExit(0)

try:
    vols = json.loads(raw)
except Exception as exc:
    raise SystemExit(f"unable to parse mongodb volumes JSON: {exc}")

has_empty_dir = any("emptyDir" in (v or {}) for v in vols)
if has_empty_dir:
    raise SystemExit("legacy mongodb deployment exists and still uses emptyDir")
print("legacy mongodb deployment exists (non-emptyDir)")
PY
  local rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    return 0
  fi

  if [[ "$FAIL_ON_LEGACY_MONGODB" == "1" ]]; then
    echo "legacy mongodb deployment still present"
    return 1
  fi

  warn_msg "legacy mongodb deployment still present (set FAIL_ON_LEGACY_MONGODB=1 to fail gate)"
  return 0
}

echo "Verify: Atlas modulestore path"
echo "  mode:                  $MODE"
echo "  context:               $K8S_CONTEXT"
echo "  app namespace:         $APP_NS"
echo "  strict runtime:        $STRICT_RUNTIME"
echo "  fail on legacy mongo:  $FAIL_ON_LEGACY_MONGODB"
echo ""

if [[ "$MODE" == "local" || "$MODE" == "all" ]]; then
  run_check "local: deployment contracts point modulestore to secret-backed Atlas host" \
    check_local_modulestore_contract
fi

if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
  run_check "runtime: deployment env contract for MONGODB_HOST" \
    check_runtime_env_contract
  run_check "runtime: lms/cms resolve Atlas modulestore host" \
    check_runtime_modulestore_is_atlas
  run_check "runtime: legacy mongodb deployment posture" \
    check_runtime_legacy_mongodb_presence
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
