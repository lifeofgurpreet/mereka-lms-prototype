#!/usr/bin/env bash
# @covers AC-009, AC-010
# @spec: secrets-management_spec.md
# Verify ExternalSecret inventories roughly match specs/secrets-management_spec.md.
#
# This is a repo-level check: it validates the ExternalSecret manifests contain the
# expected keys. It does NOT require cluster access.
#
# Usage:
#   ./scripts/qa/verify-secrets-inventory.sh
set -euo pipefail

ROOT_DIR="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT_DIR"

python3 - "$ROOT_DIR" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

root = Path(sys.argv[1]).resolve()

def load_external_secret(path: Path, name: str) -> dict:
    docs = list(yaml.safe_load_all(path.read_text(encoding="utf-8")))
    for d in docs:
        if isinstance(d, dict) and d.get("kind") == "ExternalSecret":
            md = d.get("metadata") or {}
            if md.get("name") == name:
                return d
    raise KeyError(f"ExternalSecret {name!r} not found in {path}")

base = root / "deploy/k8s/base/secrets/external-secrets.yaml"
if not base.exists():
    print("[FAIL] Missing deploy/k8s/base/secrets/external-secrets.yaml", file=sys.stderr)
    raise SystemExit(1)

openedx = load_external_secret(base, "openedx-secrets")

data = openedx.get("spec", {}).get("data") or []
if not isinstance(data, list):
    print("[FAIL] openedx-secrets spec.data is not a list", file=sys.stderr)
    raise SystemExit(1)

present = {str(i.get("secretKey")) for i in data if isinstance(i, dict) and i.get("secretKey")}

required_subset = {
    # Core
    "OPENEDX_SECRET_KEY",
    "CMS_SECRET_KEY",
    # Atlas
    "MONGODB_USERNAME",
    "MONGODB_PASSWORD",
    "FORUM_MONGODB_HOST",
    # JWT
    "JWT_SECRET_KEY_LMS",
    "JWT_SECRET_KEY_CMS",
    "JWT_SECRET_KEY_DISCOVERY",
    "JWT_SECRET_KEY_NOTES",
    "JWT_SECRET_KEY_XQUEUE",
    "JWT_PRIVATE_SIGNING_JWK",
    # OAuth2/SSO
    "OIDC_CLIENT_SECRET",
    # Stripe
    "STRIPE_SECRET_KEY",
    "STRIPE_PUBLISHABLE_KEY",
    "STRIPE_WEBHOOK_SECRET",
}

missing = sorted(required_subset - present)
if missing:
    for k in missing:
        print(f"[FAIL] openedx-secrets missing secretKey: {k}", file=sys.stderr)
    raise SystemExit(1)

# database-secrets: base is represented via placeholder Secret manifest today.
placeholder = root / "deploy/k8s/base/secrets/openedx-secrets.yaml"
if not placeholder.exists():
    print("[FAIL] Missing deploy/k8s/base/secrets/openedx-secrets.yaml", file=sys.stderr)
    raise SystemExit(1)

docs = list(yaml.safe_load_all(placeholder.read_text(encoding="utf-8")))
db = None
for d in docs:
    if isinstance(d, dict) and d.get("kind") == "Secret" and (d.get("metadata") or {}).get("name") == "database-secrets":
        db = d
        break

if not db:
    print("[FAIL] database-secrets placeholder Secret not found in openedx-secrets.yaml", file=sys.stderr)
    raise SystemExit(1)

keys = set((db.get("stringData") or {}).keys())
required_db = {
    "MYSQL_ROOT_PASSWORD",
    "OPENEDX_MYSQL_PASSWORD",
    "MYSQL_DISCOVERY_PASSWORD",
    "MYSQL_NOTES_PASSWORD",
    "MYSQL_XQUEUE_PASSWORD",
    "MYSQL_CREDENTIALS_PASSWORD",
}
missing_db = sorted(required_db - keys)
extra_db = sorted(keys - required_db)
if missing_db:
    for k in missing_db:
        print(f"[FAIL] database-secrets placeholder missing key: {k}", file=sys.stderr)
    raise SystemExit(1)
if extra_db:
    for k in extra_db:
        print(f"[WARN] database-secrets placeholder has extra key: {k}", file=sys.stderr)

print("OK")
PY
