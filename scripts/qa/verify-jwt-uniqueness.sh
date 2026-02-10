#!/usr/bin/env bash
# Verify JWT secret keys map to distinct MEREKA_LMS_* remote keys.
#
# This prevents drift where multiple services accidentally share the same JWT secret.
#
# Usage:
#   ./scripts/qa/verify-jwt-uniqueness.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

path = Path("deploy/k8s/base/secrets/external-secrets.yaml")
if not path.exists():
    print("[FAIL] Missing deploy/k8s/base/secrets/external-secrets.yaml", file=sys.stderr)
    raise SystemExit(1)

docs = list(yaml.safe_load_all(path.read_text(encoding="utf-8")))
es = None
for d in docs:
    if isinstance(d, dict) and d.get("kind") == "ExternalSecret" and (d.get("metadata") or {}).get("name") == "openedx-secrets":
        es = d
        break
if not es:
    print("[FAIL] openedx-secrets ExternalSecret not found", file=sys.stderr)
    raise SystemExit(1)

data = es.get("spec", {}).get("data") or []
mapping: dict[str, str] = {}
for item in data:
    if not isinstance(item, dict):
        continue
    sk = str(item.get("secretKey") or "")
    if not sk.startswith("JWT_SECRET_KEY_") and sk not in ("JWT_PRIVATE_SIGNING_JWK",):
        continue
    rk = str((item.get("remoteRef") or {}).get("key") or "")
    if not rk:
        continue
    mapping[sk] = rk

remote_keys = [rk for sk, rk in mapping.items() if sk.startswith("JWT_SECRET_KEY_")]
dups = {rk for rk in remote_keys if remote_keys.count(rk) > 1}
if dups:
    for rk in sorted(dups):
        users = sorted([sk for sk, v in mapping.items() if v == rk])
        print(f"[FAIL] JWT remote key reused by multiple services: {rk} <- {', '.join(users)}", file=sys.stderr)
    raise SystemExit(1)

print("OK")
PY

