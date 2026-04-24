#!/usr/bin/env bash
# One-command live substrate validation for synthetic proof fixtures.
#
# Runs the full validate-runtime-proof-fixtures.py in live-readonly mode
# inside the LMS pod. Covers: users, enterprise customers, enterprise links,
# catalogs, UUID drift, waffle flags, and password usability.
#
# Usage:
#   ./scripts/tenants/validate-substrate-live.sh [--namespace mereka-lms-dev]
#   ./scripts/tenants/validate-substrate-live.sh --json
#
# Prerequisites:
#   - kubectl configured with access to the target cluster
#   - LMS pod running in the target namespace

set -euo pipefail

NAMESPACE="${NAMESPACE:-mereka-lms-dev}"
ENV="${ENV:-dev}"
JSON_FLAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --json)
      JSON_FLAG="--json"
      shift
      ;;
    --env)
      ENV="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--namespace NS] [--env ENV] [--json]" >&2
      exit 1
      ;;
  esac
done

echo "=== Synthetic Proof Substrate Live Validation ==="
echo "Namespace : ${NAMESPACE}"
echo "Env       : ${ENV}"
echo ""

# Find the LMS pod.
LMS_POD=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=lms \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [[ -z "${LMS_POD}" ]]; then
  echo "ERROR: No LMS pod found in namespace ${NAMESPACE}" >&2
  echo "Try: kubectl get pods -n ${NAMESPACE}" >&2
  exit 1
fi

echo "LMS Pod   : ${LMS_POD}"
echo ""

TMP_DIR="/tmp/runtime-proof-validation"
MANIFEST_NAME="${ENV}.synthetic-proof-fixtures.yaml"

# Stream the local validator + manifest into the pod because the LMS runtime
# image does not ship the synthetic-fixture repo scripts.
cat "$(dirname "$0")/validate-runtime-proof-fixtures.py" \
  | kubectl exec -i -n "${NAMESPACE}" "${LMS_POD}" -- sh -lc \
    "mkdir -p '${TMP_DIR}/config/runtime-proof' && cat > '${TMP_DIR}/validate-runtime-proof-fixtures.py'"

cat "$(git rev-parse --show-toplevel)/config/runtime-proof/${MANIFEST_NAME}" \
  | kubectl exec -i -n "${NAMESPACE}" "${LMS_POD}" -- sh -lc \
    "mkdir -p '${TMP_DIR}/config/runtime-proof' && cat > '${TMP_DIR}/config/runtime-proof/${MANIFEST_NAME}'"

SHELL_PAYLOAD=$(cat <<PY
import importlib.util
import json
import os

os.environ["RUNTIME_PROOF_MANIFEST_DIR"] = "${TMP_DIR}/config/runtime-proof"
spec = importlib.util.spec_from_file_location(
    "validate_runtime_proof_fixtures",
    "${TMP_DIR}/validate-runtime-proof-fixtures.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
manifest, manifest_path = module.load_manifest("${ENV}")
results = module.run_all_checks(manifest)
results.extend(module.run_live_readonly_checks(manifest))
if "${JSON_FLAG}" == "--json":
    output = {
        "environment": manifest.get("environment"),
        "manifest_path": manifest_path,
        "mode": "live-readonly",
        "checks": [r.to_dict() for r in results],
        "passed": len([r for r in results if r.passed]),
        "failed": len([r for r in results if not r.passed]),
    }
    print(json.dumps(output, indent=2))
else:
    module.print_report_human(manifest, results, manifest_path, "live-readonly")
raise SystemExit(0 if all(r.passed for r in results) else 1)
PY
)

printf '%s\n' "${SHELL_PAYLOAD}" \
  | kubectl exec -i -n "${NAMESPACE}" "${LMS_POD}" -- sh -lc \
    "cd /openedx/edx-platform && ./manage.py lms shell"
