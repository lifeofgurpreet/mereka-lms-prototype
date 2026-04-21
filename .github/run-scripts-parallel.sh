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
ENTRIES_FILE="${RESULTS_DIR}/entries.tsv"

mkdir -p "$RESULTS_DIR"
> "${RESULTS_DIR}/summary.txt"

# ── per-script runner (called by xargs -P) ─────────────────────────────────
run_one() {
  local numbered_entry="$1"
  local index="?"
  local entry="$numbered_entry"
  if [[ "$numbered_entry" == *$'\t'* ]]; then
    index="${numbered_entry%%$'\t'*}"
    entry="${numbered_entry#*$'\t'}"
  fi

  local script_timeout="$TIMEOUT_SECS"
  if [[ "$entry" =~ (^|[[:space:]])#[[:space:]]*timeout=([0-9]+)($|[[:space:]]) ]]; then
    script_timeout="${BASH_REMATCH[2]}"
  fi

  # Strip inline comments after reading supported runner metadata.
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
  local total="${TOTAL_SCRIPTS:-?}"
  local started_at=$SECONDS

  if [[ ! -f "$script_path" ]]; then
    echo "FAIL ${name} [${index}/${total}] (file not found)"
    return 0
  fi

  echo "START ${name} [${index}/${total}] (timeout ${script_timeout}s)"

  # shellcheck disable=SC2086
  if timeout "$script_timeout" bash "$script_path" $extra_args > "$logfile" 2>&1; then
    echo "PASS ${name} [${index}/${total}] (${SECONDS-started_at}s)"
  else
    local rc=$?
    if [[ $rc -eq 124 ]]; then
      echo "TIMEOUT ${name} [${index}/${total}] (${SECONDS-started_at}s)"
    else
      echo "FAIL ${name} [${index}/${total}] (exit ${rc}, ${SECONDS-started_at}s)"
    fi
  fi
}
export -f run_one
export RESULTS_DIR TIMEOUT_SECS

# ── filter list, run in parallel, tee summary ──────────────────────────────
grep -v '^\s*$' "$SCRIPT_LIST" | grep -v '^\s*#' | nl -ba -w1 -s $'\t' > "$ENTRIES_FILE"
TOTAL_SCRIPTS=$(wc -l < "$ENTRIES_FILE" | tr -d ' ')
export TOTAL_SCRIPTS

echo "Running ${TOTAL_SCRIPTS} scripts with parallelism ${PARALLELISM} and timeout ${TIMEOUT_SECS}s"

if [[ "$TOTAL_SCRIPTS" -gt 0 ]]; then
  xargs -d '\n' -P"$PARALLELISM" -I{} bash -c 'run_one "$@"' _ {} < "$ENTRIES_FILE" | \
    tee "${RESULTS_DIR}/summary.txt"
fi

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
