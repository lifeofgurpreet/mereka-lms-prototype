#!/usr/bin/env bash
# @covers AC-ENTMFE-ROUTE-001
# @spec: enterprise_frontend_delivery_contract_spec.md
#
# Verifies the enterprise frontend route-owner manifest still matches the repo
# routing and bundle-patch surfaces that define enterprise learner/admin delivery.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

python3 - <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

repo_root = Path.cwd()
manifest_path = repo_root / "docs/programs/frontend/enterprise-frontend-route-owner.v1.yaml"

if not manifest_path.exists():
    print(f"FAIL route manifest missing: {manifest_path}")
    sys.exit(1)

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
allowed_fatality = {"fatal_required", "optional_404_nonfatal"}
route_ids: set[str] = set()
failures: list[str] = []
passes: list[str] = []

for route in manifest.get("route_families", []):
    route_id = route["id"]
    if route_id in route_ids:
        failures.append(f"duplicate route id: {route_id}")
        continue
    route_ids.add(route_id)
    passes.append(f"{route_id}: unique id")

    fatality = route.get("fatality")
    if fatality not in allowed_fatality:
        failures.append(f"{route_id}: invalid fatality {fatality!r}")
    else:
        passes.append(f"{route_id}: fatality {fatality}")

    for source_file in route.get("source_files", []):
        path = repo_root / source_file
        if not path.exists():
            failures.append(f"{route_id}: missing source file {source_file}")
        else:
            passes.append(f"{route_id}: source file exists {source_file}")

    for check in route.get("repo_checks", []):
        path = repo_root / check["file"]
        if not path.exists():
            failures.append(f"{route_id}: check file missing {check['file']}")
            continue
        text = path.read_text(encoding="utf-8")
        for fragment in check.get("contains", []):
            if fragment not in text:
                failures.append(f"{route_id}: missing fragment in {check['file']}: {fragment}")
            else:
                passes.append(f"{route_id}: fragment present in {check['file']}")
        for fragment in check.get("absent", []):
            if fragment in text:
                failures.append(f"{route_id}: forbidden fragment present in {check['file']}: {fragment}")
            else:
                passes.append(f"{route_id}: forbidden fragment absent in {check['file']}")

for message in passes:
    print(f"PASS {message}")
for message in failures:
    print(f"FAIL {message}")

if failures:
    sys.exit(1)

print("PASS enterprise frontend route-owner contract is aligned")
PY
