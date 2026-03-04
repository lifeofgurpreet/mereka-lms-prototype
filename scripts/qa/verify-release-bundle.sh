#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

BUNDLE_PATH="${1:-${REPO_ROOT}/var/ci/release-bundle.json}"
SCHEMA_PATH="${REPO_ROOT}/infrastructure/ci/release-bundle.schema.json"
SIGNATURE_PATH=""
CERTIFICATE_PATH=""
CERT_IDENTITY=""
CERT_OIDC_ISSUER="https://token.actions.githubusercontent.com"

if [[ $# -gt 0 ]]; then
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --signature)
      SIGNATURE_PATH="${2:-}"
      shift 2
      ;;
    --certificate)
      CERTIFICATE_PATH="${2:-}"
      shift 2
      ;;
    --certificate-identity)
      CERT_IDENTITY="${2:-}"
      shift 2
      ;;
    --certificate-oidc-issuer)
      CERT_OIDC_ISSUER="${2:-}"
      shift 2
      ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "${BUNDLE_PATH}" ]]; then
  echo "FAIL: release bundle not found at ${BUNDLE_PATH}" >&2
  exit 1
fi

if [[ ! -f "${SCHEMA_PATH}" ]]; then
  echo "FAIL: schema not found at ${SCHEMA_PATH}" >&2
  exit 1
fi

python3 - "${BUNDLE_PATH}" "${SCHEMA_PATH}" <<'PY'
import json
import re
import sys
from pathlib import Path

bundle_path = Path(sys.argv[1])
schema_path = Path(sys.argv[2])

bundle = json.loads(bundle_path.read_text(encoding="utf-8"))
schema = json.loads(schema_path.read_text(encoding="utf-8"))

errors = []

required_top = schema.get("required", [])
for key in required_top:
    if key not in bundle:
        errors.append(f"missing top-level key: {key}")

if bundle.get("schema_version") != "1.0.0":
    errors.append("schema_version must be 1.0.0")

if not re.fullmatch(r"rb-[0-9a-f]{7,40}-[0-9]{8}T[0-9]{6}Z", str(bundle.get("bundle_id", ""))):
    errors.append("bundle_id format invalid")

if not re.fullmatch(r"[0-9a-f]{40}", str(bundle.get("commit_sha", ""))):
    errors.append("commit_sha must be 40 lowercase hex characters")

for image_key in ("openedx", "mfe"):
    image = bundle.get("images", {}).get(image_key, {})
    digest = str(image.get("digest", ""))
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        errors.append(f"images.{image_key}.digest invalid: {digest}")

target_environment = bundle.get("target_environment")
if target_environment not in {"dev", "nonprod", "staging", "production"}:
    errors.append(f"target_environment invalid: {target_environment}")

build = bundle.get("build", {})
if not re.fullmatch(r"[0-9]+", str(build.get("run_id", ""))):
    errors.append("build.run_id must be numeric string")
if not re.fullmatch(r"[0-9]+", str(build.get("run_attempt", ""))):
    errors.append("build.run_attempt must be numeric string")

if errors:
    print("FAIL: release bundle validation errors:", file=sys.stderr)
    for err in errors:
        print(f" - {err}", file=sys.stderr)
    sys.exit(1)

print("PASS: release bundle structure and digest contract are valid")
print(f"Bundle ID: {bundle.get('bundle_id')}")
PY

if [[ -n "${SIGNATURE_PATH}" || -n "${CERTIFICATE_PATH}" || -n "${CERT_IDENTITY}" ]]; then
  if [[ -z "${SIGNATURE_PATH}" || -z "${CERTIFICATE_PATH}" || -z "${CERT_IDENTITY}" ]]; then
    echo "FAIL: --signature, --certificate, and --certificate-identity must be provided together" >&2
    exit 1
  fi
  if [[ ! -f "${SIGNATURE_PATH}" ]]; then
    echo "FAIL: signature not found at ${SIGNATURE_PATH}" >&2
    exit 1
  fi
  if [[ ! -f "${CERTIFICATE_PATH}" ]]; then
    echo "FAIL: certificate not found at ${CERTIFICATE_PATH}" >&2
    exit 1
  fi
  if ! command -v cosign >/dev/null 2>&1; then
    echo "FAIL: cosign is required for signature verification" >&2
    exit 1
  fi

  cosign verify-blob "${BUNDLE_PATH}" \
    --signature "${SIGNATURE_PATH}" \
    --certificate "${CERTIFICATE_PATH}" \
    --certificate-identity "${CERT_IDENTITY}" \
    --certificate-oidc-issuer "${CERT_OIDC_ISSUER}" \
    >/dev/null

  echo "PASS: release bundle signature verification succeeded"
fi
