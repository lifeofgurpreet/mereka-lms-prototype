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

case "${FAKE_ACTIVE_BUILD_KIND:-none}" in
  docker-buildx-build)
    printf '12345 docker buildx build --builder oldbuilder .\n'
    exit 0
    ;;
  docker-buildx-bake)
    printf '12346 docker buildx bake --file docker-bake.hcl openedx-fast\n'
    exit 0
    ;;
  docker-build)
    printf '12347 docker build --tag local/test .\n'
    exit 0
    ;;
  docker-pull)
    printf '12348 docker pull mirror.gcr.io/overhangio/openedx:21.0.4\n'
    exit 0
    ;;
  buildctl-build)
    printf '12349 buildctl build --frontend dockerfile.v0 --local context=.\n'
    exit 0
    ;;
  absolute-docker-buildx-bake)
    printf '12351 /usr/bin/docker buildx bake --file docker-bake.hcl mfe-fast\n'
    exit 0
    ;;
  absolute-buildctl-build)
    printf '12352 /usr/local/bin/buildctl build --frontend dockerfile.v0\n'
    exit 0
    ;;
  unrelated)
    printf '12350 docker ps -a\n'
    exit 0
    ;;
  none)
    exit 1
    ;;
  *)
    printf 'unexpected FAKE_ACTIVE_BUILD_KIND=%s\n' "${FAKE_ACTIVE_BUILD_KIND}" >&2
    exit 2
    ;;
esac

exit 1
SH
chmod +x "${FAKE_BIN}/pgrep"

run_cleanup() {
  local active_kind="$1"
  local log_file="$2"
  rm -f "${STATE_DIR}/removed-oldbuilder" "${STATE_DIR}/removed-container" "${log_file}"
  FAKE_ACTIVE_BUILD_KIND="${active_kind}" \
    FAKE_DOCKER_LOG="${log_file}" \
    FAKE_STATE_DIR="${STATE_DIR}" \
    PATH="${FAKE_BIN}:${PATH}" \
    MAX_AGE_HOURS=0 \
    "${SCRIPT_UNDER_TEST}" --max-keep 0
}

for active_kind in \
  docker-buildx-build \
  docker-buildx-bake \
  docker-build \
  docker-pull \
  buildctl-build \
  absolute-docker-buildx-bake \
  absolute-buildctl-build; do
  active_log="${TMP_DIR}/${active_kind}.log"
  active_out="${TMP_DIR}/${active_kind}.out"
  run_cleanup "${active_kind}" "${active_log}" >"${active_out}"

  if [[ -e "${STATE_DIR}/removed-oldbuilder" || -e "${STATE_DIR}/removed-container" ]]; then
    echo "FAIL: ${active_kind} cleanup removed a builder/container" >&2
    exit 1
  fi

  if ! grep -q 'Active Docker/BuildKit substrate process detected' "${active_out}"; then
    echo "FAIL: ${active_kind} cleanup did not report active-substrate deferral" >&2
    exit 1
  fi
done

inactive_log="${TMP_DIR}/inactive.log"
run_cleanup none "${inactive_log}" >"${TMP_DIR}/inactive.out"

if [[ ! -e "${STATE_DIR}/removed-oldbuilder" ]]; then
  echo "FAIL: inactive cleanup did not remove stale builder" >&2
  exit 1
fi

if grep -q 'Active Docker/BuildKit substrate process detected' "${TMP_DIR}/inactive.out"; then
  echo "FAIL: inactive cleanup incorrectly reported active-build deferral" >&2
  exit 1
fi

unrelated_log="${TMP_DIR}/unrelated.log"
run_cleanup unrelated "${unrelated_log}" >"${TMP_DIR}/unrelated.out"

if grep -q 'Active Docker/BuildKit substrate process detected' "${TMP_DIR}/unrelated.out"; then
  echo "FAIL: unrelated docker commands incorrectly reported active-build deferral" >&2
  exit 1
fi

echo "PASS: buildx-cleanup defers destructive cleanup while Docker/BuildKit substrate work is active"
