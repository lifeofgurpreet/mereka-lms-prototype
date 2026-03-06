#!/usr/bin/env bash
# verify-actions-pinned.sh
#
# Scans all .github/workflows/*.yml files and verifies that every `uses:` line
# references an action pinned to a full 40-character SHA-1 commit hash.
#
# Exit 0  — all actions are properly pinned
# Exit 1  — one or more actions are not SHA-pinned
#
# Usage:
#   scripts/qa/verify-actions-pinned.sh
#   scripts/qa/verify-actions-pinned.sh [--workflows-dir <path>]
#
# See docs/ops/security/ALLOWED_ACTIONS_POLICY.md for the full policy.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"

# Allow override for testing
if [[ "${1:-}" == "--workflows-dir" && -n "${2:-}" ]]; then
  WORKFLOWS_DIR="$2"
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

# SHA-1 pattern: exactly 40 hex characters after the @
SHA_PATTERN='^[A-Za-z0-9_/-]+/[A-Za-z0-9_/-]+@[0-9a-f]{40}'

pass() { echo -e "${GREEN}PASS${RESET}  $*"; }
fail() { echo -e "${RED}FAIL${RESET}  $*"; }
info() { echo -e "      $*"; }

# ---------------------------------------------------------------------------
# Main scan
# ---------------------------------------------------------------------------

echo
echo -e "${BOLD}=== verify-actions-pinned ===${RESET}"
echo -e "      Policy: docs/ops/security/ALLOWED_ACTIONS_POLICY.md"
echo -e "      Scanning: ${WORKFLOWS_DIR}"
echo

if [[ ! -d "${WORKFLOWS_DIR}" ]]; then
  echo -e "${RED}ERROR${RESET}: workflows directory not found: ${WORKFLOWS_DIR}"
  exit 1
fi

mapfile -t workflow_files < <(find "${WORKFLOWS_DIR}" -maxdepth 1 -name '*.yml' -type f | sort)

if [[ ${#workflow_files[@]} -eq 0 ]]; then
  echo -e "${YELLOW}WARN${RESET}  No workflow files found in ${WORKFLOWS_DIR}"
  exit 0
fi

total_actions=0
violations=0
declare -A seen_actions  # track unique action@sha pairs for the summary

for file in "${workflow_files[@]}"; do
  filename="$(basename "${file}")"
  file_violations=0

  # Extract all `uses:` lines with their line numbers, stripping comments
  while IFS= read -r raw_line; do
    lineno="${raw_line%%:*}"
    rest="${raw_line#*:}"
    # Strip leading whitespace and the 'uses:' keyword
    action_ref="$(echo "${rest}" | sed 's/.*uses:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | sed 's/[[:space:]]*$//')"

    # Skip empty lines (can happen if the grep matches a comment line)
    [[ -z "${action_ref}" ]] && continue

    total_actions=$(( total_actions + 1 ))

    # Record for summary
    seen_actions["${action_ref}"]=1

    # Check: must have @<40-hex-chars>
    sha_part="${action_ref##*@}"
    if [[ "${sha_part}" =~ ^[0-9a-f]{40}$ ]]; then
      : # SHA is valid — no output per-line to keep noise low
    else
      if [[ ${file_violations} -eq 0 ]]; then
        fail "${filename}"
      fi
      info "  line ${lineno}: ${action_ref}"
      info "        Expected a 40-char hex SHA after @, got: ${sha_part}"
      file_violations=$(( file_violations + 1 ))
      violations=$(( violations + 1 ))
    fi
  done < <(grep -n 'uses:' "${file}" || true)

  if [[ ${file_violations} -eq 0 ]]; then
    pass "${filename}"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo
echo -e "${BOLD}--- Summary ---${RESET}"
echo -e "  Workflow files checked : ${#workflow_files[@]}"
echo -e "  Total uses: lines      : ${total_actions}"
echo -e "  Unique actions         : ${#seen_actions[@]}"
echo

echo -e "${BOLD}Unique actions found:${RESET}"
for action in $(printf '%s\n' "${!seen_actions[@]}" | sort); do
  sha_part="${action##*@}"
  if [[ "${sha_part}" =~ ^[0-9a-f]{40}$ ]]; then
    echo -e "  ${GREEN}ok${RESET}  ${action}"
  else
    echo -e "  ${RED}!!${RESET}  ${action}"
  fi
done

echo
if [[ ${violations} -gt 0 ]]; then
  echo -e "${RED}${BOLD}RESULT: FAIL — ${violations} unpinned action(s) found${RESET}"
  echo -e "  Fix: pin each action to a full 40-char commit SHA."
  echo -e "  See docs/ops/security/ALLOWED_ACTIONS_POLICY.md for the process."
  exit 1
else
  echo -e "${GREEN}${BOLD}RESULT: PASS — all ${total_actions} action references are SHA-pinned${RESET}"
  exit 0
fi
