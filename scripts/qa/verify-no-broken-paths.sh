#!/usr/bin/env bash
# verify-no-broken-paths.sh — Detect references to deprecated paths in the repo.
#
# Complements verify-deprecation-discipline.sh (which checks shell `source`
# calls in scripts/).  This script extends coverage to:
#   1. Makefiles referencing deprecated directory paths
#   2. Documentation files (.md) treating deprecated paths as still-active
#   3. Shell scripts calling deprecated paths directly (not via `source`)
#   4. Python scripts referencing deprecated paths
#
# Deprecated paths are read from DEPR.md at runtime.  Currently known paths:
#   tools/       (DEPR-003)
#   ops/         (DEPR-004)
#   scripts/shared/_common.sh  (DEPR-006)
#
# No network calls.  No destructive operations.
#
# Usage:
#   ./scripts/qa/verify-no-broken-paths.sh
#
# Exit codes:
#   0  All checks pass
#   1  One or more checks failed
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

failures=0

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }
info() { echo "[INFO] $*"; }

# ---------------------------------------------------------------------------
# Helper: grep a directory recursively for a pattern, collect file hits.
# Avoids per-file loops (fast on large trees).
# Args: <label> <grep-extra-args…> -- <pattern> <dirs…>
# ---------------------------------------------------------------------------
check_grep_hits() {
  local label="$1"
  shift
  local extra_args=()
  while [[ "$1" != "--" ]]; do
    extra_args+=("$1")
    shift
  done
  shift  # consume "--"
  local pattern="$1"
  shift
  local dirs=("$@")

  local hits
  # Capture file list; grep returns 1 when no match (safe with || true)
  hits="$(grep -rl "${extra_args[@]+"${extra_args[@]}"}" -E "$pattern" "${dirs[@]}" 2>/dev/null || true)"

  if [[ -n "$hits" ]]; then
    fail "$label — found active reference(s) in:"
    while IFS= read -r f; do
      echo "        $f"
    done <<< "$hits"
  else
    pass "$label — no active references found"
  fi
}

# ---------------------------------------------------------------------------
# Derive the list of deprecated directory paths from DEPR.md
# ---------------------------------------------------------------------------
echo ""
echo "--- 0. Derive deprecated paths from DEPR.md ---"

if [[ ! -f "DEPR.md" ]]; then
  fail "DEPR.md not found — cannot derive deprecated paths"
  echo ""
  echo "FAIL — $failures check(s) failed" >&2
  exit 1
fi

DEPRECATED_DIRS=()
DEPRECATED_FILES=()

if grep -q "DEPR-003" DEPR.md; then
  DEPRECATED_DIRS+=("tools")
fi

if grep -q "DEPR-004" DEPR.md; then
  DEPRECATED_DIRS+=("ops")
fi

if grep -q "DEPR-006" DEPR.md; then
  DEPRECATED_FILES+=("scripts/shared/_common.sh")
fi

info "Deprecated directories: ${DEPRECATED_DIRS[*]:-none}"
info "Deprecated files:       ${DEPRECATED_FILES[*]:-none}"

if [[ "${#DEPRECATED_DIRS[@]}" -eq 0 && "${#DEPRECATED_FILES[@]}" -eq 0 ]]; then
  info "No deprecated paths found in DEPR.md — nothing to check"
  echo ""
  echo "OK — no deprecated paths defined"
  exit 0
fi

# ---------------------------------------------------------------------------
# 1. Makefiles
# ---------------------------------------------------------------------------
echo ""
echo "--- 1. Makefile references to deprecated paths ---"

# Collect Makefile paths (fast, bounded set)
mapfile -d '' makefile_list < <(find "$REPO_ROOT" \
  \( -name "Makefile" -o -name "*.mk" \) \
  -not -path "*/.git/*" \
  -print0 2>/dev/null)

if [[ "${#makefile_list[@]}" -gt 0 ]]; then
  for dep_dir in "${DEPRECATED_DIRS[@]}"; do
    check_grep_hits \
      "Makefile active reference to ${dep_dir}/" \
      -- "(^|[[:space:]/\$(])(${dep_dir}/)" \
      "${makefile_list[@]}"
  done
  for dep_file in "${DEPRECATED_FILES[@]}"; do
    check_grep_hits \
      "Makefile active reference to ${dep_file}" \
      -- "${dep_file}" \
      "${makefile_list[@]}"
  done
else
  info "No Makefiles found — skipping Makefile checks"
fi

# ---------------------------------------------------------------------------
# 2. Documentation — .md files treating deprecated paths as active
#
# Strategy: flag markdown hyperlinks that navigate to a deprecated path.
# We look for markdown link syntax ]( pointing at deprecated dirs/files.
#
# Excluded from scanning:
#   - DEPR.md (the canonical deprecation register)
#   - Tombstone README files (tools/README.md, ops/README.md)
#   - docs/archive/ (historical records)
#   - specs/testmaps/ and specs/plans/ (spec-tooling artifacts, not navigable docs)
#   - Any file in the repository-structure spec family (spec describing the rule itself)
#
# NOTE: prose mentions like "`tools/`" or "tools/ directory" in explanatory text
# are expected in specs and runbooks; only link-syntax ]( is treated as "active".
# ---------------------------------------------------------------------------
echo ""
echo "--- 2. Documentation hyperlinks to deprecated paths ---"

DOC_DIRS=("docs" "specs" "specdocs")

# Build exclude flags for grep
doc_exclude_flags=(
  "--exclude=DEPR.md"
  "--exclude=README.md"
  "--exclude-dir=archive"
  "--exclude-dir=plans"
  "--exclude-dir=testmaps"
  "--exclude-dir=.git"
)

for dep_dir in "${DEPRECATED_DIRS[@]}"; do
  active_doc_dirs=()
  for d in "${DOC_DIRS[@]}"; do
    [[ -d "$d" ]] && active_doc_dirs+=("$d")
  done
  if [[ "${#active_doc_dirs[@]}" -gt 0 ]]; then
    # Only match markdown link destinations: ](path) where path starts with dep_dir/
    check_grep_hits \
      "Docs hyperlink to deprecated ${dep_dir}/" \
      "${doc_exclude_flags[@]}" --include="*.md" \
      -- "\]\(\.?/?(${dep_dir}/)" \
      "${active_doc_dirs[@]}"
  else
    info "No doc directories found — skipping doc check for ${dep_dir}/"
  fi
done

for dep_file in "${DEPRECATED_FILES[@]}"; do
  active_doc_dirs=()
  for d in "${DOC_DIRS[@]}"; do
    [[ -d "$d" ]] && active_doc_dirs+=("$d")
  done
  if [[ "${#active_doc_dirs[@]}" -gt 0 ]]; then
    check_grep_hits \
      "Docs hyperlink to deprecated ${dep_file}" \
      "${doc_exclude_flags[@]}" --include="*.md" \
      -- "\]\([^)]*${dep_file}" \
      "${active_doc_dirs[@]}"
  fi
done

# ---------------------------------------------------------------------------
# 3. Shell scripts — direct execution of deprecated paths
#    verify-deprecation-discipline.sh covers `source` calls in scripts/.
#    Here we catch direct invocations: ./tools/foo, bash tools/foo, exec tools/
# ---------------------------------------------------------------------------
echo ""
echo "--- 3. Shell script direct-invocation references to deprecated paths ---"

SHELL_DIRS=("scripts" "infrastructure/tutor" "deploy")

for dep_dir in "${DEPRECATED_DIRS[@]}"; do
  active_sh_dirs=()
  for d in "${SHELL_DIRS[@]}"; do
    [[ -d "$d" ]] && active_sh_dirs+=("$d")
  done
  if [[ "${#active_sh_dirs[@]}" -gt 0 ]]; then
    check_grep_hits \
      "Shell direct invocation of deprecated ${dep_dir}/" \
      --include="*.sh" \
      --exclude="verify-deprecation-discipline.sh" \
      --exclude="verify-no-broken-paths.sh" \
      -- "(^\./|bash |exec |sh |\\\$REPO_ROOT/)(${dep_dir}/)" \
      "${active_sh_dirs[@]}"
  fi
done

for dep_file in "${DEPRECATED_FILES[@]}"; do
  active_sh_dirs=()
  for d in "${SHELL_DIRS[@]}"; do
    [[ -d "$d" ]] && active_sh_dirs+=("$d")
  done
  if [[ "${#active_sh_dirs[@]}" -gt 0 ]]; then
    check_grep_hits \
      "Shell direct invocation of deprecated ${dep_file}" \
      --include="*.sh" \
      --exclude="verify-deprecation-discipline.sh" \
      --exclude="verify-no-broken-paths.sh" \
      -- "(bash |exec |sh ).*${dep_file}" \
      "${active_sh_dirs[@]}"
  fi
done

# ---------------------------------------------------------------------------
# 4. Python scripts referencing deprecated paths
# ---------------------------------------------------------------------------
echo ""
echo "--- 4. Python script references to deprecated paths ---"

PYTHON_DIRS=("scripts" "services" "infrastructure")

for dep_dir in "${DEPRECATED_DIRS[@]}"; do
  active_py_dirs=()
  for d in "${PYTHON_DIRS[@]}"; do
    [[ -d "$d" ]] && active_py_dirs+=("$d")
  done
  if [[ "${#active_py_dirs[@]}" -gt 0 ]]; then
    # Match string literals referencing the deprecated dir; skip comment lines (#)
    check_grep_hits \
      "Python reference to deprecated ${dep_dir}/" \
      --include="*.py" \
      --exclude-dir="__pycache__" \
      --exclude-dir=".venv" \
      -- "^[^#].*([\"\'](${dep_dir}/))" \
      "${active_py_dirs[@]}"
  else
    info "No Python source directories found — skipping Python checks for ${dep_dir}/"
  fi
done

for dep_file in "${DEPRECATED_FILES[@]}"; do
  active_py_dirs=()
  for d in "${PYTHON_DIRS[@]}"; do
    [[ -d "$d" ]] && active_py_dirs+=("$d")
  done
  if [[ "${#active_py_dirs[@]}" -gt 0 ]]; then
    check_grep_hits \
      "Python reference to deprecated ${dep_file}" \
      --include="*.py" \
      --exclude-dir="__pycache__" \
      --exclude-dir=".venv" \
      -- "^[^#].*[\"\'].*${dep_file}" \
      "${active_py_dirs[@]}"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "--- Summary ---"
if [[ "$failures" -eq 0 ]]; then
  echo "OK — all broken-path checks passed"
  exit 0
fi
echo "FAIL — $failures check(s) failed" >&2
exit 1
