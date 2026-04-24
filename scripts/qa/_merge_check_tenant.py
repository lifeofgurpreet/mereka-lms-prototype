#!/usr/bin/env python3
"""Internal helper: validate a single tenant domain against a sites YAML file.

Usage: python3 _merge_check_tenant.py <domain> <sites_file> <schema_file>

Not intended to be called directly by operators.
Used by verify-tenant-branding-fallback.sh to run per-tenant validation.

Exit 0 if the tenant's site_values are valid and all required keys have defaults.
Exit 1 on validation errors.
Exit 2 on file/config errors.
"""

from __future__ import annotations

import sys
from pathlib import Path

if len(sys.argv) != 4:
    print(f"Usage: {sys.argv[0]} <domain> <sites_file> <schema_file>", file=sys.stderr)
    sys.exit(2)

domain = sys.argv[1]
sites_path = Path(sys.argv[2])
schema_path = Path(sys.argv[3])

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts" / "shared"))

try:
    import merge_tenant_branding as mtb
except ImportError as exc:
    print(f"ERROR: cannot import merge_tenant_branding: {exc}", file=sys.stderr)
    sys.exit(2)

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed (pip install pyyaml)", file=sys.stderr)
    sys.exit(2)

if not schema_path.exists():
    print(f"ERROR: schema not found: {schema_path}", file=sys.stderr)
    sys.exit(2)
if not sites_path.exists():
    print(f"ERROR: sites file not found: {sites_path}", file=sys.stderr)
    sys.exit(2)

schema = mtb.Schema.load(schema_path)
data = yaml.safe_load(sites_path.read_text(encoding="utf-8")) or {}
sites = data.get("sites") or []

site_values: dict = {}
found = False
for site in sites:
    if (site or {}).get("domain") == domain:
        site_values = dict((site or {}).get("site_values") or {})
        found = True
        break

if not found:
    print(f"ERROR: domain {domain!r} not found in {sites_path}", file=sys.stderr)
    sys.exit(2)

_, errors = mtb.merge_tenant(domain, site_values, schema)
if errors:
    for e in errors:
        print(f"  {e.key}: {e.message}")
    sys.exit(1)

sys.exit(0)
