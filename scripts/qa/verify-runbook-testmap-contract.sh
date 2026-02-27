#!/usr/bin/env bash
# @covers AC-RS-004
# @spec: repository-structure_spec.md
# Enforce runbook testmap reference contract.
#
# Contract:
# - docs/runbooks/*.md MUST NOT reference legacy *_testmap.yaml/.yml names
# - Any explicit "Testmap" reference MUST point to specs/testmaps/*.testmap.yml
# - Referenced testmap files MUST exist
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

RUNBOOK_DIR="docs/runbooks"

if [[ ! -d "$RUNBOOK_DIR" ]]; then
  fail "runbook directory missing: $RUNBOOK_DIR"
  echo
  echo "✗ $failures runbook testmap contract check(s) failed"
  exit 1
fi

# Legacy naming drift should never appear again in runbooks.
if rg -n '_testmap\\.ya?ml|\\.testmap\\.yaml' "$RUNBOOK_DIR" >/dev/null 2>&1; then
  fail "runbooks contain legacy testmap naming (_testmap.yaml/.yml or .testmap.yaml)"
  rg -n '_testmap\\.ya?ml|\\.testmap\\.yaml' "$RUNBOOK_DIR" || true
else
  pass "runbooks contain no legacy testmap naming"
fi

# Validate explicit Testmap references.
mapfile -t refs < <(
  python3 - <<'PY'
import pathlib
import re

root = pathlib.Path('docs/runbooks')
pat = re.compile(r"Testmap\*\*:\s*`([^`]+)`")
for md in sorted(root.glob('*.md')):
    text = md.read_text(encoding='utf-8', errors='ignore')
    for m in pat.finditer(text):
        print(f"{md}:{m.group(1)}")
PY
)

if [[ "${#refs[@]}" -eq 0 ]]; then
  fail "no explicit Testmap references found under $RUNBOOK_DIR"
else
  pass "found ${#refs[@]} explicit Testmap reference(s) under $RUNBOOK_DIR"
fi

for ref in "${refs[@]:-}"; do
  [[ -z "$ref" ]] && continue
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
