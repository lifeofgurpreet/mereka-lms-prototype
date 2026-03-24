#!/usr/bin/env bash
# @covers AC-MTA-001, AC-MTA-002
# @spec: multi-tenancy-architecture_spec.md
#
# Guardrail: keep tenant contract domains visible in the repo's Cloudflare
# inventory snapshots. This is an inventory-visibility check only; canonical
# domain/routing proof lives in deploy/k8s/tenancy/tenant-registry.yaml plus
# the runtime-proof entrypoints that consume it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - "$REPO_ROOT" <<'PY'
from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

import yaml

repo_root = Path(sys.argv[1])

contract_path = repo_root / "infrastructure/tenants/tenant-contracts.yml"
inventory_paths = [
    repo_root / "infrastructure/cloudflare/records.json",
    repo_root / "infrastructure/cloudflare/records.biji-biji.com.json",
    repo_root / "infrastructure/cloudflare/records.mereka-dev.json",
]

failed = 0
warned = 0
passed = 0


def ok(msg: str) -> None:
    global passed
    passed += 1
    print(f"PASS {msg}")


def warn(msg: str) -> None:
    global warned
    warned += 1
    print(f"WARN {msg}")


def fail(msg: str) -> None:
    global failed
    failed += 1
    print(f"FAIL {msg}")


print("=== Tenant DNS Inventory Verification ===")

if not contract_path.exists():
    fail(f"tenant contract missing: {contract_path}")
    print(f"Summary: PASS={passed} WARN={warned} FAIL={failed}")
    raise SystemExit(1)

contract = yaml.safe_load(contract_path.read_text(encoding="utf-8")) or {}
tenants = [t for t in contract.get("tenants", []) if t.get("active", True)]
if not tenants:
    fail("no active tenants in tenant-contracts.yml")
    print(f"Summary: PASS={passed} WARN={warned} FAIL={failed}")
    raise SystemExit(1)
ok(f"active tenant contracts loaded: {len(tenants)}")

inventory_sources: dict[str, list[str]] = defaultdict(list)
for inv in inventory_paths:
    if not inv.exists():
        warn(f"inventory file missing: {inv.relative_to(repo_root)}")
        continue
    try:
        data = json.loads(inv.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"invalid JSON in {inv.relative_to(repo_root)}: {exc}")
        continue
    if not isinstance(data, list):
        fail(f"inventory file must be a JSON array: {inv.relative_to(repo_root)}")
        continue
    ok(f"inventory file readable: {inv.relative_to(repo_root)} ({len(data)} records)")
    for rec in data:
        if not isinstance(rec, dict):
            continue
        name = str(rec.get("name") or "").strip().lower()
        if not name:
            continue
        inventory_sources[name].append(str(inv.relative_to(repo_root)))

for tenant in tenants:
    slug = tenant.get("slug", "<unknown>")
    domains = tenant.get("domains") or {}
    lms = str(domains.get("lms") or "").strip().lower()
    studio = str(domains.get("studio") or "").strip().lower()
    apps = str(domains.get("apps") or "").strip().lower()
    admin = str(domains.get("admin") or "").strip().lower()

    print(f"--- tenant: {slug} ---")

    if not lms:
        fail(f"{slug}: contract missing lms domain")
    elif lms not in inventory_sources:
        fail(f"{slug}: lms domain '{lms}' missing from Cloudflare inventory files")
    else:
        ok(f"{slug}: lms domain present in inventory ({', '.join(sorted(set(inventory_sources[lms])))})")

    # Advisory only: not all tenants currently expose every surface as DNS records.
    for label, host in (("studio", studio), ("apps", apps), ("admin", admin)):
        if not host:
            warn(f"{slug}: contract missing {label} domain")
            continue
        if host in inventory_sources:
            ok(f"{slug}: {label} domain present in inventory")
        else:
            warn(f"{slug}: {label} domain '{host}' missing from inventory (onboarding drift risk)")

    aliases = tenant.get("aliases") or []
    for alias in aliases:
        alias_host = str(alias).strip().lower()
        if not alias_host:
            continue
        if alias_host in inventory_sources:
            ok(f"{slug}: alias domain present in inventory ({alias_host})")
        else:
            warn(f"{slug}: alias domain missing from inventory ({alias_host})")

print(f"Summary: PASS={passed} WARN={warned} FAIL={failed}")
if failed:
    raise SystemExit(1)
PY
