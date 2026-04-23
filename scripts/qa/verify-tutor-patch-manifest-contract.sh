#!/usr/bin/env bash
# @covers AC-TCR-004, AC-TCR-007, AC-TCR-011
# @spec: tutor-configuration-resilience_spec.md
#
# Static authority verifier for the remaining Tutor post-render patch layer.
# It ties the active manifest to apply-patches.sh, patch modules, the inventory
# ledger, and the build-optimizations render-delta contract.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PATCH_MANIFEST="${PATCH_MANIFEST:-$REPO_ROOT/infrastructure/tutor/patch-manifest.yml}"
APPLY_PATCHES_SCRIPT="${APPLY_PATCHES_SCRIPT:-$REPO_ROOT/infrastructure/tutor/apply-patches.sh}"
PATCH_INVENTORY_DOC="${PATCH_INVENTORY_DOC:-$REPO_ROOT/docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md}"
BUILD_OPTIMIZATIONS_DELTA_CONTRACT="${BUILD_OPTIMIZATIONS_DELTA_CONTRACT:-$REPO_ROOT/infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml}"

python3 - <<'PY' "$REPO_ROOT" "$PATCH_MANIFEST" "$APPLY_PATCHES_SCRIPT" "$PATCH_INVENTORY_DOC" "$BUILD_OPTIMIZATIONS_DELTA_CONTRACT"
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML is required for Tutor patch manifest verification") from exc

repo_root = Path(sys.argv[1]).resolve()
manifest_path = Path(sys.argv[2])
apply_patches_path = Path(sys.argv[3])
inventory_doc_path = Path(sys.argv[4])
delta_contract_path = Path(sys.argv[5])

required_patch_fields = {
    "id",
    "module",
    "function",
    "target",
    "target_family",
    "authority_class",
    "description",
    "retirement_trigger",
    "required",
}

allowed_authority_classes = {
    "authority_correction",
    "obsolete_expectation_removal",
    "temporary_compatibility_layer",
    "intentional_architecture_change",
    "migration_guard",
    "filesystem_sync",
}

historical_modules = {
    "mysql-auth.sh",
    "mfe-node.sh",
    "domain-names.sh",
    "csrf-origins.sh",
    "footer-component.sh",
    "prometheus-metrics.sh",
    "mongodb-atlas.sh",
    "security-hardening.sh",
}

failures: list[str] = []


def repo_path(value: str | Path) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return repo_root / path


def require_file(path: Path, label: str) -> bool:
    if path.is_file():
        return True
    failures.append(f"missing {label}: {path}")
    return False


def load_yaml(path: Path, label: str) -> dict:
    if not require_file(path, label):
        return {}
    payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(payload, dict):
        failures.append(f"{label} must load as a mapping: {path}")
        return {}
    return payload


def contains_token(text: str, token: str) -> bool:
    escaped = re.escape(token)
    return re.search(rf"(?<![A-Za-z0-9_-]){escaped}(?![A-Za-z0-9_-])", text) is not None


def shell_function_defined(text: str, function_name: str) -> bool:
    escaped = re.escape(function_name)
    patterns = (
        rf"(?m)^\s*{escaped}\s*\(\)\s*\{{",
        rf"(?m)^\s*function\s+{escaped}\b",
    )
    return any(re.search(pattern, text) for pattern in patterns)


def shell_function_called_by_apply_patches(text: str, function_name: str) -> bool:
    escaped = re.escape(function_name)
    return (
        re.search(rf"(?m)^\s*apply_patch\s+{escaped}\b", text) is not None
        or re.search(rf"(?m)^\s*{escaped}\b(?!\s*\(\))", text) is not None
    )


manifest = load_yaml(manifest_path, "patch manifest")
inventory_text = ""
if require_file(inventory_doc_path, "patch inventory doc"):
    inventory_text = inventory_doc_path.read_text(encoding="utf-8")

apply_text = ""
if require_file(apply_patches_path, "apply-patches.sh"):
    apply_text = apply_patches_path.read_text(encoding="utf-8")

metadata = manifest.get("metadata") if isinstance(manifest.get("metadata"), dict) else {}
for field in ("inventory", "spec"):
    value = metadata.get(field)
    if not isinstance(value, str) or not value.strip():
        failures.append(f"manifest metadata missing {field}")
    elif not repo_path(value).is_file():
        failures.append(f"manifest metadata {field} target missing: {value}")

inventory_rel = str(inventory_doc_path.relative_to(repo_root)) if inventory_doc_path.is_relative_to(repo_root) else str(inventory_doc_path)
if metadata.get("inventory") and str(metadata["inventory"]) != inventory_rel:
    failures.append(
        f"manifest metadata inventory must point at {inventory_rel}, found {metadata['inventory']!r}"
    )

patches = manifest.get("patches")
if not isinstance(patches, list) or not patches:
    failures.append("manifest must contain a non-empty patches list")
    patches = []

inactive_modules = manifest.get("inactive_modules") or []
if not isinstance(inactive_modules, list):
    failures.append("inactive_modules must be a list when present")
    inactive_modules = []

sourced_modules = {
    match.group(1)
    for match in re.finditer(
        r'''source\s+["']?\$PATCHES_DIR/([^"'\s]+\.sh)["']?''',
        apply_text,
    )
}
sourced_patch_modules = {module for module in sourced_modules if module != "_common.sh"}

active_ids: set[str] = set()
active_modules_by_basename: dict[str, set[str]] = {}
active_has_build_delta = False
active_has_dependency_mirror = False

for index, patch in enumerate(patches, start=1):
    if not isinstance(patch, dict):
        failures.append(f"patches[{index}] must be a mapping")
        continue

    patch_id = str(patch.get("id") or "")
    label = patch_id or f"patches[{index}]"
    if not patch_id:
        failures.append(f"patches[{index}] missing id")
    elif patch_id in active_ids:
        failures.append(f"duplicate active patch id: {patch_id}")
    else:
        active_ids.add(patch_id)

    missing = sorted(
        field for field in required_patch_fields if field not in patch or patch[field] in ("", None)
    )
    if missing:
        failures.append(f"{label}: missing required field(s): {', '.join(missing)}")
        continue

    authority_class = str(patch.get("authority_class"))
    if authority_class not in allowed_authority_classes:
        failures.append(f"{label}: unsupported authority_class {authority_class!r}")

    if patch.get("required") is not True:
        failures.append(f"{label}: active patches must set required: true")

    module_value = str(patch.get("module"))
    module_path = repo_path(module_value)
    module_basename = module_path.name
    active_modules_by_basename.setdefault(module_basename, set()).add(patch_id)

    if module_basename in historical_modules:
        failures.append(f"{label}: historical patch module cannot be active: {module_basename}")

    if not module_path.is_file():
        failures.append(f"{label}: module does not exist: {module_value}")
    else:
        module_text = module_path.read_text(encoding="utf-8")
        function_name = str(patch.get("function"))
        if not shell_function_defined(module_text, function_name):
            failures.append(f"{label}: function {function_name} not defined in {module_value}")

    if module_path.resolve() != apply_patches_path.resolve() and module_path.suffix == ".sh":
        if module_basename not in sourced_patch_modules:
            failures.append(f"{label}: module is not sourced by apply-patches.sh: {module_basename}")

    function_name = str(patch.get("function"))
    if not shell_function_called_by_apply_patches(apply_text, function_name):
        failures.append(f"{label}: function is not invoked by apply-patches.sh: {function_name}")

    if "mfe/build/mfe/indigo" in str(patch.get("target")):
        failures.append(f"{label}: active patch target still points at retired Indigo build context")

    if inventory_text:
        inventory_tokens = {patch_id, module_basename, function_name}
        if not any(token and token in inventory_text for token in inventory_tokens):
            failures.append(f"{label}: missing from inventory ledger")
        if authority_class.replace("_", " ") not in inventory_text and authority_class.upper() not in inventory_text:
            failures.append(f"{label}: authority_class not reflected in inventory ledger: {authority_class}")

    if patch_id == "build-optimizations-render-delta":
        active_has_build_delta = True
        description = f"{patch.get('description', '')} {patch.get('retirement_trigger', '')}"
        if "build-optimizations.allowed-delta.yaml" not in description:
            failures.append(f"{label}: must name build-optimizations.allowed-delta.yaml")

    if patch_id == "dependency-image-mirror-normalization":
        active_has_dependency_mirror = True

for sourced_module in sorted(sourced_patch_modules):
    if sourced_module in historical_modules:
        failures.append(f"historical patch module is still sourced by apply-patches.sh: {sourced_module}")
    if sourced_module not in active_modules_by_basename:
        failures.append(f"sourced patch module missing from active manifest: {sourced_module}")

for item in inactive_modules:
    if not isinstance(item, dict):
        failures.append("inactive_modules entry must be a mapping")
        continue
    module_value = item.get("module")
    if not isinstance(module_value, str) or not module_value.strip():
        failures.append("inactive_modules entry missing module")
        continue
    module_path = repo_path(module_value)
    module_basename = module_path.name
    if not module_path.is_file():
        failures.append(f"inactive module target missing: {module_value}")
    if module_basename in sourced_patch_modules:
        failures.append(f"inactive module is still sourced by apply-patches.sh: {module_basename}")
    if module_basename in active_modules_by_basename:
        failures.append(f"inactive module is also active in manifest: {module_basename}")

if "Remaining `build-optimizations.sh` Mutation Ledger" not in inventory_text:
    failures.append("inventory doc missing Remaining build-optimizations.sh Mutation Ledger")
if "Review Rule" not in inventory_text:
    failures.append("inventory doc missing verifier/patch Review Rule")

delta_contract = load_yaml(delta_contract_path, "build-optimizations allowed-delta contract")
if active_has_build_delta:
    if delta_contract.get("default_policy") != "fail_closed":
        failures.append("build-optimizations allowed-delta contract default_policy must be fail_closed")

    contract_inventory = delta_contract.get("inventory_doc")
    expected_inventory = str(inventory_doc_path.relative_to(repo_root)) if inventory_doc_path.is_relative_to(repo_root) else str(inventory_doc_path)
    if contract_inventory != expected_inventory:
        failures.append(
            f"build-optimizations allowed-delta contract inventory_doc must be {expected_inventory}, found {contract_inventory!r}"
        )

    source_script = delta_contract.get("source_script")
    if source_script != "infrastructure/tutor/patches/build-optimizations.sh":
        failures.append(
            "build-optimizations allowed-delta contract source_script must be infrastructure/tutor/patches/build-optimizations.sh"
        )

    deltas = delta_contract.get("allowed_deltas")
    if not isinstance(deltas, list) or not deltas:
        failures.append("build-optimizations allowed-delta contract must contain allowed_deltas")
        deltas = []

    delta_ids: set[str] = set()
    delta_source_text_cache: dict[Path, str] = {}

    def delta_source_text(source_value: str | None) -> str:
        effective_source = source_value or source_script
        if not isinstance(effective_source, str) or not effective_source.strip():
            failures.append("build-optimizations allowed-delta contract missing source_script")
            return ""
        source_path = repo_path(effective_source)
        if source_path not in delta_source_text_cache:
            if not source_path.is_file():
                failures.append(f"missing allowed-delta source script: {source_path}")
                delta_source_text_cache[source_path] = ""
            else:
                delta_source_text_cache[source_path] = source_path.read_text(encoding="utf-8")
        return delta_source_text_cache[source_path]

    for index, delta in enumerate(deltas, start=1):
        if not isinstance(delta, dict):
            failures.append(f"allowed_deltas[{index}] must be a mapping")
            continue
        delta_id = str(delta.get("id") or "")
        label = delta_id or f"allowed_deltas[{index}]"
        if not delta_id:
            failures.append(f"allowed_deltas[{index}] missing id")
        elif delta_id in delta_ids:
            failures.append(f"duplicate allowed delta id: {delta_id}")
        else:
            delta_ids.add(delta_id)

        authority_class = str(delta.get("authority_class") or "")
        if authority_class not in allowed_authority_classes:
            failures.append(f"{label}: unsupported allowed-delta authority_class {authority_class!r}")
        if not str(delta.get("retirement_trigger") or "").strip():
            failures.append(f"{label}: missing retirement_trigger")
        markers = delta.get("source_markers")
        if not isinstance(markers, list) or not markers:
            failures.append(f"{label}: missing source_markers")
        else:
            source_text = delta_source_text(delta.get("source_script") if isinstance(delta.get("source_script"), str) else None)
            for marker in markers:
                if not isinstance(marker, str) or marker not in source_text:
                    failures.append(f"{label}: source marker missing from allowed-delta source: {marker!r}")
        if inventory_text and delta_id and not contains_token(inventory_text, delta_id):
            failures.append(f"{label}: missing exact id token from inventory ledger")

if active_has_dependency_mirror and delta_contract:
    delta_ids = {
        str(delta.get("id"))
        for delta in delta_contract.get("allowed_deltas", [])
        if isinstance(delta, dict)
    }
    if "dependency-image-mirror-normalization" not in delta_ids:
        failures.append(
            "dependency-image-mirror-normalization active patch must be represented in allowed-delta contract"
        )

if failures:
    for failure in failures:
        print(f"FAIL: {failure}", file=sys.stderr)
    raise SystemExit(1)

print(
    "PASS: Tutor patch manifest contract is bounded "
    f"({len(active_ids)} active patches, {len(sourced_patch_modules)} sourced modules)"
)
PY
