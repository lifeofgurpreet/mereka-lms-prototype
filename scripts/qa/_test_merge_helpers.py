#!/usr/bin/env python3
"""Internal test helper for verify-tenant-branding-fallback.sh.

Not intended to be called directly by operators.
Runs isolated unit-style checks against merge_tenant_branding logic.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts" / "shared"))

import merge_tenant_branding as mtb  # noqa: E402


def test_unknown_key(schema_path: str, sites_path: str, domain: str) -> int:
    """AC-003: ensure an unknown key in site_values is rejected."""
    try:
        import yaml
    except ImportError:
        print("SKIP: PyYAML not available")
        return 0

    schema = mtb.Schema.load(Path(schema_path))
    data = yaml.safe_load(Path(sites_path).read_text(encoding="utf-8")) or {}
    site_values: dict = {}
    for site in data.get("sites") or []:
        if (site or {}).get("domain") == domain:
            site_values = dict((site or {}).get("site_values") or {})
            break

    _, errors = mtb.merge_tenant(domain, site_values, schema)
    unknown_errors = [e for e in errors if "unknown key" in e.message]
    if unknown_errors:
        return 0  # correctly rejected
    print(f"FAIL: unknown key was not rejected for {domain}")
    print(f"  site_values keys: {sorted(site_values)}")
    print(f"  errors: {[str(e) for e in errors]}")
    return 1


def test_base_defaults(schema_path: str) -> int:
    """AC-004: minimal tenant config resolves missing keys to base defaults."""
    schema = mtb.Schema.load(Path(schema_path))

    minimal_sv: dict = {
        "domain": "minimal.mereka.io",
        "site_name": "Minimal Site",
        "platform_name": "Minimal Platform",
        "LMS_ROOT_URL": "https://minimal.mereka.io",
        "CMS_ROOT_URL": "https://studio.minimal.mereka.io",
        "MFE_BASE_URL": "https://apps.minimal.mereka.io",
        "THEME_NAME": "mereka",
        "course_org_filter": ["MINIMAL"],
    }

    merged, errors = mtb.merge_tenant("minimal.mereka.io", minimal_sv, schema)

    if errors:
        for e in errors:
            print(f"FAIL: validation error: {e}")
        return 1

    # Spot-check a few known base defaults
    expected = {
        "logo_url": "/",
        "favicon_path": "mereka/images/favicon.ico",
        "homepage_banner_enabled": False,
        "ENABLE_COMPREHENSIVE_THEMING": True,
    }
    ok = True
    for key, want in expected.items():
        got = merged.get(key)
        if got != want:
            print(f"FAIL: {key} expected {want!r}, got {got!r}")
            ok = False

    return 0 if ok else 1


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--test", required=True, choices=["unknown-key", "base-defaults"])
    parser.add_argument("--schema", required=True)
    parser.add_argument("--sites", default=None)
    parser.add_argument("--domain", default=None)
    args = parser.parse_args()

    if args.test == "unknown-key":
        if not args.sites or not args.domain:
            print("ERROR: --sites and --domain required for unknown-key test", file=sys.stderr)
            sys.exit(1)
        sys.exit(test_unknown_key(args.schema, args.sites, args.domain))
    elif args.test == "base-defaults":
        sys.exit(test_base_defaults(args.schema))


if __name__ == "__main__":
    main()
