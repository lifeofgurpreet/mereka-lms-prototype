#!/usr/bin/env bash
# Contract tests for verify-workflow-script-references.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-workflow-script-references.sh"

PASS=0
FAIL=0

run_case() {
  local name="$1"
  local expected_status="$2"
  local expected_marker="$3"
  local setup_fn="$4"
  local cleanup_fn="$5"

  local stdout_file
  local stderr_file
  stdout_file="$(mktemp -t workflow-ref-test.stdout.XXXXXX)"
  stderr_file="$(mktemp -t workflow-ref-test.stderr.XXXXXX)"

  "$setup_fn"

  local status=0
  set +e
  (cd "$REPO_ROOT" && "$VERIFY_SCRIPT" >"$stdout_file" 2>"$stderr_file")
  status=$?
  set -e

  "$cleanup_fn"

  if [[ "$status" -ne "$expected_status" ]]; then
    echo "FAIL: $name expected_status=$expected_status observed=$status"
    echo "stdout:"
    sed 's/^/  /' "$stdout_file" || true
    echo "stderr:"
    sed 's/^/  /' "$stderr_file" || true
    FAIL=$((FAIL + 1))
    rm -f "$stdout_file" "$stderr_file"
    return
  fi

  if [[ -n "$expected_marker" ]]; then
    if ! rg -q --fixed-strings "$expected_marker" "$stdout_file" "$stderr_file"; then
      echo "FAIL: $name missing marker '$expected_marker'"
      echo "stdout:"
      sed 's/^/  /' "$stdout_file" || true
      echo "stderr:"
      sed 's/^/  /' "$stderr_file" || true
      FAIL=$((FAIL + 1))
      rm -f "$stdout_file" "$stderr_file"
      return
    fi
  fi

  echo "PASS: $name"
  PASS=$((PASS + 1))
  rm -f "$stdout_file" "$stderr_file"
}

WF_FILE="$REPO_ROOT/.github/workflows/workflow-ref-test-temp.yml"
TMP_SCRIPT="$REPO_ROOT/scripts/qa/workflow-ref-test-temp.sh"

setup_missing_script() {
  cat >"$WF_FILE" <<'EOF'
name: Temp Workflow Ref Test
on:
  workflow_dispatch:
jobs:
  test:
    runs-on: mereka-k8s-runners
    steps:
      - run: ./scripts/qa/does-not-exist-workflow-ref-test.sh
EOF
}

cleanup_missing_script() {
  rm -f "$WF_FILE"
}

setup_non_executable_script() {
  cat >"$TMP_SCRIPT" <<'EOF'
#!/usr/bin/env bash
echo "tmp"
EOF
  chmod 644 "$TMP_SCRIPT"

  cat >"$WF_FILE" <<'EOF'
name: Temp Workflow Ref Test
on:
  workflow_dispatch:
jobs:
  test:
    runs-on: mereka-k8s-runners
    steps:
      - run: ./scripts/qa/workflow-ref-test-temp.sh
EOF
}

cleanup_non_executable_script() {
  rm -f "$WF_FILE" "$TMP_SCRIPT"
}

run_case \
  "detect-missing-script-reference" \
  1 \
  "references missing script: scripts/qa/does-not-exist-workflow-ref-test.sh" \
  setup_missing_script \
  cleanup_missing_script

run_case \
  "detect-non-executable-script-reference" \
  1 \
  "references non-executable script: scripts/qa/workflow-ref-test-temp.sh" \
  setup_non_executable_script \
  cleanup_non_executable_script

printf 'Result: PASS (%s checks passed), FAIL (%s checks failed)\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
