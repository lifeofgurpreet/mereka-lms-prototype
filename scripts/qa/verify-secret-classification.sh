#!/usr/bin/env bash
# @covers AC-009, AC-010
# @spec: secrets-management_spec.md
#
# Validate secret classification coverage for all MEREKA_LMS_* ExternalSecret keys.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CLASSIFICATION_FILE="$REPO_ROOT/deploy/k8s/base/secrets/SECRET_CLASSIFICATION.yaml"
SCOPE_MODE="${VERIFY_SECRET_CLASSIFICATION_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_SECRET_CLASSIFICATION_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  local changed_path

  if [[ "$SCOPE_MODE" != "changed" ]]; then
    return 1
  fi

  if [[ -z "${CHANGED_FILES_RAW//[[:space:]]/}" ]]; then
    return 1
  fi

  while IFS= read -r changed_path; do
    [[ -n "$changed_path" ]] || continue
    case "$changed_path" in
      .github/workflows/ci.yml|\
      deploy/*|\
      services/*|\
      scripts/qa/verify-secret-classification.sh)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if [[ ! -f "$CLASSIFICATION_FILE" ]]; then
  echo "FAIL missing classification file: $CLASSIFICATION_FILE" >&2
  exit 1
fi

if should_skip_scope; then
  echo "PASS verify-secret-classification (scope skip: no secret-classification-relevant changes)"
  exit 0
fi

python3 - "$REPO_ROOT" "$CLASSIFICATION_FILE" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

repo_root = Path(sys.argv[1])
classification_path = Path(sys.argv[2])


def gather_external_secret_keys(root: Path) -> set[str]:
    keys: set[str] = set()
    search_roots = [root / "deploy", root / "services"]
    for base in search_roots:
        if not base.exists():
            continue
        for path in list(base.rglob("*.yaml")) + list(base.rglob("*.yml")):
            if "/overlays/local/" in path.as_posix():
                continue
            try:
                docs = list(yaml.safe_load_all(path.read_text(encoding="utf-8")))
            except Exception:
                continue
            for doc in docs:
                if not isinstance(doc, dict):
                    continue
                if doc.get("kind") != "ExternalSecret":
                    continue
                data_items = (((doc.get("spec") or {}).get("data")) or [])
                for item in data_items:
                    if not isinstance(item, dict):
                        continue
                    remote = item.get("remoteRef") or {}
                    key = remote.get("key")
                    if isinstance(key, str) and key.startswith("MEREKA_LMS_"):
                        keys.add(key)
    return keys


external_keys = gather_external_secret_keys(repo_root)
if not external_keys:
    raise SystemExit("FAIL no MEREKA_LMS_* keys discovered in ExternalSecret manifests")

data = yaml.safe_load(classification_path.read_text(encoding="utf-8"))
if not isinstance(data, dict):
    raise SystemExit("FAIL classification file must be a YAML mapping")

entries = data.get("secrets")
if not isinstance(entries, list):
    raise SystemExit("FAIL classification file must contain a top-level 'secrets' list")

allowed_classes = {"env_unique", "shared_by_design", "generated_at_deploy"}
shared: set[str] = set()
env_unique: set[str] = set()
generated: set[str] = set()
all_classified: set[str] = set()

for index, item in enumerate(entries):
    if not isinstance(item, dict):
        raise SystemExit(f"FAIL classification entry {index} must be a mapping")
    key = item.get("key")
    cls = item.get("class")
    if not isinstance(key, str) or not key.startswith("MEREKA_LMS_"):
        raise SystemExit(f"FAIL classification entry {index} has invalid key: {key!r}")
    if cls not in allowed_classes:
        raise SystemExit(
            f"FAIL classification entry {index} has invalid class {cls!r}; "
            f"expected one of {sorted(allowed_classes)}"
        )
    if key in all_classified:
        raise SystemExit(f"FAIL duplicate key in classification file: {key}")
    all_classified.add(key)
    if cls == "shared_by_design":
        shared.add(key)
    elif cls == "env_unique":
        env_unique.add(key)
    elif cls == "generated_at_deploy":
        generated.add(key)

coverage_set = shared | env_unique | generated
unknown = sorted(all_classified - external_keys)
if unknown:
    print("FAIL unknown keys in classification (not present in ExternalSecret manifests):")
    for key in unknown:
        print(f"  - {key}")
    raise SystemExit(1)

missing = sorted(external_keys - coverage_set)
if missing:
    print("FAIL missing keys in classification coverage:")
    for key in missing:
        print(f"  - {key}")
    raise SystemExit(1)

overlap = sorted(shared & env_unique)
if overlap:
    print("FAIL keys cannot be both shared and env_unique:")
    for key in overlap:
        print(f"  - {key}")
    raise SystemExit(1)

print(f"PASS external keys discovered: {len(external_keys)}")
print(f"PASS shared classified keys: {len(shared)}")
print(f"PASS env_unique classified keys: {len(env_unique)}")
print(f"PASS generated_at_deploy classified keys: {len(generated)}")
PY
