#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_UNDER_TEST="${REPO_ROOT}/scripts/runner/buildx-cleanup.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_BIN="${TMP_DIR}/bin"
STATE_DIR="${TMP_DIR}/state"
mkdir -p "${FAKE_BIN}" "${STATE_DIR}"

cat >"${FAKE_BIN}/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${FAKE_DOCKER_LOG:?}"
STATE_DIR="${FAKE_STATE_DIR:?}"

printf 'docker %s\n' "$*" >>"${LOG_FILE}"

case "$*" in
  info)
    exit 0
    ;;
  "buildx ls --format {{.Name}}")
    printf 'default\noldbuilder\n'
    exit 0
    ;;
  "inspect --format {{.Created}} buildx_buildkit_oldbuilder")
    printf '2020-01-01T00:00:00Z\n'
    exit 0
    ;;
  "inspect --format {{.Created}} buildx_buildkit_default")
    printf '2020-01-01T00:00:00Z\n'
    exit 0
    ;;
  "inspect --format {{.State.Status}} buildx_buildkit_oldbuilder")
    printf 'running\n'
    exit 0
    ;;
  "buildx rm oldbuilder")
    printf 'removed\n' >"${STATE_DIR}/removed-oldbuilder"
    exit 0
    ;;
esac

if [[ "$1" == "ps" ]]; then
  printf 'buildx_buildkit_default\nbuildx_buildkit_oldbuilder\n'
  exit 0
fi

if [[ "$1" == "rm" ]]; then
  printf 'removed-container\n' >"${STATE_DIR}/removed-container"
  exit 0
fi

printf 'unexpected docker invocation: %s\n' "$*" >&2
exit 1
SH
chmod +x "${FAKE_BIN}/docker"

cat >"${FAKE_BIN}/pgrep" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${FAKE_ACTIVE_BUILD:-0}" == "1" ]]; then
  printf '12345 docker buildx build --builder oldbuilder .\n'
  exit 0
fi

exit 1
SH
chmod +x "${FAKE_BIN}/pgrep"

run_cleanup() {
  local active="$1"
  local log_file="$2"
  rm -f "${STATE_DIR}/removed-oldbuilder" "${STATE_DIR}/removed-container" "${log_file}"
  FAKE_ACTIVE_BUILD="${active}" \
    FAKE_DOCKER_LOG="${log_file}" \
    FAKE_STATE_DIR="${STATE_DIR}" \
    PATH="${FAKE_BIN}:${PATH}" \
    MAX_AGE_HOURS=0 \
    "${SCRIPT_UNDER_TEST}" --max-keep 0
}

active_log="${TMP_DIR}/active.log"
run_cleanup 1 "${active_log}" >"${TMP_DIR}/active.out"

if [[ -e "${STATE_DIR}/removed-oldbuilder" || -e "${STATE_DIR}/removed-container" ]]; then
  echo "FAIL: active build cleanup removed a builder/container" >&2
  exit 1
fi

if ! grep -q 'Active Docker/Buildx build process detected' "${TMP_DIR}/active.out"; then
  echo "FAIL: active build cleanup did not report active-build deferral" >&2
  exit 1
fi

inactive_log="${TMP_DIR}/inactive.log"
run_cleanup 0 "${inactive_log}" >"${TMP_DIR}/inactive.out"

if [[ ! -e "${STATE_DIR}/removed-oldbuilder" ]]; then
  echo "FAIL: inactive cleanup did not remove stale builder" >&2
  exit 1
fi

if grep -q 'Active Docker/Buildx build process detected' "${TMP_DIR}/inactive.out"; then
  echo "FAIL: inactive cleanup incorrectly reported active-build deferral" >&2
  exit 1
fi

echo "PASS: buildx-cleanup defers destructive cleanup while builds are active"
