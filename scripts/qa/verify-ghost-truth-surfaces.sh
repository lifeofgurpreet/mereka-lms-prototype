#!/usr/bin/env bash
# @covers AC-TRUTH-001
# @spec: multi-tenancy-architecture_spec.md
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT_FILE="$REPO_ROOT/config/ghost-truth-surfaces.yaml"
SOURCE_MATRIX="$REPO_ROOT/config/source-of-truth-matrix.yaml"

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }

echo "=== Ghost Truth Surface Verification ==="
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

echo "--- Check 2: ghost surfaces are classified and not claimed as canonical ---"
if python3 - "$REPO_ROOT" "$CONTRACT_FILE" "$SOURCE_MATRIX" <<'PY'
import fnmatch
import re
import sys
from pathlib import Path

import yaml

repo_root = Path(sys.argv[1])
contract = yaml.safe_load(open(sys.argv[2]))
source_matrix = yaml.safe_load(open(sys.argv[3])) if Path(sys.argv[3]).exists() else {"surfaces": []}
issues = []

surfaces = contract.get("surfaces", [])
assert surfaces, "no ghost surfaces defined"

for row in surfaces:
    for field in ("id", "repo", "path", "path_hint", "class", "canonical_source"):
        if field not in row:
            issues.append(f"ghost surface {row.get('id', '<unknown>')} missing {field}")
    if row.get("repo") == "mereka-lms" and row.get("must_exist", False):
        if not (repo_root / row["path_hint"]).exists():
            issues.append(f"ghost surface {row['id']} expected existing path {row['path_hint']}")

canonical_paths = []
for surface in source_matrix.get("surfaces", []):
    for location in surface.get("canonical_locations", []):
        canonical_paths.append((location.get("repo"), location.get("path")))

for row in surfaces:
    pattern = row.get("path")
    if row.get("repo") in {"mereka-lms", "local-home"}:
        for canonical_repo, canonical_path in canonical_paths:
            if canonical_repo in {"mereka-lms", "local-home"} and (
                fnmatch.fnmatch(pattern, canonical_path)
                or fnmatch.fnmatch(canonical_path, pattern)
            ):
                issues.append(
                    f"ghost surface {row['id']} overlaps canonical source-of-truth path {canonical_path}"
                )

forbidden_terms = [term.lower() for term in contract.get("forbidden_canonical_terms", [])]
allowed_terms = [term.lower() for term in contract.get("allowed_noncanonical_terms", [])]
scan_targets = []
for target in contract.get("scan_paths", []):
    path = repo_root / target
    if path.is_dir():
        scan_targets.extend(
            p for p in path.rglob("*")
            if p.is_file() and ".git/" not in p.as_posix() and ".cache/" not in p.as_posix()
        )
    elif path.is_file():
        scan_targets.append(path)

for row in surfaces:
    if not row.get("reject_canonical_mentions", False):
        continue
    token = row["path_hint"]
    token_re = re.compile(re.escape(token), re.IGNORECASE)
    for path in scan_targets:
        try:
            text = path.read_text(encoding="utf-8")
        except Exception:
            continue
        for idx, line in enumerate(text.splitlines(), start=1):
            lowered = line.lower()
            if not token_re.search(line):
                continue
            if any(term in lowered for term in forbidden_terms) and not any(term in lowered for term in allowed_terms):
                issues.append(f"{path.relative_to(repo_root)}:{idx}: canonical claim for local mirror token {token}")

if issues:
    for issue in issues:
        print(issue)
    raise SystemExit(1)

print(f"Validated {len(surfaces)} ghost truth surfaces")
PY
then
  pass "ghost truth registry is internally consistent"
else
  fail "ghost truth registry contains canonical overlap or invalid claims"
fi

echo
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Ghost truth surface checks pass."
