#!/usr/bin/env bash
# @covers AC-ENTMFE-CFG-001
# @spec: enterprise_frontend_delivery_contract_spec.md
#
# Verifies enterprise frontend config-consumption and patch ownership remain
# aligned across env.config.js, Dockerfiles, Tutor runtime theme inputs, and
# patch-missing-env.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

python3 - <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

repo_root = Path.cwd()
manifest_path = repo_root / "docs/programs/frontend/enterprise-frontend-config-consumption.v1.yaml"
patch_script_path = repo_root / "infrastructure/docker/enterprise-mfe-clean/patch-missing-env.sh"

if not manifest_path.exists():
    print(f"FAIL config manifest missing: {manifest_path}")
    sys.exit(1)
if not patch_script_path.exists():
    print(f"FAIL patch script missing: {patch_script_path}")
    sys.exit(1)

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
patch_script = patch_script_path.read_text(encoding="utf-8")
key_entries = manifest.get("keys", [])
declared_keys = {entry["name"]: entry for entry in key_entries}
failures: list[str] = []
passes: list[str] = []

env_files = [
    repo_root / "deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js",
    repo_root / "deploy/k8s/overlays/staging/enterprise-mfe-env.js",
    repo_root / "deploy/k8s/overlays/rke2-nonprod/enterprise-mfe-env.js",
    repo_root / "deploy/k8s/overlays/local/enterprise-mfe-env.js",
]
env_key_pattern = re.compile(r"^\s*([A-Z0-9_]+)\s*:", re.MULTILINE)
actual_env_keys: set[str] = set()
for path in env_files:
    if not path.exists():
        failures.append(f"env file missing: {path.relative_to(repo_root)}")
        continue
    text = path.read_text(encoding="utf-8")
    actual_env_keys.update(env_key_pattern.findall(text))
    passes.append(f"env file exists {path.relative_to(repo_root)}")
    if "window.PARAGON_THEME" in text:
        passes.append(f"{path.relative_to(repo_root)} declares PARAGON_THEME")

patch_keys = set(re.findall(r'replace_key "([A-Z0-9_]+)" ', patch_script))
required_modes = {
    "runtime_env",
    "patched_bundle_default",
    "build_patch_only",
    "dead_if_runtime_only",
    "runtime_window_global",
    "plugin_runtime_alignment",
}

unexpected_env_keys = sorted(actual_env_keys - set(declared_keys))
for key in unexpected_env_keys:
    failures.append(f"undeclared enterprise env key: {key}")

unexpected_patch_keys = sorted(patch_keys - set(declared_keys))
for key in unexpected_patch_keys:
    failures.append(f"patch-missing-env replace_key not declared in contract: {key}")

for name, entry in declared_keys.items():
    modes = set(entry.get("consumption_modes", []))
    if not modes:
      failures.append(f"{name}: missing consumption_modes")
      continue
    unknown = sorted(modes - required_modes)
    if unknown:
      failures.append(f"{name}: unknown consumption modes {unknown}")
    else:
      passes.append(f"{name}: consumption modes declared")

    for owner in entry.get("owner_files", []):
        path = repo_root / owner
        if not path.exists():
            failures.append(f"{name}: owner file missing {owner}")
        else:
            passes.append(f"{name}: owner file exists {owner}")

    if "runtime_env" in modes and name not in actual_env_keys:
        failures.append(f"{name}: declared runtime_env but missing from enterprise env files")
    if "build_patch_only" in modes and name not in patch_keys:
        failures.append(f"{name}: declared build_patch_only but replace_key missing")
    if "patched_bundle_default" in modes and name not in patch_keys:
        failures.append(f"{name}: declared patched_bundle_default but replace_key missing")
    if "dead_if_runtime_only" in modes and name in actual_env_keys:
        failures.append(f"{name}: declared dead_if_runtime_only but present in runtime env")

for patch in manifest.get("patch_inventory", []):
    patch_id = patch["id"]
    search_signature = patch["search_signature"]
    success_fragment = patch["success_fragment"]
    if search_signature not in patch_script:
        failures.append(f"{patch_id}: search signature missing from patch script")
    else:
        passes.append(f"{patch_id}: search signature present")
    if success_fragment not in patch_script:
        failures.append(f"{patch_id}: success fragment missing from patch script")
    else:
        passes.append(f"{patch_id}: success fragment present")

for check in manifest.get("parity_checks", []):
    path = repo_root / check["file"]
    if not path.exists():
        failures.append(f"{check['id']}: parity file missing {check['file']}")
        continue
    text = path.read_text(encoding="utf-8")
    for fragment in check.get("contains", []):
        if fragment not in text:
            failures.append(f"{check['id']}: missing fragment in {check['file']}: {fragment}")
        else:
            passes.append(f"{check['id']}: fragment present")

for message in passes:
    print(f"PASS {message}")
for message in failures:
    print(f"FAIL {message}")

if failures:
    sys.exit(1)

print("PASS enterprise frontend config contract is aligned")
PY
