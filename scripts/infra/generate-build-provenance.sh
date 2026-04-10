#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../lib/lane-normalize.sh
source "${REPO_ROOT}/scripts/lib/lane-normalize.sh"
# shellcheck source=../lib/control-plane-contract-ref.sh
source "${REPO_ROOT}/scripts/lib/control-plane-contract-ref.sh"

usage() {
  cat <<'EOF'
Usage: generate-build-provenance.sh \
  --output <path> \
  --repository <owner/repo> \
  --commit-sha <40-hex> \
  --target-environment <dev|nonprod|staging|production> \
  --openedx-digest <sha256:...> \
  --mfe-digest <sha256:...> \
  --release-bundle-id <id> \
  --gitops-repo <owner/repo> \
  --gitops-commit <40-hex>
EOF
}

OUTPUT=""
REPOSITORY=""
COMMIT_SHA=""
TARGET_ENV=""
OPENEDX_DIGEST=""
MFE_DIGEST=""
RELEASE_BUNDLE_ID=""
GITOPS_REPO=""
GITOPS_COMMIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --repository) REPOSITORY="${2:-}"; shift 2 ;;
    --commit-sha) COMMIT_SHA="${2:-}"; shift 2 ;;
    --target-environment) TARGET_ENV="${2:-}"; shift 2 ;;
    --openedx-digest) OPENEDX_DIGEST="${2:-}"; shift 2 ;;
    --mfe-digest) MFE_DIGEST="${2:-}"; shift 2 ;;
    --release-bundle-id) RELEASE_BUNDLE_ID="${2:-}"; shift 2 ;;
    --gitops-repo) GITOPS_REPO="${2:-}"; shift 2 ;;
    --gitops-commit) GITOPS_COMMIT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for req in OUTPUT REPOSITORY COMMIT_SHA TARGET_ENV OPENEDX_DIGEST MFE_DIGEST RELEASE_BUNDLE_ID GITOPS_REPO GITOPS_COMMIT; do
  if [[ -z "${!req}" ]]; then
    echo "Missing required argument: ${req}" >&2
    usage >&2
    exit 1
  fi
done

[[ "${COMMIT_SHA}" =~ ^[0-9a-f]{40}$ ]] || { echo "Invalid commit SHA: ${COMMIT_SHA}" >&2; exit 1; }
[[ "${GITOPS_COMMIT}" =~ ^[0-9a-f]{40}$ ]] || { echo "Invalid gitops commit: ${GITOPS_COMMIT}" >&2; exit 1; }
[[ "${OPENEDX_DIGEST}" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "Invalid openedx digest: ${OPENEDX_DIGEST}" >&2; exit 1; }
[[ "${MFE_DIGEST}" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "Invalid mfe digest: ${MFE_DIGEST}" >&2; exit 1; }
[[ "${RELEASE_BUNDLE_ID}" =~ ^rb-[0-9a-f]{7,40}-[0-9]{8}T[0-9]{6}Z$ ]] || {
  echo "Invalid release bundle id: ${RELEASE_BUNDLE_ID}" >&2
  exit 1
}
if ! is_valid_target_environment "${TARGET_ENV}"; then
  echo "Invalid target environment: ${TARGET_ENV}" >&2
  exit 1
fi
# Normalize to canonical lane names for proof artifacts.
TARGET_ENV="$(normalize_lane_to_canonical "${TARGET_ENV}")"

mkdir -p "$(dirname "${OUTPUT}")"

export OUTPUT REPOSITORY COMMIT_SHA TARGET_ENV OPENEDX_DIGEST MFE_DIGEST RELEASE_BUNDLE_ID GITOPS_REPO GITOPS_COMMIT
export CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export CONTRACT_REF="$(resolve_control_plane_contract_ref)"

python3 - <<'PY'
import json
import os

payload = {
    "schema_version": "1.0.0",
    "created_at": os.environ["CREATED_AT"],
    "repository": os.environ["REPOSITORY"],
    "commit_sha": os.environ["COMMIT_SHA"],
    "target_environment": os.environ["TARGET_ENV"],
    "service_id": "mereka-lms",
    "contract_family": "build-provenance",
    "contract_version": "1.0",
    "contract_ref": os.environ["CONTRACT_REF"],
    "release_bundle_id": os.environ["RELEASE_BUNDLE_ID"],
    "images": {
        "openedx_digest": os.environ["OPENEDX_DIGEST"],
        "mfe_digest": os.environ["MFE_DIGEST"],
    },
    "gitops": {
        "repository": os.environ["GITOPS_REPO"],
        "commit_sha": os.environ["GITOPS_COMMIT"],
    },
}

with open(os.environ["OUTPUT"], "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY

echo "Generated build provenance: ${OUTPUT}"
