#!/usr/bin/env bash
# Usage: .github/run-scripts-parallel.sh <script-list-file> [parallelism] [timeout-seconds]
#
# Reads one script path per line from the list file (# comments and blank lines ignored).
# Scripts may include flags after the path (e.g. "scripts/qa/foo.sh --skip-infra").
# Runs them in parallel via xargs -P, collects PASS/FAIL/TIMEOUT/SKIP results,
# prints per-script logs on failure, and exits non-zero if any script fails or times out.

set -uo pipefail

SCRIPT_LIST="${1:?Usage: run-scripts-parallel.sh <list-file> [parallelism] [timeout-seconds]}"
PARALLELISM="${2:-4}"
TIMEOUT_SECS="${3:-120}"
RESULTS_DIR="var/ci-results"

mkdir -p "$RESULTS_DIR"
> "${RESULTS_DIR}/summary.txt"

# ── per-script runner (called by xargs -P) ─────────────────────────────────
run_one() {
  local entry="$1"
  # Strip inline comments
  local entry_clean="${entry%% #*}"
  entry_clean="${entry_clean## }"
  entry_clean="${entry_clean%% }"
  [[ -z "$entry_clean" ]] && return 0

  # Split into script path + optional flags
  local script_path
  script_path=$(awk '{print $1}' <<< "$entry_clean")
  local extra_args
  extra_args=$(awk '{$1=""; print substr($0,2)}' <<< "$entry_clean")

  local name
  name=$(basename "$script_path" .sh)
  local logfile="${RESULTS_DIR}/${name}.log"

  if [[ ! -f "$script_path" ]]; then
    echo "FAIL ${name} (file not found)"
    return 0
  fi

  # shellcheck disable=SC2086
  if timeout "$TIMEOUT_SECS" bash "$script_path" $extra_args > "$logfile" 2>&1; then
    echo "PASS ${name}"
  else
    local rc=$?
    if [[ $rc -eq 124 ]]; then
      echo "TIMEOUT ${name}"
    else
      echo "FAIL ${name} (exit ${rc})"
    fi
  fi
}
export -f run_one
export RESULTS_DIR TIMEOUT_SECS

# ── filter list, run in parallel, tee summary ──────────────────────────────
grep -v '^\s*$' "$SCRIPT_LIST" | grep -v '^\s*#' | \
  xargs -P"$PARALLELISM" -I{} bash -c 'run_one "$@"' _ {} | \
  tee "${RESULTS_DIR}/summary.txt"

# ── aggregate counts ────────────────────────────────────────────────────────
PASS=$(grep -c "^PASS"    "${RESULTS_DIR}/summary.txt" || true)
FAIL=$(grep -c "^FAIL"    "${RESULTS_DIR}/summary.txt" || true)
TIMEOUTS=$(grep -c "^TIMEOUT" "${RESULTS_DIR}/summary.txt" || true)
SKIPS=$(grep -c "^SKIP"   "${RESULTS_DIR}/summary.txt" || true)
TOTAL=$((PASS + FAIL + TIMEOUTS + SKIPS))

echo ""
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed, ${TIMEOUTS} timed out, ${SKIPS} skipped ==="

if [[ $FAIL -gt 0 || $TIMEOUTS -gt 0 ]]; then
  echo ""
  echo "::error::${FAIL} script(s) failed, ${TIMEOUTS} timed out"
  grep "^FAIL\|^TIMEOUT" "${RESULTS_DIR}/summary.txt" | while IFS= read -r line; do
    name=$(awk '{print $2}' <<< "$line")
    echo "--- ${name} ---"
    tail -20 "${RESULTS_DIR}/${name}.log" 2>/dev/null || echo "(no log)"
  done
  exit 1
fi
