#!/usr/bin/env bash
# @spec: ci-cd-pipeline_spec.md
# @covers AC-009, AC-020
#
# verify-binary-pinning-pcp.sh
#
# Cross-repo check: scans platform-control-plane CI workflows for binary
# downloads that lack checksum verification.
#
# This is the companion script to docs/policies/operations/BINARY_PINNING.md (T057).
# Actual remediation belongs in the platform-control-plane repository.
#
# Exit codes:
#   0 — all checks PASS (or all SKIP because repo is unavailable)
#   1 — one or more unpinned downloads detected
#
# Usage:
#   scripts/qa/verify-binary-pinning-pcp.sh
#   PCP_REPO=/path/to/platform-control-plane scripts/qa/verify-binary-pinning-pcp.sh
#
# Environment:
#   PCP_REPO   Override default search path for the pcp repo
#              (default: ~/projects/platform-control-plane)

set -euo pipefail

# ---------------------------------------------------------------------------
# Colours and counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}PASS${NC}  $*"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC}  $*"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC}  $*"; SKIP=$((SKIP + 1)); }

# ---------------------------------------------------------------------------
# Locate platform-control-plane repo
# ---------------------------------------------------------------------------
DEFAULT_PCP_PATHS=(
  "${HOME}/projects/platform-control-plane"
  "${HOME}/projects/k8s/platform-control-plane"
  "/opt/platform-control-plane"
)

PCP_REPO="${PCP_REPO:-}"

if [[ -z "${PCP_REPO}" ]]; then
  for candidate in "${DEFAULT_PCP_PATHS[@]}"; do
    if [[ -d "${candidate}" ]]; then
      PCP_REPO="${candidate}"
      break
    fi
  done
fi

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
echo
echo -e "${BOLD}=== verify-binary-pinning-pcp ===${NC}"
echo -e "      Checks: unpinned curl/wget binary downloads in pcp CI workflows"
echo -e "      Policy: docs/policies/operations/BINARY_PINNING.md"
echo

if [[ -z "${PCP_REPO}" || ! -d "${PCP_REPO}" ]]; then
  skip "platform-control-plane repo not found locally (searched: ${DEFAULT_PCP_PATHS[*]})"
  skip "Set PCP_REPO=/path/to/repo to enable these checks"
  echo
  echo -e "${BOLD}--- Summary ---${NC}"
  echo -e "  PASS: ${PASS} | FAIL: ${FAIL} | SKIP: ${SKIP}"
  echo
  echo -e "${YELLOW}${BOLD}RESULT: SKIP — cross-repo not available${NC}"
  exit 0
fi

echo -e "      Repo: ${PCP_REPO}"
echo

WORKFLOWS_DIR="${PCP_REPO}/.github/workflows"

if [[ ! -d "${WORKFLOWS_DIR}" ]]; then
  skip "No .github/workflows directory found in ${PCP_REPO}"
  echo
  echo -e "${BOLD}--- Summary ---${NC}"
  echo -e "  PASS: ${PASS} | FAIL: ${FAIL} | SKIP: ${SKIP}"
  echo
  echo -e "${YELLOW}${BOLD}RESULT: SKIP — no workflows directory${NC}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Scan: unpinned binary downloads
#
# Patterns that indicate a binary is fetched without a checksum:
#   curl ...    followed by no sha256sum / shasum check within 5 lines
#   wget ...    same
#
# We look for the raw download invocations and flag any that are NOT
# immediately followed (within the same step) by a checksum verification.
# ---------------------------------------------------------------------------
mapfile -t workflow_files < <(find "${WORKFLOWS_DIR}" -maxdepth 1 -name '*.yml' -type f | sort)

if [[ ${#workflow_files[@]} -eq 0 ]]; then
  skip "No workflow files found in ${WORKFLOWS_DIR}"
  echo
  echo -e "${BOLD}--- Summary ---${NC}"
  echo -e "  PASS: ${PASS} | FAIL: ${FAIL} | SKIP: ${SKIP}"
  echo
  echo -e "${YELLOW}${BOLD}RESULT: SKIP — no workflows found${NC}"
  exit 0
fi

echo -e "${BOLD}--- Scanning ${#workflow_files[@]} workflow file(s) ---${NC}"
echo

for wf in "${workflow_files[@]}"; do
  wf_name="$(basename "${wf}")"
  wf_violations=0

  # Collect all lines with curl/wget binary downloads (exclude health-check / json-only calls)
  while IFS= read -r match; do
    lineno="${match%%:*}"
    line_content="${match#*:}"

    # Skip lines that are clearly not binary downloads:
    #   - curl used for API calls (json content-type, -d '{', etc.)
    #   - curl -f or --fail used for health probes without a file output
    if grep -qE '(-H.*application/json|--data.*\{|-d.*\{|Content-Type|/health|/healthz)' <<<"${line_content}"; then
      continue
    fi

    # Only flag lines that download to a file (-o, -O, --output, -L followed by pipe to file)
    if ! grep -qE '(-o[[:space:]]|-O[[:space:]]|--output[[:space:]]|-O$|-O[[:space:]]|> [a-zA-Z]|\| (tar|sh|bash|install))' <<<"${line_content}"; then
      # Also flag pipe-to-shell: curl ... | bash (always unpinned)
      if ! grep -qE '\| *(ba)?sh' <<<"${line_content}"; then
        continue
      fi
    fi

    # Now check the surrounding ±10 lines for checksum verification
    context_start=$(( lineno > 10 ? lineno - 10 : 1 ))
    context_end=$(( lineno + 10 ))
    context_block="$(sed -n "${context_start},${context_end}p" "${wf}")"

    if grep -qiE '(sha256sum|shasum|sha512sum|md5sum|cosign verify|EXPECTED_SHA|CHECKSUM|verify.*hash)' <<<"${context_block}"; then
      : # checksum present in context — ok
    else
      if [[ ${wf_violations} -eq 0 ]]; then
        fail "${wf_name}: unpinned download(s) detected"
      fi
      echo -e "        line ${lineno}: ${line_content}" | sed 's/^[[:space:]]*/        /'
      wf_violations=$(( wf_violations + 1 ))
    fi
  done < <(grep -nE '(curl|wget)[[:space:]]' "${wf}" 2>/dev/null || true)

  if [[ ${wf_violations} -eq 0 ]]; then
    pass "${wf_name}: no unpinned downloads detected"
  fi
done

# ---------------------------------------------------------------------------
# Check: no pipe-to-shell install patterns
# ---------------------------------------------------------------------------
echo
echo -e "${BOLD}--- Pipe-to-shell check ---${NC}"

pipe_to_shell_count=0
while IFS= read -r match; do
  wf_path="${match%%:*}"
  wf_name="$(basename "${wf_path}")"
  rest="${match#*:}"
  lineno="${rest%%:*}"
  line_content="${rest#*:}"
  fail "${wf_name} line ${lineno}: pipe-to-shell: ${line_content}"
  pipe_to_shell_count=$(( pipe_to_shell_count + 1 ))
done < <(grep -rnE '(curl|wget).*\|[[:space:]]*(ba)?sh' "${WORKFLOWS_DIR}" 2>/dev/null || true)

if [[ ${pipe_to_shell_count} -eq 0 ]]; then
  pass "No pipe-to-shell patterns found"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo -e "${BOLD}--- Summary ---${NC}"
echo -e "  Workflow files scanned : ${#workflow_files[@]}"
echo -e "  PASS: ${PASS} | FAIL: ${FAIL} | SKIP: ${SKIP}"
echo

if [[ ${FAIL} -gt 0 ]]; then
  echo -e "${RED}${BOLD}RESULT: FAIL — ${FAIL} check(s) failed${NC}"
  echo -e "  Remediate in the platform-control-plane repository."
  echo -e "  See docs/policies/operations/BINARY_PINNING.md for the pinning process."
  exit 1
else
  echo -e "${GREEN}${BOLD}RESULT: PASS — all checks passed${NC}"
  exit 0
fi
