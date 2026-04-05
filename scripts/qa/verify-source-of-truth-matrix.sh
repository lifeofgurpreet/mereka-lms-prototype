#!/usr/bin/env bash
# @covers AC-TRUTH-002
# @spec: multi-tenancy-architecture_spec.md
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT_FILE="$REPO_ROOT/config/source-of-truth-matrix.yaml"
GHOST_FILE="$REPO_ROOT/config/ghost-truth-surfaces.yaml"

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }

echo "=== Source-of-Truth Matrix Verification ==="
echo "Repo root: $REPO_ROOT"

echo "--- Check 1: contract exists and is valid YAML ---"
if [[ -f "$CONTRACT_FILE" ]]; then
  pass "$CONTRACT_FILE exists"
else
  fail "$CONTRACT_FILE missing"
fi
if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$CONTRACT_FILE" 2>/dev/null; then
  pass "$CONTRACT_FILE is valid YAML"
else
  fail "$CONTRACT_FILE is not valid YAML"
fi

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "=== Summary ==="
  echo "PASS: $passes | FAIL: $failures"
  exit 1
fi

echo "--- Check 2: canonical paths exist and do not overlap ghost/local-only truth ---"
if python3 - "$REPO_ROOT" "$CONTRACT_FILE" "$GHOST_FILE" <<'PY'
import fnmatch
import sys
from pathlib import Path

import yaml

repo_root = Path(sys.argv[1])
contract = yaml.safe_load(open(sys.argv[2]))
ghost_contract = yaml.safe_load(open(sys.argv[3])) if Path(sys.argv[3]).exists() else {"surfaces": []}
issues = []

surfaces = contract.get("surfaces", [])
assert len(surfaces) >= 6, "need at least 6 source-of-truth surfaces"
ghost_patterns = [
    row["path"]
    for row in ghost_contract.get("surfaces", [])
    if row.get("repo") in {"mereka-lms", "local-home"}
]

for surface in surfaces:
    for field in ("id", "canonical_locations", "consumer_guards"):
        if field not in surface:
            issues.append(f"surface {surface.get('id', '<unknown>')} missing {field}")
    for guard in surface.get("consumer_guards", []):
        if not (repo_root / guard).exists():
            issues.append(f"surface {surface['id']} references missing guard {guard}")
    for location in surface.get("canonical_locations", []):
        repo = location.get("repo")
        path = location.get("path")
        if not repo or not path:
            issues.append(f"surface {surface['id']} has incomplete canonical location {location}")
            continue
        if path.startswith("~/"):
            issues.append(f"surface {surface['id']} uses home-directory canonical path {path}")
        if repo == "mereka-lms":
            candidate = repo_root / path
            if any(token in path for token in ("*", "?", "[")):
                if not list(repo_root.glob(path)):
                    issues.append(f"surface {surface['id']} canonical glob has no matches: {path}")
            elif not candidate.exists():
                issues.append(f"surface {surface['id']} canonical path missing: {path}")
        local_checkout = location.get("local_checkout")
        if local_checkout:
            checkout_path = (repo_root / local_checkout).resolve()
            if not checkout_path.exists():
                issues.append(f"surface {surface['id']} local checkout missing: {local_checkout}")
        for pattern in ghost_patterns:
            if repo in {"mereka-lms", "local-home"} and (
                fnmatch.fnmatch(path, pattern) or fnmatch.fnmatch(pattern, path)
            ):
                issues.append(f"surface {surface['id']} canonical path overlaps ghost pattern {pattern}")
    for mirror in surface.get("mirror_locations", []):
        path = mirror.get("path", "")
        if mirror.get("repo") in {"local-home", "github-actions"} and mirror.get("class") is None:
            issues.append(f"surface {surface['id']} mirror {path} missing class")

if issues:
    for issue in issues:
        print(issue)
    raise SystemExit(1)

print(f"Validated {len(surfaces)} source-of-truth surfaces")
PY
then
  pass "source-of-truth matrix is structurally valid"
else
  fail "source-of-truth matrix has invalid canonical or mirror paths"
fi

echo
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Source-of-truth matrix checks pass."
