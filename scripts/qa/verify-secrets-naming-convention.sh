#!/usr/bin/env bash
# Verify ExternalSecrets remoteRef keys follow MEREKA_LMS_* conventions.
#
# Scope: deploy/k8s/**/secrets/**/*.yaml + overlays secret patches.
#
# Usage:
#   ./scripts/qa/verify-secrets-naming-convention.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

paths: list[Path] = []
for p in [
    Path("deploy/k8s/base/secrets"),
    Path("deploy/k8s/overlays"),
]:
    if p.exists():
        paths.extend(sorted(p.rglob("*.y*ml")))

bad_remote: list[tuple[str, str, str]] = []  # file, secretKey, remoteKey
bad_local: list[tuple[str, str]] = []  # file, secretKey

for f in paths:
    try:
        docs = list(yaml.safe_load_all(f.read_text(encoding="utf-8")))
    except Exception:
        continue
    for d in docs:
        if not isinstance(d, dict):
            continue
        if d.get("kind") != "ExternalSecret":
            continue
        spec = d.get("spec") or {}
        data = spec.get("data") or []
        if not isinstance(data, list):
            continue
        for item in data:
            if not isinstance(item, dict):
                continue
            secret_key = str(item.get("secretKey") or "").strip()
            remote_ref = item.get("remoteRef") or {}
            remote_key = str(remote_ref.get("key") or "").strip()
            if secret_key and secret_key.startswith("MEREKA_LMS_"):
                bad_local.append((str(f), secret_key))
            if remote_key and not remote_key.startswith("MEREKA_LMS_"):
                bad_remote.append((str(f), secret_key, remote_key))

if bad_local:
    for f, sk in bad_local[:50]:
        print(f"[FAIL] ExternalSecret secretKey must not use MEREKA_LMS_ prefix: {f}: {sk}", file=sys.stderr)
if bad_remote:
    for f, sk, rk in bad_remote[:50]:
        print(f"[FAIL] ExternalSecret remoteRef.key must start with MEREKA_LMS_: {f}: {sk} -> {rk}", file=sys.stderr)

if bad_local or bad_remote:
    raise SystemExit(1)

print("OK")
PY

