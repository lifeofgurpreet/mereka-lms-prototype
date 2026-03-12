#!/usr/bin/env bash
# verify-script-registry-completeness.sh
# Enforces Charter non-negotiable #6:
#   "No new release-critical script without registry entry."
#
# Checks:
#   1. Every script in scripts/release/ is registered in script-registry.yaml
#   2. Every scripts/infra/canonical-*.sh and scripts/infra/release-*.sh is registered
#   3. Every release-blocking scripts/qa/* and scripts/ci/* script is in ci-scripts-static.txt
#
# Usage:
#   bash scripts/qa/verify-script-registry-completeness.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY="${REPO_ROOT}/scripts/governance/script-registry.yaml"
CI_LIST="${REPO_ROOT}/.github/ci-scripts-static.txt"
CI_RUNTIME_LIST="${REPO_ROOT}/.github/ci-scripts-runtime.txt"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL + 1)); }
info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

echo "=== Script Registry Completeness Check ==="
echo ""

# ── Build lookup: registered paths ───────────────────────────────────────────
mapfile -t REGISTERED_PATHS < <(
  grep -E '^\s+- path: ' "${REGISTRY}" | sed 's/^\s*- path: //' | tr -d ' '
)

declare -A REGISTERED_SET
for p in "${REGISTERED_PATHS[@]}"; do
  REGISTERED_SET["${p}"]=1
done

# ── Build lookup: release-blocking qa/ci paths from registry ─────────────────
# Scan consecutive lines: record path, emit if criticality: release-blocking
# Scope to scripts/qa/ and scripts/ci/ — infra orchestration scripts are not
# expected in ci-scripts-static.txt (they mutate cluster/registry).
declare -A BLOCKING_VERIFICATION_SET
current_path=""
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]path:[[:space:]](.+)$ ]]; then
    current_path="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ criticality:[[:space:]]release-blocking && -n "$current_path" ]]; then
    if [[ "$current_path" == scripts/qa/* || "$current_path" == scripts/ci/* ]]; then
      BLOCKING_VERIFICATION_SET["${current_path}"]=1
    fi
    current_path=""
  elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]path: ]]; then
    current_path=""
  fi
done < "${REGISTRY}"

# ── Build lookup: script base-paths in ci-scripts-static.txt ─────────────────
# Entries may include arguments (e.g. "scripts/release/release-gate.sh --skip-cluster")
# Strip arguments when building the lookup set.
declare -A CI_SET
while IFS= read -r line; do
  [[ "$line" =~ ^#  || -z "${line// }" ]] && continue
  base_path="${line%% *}"
  CI_SET["${base_path}"]=1
done < "${CI_LIST}"
if [[ -f "${CI_RUNTIME_LIST}" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#  || -z "${line// }" ]] && continue
    base_path="${line%% *}"
    CI_SET["${base_path}"]=1
  done < "${CI_RUNTIME_LIST}"
fi

# ── Check 1: scripts/release/* must be registered ────────────────────────────
echo "--- 1. scripts/release/ — all scripts registered ---"
if [[ -d "${REPO_ROOT}/scripts/release" ]]; then
  found=0
  while IFS= read -r abs_script; do
    rel="${abs_script#"${REPO_ROOT}/"}"
    found=$((found + 1))
    if [[ -n "${REGISTERED_SET["${rel}"]:-}" ]]; then
      pass "${rel}"
    else
      fail "${rel} — not in script-registry.yaml (Charter #6 violation)"
    fi
  done < <(find "${REPO_ROOT}/scripts/release" -maxdepth 1 -name '*.sh' -type f | sort)
  [[ "$found" -eq 0 ]] && info "No scripts found in scripts/release/"
else
  info "scripts/release/ does not exist — skipping"
fi

# ── Check 2: scripts/infra/canonical-*.sh and release-*.sh must be registered ─
echo ""
echo "--- 2. scripts/infra/{canonical,release}-*.sh — all registered ---"
found=0
while IFS= read -r abs_script; do
  rel="${abs_script#"${REPO_ROOT}/"}"
  found=$((found + 1))
  if [[ -n "${REGISTERED_SET["${rel}"]:-}" ]]; then
    pass "${rel}"
  else
    fail "${rel} — not in script-registry.yaml (Charter #6 violation)"
  fi
done < <(find "${REPO_ROOT}/scripts/infra" -maxdepth 1 \
  \( -name 'canonical-*.sh' -o -name 'release-*.sh' \) -type f | sort)
[[ "$found" -eq 0 ]] && info "No canonical-* or release-* scripts found in scripts/infra/"

# ── Check 3: release-blocking qa/ci scripts must be in ci-scripts-static.txt ──
echo ""
echo "--- 3. release-blocking scripts/qa/ and scripts/ci/ — in ci-scripts-static.txt ---"
if [[ "${#BLOCKING_VERIFICATION_SET[@]}" -eq 0 ]]; then
  info "No release-blocking scripts/qa/ or scripts/ci/ entries found in registry"
else
  for path in $(echo "${!BLOCKING_VERIFICATION_SET[@]}" | tr ' ' '\n' | sort); do
    if [[ -n "${CI_SET["${path}"]:-}" ]]; then
      pass "${path}"
    else
      fail "${path} — criticality: release-blocking but absent from ci-scripts-static.txt and ci-scripts-runtime.txt"
    fi
  done
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "  PASS: ${PASS}"
echo "  FAIL: ${FAIL}"
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL — ${FAIL} violation(s). Add missing entries to script-registry.yaml and/or ci-scripts-static.txt.${NC}"
  exit 1
fi

echo -e "${GREEN}RESULT: PASS${NC}"
