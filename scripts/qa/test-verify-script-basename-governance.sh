#!/usr/bin/env bash
# Seeded-defect tests for verify-script-basename-governance.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-script-basename-governance.sh"
SCOPE_MODE="${TEST_VERIFY_SCRIPT_BASENAME_GOVERNANCE_SCOPE:-}"
CHANGED_FILES_RAW="${TEST_VERIFY_SCRIPT_BASENAME_GOVERNANCE_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  local path

  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      .github/workflows/ci.yml|\
      scripts/qa/test-verify-script-basename-governance.sh|\
      scripts/qa/verify-script-basename-governance.sh|\
      scripts/qa/duplicate-script-basenames.allowlist|\
      scripts/*)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS test-verify-script-basename-governance (scope skip: no script-basename-governance-relevant changes)"
  exit 0
fi

PASS=0
FAIL=0

run_case() {
  local name="$1"
  local expected_status="$2"
  local expected_marker="$3"
  local setup_fn="$4"
  local cleanup_fn="$5"

  local stdout_file
  stdout_file="$(mktemp -t script-basename-test.stdout.XXXXXX)"

  "$setup_fn"

  local status=0
  set +e
  (cd "$REPO_ROOT" && "$VERIFY_SCRIPT" >"$stdout_file" 2>&1)
  status=$?
  set -e

  "$cleanup_fn"

  if [[ "$status" -ne "$expected_status" ]]; then
    echo "FAIL: $name expected_status=$expected_status observed=$status"
    sed 's/^/  /' "$stdout_file" || true
    FAIL=$((FAIL + 1))
    rm -f "$stdout_file"
    return
  fi

  if [[ -n "$expected_marker" ]]; then
    if ! rg -q --fixed-strings "$expected_marker" "$stdout_file"; then
      echo "FAIL: $name missing marker '$expected_marker'"
      sed 's/^/  /' "$stdout_file" || true
      FAIL=$((FAIL + 1))
      rm -f "$stdout_file"
      return
    fi
  fi

  echo "PASS: $name"
  PASS=$((PASS + 1))
  rm -f "$stdout_file"
}

TMP_DIR="$REPO_ROOT/scripts/qa/tmp-basename-governance"
TMP_FILE="$TMP_DIR/verify-repo-structure.sh"

setup_unknown_duplicate() {
  mkdir -p "$TMP_DIR"
  cat >"$TMP_FILE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "temp duplicate"
EOF
  chmod +x "$TMP_FILE"
}

cleanup_unknown_duplicate() {
  rm -f "$TMP_FILE"
  rmdir "$TMP_DIR" 2>/dev/null || true
}

setup_none() { :; }
cleanup_none() { :; }

run_case \
  "baseline-allowlisted-duplicates-pass" \
  0 \
  "Summary: PASS=" \
  setup_none \
  cleanup_none

run_case \
  "detect-unallowlisted-duplicate-basename" \
  1 \
  "duplicate executable basename not allowlisted: verify-repo-structure.sh" \
  setup_unknown_duplicate \
  cleanup_unknown_duplicate

printf 'Result: PASS (%s checks passed), FAIL (%s checks failed)\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
