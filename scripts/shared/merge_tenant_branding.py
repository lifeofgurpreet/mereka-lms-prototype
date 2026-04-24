#!/usr/bin/env python3
"""Merge tenant branding: base defaults + tenant site_values with schema validation.

Usage:
    python3 scripts/shared/merge_tenant_branding.py --tenant academyv2.mereka.io
    python3 scripts/shared/merge_tenant_branding.py --tenant academyv2.mereka.io --env dev
    python3 scripts/shared/merge_tenant_branding.py --all
    python3 scripts/shared/merge_tenant_branding.py --all --check-only

Exit codes:
    0   All tenants validated and merged successfully
    1   One or more validation errors (unknown keys, bad types, missing required keys)
    2   Configuration or file error (missing schema/sites file, bad YAML)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCHEMA_PATH = REPO_ROOT / "infrastructure" / "tutor" / "tenant-branding-schema.yml"
SITES_PROD = REPO_ROOT / "infrastructure" / "tutor" / "multisite-sites.yml"
SITES_DEV = REPO_ROOT / "infrastructure" / "tutor" / "multisite-sites.dev.yml"
SITES_STAGING = REPO_ROOT / "infrastructure" / "tutor" / "multisite-sites.staging.yml"

ENV_TO_FILE: dict[str, Path] = {
    "prod": SITES_PROD,
    "dev": SITES_DEV,
    "staging": SITES_STAGING,
}

_HEX_COLOR_RE = re.compile(r"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$")


def _load_yaml(path: Path) -> dict[str, Any]:
    try:
        import yaml  # type: ignore
    except ImportError as exc:
        _die(f"PyYAML is required: pip install pyyaml\n  {exc}", code=2)
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception as exc:
        _die(f"Failed to parse {path}: {exc}", code=2)


def _die(msg: str, code: int = 1) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


@dataclass
class SchemaKey:
    name: str
    type: str
    required: bool
    base_default: Any
    description: str


@dataclass
class Schema:
    base_defaults: dict[str, Any]
    keys: dict[str, SchemaKey]

    @classmethod
    def load(cls, path: Path) -> Schema:
        raw = _load_yaml(path)
        if not isinstance(raw, dict):
            _die(f"Schema file {path} must be a YAML mapping", code=2)
        base_defaults = dict(raw.get("base_defaults") or {})
        keys_raw = raw.get("keys") or {}
        if not isinstance(keys_raw, dict):
            _die(f"Schema 'keys' section must be a mapping in {path}", code=2)
        keys: dict[str, SchemaKey] = {}
        for name, spec in keys_raw.items():
            spec = spec or {}
            keys[name] = SchemaKey(
                name=name,
                type=str(spec.get("type") or "any"),
                required=bool(spec.get("required", False)),
                base_default=spec.get("base_default"),
                description=str(spec.get("description") or ""),
            )
        return cls(base_defaults=base_defaults, keys=keys)


@dataclass
class ValidationError:
    tenant_domain: str
    key: str
    message: str

    def __str__(self) -> str:
        return f"[{self.tenant_domain}] {self.key}: {self.message}"


def _validate_type(key_name: str, value: Any, expected_type: str) -> str | None:
    """Return an error message string, or None if valid."""
    if value is None:
        return None  # null is always acceptable for optional keys
    if expected_type == "any":
        return None
    if expected_type == "string":
        if not isinstance(value, str):
            return f"expected string, got {type(value).__name__!r} ({value!r})"
        return None
    if expected_type == "bool":
        if not isinstance(value, bool):
            return f"expected bool (true/false), got {type(value).__name__!r} ({value!r})"
        return None
    if expected_type == "url":
        if not isinstance(value, str):
            return f"expected URL string, got {type(value).__name__!r} ({value!r})"
        if not (value.startswith("https://") or value.startswith("http://") or value.startswith("/")):
            return f"expected absolute URL (https://...) or root-relative path (/...), got {value!r}"
        return None
    if expected_type == "hex_color":
        if not isinstance(value, str):
            return f"expected hex color string, got {type(value).__name__!r} ({value!r})"
        if not _HEX_COLOR_RE.match(value):
            return f"expected CSS hex color (#RGB or #RRGGBB), got {value!r}"
        return None
    if expected_type == "list_of_strings":
        if isinstance(value, str):
            return None  # single string is coerced to list downstream
        if not isinstance(value, list):
            return f"expected list of strings, got {type(value).__name__!r}"
        for item in value:
            if not isinstance(item, str):
                return f"list items must be strings, got {type(item).__name__!r} ({item!r})"
        return None
    # unknown type in schema — pass through
    return None


def merge_tenant(
    domain: str,
    site_values: dict[str, Any],
    schema: Schema,
) -> tuple[dict[str, Any], list[ValidationError]]:
    """
    Merge base defaults with tenant overrides and validate the result.

    Merge order (AC-002): base_defaults first, tenant site_values override.
    Unknown keys in site_values are rejected (AC-003).
    Missing keys resolve to base defaults (AC-004).

    Returns (merged_config, errors).
    """
    errors: list[ValidationError] = []

    # AC-003: reject unknown keys
    for key in site_values:
        if key not in schema.keys:
            errors.append(ValidationError(
                tenant_domain=domain,
                key=key,
                message=f"unknown key (not in schema). Allowed keys: {sorted(schema.keys)}",
            ))

    # Build merged config: base_defaults, then tenant overrides (only known keys)
    merged: dict[str, Any] = {}

    # Start with base defaults from schema keys
    for key_name, key_spec in schema.keys.items():
        # Prefer base_defaults section if present, else key.base_default
        if key_name in schema.base_defaults:
            merged[key_name] = schema.base_defaults[key_name]
        elif key_spec.base_default is not None:
            merged[key_name] = key_spec.base_default
        # else leave absent (will be caught by required check below)

    # Apply tenant overrides (AC-004 inverse: tenant CAN override)
    for key, value in site_values.items():
        if key in schema.keys:
            merged[key] = value

    # Validate types for all present values
    for key_name, key_spec in schema.keys.items():
        if key_name not in merged:
            continue
        value = merged[key_name]
        type_error = _validate_type(key_name, value, key_spec.type)
        if type_error:
            errors.append(ValidationError(
                tenant_domain=domain,
                key=key_name,
                message=type_error,
            ))

    # AC-004 / AC-003: check required keys are present after merge
    for key_name, key_spec in schema.keys.items():
        if not key_spec.required:
            continue
        if not merged.get(key_name):
            errors.append(ValidationError(
                tenant_domain=domain,
                key=key_name,
                message=(
                    "required key is missing and has no base default — "
                    "add it to site_values for this tenant"
                ),
            ))

    return merged, errors


def load_tenants(sites_file: Path) -> list[tuple[str, dict[str, Any]]]:
    """Load (domain, site_values) pairs from a multisite YAML file."""
    raw = _load_yaml(sites_file)
    sites = raw.get("sites") or []
    if not isinstance(sites, list):
        _die(f"{sites_file}: top-level 'sites' must be a list", code=2)
    result: list[tuple[str, dict[str, Any]]] = []
    for entry in sites:
        if not isinstance(entry, dict):
            continue
        domain = str(entry.get("domain") or "")
        site_values = dict(entry.get("site_values") or {})
        if domain:
            result.append((domain, site_values))
    return result


def run_merge(
    tenants: list[tuple[str, dict[str, Any]]],
    schema: Schema,
    check_only: bool,
    verbose: bool,
) -> int:
    """Run merge+validate for all tenants. Returns exit code."""
    all_errors: list[ValidationError] = []

    for domain, site_values in tenants:
        merged, errors = merge_tenant(domain, site_values, schema)
        all_errors.extend(errors)

        if errors:
            print(f"FAIL  {domain}", file=sys.stderr)
            for err in errors:
                print(f"      {err.key}: {err.message}", file=sys.stderr)
        else:
            if check_only or verbose:
                print(f"PASS  {domain}")
            if not check_only:
                # Emit merged JSON to stdout for downstream consumers
                print(json.dumps(merged, indent=2, default=str))

    if all_errors:
        print(f"\n{len(all_errors)} validation error(s) across {len(tenants)} tenant(s).", file=sys.stderr)
        return 1

    if check_only or verbose:
        print(f"\nAll {len(tenants)} tenant(s) validated successfully.")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--tenant",
        metavar="DOMAIN",
        help="Merge and validate a single tenant by domain",
    )
    group.add_argument(
        "--all",
        action="store_true",
        help="Merge and validate all tenants across all env files",
    )
    parser.add_argument(
        "--env",
        choices=list(ENV_TO_FILE.keys()),
        default=None,
        help="Environment file to use (default: all envs when --all, prod when --tenant)",
    )
    parser.add_argument(
        "--schema",
        metavar="PATH",
        default=str(SCHEMA_PATH),
        help=f"Path to branding schema YAML (default: {SCHEMA_PATH})",
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Validate without printing merged output; exits non-zero on errors",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print PASS lines even in check-only mode",
    )
    args = parser.parse_args()

    schema_path = Path(args.schema)
    if not schema_path.exists():
        _die(f"Schema file not found: {schema_path}", code=2)
    schema = Schema.load(schema_path)

    # Determine which files to load
    if args.env:
        files = [ENV_TO_FILE[args.env]]
    elif args.all:
        files = [f for f in ENV_TO_FILE.values() if f.exists()]
        if not files:
            _die("No multisite YAML files found in infrastructure/tutor/", code=2)
    else:
        # --tenant without --env: use prod, then dev as fallback
        files = [f for f in [SITES_PROD, SITES_DEV] if f.exists()]

    # Collect tenants from all applicable files
    tenants: list[tuple[str, dict[str, Any]]] = []
    for f in files:
        tenants.extend(load_tenants(f))

    if args.tenant:
        # Filter to just the requested domain
        matched = [(d, sv) for d, sv in tenants if d == args.tenant]
        if not matched:
            available = [d for d, _ in tenants]
            _die(
                f"Tenant {args.tenant!r} not found in any loaded sites file.\n"
                f"Available: {available}",
                code=2,
            )
        tenants = matched

    if not tenants:
        _die("No tenant definitions found in the specified files.", code=2)

    code = run_merge(tenants, schema, check_only=args.check_only, verbose=args.verbose)
    sys.exit(code)


if __name__ == "__main__":
    main()
