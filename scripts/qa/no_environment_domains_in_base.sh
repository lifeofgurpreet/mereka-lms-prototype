#!/usr/bin/env bash
# Standalone gate: no environment-specific domains in deploy/k8s/base/
#
# Base Kustomize resources must be environment-neutral. Hard-coding
# production or dev domain names in base/ makes overlays non-portable and
# leaks environment assumptions into shared manifests.
#
# Domains that must NOT appear in base/:
#   *.mereka.io     — production domain
#   *.mereka.dev    — development domain
#   biji-biji.com   — alternative production domain
#   skillourfuture  — partner domain
#
# Lines that are pure comments (starting with optional whitespace + #) are
# exempt — documentation in YAML comments is acceptable.
#
# Usage:
#   scripts/qa/no_environment_domains_in_base.sh [SCOPE_DIR]
#   Default SCOPE_DIR: deploy/k8s/base/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE_DIR="${1:-${REPO_ROOT}/deploy/k8s/base}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

hits=0

scan_domain() {
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
    while IFS= read -r line; do
      # Strip the filename:lineno: prefix to get the content
      local content="${line#*:*:}"
      # Skip comment-only lines (optional leading whitespace, then #)
      if [[ "$content" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      echo -e "${RED}[FAIL]${NC} Environment domain ($label) in base: $line"
      hits=$((hits + 1))
    done <<< "$results"
  fi
}

scan_domain "*.mereka.io"    '\.mereka\.io'
scan_domain "*.mereka.dev"   '\.mereka\.dev'
scan_domain "biji-biji.com"  'biji-biji\.com'
scan_domain "skillourfuture" 'skillourfuture'

if [[ $hits -gt 0 ]]; then
  echo ""
  echo -e "${RED}FAIL${NC}: $hits environment domain reference(s) in $SCOPE_DIR"
  echo "      Environment-specific domains belong in overlays/, not base/."
  exit 1
fi

echo -e "${GREEN}PASS${NC}: No environment-specific domains found in $SCOPE_DIR"
