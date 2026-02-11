#!/usr/bin/env bash
# @covers AC-015, AC-016
# @spec: secrets-management_spec.md
# Verify ExternalSecrets Operator config manifests match secrets-management_spec.md.
#
# Repo-level checks only (no cluster required):
# - ExternalSecret refreshInterval, target policies, secretStoreRef
# - ClusterSecretStore gcpsm projectID + secretVersionSelectionPolicy
#
# Usage:
#   ./scripts/qa/verify-externalsecret-config.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

def load_docs(p: Path) -> list[dict]:
    docs = []
    for d in yaml.safe_load_all(p.read_text(encoding="utf-8")):
        if isinstance(d, dict):
            docs.append(d)
    return docs

es_path = Path("deploy/k8s/base/secrets/external-secrets.yaml")
cs_path = Path("deploy/k8s/base/secrets/cluster-secret-store.yaml")
if not es_path.exists():
    print("[FAIL] Missing deploy/k8s/base/secrets/external-secrets.yaml", file=sys.stderr)
    raise SystemExit(1)
if not cs_path.exists():
    print("[FAIL] Missing deploy/k8s/base/secrets/cluster-secret-store.yaml", file=sys.stderr)
    raise SystemExit(1)

es_docs = load_docs(es_path)
for d in es_docs:
    if d.get("kind") != "ExternalSecret":
        continue
    md = d.get("metadata") or {}
    name = md.get("name")
    spec = d.get("spec") or {}
    if spec.get("refreshInterval") != "1h":
        print(f"[FAIL] ExternalSecret {name}: refreshInterval must be 1h", file=sys.stderr)
        raise SystemExit(1)
    ssr = spec.get("secretStoreRef") or {}
    if ssr.get("kind") != "ClusterSecretStore" or ssr.get("name") != "gcp-secret-manager":
        print(f"[FAIL] ExternalSecret {name}: secretStoreRef must be ClusterSecretStore/gcp-secret-manager", file=sys.stderr)
        raise SystemExit(1)
    target = spec.get("target") or {}
    if target.get("creationPolicy") != "Owner":
        print(f"[FAIL] ExternalSecret {name}: target.creationPolicy must be Owner", file=sys.stderr)
        raise SystemExit(1)
    if target.get("deletionPolicy") != "Retain":
        print(f"[FAIL] ExternalSecret {name}: target.deletionPolicy must be Retain", file=sys.stderr)
        raise SystemExit(1)

cs_docs = load_docs(cs_path)
stores = [d for d in cs_docs if d.get("kind") == "ClusterSecretStore"]
if not stores:
    print("[FAIL] No ClusterSecretStore found in cluster-secret-store.yaml", file=sys.stderr)
    raise SystemExit(1)

ok = False
for d in stores:
    if (d.get("metadata") or {}).get("name") != "gcp-secret-manager":
        continue
    gcpsm = ((d.get("spec") or {}).get("provider") or {}).get("gcpsm") or {}
    if gcpsm.get("projectID") != "bbi-k8":
        print("[FAIL] ClusterSecretStore projectID must be bbi-k8", file=sys.stderr)
        raise SystemExit(1)
    if gcpsm.get("secretVersionSelectionPolicy") != "LatestOrFail":
        print("[FAIL] ClusterSecretStore secretVersionSelectionPolicy must be LatestOrFail", file=sys.stderr)
        raise SystemExit(1)
    ok = True

if not ok:
    print("[FAIL] ClusterSecretStore gcp-secret-manager not found", file=sys.stderr)
    raise SystemExit(1)

print("OK")
PY

