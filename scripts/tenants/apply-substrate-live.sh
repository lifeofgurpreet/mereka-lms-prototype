#!/usr/bin/env bash
# Apply synthetic proof fixtures against the live LMS pod using the local repo
# scripts + manifest. Supports optional password setting via env vars.
#
# Usage:
#   ./scripts/tenants/apply-substrate-live.sh [--namespace mereka-lms-dev] [--env dev]
#   ./scripts/tenants/apply-substrate-live.sh --set-passwords

set -euo pipefail

NAMESPACE="${NAMESPACE:-mereka-lms-dev}"
ENV="${ENV:-dev}"
SET_PASSWORDS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --env)
      ENV="$2"
      shift 2
      ;;
    --set-passwords)
      SET_PASSWORDS=true
      shift
      ;;
    *)
      echo "Usage: $0 [--namespace NS] [--env ENV] [--set-passwords]" >&2
      exit 1
      ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT_DIR="${REPO_ROOT}/scripts/tenants"
TMP_DIR="/tmp/runtime-proof-bootstrap"
MANIFEST_NAME="${ENV}.synthetic-proof-fixtures.yaml"

echo "=== Synthetic Proof Substrate Live Apply ==="
echo "Namespace : ${NAMESPACE}"
echo "Env       : ${ENV}"
echo "Passwords : ${SET_PASSWORDS}"
echo ""

LMS_POD=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=lms \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [[ -z "${LMS_POD}" ]]; then
  echo "ERROR: No LMS pod found in namespace ${NAMESPACE}" >&2
  exit 1
fi

echo "LMS Pod   : ${LMS_POD}"
echo ""

cat "${SCRIPT_DIR}/bootstrap-runtime-proof-fixtures.py" \
  | kubectl exec -i -n "${NAMESPACE}" "${LMS_POD}" -- sh -lc \
    "mkdir -p '${TMP_DIR}/config/runtime-proof' && cat > '${TMP_DIR}/bootstrap-runtime-proof-fixtures.py'"

cat "${SCRIPT_DIR}/lib/proof_fixtures.py" \
  | kubectl exec -i -n "${NAMESPACE}" "${LMS_POD}" -- sh -lc \
    "mkdir -p '${TMP_DIR}/lib' && cat > '${TMP_DIR}/lib/proof_fixtures.py'"

cat "${REPO_ROOT}/config/runtime-proof/${MANIFEST_NAME}" \
  | kubectl exec -i -n "${NAMESPACE}" "${LMS_POD}" -- sh -lc \
    "mkdir -p '${TMP_DIR}/config/runtime-proof' && cat > '${TMP_DIR}/config/runtime-proof/${MANIFEST_NAME}'"

POD_ENV_EXPORTS=""
for env_var in \
  LANEA_PLATFORM_ADMIN_PASSWORD \
  LANEA_ENTERPRISE_ADMIN_PASSWORD \
  LANEA_ENTERPRISE_LEARNER_PASSWORD \
  LANEA_UNLINKED_USER_PASSWORD
do
  if [[ -n "${!env_var:-}" ]]; then
    escaped_value=$(printf '%s' "${!env_var}" | sed "s/'/'\\\\''/g")
    POD_ENV_EXPORTS="${POD_ENV_EXPORTS}os.environ['${env_var}'] = '${escaped_value}'
"
  fi
done

SHELL_PAYLOAD=$(cat <<PY
import importlib.util
import os
import sys

os.environ["RUNTIME_PROOF_MANIFEST_DIR"] = "${TMP_DIR}/config/runtime-proof"
sys.path.insert(0, "${TMP_DIR}")
${POD_ENV_EXPORTS}
spec = importlib.util.spec_from_file_location(
    "bootstrap_runtime_proof_fixtures",
    "${TMP_DIR}/bootstrap-runtime-proof-fixtures.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
manifest = module.load_manifest("${ENV}")
raise SystemExit(
    module.run_apply(
        manifest,
        "${ENV}",
        as_json=False,
        set_passwords=${SET_PASSWORDS^},
    )
)
PY
)

printf '%s\n' "${SHELL_PAYLOAD}" \
  | kubectl exec -i -n "${NAMESPACE}" "${LMS_POD}" -- sh -lc \
    "cd /openedx/edx-platform && ./manage.py lms shell"
