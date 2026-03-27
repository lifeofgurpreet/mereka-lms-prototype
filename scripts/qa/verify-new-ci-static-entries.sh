#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
#
# Enforce quality contract for newly added static CI inventory entries.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

REGISTRY_FILE="scripts/governance/script-registry.yaml"
STAGED_ONLY=0
STRICT="${STRICT:-1}"

usage() {
  cat <<'USAGE'
Usage: scripts/qa/verify-new-ci-static-entries.sh [--staged-only]

Options:
  --staged-only   Inspect newly added static-inventory entries in staged index only.

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

find_base_commit() {
  local base_ref="${GITHUB_BASE_REF:-main}"
  local merge_base=""

  if git rev-parse --verify -q "refs/remotes/origin/$base_ref" >/dev/null 2>&1; then
    merge_base="$(git merge-base HEAD "refs/remotes/origin/$base_ref" 2>/dev/null || true)"
    if [[ -n "$merge_base" ]]; then
      printf '%s\n' "$merge_base"
      return 0
    fi
  fi

  git fetch --no-tags --depth=200 origin "$base_ref:refs/remotes/origin/$base_ref" >/dev/null 2>&1 || true
  if git rev-parse --verify -q "refs/remotes/origin/$base_ref" >/dev/null 2>&1; then
    merge_base="$(git merge-base HEAD "refs/remotes/origin/$base_ref" 2>/dev/null || true)"
    if [[ -n "$merge_base" ]]; then
      printf '%s\n' "$merge_base"
      return 0
    fi
  fi

  if git rev-parse --verify -q HEAD^ >/dev/null 2>&1; then
    printf 'HEAD^\n'
    return 0
  fi

  return 1
}

collect_added_entries() {
  if ! command -v python3 >/dev/null 2>&1; then
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      do_fail "python3 required for static-inventory entry contract check"
    else
      do_warn "python3 not available; skipping new static-entry checks"
    fi
    return
  fi

  if [[ "$STAGED_ONLY" -eq 1 ]]; then
    local head_spec=""
    if git rev-parse --verify -q HEAD >/dev/null 2>&1; then
      head_spec="HEAD:$REGISTRY_FILE"
    fi

    BASE_SPEC="$head_spec" CURRENT_SPEC=":$REGISTRY_FILE" python3 - <<'PY'
import os
import subprocess
import sys

try:
    import yaml
except ImportError as exc:
    raise SystemExit(f"PyYAML required for {os.environ['CURRENT_SPEC']}: {exc}")


def read_blob(spec: str) -> str:
    if not spec:
        return ""
    proc = subprocess.run(
        ["git", "show", spec],
        check=False,
        capture_output=True,
        text=True,
    )
    return proc.stdout if proc.returncode == 0 else ""


def read_entries(raw: str) -> set[str]:
    if not raw.strip():
        return set()
    payload = yaml.safe_load(raw) or {}
    inventory = payload.get("ci_static_inventory") or {}
    entries = inventory.get("entries") or []
    result: set[str] = set()
    for item in entries:
        if not isinstance(item, dict):
            continue
        script = item.get("script")
        if isinstance(script, str) and script.strip():
            result.add(script.strip())
    return result


base_entries = read_entries(read_blob(os.environ.get("BASE_SPEC", "")))
current_entries = read_entries(read_blob(os.environ["CURRENT_SPEC"]))
for script in sorted(current_entries - base_entries):
    print(script)
PY
    return
  fi

  local base_commit
  if ! base_commit="$(find_base_commit)"; then
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      do_fail "could not determine git base for static-inventory entry contract check"
      return
    fi
    do_warn "could not determine git base; skipping new static-entry checks"
    return
  fi

  BASE_SPEC="$base_commit:$REGISTRY_FILE" CURRENT_FILE="$REGISTRY_FILE" python3 - <<'PY'
import os
import subprocess
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit(f"PyYAML required for {os.environ['CURRENT_FILE']}: {exc}")


def read_entries(raw: str) -> set[str]:
    if not raw.strip():
        return set()
    payload = yaml.safe_load(raw) or {}
    inventory = payload.get("ci_static_inventory") or {}
    entries = inventory.get("entries") or []
    result: set[str] = set()
    for item in entries:
        if not isinstance(item, dict):
            continue
        script = item.get("script")
        if isinstance(script, str) and script.strip():
            result.add(script.strip())
    return result


current_path = Path(os.environ["CURRENT_FILE"])
proc = subprocess.run(
    ["git", "show", os.environ["BASE_SPEC"]],
    check=False,
    capture_output=True,
    text=True,
)
base_raw = proc.stdout if proc.returncode == 0 else ""
current_raw = current_path.read_text(encoding="utf-8")

base_entries = read_entries(base_raw)
current_entries = read_entries(current_raw)
for script in sorted(current_entries - base_entries):
    print(script)
PY
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

if [[ ! -f "$REGISTRY_FILE" ]]; then
  do_fail "$REGISTRY_FILE not found"
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
  do_pass "no newly added static-inventory entries detected"
  echo "Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN"
  exit 0
fi

for path in "${added_paths[@]}"; do
  if [[ ! -f "$path" ]]; then
    do_fail "$path: added static-inventory entry target file missing"
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
