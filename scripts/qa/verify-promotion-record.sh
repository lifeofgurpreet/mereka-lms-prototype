#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RECORD_PATH="${1:-${REPO_ROOT}/var/ci/promotion-record.json}"

if [[ ! -f "${RECORD_PATH}" ]]; then
  echo "FAIL: promotion record not found at ${RECORD_PATH}" >&2
  exit 1
fi

python3 - "${RECORD_PATH}" <<'PY'
import json
import re
import sys

path = sys.argv[1]
payload = json.load(open(path, encoding="utf-8"))
errors = []

def check_rx(value, pattern, label):
    if not re.fullmatch(pattern, str(value or "")):
        errors.append(f"{label} invalid: {value}")

for key in ("schema_version", "repository", "commit_sha", "target_environment", "release_bundle_id", "images", "gitops"):
    if key not in payload:
        errors.append(f"missing key: {key}")

if payload.get("schema_version") != "1.0.0":
    errors.append("schema_version must be 1.0.0")

check_rx(payload.get("commit_sha"), r"[0-9a-f]{40}", "commit_sha")
if payload.get("target_environment") not in {"dev", "nonprod", "staging", "production"}:
    errors.append(f"target_environment invalid: {payload.get('target_environment')}")
check_rx(payload.get("release_bundle_id"), r"rb-[0-9a-f]{7,40}-[0-9]{8}T[0-9]{6}Z", "release_bundle_id")

images = payload.get("images", {})
check_rx(images.get("openedx_digest"), r"sha256:[0-9a-f]{64}", "images.openedx_digest")
check_rx(images.get("mfe_digest"), r"sha256:[0-9a-f]{64}", "images.mfe_digest")

gitops = payload.get("gitops", {})
if not str(gitops.get("repository", "")).strip():
    errors.append("gitops.repository missing")
check_rx(gitops.get("commit_sha"), r"[0-9a-f]{40}", "gitops.commit_sha")

if errors:
    print("FAIL: promotion record validation errors:", file=sys.stderr)
    for err in errors:
        print(f" - {err}", file=sys.stderr)
    sys.exit(1)

print("PASS: promotion record contract valid")
PY

