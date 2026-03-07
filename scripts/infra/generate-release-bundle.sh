#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: generate-release-bundle.sh \
  --output <path> \
  --repo <owner/repo> \
  --commit-sha <40-hex> \
  --workflow <workflow-path> \
  --run-id <id> \
  --run-attempt <attempt> \
  --target-environment <dev|nonprod|staging|production> \
  --openedx-image <image-name> \
  --openedx-digest <sha256:...> \
  --mfe-image <image-name> \
  --mfe-digest <sha256:...>
EOF
}

OUTPUT=""
REPO=""
COMMIT_SHA=""
WORKFLOW=""
RUN_ID=""
RUN_ATTEMPT=""
TARGET_ENV=""
OPENEDX_IMAGE=""
OPENEDX_DIGEST=""
MFE_IMAGE=""
MFE_DIGEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --commit-sha) COMMIT_SHA="${2:-}"; shift 2 ;;
    --workflow) WORKFLOW="${2:-}"; shift 2 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --run-attempt) RUN_ATTEMPT="${2:-}"; shift 2 ;;
    --target-environment) TARGET_ENV="${2:-}"; shift 2 ;;
    --openedx-image) OPENEDX_IMAGE="${2:-}"; shift 2 ;;
    --openedx-digest) OPENEDX_DIGEST="${2:-}"; shift 2 ;;
    --mfe-image) MFE_IMAGE="${2:-}"; shift 2 ;;
    --mfe-digest) MFE_DIGEST="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for req in OUTPUT REPO COMMIT_SHA WORKFLOW RUN_ID RUN_ATTEMPT TARGET_ENV OPENEDX_IMAGE OPENEDX_DIGEST MFE_IMAGE MFE_DIGEST; do
  if [[ -z "${!req}" ]]; then
    echo "Missing required argument: ${req}" >&2
    usage >&2
    exit 1
  fi
done

if [[ ! "${COMMIT_SHA}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Invalid commit SHA: ${COMMIT_SHA}" >&2
  exit 1
fi
if [[ ! "${OPENEDX_DIGEST}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "Invalid openedx digest: ${OPENEDX_DIGEST}" >&2
  exit 1
fi
if [[ ! "${MFE_DIGEST}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "Invalid mfe digest: ${MFE_DIGEST}" >&2
  exit 1
fi
case "${TARGET_ENV}" in
  dev|nonprod|staging|production|prod|rke2-nonprod) ;;
  *)
    echo "Invalid target environment: ${TARGET_ENV}" >&2
    exit 1
    ;;
esac
# Normalize to canonical lane names for proof artifacts
case "${TARGET_ENV}" in
  rke2-nonprod|nonprod) TARGET_ENV="dev" ;;
  production) TARGET_ENV="prod" ;;
esac

mkdir -p "$(dirname "${OUTPUT}")"

created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
bundle_id="rb-${COMMIT_SHA:0:8}-${stamp}"

export BUNDLE_ID="${bundle_id}"
export CREATED_AT="${created_at}"
export REPO
export COMMIT_SHA
export TARGET_ENV
export WORKFLOW
export RUN_ID
export RUN_ATTEMPT
export OPENEDX_IMAGE
export OPENEDX_DIGEST
export MFE_IMAGE
export MFE_DIGEST

python3 - "$OUTPUT" <<'PY'
import json
import os
import sys

output = sys.argv[1]
payload = {
    "schema_version": "1.0.0",
    "bundle_id": os.environ["BUNDLE_ID"],
    "created_at": os.environ["CREATED_AT"],
    "repository": os.environ["REPO"],
    "commit_sha": os.environ["COMMIT_SHA"],
    "target_environment": os.environ["TARGET_ENV"],
    "build": {
        "workflow": os.environ["WORKFLOW"],
        "run_id": os.environ["RUN_ID"],
        "run_attempt": os.environ["RUN_ATTEMPT"],
    },
    "images": {
        "openedx": {
            "name": os.environ["OPENEDX_IMAGE"],
            "digest": os.environ["OPENEDX_DIGEST"],
        },
        "mfe": {
            "name": os.environ["MFE_IMAGE"],
            "digest": os.environ["MFE_DIGEST"],
        },
    },
    "artifacts": {
        "sbom": {
            "openedx": "sbom-openedx",
            "mfe": "sbom-mfe",
        },
        "provenance": {
            "artifact_name": "slsa-provenance",
            "openedx_predicate": "var/ci/provenance-openedx.json",
            "mfe_predicate": "var/ci/provenance-mfe.json",
        },
        "vulnerability_scan": {
            "openedx": "trivy-openedx-scan",
            "mfe": "trivy-mfe-scan",
        },
    },
}

with open(output, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY

echo "Generated release bundle: ${OUTPUT}"
echo "Bundle ID: ${bundle_id}"
