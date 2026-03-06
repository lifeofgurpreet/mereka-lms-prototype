#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
#
# Enforce quality contract for newly added entries in .github/ci-scripts-static.txt.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

LIST_FILE=".github/ci-scripts-static.txt"
STAGED_ONLY=0
STRICT="${STRICT:-1}"

usage() {
  cat <<'USAGE'
Usage: scripts/qa/verify-new-ci-static-entries.sh [--staged-only]

Options:
  --staged-only   Inspect newly added static-list entries in staged index only.

Environment:
  STRICT=1        Fail on violations (default).
  STRICT=0        Warn-only mode.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged-only)
      STAGED_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$STRICT" in
  0|1) ;;
  *)
    echo "Invalid STRICT='$STRICT' (expected 0 or 1)" >&2
    exit 2
    ;;
esac

PASS=0
FAIL=0
WARN=0

do_pass() { echo "PASS $1"; PASS=$((PASS + 1)); }
do_fail() { echo "FAIL $1"; FAIL=$((FAIL + 1)); }
do_warn() { echo "WARN $1"; WARN=$((WARN + 1)); }

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

find_diff_range() {
  local base_ref="${GITHUB_BASE_REF:-main}"
  local merge_base=""

  if git rev-parse --verify -q "refs/remotes/origin/$base_ref" >/dev/null 2>&1; then
    merge_base="$(git merge-base HEAD "refs/remotes/origin/$base_ref" 2>/dev/null || true)"
    if [[ -n "$merge_base" ]]; then
      printf '%s..HEAD\n' "$merge_base"
      return 0
    fi
  fi

  git fetch --no-tags --depth=200 origin "$base_ref:refs/remotes/origin/$base_ref" >/dev/null 2>&1 || true
  if git rev-parse --verify -q "refs/remotes/origin/$base_ref" >/dev/null 2>&1; then
    merge_base="$(git merge-base HEAD "refs/remotes/origin/$base_ref" 2>/dev/null || true)"
    if [[ -n "$merge_base" ]]; then
      printf '%s..HEAD\n' "$merge_base"
      return 0
    fi
  fi

  if git rev-parse --verify -q HEAD^ >/dev/null 2>&1; then
    printf 'HEAD^..HEAD\n'
    return 0
  fi

  return 1
}

collect_added_entries() {
  if [[ "$STAGED_ONLY" -eq 1 ]]; then
    git diff --cached -U0 -- "$LIST_FILE" \
      | awk '/^\+[^+]/ { print substr($0,2) }'
    return
  fi

  local diff_range
  if ! diff_range="$(find_diff_range)"; then
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      do_fail "could not determine git diff range for static-list entry contract check"
      return
    fi
    do_warn "could not determine git diff range; skipping new static-entry checks"
    return
  fi

  git diff -U0 "$diff_range" -- "$LIST_FILE" \
    | awk '/^\+[^+]/ { print substr($0,2) }'
}

validate_verify_script_contract() {
  local path="$1"

  if [[ "$(head -n 1 "$path")" == "#!/usr/bin/env bash" ]]; then
    do_pass "$path: bash shebang"
  else
    do_fail "$path: first line must be '#!/usr/bin/env bash'"
  fi

  if grep -Eq '^[[:space:]]*set -euo pipefail[[:space:]]*$' "$path"; then
    do_pass "$path: strict mode set -euo pipefail"
  else
    do_fail "$path: missing strict mode set -euo pipefail"
  fi

  if grep -Eq '^[[:space:]]*# @covers[[:space:]]+AC-[A-Z0-9-]+' "$path"; then
    do_pass "$path: @covers annotation"
  else
    do_fail "$path: missing @covers annotation"
  fi

  if grep -Eq '^[[:space:]]*# @spec:[[:space:]]+.+_spec\.md' "$path"; then
    do_pass "$path: @spec annotation"
  else
    do_fail "$path: missing @spec annotation"
  fi
}

if [[ ! -f "$LIST_FILE" ]]; then
  do_fail "$LIST_FILE not found"
  echo "Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN"
  exit 1
fi

mapfile -t raw_added < <(collect_added_entries || true)
added_paths=()
for line in "${raw_added[@]}"; do
  clean="${line%% #*}"
  clean="$(trim "$clean")"
  [[ -z "$clean" ]] && continue
  [[ "$clean" == \#* ]] && continue
  path="$(awk '{print $1}' <<<"$clean")"
  [[ -z "$path" ]] && continue
  added_paths+=("$path")
done

if [[ "${#added_paths[@]}" -eq 0 ]]; then
  do_pass "no newly added ci static-list entries detected"
  echo "Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN"
  exit 0
fi

for path in "${added_paths[@]}"; do
  if [[ ! -f "$path" ]]; then
    do_fail "$path: added static-list entry target file missing"
    continue
  fi
  do_pass "$path: target file exists"

  if [[ "$path" == scripts/qa/deprecated/* ]]; then
    do_fail "$path: deprecated verify script must not be added to ci static list"
    continue
  fi

  if [[ "$path" == *.sh ]]; then
    if [[ -x "$path" ]]; then
      do_pass "$path: executable mode"
    else
      do_fail "$path: must be executable"
    fi
    if bash -n "$path"; then
      do_pass "$path: shell syntax"
    else
      do_fail "$path: shell syntax invalid"
    fi
  fi

  if [[ "$path" == scripts/*/verify-*.sh ]]; then
    validate_verify_script_contract "$path"
  fi
done

echo "Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN"
if [[ "$FAIL" -gt 0 ]]; then
  if [[ "$STRICT" -eq 1 ]]; then
    exit 1
  fi
  do_warn "violations detected but STRICT=0"
fi
