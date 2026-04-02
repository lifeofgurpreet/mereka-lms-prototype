#!/usr/bin/env bash
# verify-ci-execution-contract.sh
#
# CI-safe read-only verifier. Checks that the CI execution contract is intact:
#   1. ci-scripts-static.txt exists and has >100 entries
#   2. Every script listed in ci-scripts-static.txt exists on disk
#   3. Every script listed is executable
#   4. setup-python-env composite action exists
#   5. ci.yml exists
#   6. kubeconform exclusion patterns cover expected data paths
#   7. kubeconform schema cache + retry hardening is present
#   8. Python lzma fallback is present in the shellcheck install step
#   9. lsb_release stub step is present in setup-python-env
#
# Usage:
#   scripts/qa/verify-ci-execution-contract.sh
#
# Exit codes: 0 = all checks pass, 1 = one or more checks failed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SCRIPTS_LIST="${REPO_ROOT}/.github/ci-scripts-static.txt"
CI_YML="${REPO_ROOT}/.github/workflows/ci.yml"
SETUP_ACTION="${REPO_ROOT}/.github/actions/setup-python-env/action.yml"

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}PASS${RESET} $*"; (( PASS++ )) || true; }
fail() { echo -e "${RED}FAIL${RESET} $*"; (( FAIL++ )) || true; }

# ── Check 1: ci-scripts-static.txt exists ────────────────────────────────────
if [[ -f "${SCRIPTS_LIST}" ]]; then
  pass "ci-scripts-static.txt exists"
else
  fail "ci-scripts-static.txt not found at ${SCRIPTS_LIST}"
fi

# ── Check 2: ci-scripts-static.txt has >100 entries ──────────────────────────
if [[ -f "${SCRIPTS_LIST}" ]]; then
  # Count non-blank, non-comment lines
  entry_count=$(grep -c -E '^[^#[:space:]]' "${SCRIPTS_LIST}" 2>/dev/null || true)
  if (( entry_count > 100 )); then
    pass "ci-scripts-static.txt has ${entry_count} entries (>100)"
  else
    fail "ci-scripts-static.txt has only ${entry_count} entries (expected >100)"
  fi
fi

# ── Checks 3 & 4: each listed script exists and is executable ────────────────
missing_scripts=0
non_exec_scripts=0

if [[ -f "${SCRIPTS_LIST}" ]]; then
  while IFS= read -r line; do
    # Skip blank lines and comments
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
    # Strip inline flags (e.g. "scripts/qa/foo.sh --skip-infra" → "scripts/qa/foo.sh")
    script_path="${line%% *}"
    full_path="${REPO_ROOT}/${script_path}"

    if [[ ! -f "${full_path}" ]]; then
      fail "Listed script not found on disk: ${script_path}"
      (( missing_scripts++ )) || true
    elif [[ ! -x "${full_path}" ]]; then
      fail "Listed script not executable: ${script_path}"
      (( non_exec_scripts++ )) || true
    fi
  done < "${SCRIPTS_LIST}"

  if (( missing_scripts == 0 )); then
    pass "All listed scripts exist on disk"
  fi
  if (( non_exec_scripts == 0 )); then
    pass "All listed scripts are executable"
  fi
fi

# ── Check 5: setup-python-env composite action exists ────────────────────────
if [[ -f "${SETUP_ACTION}" ]]; then
  pass "setup-python-env action.yml exists"
else
  fail "setup-python-env action.yml not found at ${SETUP_ACTION}"
fi

# ── Check 6: ci.yml exists ───────────────────────────────────────────────────
if [[ -f "${CI_YML}" ]]; then
  pass "ci.yml exists"
else
  fail "ci.yml not found at ${CI_YML}"
fi

# ── Check 7: kubeconform exclusion patterns ───────────────────────────────────
if [[ -f "${CI_YML}" ]]; then
  required_exclusions=(
    "patches/"
    "config/"
    "settings/"
    "helm-values"
    "registry"
    "SECRET_CLASSIFICATION"
  )
  all_exclusions_present=true
  for pattern in "${required_exclusions[@]}"; do
    if grep -qF "${pattern}" "${CI_YML}"; then
      pass "kubeconform exclusion present: ${pattern}"
    else
      fail "kubeconform exclusion missing in ci.yml: ${pattern}"
      all_exclusions_present=false
    fi
  done
fi

# ── Check 8: Python lzma fallback in shellcheck install step ─────────────────
if [[ -f "${CI_YML}" ]]; then
  if grep -q "kubeconform-schemas" "${CI_YML}" && grep -q "error while downloading schema" "${CI_YML}"; then
    pass "kubeconform schema cache + transient download retry present in ci.yml"
  else
    fail "kubeconform schema cache/retry hardening missing in ci.yml"
  fi
fi

# ── Check 9: Python lzma fallback in shellcheck install step ─────────────────
if [[ -f "${CI_YML}" ]]; then
  if grep -q "import lzma" "${CI_YML}"; then
    pass "Python lzma fallback present in ci.yml (shellcheck install)"
  else
    fail "Python lzma fallback not found in ci.yml — shellcheck install will fail on ARC runners without xz"
  fi
fi

# ── Check 10: lsb_release stub in setup-python-env ───────────────────────────
if [[ -f "${SETUP_ACTION}" ]]; then
  if grep -q "lsb_release" "${SETUP_ACTION}"; then
    pass "lsb_release stub step present in setup-python-env action.yml"
  else
    fail "lsb_release stub not found in setup-python-env action.yml — ARC runners will fail pip cache key generation"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if (( FAIL > 0 )); then
  echo -e "${RED}CI execution contract verification FAILED${RESET}"
  exit 1
fi

echo -e "${GREEN}CI execution contract verification PASSED${RESET}"
exit 0
