#!/usr/bin/env bash
# @covers AC-009, AC-010
# @spec: secrets-management_spec.md
#
# Validate secret classification coverage for all MEREKA_LMS_* ExternalSecret keys.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLASSIFICATION_FILE="$REPO_ROOT/docs/operations/SECRETS_CLASSIFICATION.yml"

if [[ ! -f "$CLASSIFICATION_FILE" ]]; then
  echo "FAIL missing classification file: $CLASSIFICATION_FILE" >&2
  exit 1
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


def as_set(payload: dict, key: str) -> set[str]:
    value = payload.get(key)
    if value is None:
        return set()
    if not isinstance(value, list):
        raise SystemExit(f"FAIL classification classes.{key} must be a list")
    bad = [item for item in value if not isinstance(item, str)]
    if bad:
        raise SystemExit(f"FAIL classification classes.{key} contains non-string entries")
    return set(value)


external_keys = gather_external_secret_keys(repo_root)
if not external_keys:
    raise SystemExit("FAIL no MEREKA_LMS_* keys discovered in ExternalSecret manifests")

data = yaml.safe_load(classification_path.read_text(encoding="utf-8"))
if not isinstance(data, dict):
    raise SystemExit("FAIL classification file must be a YAML mapping")

classes = data.get("classes")
if not isinstance(classes, dict):
    raise SystemExit("FAIL classification file missing classes mapping")

shared = as_set(classes, "shared")
env_unique = as_set(classes, "env_unique")
generated = as_set(classes, "generated")

coverage_set = shared | env_unique
unknown = sorted((shared | env_unique | generated) - external_keys)
if unknown:
    print("FAIL unknown keys in classification (not present in ExternalSecret manifests):")
    for key in unknown:
        print(f"  - {key}")
    raise SystemExit(1)

missing = sorted(external_keys - coverage_set)
if missing:
    print("FAIL missing keys in shared/env_unique classification coverage:")
    for key in missing:
        print(f"  - {key}")
    raise SystemExit(1)

overlap = sorted(shared & env_unique)
if overlap:
    print("FAIL keys cannot be both shared and env_unique:")
    for key in overlap:
        print(f"  - {key}")
    raise SystemExit(1)

not_subset = sorted(generated - coverage_set)
if not_subset:
    print("FAIL generated keys must also be classified as shared or env_unique:")
    for key in not_subset:
        print(f"  - {key}")
    raise SystemExit(1)

print(f"PASS external keys discovered: {len(external_keys)}")
print(f"PASS shared classified keys: {len(shared)}")
print(f"PASS env_unique classified keys: {len(env_unique)}")
print(f"PASS generated classified keys: {len(generated)}")
PY
