#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

RELEASE_OBJECT_PATH="${1:-${REPO_ROOT}/var/ci/release-object.json}"
SCHEMA_PATH="${REPO_ROOT}/schemas/release-object.schema.json"

if [[ ! -f "${RELEASE_OBJECT_PATH}" ]]; then
  echo "FAIL: release object not found at ${RELEASE_OBJECT_PATH}" >&2
  exit 1
fi

if [[ ! -f "${SCHEMA_PATH}" ]]; then
  echo "FAIL: schema not found at ${SCHEMA_PATH}" >&2
  exit 1
fi

python3 - "${RELEASE_OBJECT_PATH}" "${SCHEMA_PATH}" <<'PY'
import json
import re
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
schema = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
errors = []

for key in schema.get("required", []):
    if key not in payload:
        errors.append(f"missing top-level key: {key}")

def check_rx(value, pattern, label):
    if value is None:
        errors.append(f"{label} missing")
        return
    if not re.fullmatch(pattern, str(value)):
        errors.append(f"{label} invalid: {value}")

if payload.get("schema_version") != "release-object/v1":
    errors.append("schema_version must be release-object/v1")

check_rx(payload.get("release_id"), r"ro-rb-[0-9a-f]{7,40}-[0-9]{8}T[0-9]{6}Z", "release_id")
check_rx(payload.get("app_commit_sha"), r"[0-9a-f]{40}", "app_commit_sha")
valid_envs = {"dev", "nonprod", "staging", "production", "prod", "rke2-nonprod"}
if payload.get("build_origin_environment") not in valid_envs:
    errors.append(f"build_origin_environment invalid: {payload.get('build_origin_environment')}")
promotion_target = payload.get("promotion_target_environment")
if promotion_target is not None and promotion_target not in valid_envs:
    errors.append(f"promotion_target_environment invalid: {promotion_target}")

legacy_target = payload.get("target_environment")
if legacy_target is not None and legacy_target != payload.get("build_origin_environment"):
    errors.append("target_environment must match build_origin_environment when present")

tenant_contract = payload.get("tenant_contract", {})
if not str(tenant_contract.get("path", "")).strip():
    errors.append("tenant_contract.path missing")
check_rx(tenant_contract.get("sha256"), r"[0-9a-f]{64}", "tenant_contract.sha256")

build = payload.get("build", {})
if not str(build.get("workflow", "")).strip():
    errors.append("build.workflow missing")
check_rx(build.get("run_id"), r"[0-9]+", "build.run_id")
check_rx(build.get("run_attempt"), r"[0-9]+", "build.run_attempt")
check_rx(build.get("release_bundle_id"), r"rb-[0-9a-f]{7,40}-[0-9]{8}T[0-9]{6}Z", "build.release_bundle_id")

images = payload.get("images", {})
for key in ("openedx", "mfe"):
    image = images.get(key, {})
    if not str(image.get("name", "")).strip():
        errors.append(f"images.{key}.name missing")
    check_rx(image.get("digest"), r"sha256:[0-9a-f]{64}", f"images.{key}.digest")

source_artifacts = payload.get("source_artifacts", {})
if not str(source_artifacts.get("release_bundle_json", "")).strip():
    errors.append("source_artifacts.release_bundle_json missing")

promotion = payload.get("promotion", {})
status = promotion.get("status")
if status not in {"build-only", "gitops-linked"}:
    errors.append(f"promotion.status invalid: {status}")
gitops_repo = promotion.get("gitops_repository")
gitops_commit = promotion.get("gitops_commit_sha")
if status == "build-only":
    if gitops_repo is not None or gitops_commit is not None:
        errors.append("build-only release object must not claim gitops linkage")
elif status == "gitops-linked":
    if not str(gitops_repo or "").strip():
        errors.append("gitops-linked release object missing gitops_repository")
    check_rx(gitops_commit, r"[0-9a-f]{40}", "promotion.gitops_commit_sha")

if errors:
    print("FAIL: release object validation errors:", file=sys.stderr)
    for error in errors:
        print(f" - {error}", file=sys.stderr)
    sys.exit(1)

print("PASS: release object contract valid")
print(f"Release ID: {payload.get('release_id')}")
PY
