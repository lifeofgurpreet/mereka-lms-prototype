#!/usr/bin/env bash
# @covers AC-RS-004
# @spec: repository-structure_spec.md
# Enforce docs testmap reference contract.
#
# Contract:
# - non-archive docs MUST NOT reference legacy *_testmap.yaml/.yml names
# - Any explicit "Testmap" reference MUST point to specs/testmaps/*.testmap.yml
# - Referenced testmap files MUST exist
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

DOCS_DIR="docs"

if [[ ! -d "$DOCS_DIR" ]]; then
  fail "docs directory missing: $DOCS_DIR"
  echo
  echo "✗ $failures docs testmap contract check(s) failed"
  exit 1
fi

# Legacy naming drift should never appear again in live docs.
if rg -n '_testmap\\.ya?ml|\\.testmap\\.yaml' "$DOCS_DIR" --glob '!docs/archive/**' >/dev/null 2>&1; then
  fail "live docs contain legacy testmap naming (_testmap.yaml/.yml or .testmap.yaml)"
  rg -n '_testmap\\.ya?ml|\\.testmap\\.yaml' "$DOCS_DIR" --glob '!docs/archive/**' || true
else
  pass "live docs contain no legacy testmap naming"
fi

# Validate testmap path references in live docs.
mapfile -t refs < <(
  python3 - <<'PY'
import pathlib
import re

root = pathlib.Path('docs')
explicit_pat = re.compile(r"\*\*Testmap\*\*:\s*`([^`]+)`", re.IGNORECASE)
path_pat = re.compile(r"(specs/testmaps/[A-Za-z0-9._/-]*testmap[A-Za-z0-9._/-]*)")
for md in sorted(root.rglob('*.md')):
    if 'archive' in md.parts:
        continue
    text = md.read_text(encoding='utf-8', errors='ignore')
    # Strictly-labeled Testmap references
    for m in explicit_pat.finditer(text):
        print(f"{md}:{m.group(1)}")
    # Any direct path-like testmap references in live docs
    for m in path_pat.finditer(text):
        print(f"{md}:{m.group(1)}")
PY
)

if [[ "${#refs[@]}" -eq 0 ]]; then
  fail "no testmap path references found under live docs"
else
  pass "found ${#refs[@]} testmap path reference(s) under live docs"
fi

declare -A seen_refs=()
for ref in "${refs[@]:-}"; do
  [[ -z "$ref" ]] && continue
  if [[ -n "${seen_refs[$ref]:-}" ]]; then
    continue
  fi
  seen_refs["$ref"]=1

  src_file="${ref%%:*}"
  testmap_path="${ref#*:}"

  if [[ ! "$testmap_path" =~ ^specs/testmaps/.+\.testmap\.yml$ ]]; then
    fail "$src_file has non-canonical testmap path: $testmap_path"
    continue
  fi

  if [[ ! -f "$testmap_path" ]]; then
    fail "$src_file references missing testmap file: $testmap_path"
    continue
  fi

  pass "$src_file references canonical existing testmap: $testmap_path"
done

echo
if [[ "$failures" -eq 0 ]]; then
  echo "✓ Runbook testmap contract checks passed"
  exit 0
else
  echo "✗ $failures runbook testmap contract check(s) failed"
  exit 1
fi
