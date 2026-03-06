#!/usr/bin/env bash
# @covers AC-RS-001, AC-RS-002, AC-RS-003, AC-RS-004
# @spec: repository-structure_spec.md
# verify-repo-hygiene-artifacts.sh
#
# Enforces repository hygiene by blocking tracked runtime artifacts, local caches,
# and generated outputs that should remain outside git history.
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

violations=0
checks=0

fail() {
  echo "  FAIL: $*" >&2
  violations=$((violations + 1))
}

pass() {
  checks=$((checks + 1))
}

echo "=== Repo Hygiene Artifact Verification ==="
echo "Repo: $REPO_ROOT"
echo ""

while IFS= read -r -d '' path; do
  case "$path" in
    exports/*)
      fail "$path is tracked under exports/ (raw export data must not be committed)"
      ;;
    var/*)
      fail "$path is tracked under var/ (runtime evidence/artifacts must not be committed)"
      ;;
    tutor_env/dev/frontend-app-*)
      fail "$path is tracked under tutor_env/dev/frontend-app-* (local MFE clones must not be committed)"
      ;;
    tmp/frontend-app-*)
      if [[ "$path" == "tmp/frontend-app-authn" ]]; then
        mode="$(git ls-files -s -- "$path" | awk 'NR==1 {print $1}')"
        if [[ "$mode" == "160000" ]]; then
          pass
        else
          fail "$path exists but is not a submodule pointer (expected gitlink mode 160000)"
        fi
      else
        fail "$path is a tracked tmp/frontend-app-* clone outside the allowlisted authn submodule"
      fi
      ;;
    *__pycache__/*|*/__pycache__)
      fail "$path is tracked bytecode cache content (__pycache__)"
      ;;
    .ruff_cache/*|*/.ruff_cache/*|.ruff_cache)
      fail "$path is tracked Ruff cache content (.ruff_cache)"
      ;;
    .pytest_cache/*|*/.pytest_cache/*|.pytest_cache)
      fail "$path is tracked pytest cache content (.pytest_cache)"
      ;;
    .mypy_cache/*|*/.mypy_cache/*|.mypy_cache)
      fail "$path is tracked mypy cache content (.mypy_cache)"
      ;;
    *.pyc|*.pyo)
      fail "$path is tracked compiled Python bytecode"
      ;;
    infrastructure/tutor/brand-*/dist/*)
      if [[ "$(basename "$path")" == ".gitkeep" ]]; then
        pass
      else
        fail "$path is tracked generated dist output (only .gitkeep placeholders are allowed)"
      fi
      ;;
    *)
      pass
      ;;
  esac
done < <(git ls-files -z)

echo "=== Summary ==="
echo "Checks     : $checks"
echo "Violations : $violations"
echo ""

if [[ "$violations" -gt 0 ]]; then
  echo "FAIL — repository hygiene violations found." >&2
  exit 1
fi

echo "PASS — tracked files comply with repository hygiene rules."
