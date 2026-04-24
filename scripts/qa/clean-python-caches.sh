#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

DIR_PATTERNS=(
  "__pycache__"
  ".pytest_cache"
  ".mypy_cache"
  ".ruff_cache"
)

FILE_PATTERNS=(
  "*.pyc"
  "*.pyo"
)

echo "=== Python Cache Cleanup ==="
echo "Repo : $REPO_ROOT"
echo "Mode : $([[ "$DRY_RUN" == true ]] && echo 'dry-run' || echo 'apply')"
echo ""

dir_hits=0
for pattern in "${DIR_PATTERNS[@]}"; do
  while IFS= read -r -d '' path; do
    dir_hits=$((dir_hits + 1))
    if [[ "$DRY_RUN" == true ]]; then
      echo "would remove dir: ${path#$REPO_ROOT/}"
    else
      rm -rf "$path"
      echo "removed dir: ${path#$REPO_ROOT/}"
    fi
  done < <(find "$REPO_ROOT" -type d -name "$pattern" -print0)
done

file_hits=0
for pattern in "${FILE_PATTERNS[@]}"; do
  while IFS= read -r -d '' path; do
    file_hits=$((file_hits + 1))
    if [[ "$DRY_RUN" == true ]]; then
      echo "would remove file: ${path#$REPO_ROOT/}"
    else
      rm -f "$path"
      echo "removed file: ${path#$REPO_ROOT/}"
    fi
  done < <(find "$REPO_ROOT" -type f -name "$pattern" -print0)
done

echo ""
echo "Directories matched : $dir_hits"
echo "Files matched       : $file_hits"
echo "Done."
