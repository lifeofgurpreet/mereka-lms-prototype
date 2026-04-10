#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

DEFAULT_PLATFORM_ROOTS=(
  "$REPO_ROOT/var/ci/platform-control-plane"
  "$REPO_ROOT/../platform-control-plane"
  "$REPO_ROOT/../../platform-control-plane"
  "$HOME/projects/k8s/platform-control-plane"
  "$HOME/projects/platform-control-plane"
)

RELEASE_OBJECT_PATH="${1:-${REPO_ROOT}/var/ci/release-object.json}"
PLATFORM_ROOT="${PLATFORM_CONTROL_PLANE_ROOT:-${WAVE10_PCP_ROOT:-}}"
platform_root_explicit=0
[[ -n "${PLATFORM_CONTROL_PLANE_ROOT:-}" || -n "${WAVE10_PCP_ROOT:-}" ]] && platform_root_explicit=1

if [[ -z "$PLATFORM_ROOT" ]]; then
  for candidate in "${DEFAULT_PLATFORM_ROOTS[@]}"; do
    if [[ -f "$candidate/contracts/release-object-projection-schema.yaml" ]]; then
      PLATFORM_ROOT="$candidate"
      break
    fi
  done
fi

SCHEMA_PATH="${RELEASE_OBJECT_SCHEMA_PATH:-${PLATFORM_ROOT}/contracts/release-object-projection-schema.yaml}"

if [[ ! -f "${RELEASE_OBJECT_PATH}" ]]; then
  echo "FAIL: release object not found at ${RELEASE_OBJECT_PATH}" >&2
  exit 1
fi

if [[ ! -f "${SCHEMA_PATH}" ]]; then
  if [[ "$platform_root_explicit" -eq 1 || -n "${RELEASE_OBJECT_SCHEMA_PATH:-}" ]]; then
    echo "FAIL: release-object projection schema not found at ${SCHEMA_PATH}" >&2
    exit 1
  fi
  echo "FAIL: platform-control-plane release-object projection schema unavailable" >&2
  echo "Looked for: ${SCHEMA_PATH}" >&2
  exit 1
fi

python3 - "${RELEASE_OBJECT_PATH}" "${SCHEMA_PATH}" <<'PY'
from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any
import json
import re
import sys

import yaml


payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
schema = yaml.safe_load(Path(sys.argv[2]).read_text(encoding="utf-8"))
errors: list[str] = []


def missing_required(value: Any, spec: dict[str, Any] | None = None) -> bool:
    if value is None:
        return not bool((spec or {}).get("nullable", False))
    return value == ""


def valid_datetime(value: str) -> bool:
    if not isinstance(value, str):
        return False
    candidate = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        datetime.fromisoformat(candidate)
    except ValueError:
        return False
    return True


def validate_property(prop_name: str, spec: dict[str, Any], value: Any, path: str) -> None:
    nullable = bool(spec.get("nullable", False))
    if value is None:
        if nullable:
            return
        errors.append(f"{path}.{prop_name} must not be null")
        return

    expected_type = spec.get("type")
    type_valid = True
    if expected_type == "string":
        if not isinstance(value, str):
            errors.append(f"{path}.{prop_name} must be a string")
            type_valid = False
        elif spec.get("format") == "date-time" and not valid_datetime(value):
            errors.append(f"{path}.{prop_name} must be a valid RFC3339 date-time")
    elif expected_type == "array":
        if not isinstance(value, list):
            errors.append(f"{path}.{prop_name} must be an array")
            type_valid = False
        else:
            min_items = spec.get("min_items")
            if isinstance(min_items, int) and len(value) < min_items:
                errors.append(f"{path}.{prop_name} must contain at least {min_items} item(s)")
    elif expected_type == "object":
        if not isinstance(value, dict):
            errors.append(f"{path}.{prop_name} must be an object")
            type_valid = False
        else:
            required_object_fields = spec.get("required_object_fields")
            if required_object_fields is not None:
                object_schema = spec.get("object_schema")
                nested_properties = object_schema.get("properties") if isinstance(object_schema, dict) else None
                for field in required_object_fields:
                    nested_spec = nested_properties.get(field) if isinstance(nested_properties, dict) else None
                    if field not in value or missing_required(
                        value.get(field),
                        nested_spec if isinstance(nested_spec, dict) else None,
                    ):
                        errors.append(f"{path}.{prop_name} missing required object field '{field}'")
            nested_schema = spec.get("object_schema")
            nested_properties = nested_schema.get("properties") if isinstance(nested_schema, dict) else None
            if isinstance(nested_properties, dict):
                for field_name, nested_value in value.items():
                    nested_spec = nested_properties.get(field_name)
                    if isinstance(nested_spec, dict):
                        validate_property(field_name, nested_spec, nested_value, f"{path}.{prop_name}")
    elif expected_type == "boolean":
        if not isinstance(value, bool):
            errors.append(f"{path}.{prop_name} must be a boolean")
            type_valid = False

    enum = spec.get("enum")
    if type_valid and isinstance(enum, list) and enum and value not in enum:
        errors.append(f"{path}.{prop_name} must be one of {enum}, got {value!r}")


required_fields = schema.get("required_fields") or []
properties = schema.get("properties") or {}
handshake_fields = ("contract_family", "contract_version", "contract_ref")

for field in required_fields:
    field_spec = properties.get(field)
    if field not in payload or missing_required(
        payload.get(field),
        field_spec if isinstance(field_spec, dict) else None,
    ):
        errors.append(f"missing top-level key: {field}")
        continue
    if isinstance(field_spec, dict):
        validate_property(field, field_spec, payload.get(field), "release_object")

for field in handshake_fields:
    field_spec = properties.get(field)
    if field not in payload or missing_required(
        payload.get(field),
        field_spec if isinstance(field_spec, dict) else None,
    ):
        errors.append(f"missing handshake field: {field}")
        continue
    if isinstance(field_spec, dict):
        validate_property(field, field_spec, payload.get(field), "release_object")

if payload.get("schema_version") != "release-object/v1":
    errors.append("schema_version must be release-object/v1")

legacy_target = payload.get("target_environment")
if legacy_target is not None and legacy_target != payload.get("build_origin_environment"):
    errors.append("target_environment must match build_origin_environment when present")

promotion = payload.get("promotion", {})
status = promotion.get("status")
gitops_repo = promotion.get("gitops_repository")
gitops_commit = promotion.get("gitops_commit_sha")
if status == "build-only":
    if gitops_repo is not None or gitops_commit is not None:
        errors.append("build-only release object must not claim gitops linkage")
elif status == "gitops-linked":
    if not str(gitops_repo or "").strip():
        errors.append("gitops-linked release object missing gitops_repository")
    if gitops_commit is None:
        errors.append("promotion.gitops_commit_sha missing")
    elif not re.fullmatch(r"[0-9a-f]{40}", str(gitops_commit)):
        errors.append(f"promotion.gitops_commit_sha invalid: {gitops_commit}")

if errors:
    print("FAIL: release object validation errors:", file=sys.stderr)
    for error in errors:
        print(f" - {error}", file=sys.stderr)
    sys.exit(1)

print("PASS: release object contract valid")
print(f"Release ID: {payload.get('release_id')}")
print(f"Contract ref: {payload.get('contract_ref')}")
PY
