#!/usr/bin/env bash
# Standalone gate: no :latest tags or placeholder/ image prefixes under deploy/k8s/
#
# Mutable tags like :latest can silently pull a different image on each deploy,
# breaking reproducibility and making rollbacks unreliable.
#
# Placeholder image prefixes (placeholder/, example/, TODO) indicate scaffolding
# that was not replaced with a real image before committing.
#
# Usage:
#   scripts/qa/no_mutable_or_placeholder_images.sh [SCOPE_DIR]
#   Default SCOPE_DIR: deploy/k8s/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE_DIR="${1:-${REPO_ROOT}/deploy/k8s}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

hits=0

scan_pattern() {
  local label="$1"
  local pattern="$2"
  local results
  set +e
  results=$(rg -n \
    --glob '!.git/**' \
    --glob '!*.md' \
    -- "$pattern" "$SCOPE_DIR" 2>/dev/null)
  local rc=$?
  set -e
  if [[ $rc -ne 0 && $rc -ne 1 ]]; then
    echo "rg error (rc=$rc) scanning $label" >&2
    exit "$rc"
  fi
  if [[ -n "$results" ]]; then
    echo -e "${RED}[FAIL]${NC} $label:"
    while IFS= read -r line; do
      echo "  $line"
      hits=$((hits + 1))
    done <<< "$results"
  fi
}

# :latest tag — matches YAML newTag: latest or image: foo:latest
scan_pattern ":latest tag" '(newTag|image):[[:space:]]+[^[:space:]]+:latest[[:space:]]*$|(newTag):[[:space:]]+latest[[:space:]]*$'

# placeholder/ image prefix
scan_pattern "placeholder/ image prefix" 'image:[[:space:]]+placeholder/'

if [[ $hits -gt 0 ]]; then
  echo ""
  echo -e "${RED}FAIL${NC}: $hits mutable/placeholder image reference(s) found in $SCOPE_DIR"
  echo "      Use digest-pinned or deterministic SHA-based tags for all images."
  exit 1
fi

echo -e "${GREEN}PASS${NC}: No mutable or placeholder image references found in $SCOPE_DIR"
