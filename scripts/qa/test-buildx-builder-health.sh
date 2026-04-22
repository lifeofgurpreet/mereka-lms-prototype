#!/usr/bin/env bash
# Fixture tests for local Buildx builder health guards.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HEALTH="$REPO_ROOT/scripts/infra/buildx-builder-health.sh"
TMP_DIR="$(mktemp -d -t buildx-builder-health-test.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

pass() { echo "PASS $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL $1" >&2; FAIL=$((FAIL + 1)); }

# shellcheck source=scripts/infra/buildx-builder-health.sh
source "$HEALTH"

idle_snapshot="$TMP_DIR/idle.txt"
cat >"$idle_snapshot" <<'EOF'
PID PPID COMMAND COMMAND
1 0 buildkitd buildkitd --addr unix:///run/buildkit/buildkitd.sock
EOF

stale_snapshot="$TMP_DIR/stale.txt"
cat >"$stale_snapshot" <<'EOF'
PID PPID COMMAND COMMAND
1 0 buildkitd buildkitd --addr unix:///run/buildkit/buildkitd.sock
92 1 npm npm install --legacy-peer-deps @edx/brand@file:./brand-mereka
104 92 sh sh -c node ./scripts/build.js
EOF

idle_out="$TMP_DIR/idle.out"
stale_out="$TMP_DIR/stale.out"

if ! printf '%s\n' "$(cat "$idle_snapshot")" | mereka_buildx_stale_executor_processes >"$idle_out"; then
  pass "idle BuildKit process snapshot is healthy"
else
  cat "$idle_out" >&2 || true
  fail "idle BuildKit process snapshot is healthy"
fi

if printf '%s\n' "$(cat "$stale_snapshot")" | mereka_buildx_stale_executor_processes >"$stale_out" \
  && grep -q 'npm install' "$stale_out" \
  && grep -q 'sh -c node' "$stale_out"; then
  pass "stale npm/sh executor processes are detected"
else
  cat "$stale_out" >&2 || true
  fail "stale npm/sh executor processes are detected"
fi

active_file="$TMP_DIR/active.txt"
cat >"$active_file" <<'EOF'
12345 docker buildx bake --file docker-bake.hcl mfe-fast
EOF
idle_active_file="$TMP_DIR/no-active.txt"
: >"$idle_active_file"

fake_bin="$TMP_DIR/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/docker" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "${FAKE_DOCKER_LOG:?}"
exit 0
SH
chmod +x "$fake_bin/docker"

set +e
PATH="$fake_bin:$PATH" \
FAKE_DOCKER_LOG="$TMP_DIR/docker-active.log" \
MEREKA_BUILDX_ACTIVE_PROCESSES_FILE="$active_file" \
  bash -c "source '$HEALTH'; mga_builder=mereka-dependency-mirror; mga_reason='test active guard'; mga_result=0; mga_output=\$(mereka_buildx_remove_builder_safely \"\$mga_builder\" \"\$mga_reason\" 2>&1) || mga_result=\$?; printf '%s\n' \"\$mga_output\"; exit \"\$mga_result\"" \
  >"$TMP_DIR/active.out" 2>"$TMP_DIR/active.err"
active_rc=$?
set -e

if [[ "$active_rc" -ne 0 ]] \
  && grep -q "Refusing to mutate Buildx builder 'mereka-dependency-mirror'" "$TMP_DIR/active.out" \
  && [[ ! -s "$TMP_DIR/docker-active.log" ]]; then
  pass "builder removal refuses while active build processes exist"
else
  cat "$TMP_DIR/active.out" >&2 || true
  cat "$TMP_DIR/active.err" >&2 || true
  fail "builder removal refuses while active build processes exist"
fi

PATH="$fake_bin:$PATH" \
FAKE_DOCKER_LOG="$TMP_DIR/docker-idle.log" \
MEREKA_BUILDX_ACTIVE_PROCESSES_FILE="$idle_active_file" \
  bash -c "source '$HEALTH'; mga_builder=mereka-dependency-mirror; mga_reason='test idle remove'; mga_result=0; mga_output=\$(mereka_buildx_remove_builder_safely \"\$mga_builder\" \"\$mga_reason\" 2>&1) || mga_result=\$?; printf '%s\n' \"\$mga_output\"; exit \"\$mga_result\""

if grep -q '^buildx rm mereka-dependency-mirror$' "$TMP_DIR/docker-idle.log"; then
  pass "idle builder removal invokes docker buildx rm"
else
  cat "$TMP_DIR/docker-idle.log" >&2 || true
  fail "idle builder removal invokes docker buildx rm"
fi

reason="$(
  MEREKA_BUILDX_BUILDER_CONTAINER_NAME=buildx_buildkit_mereka-dependency-mirror0 \
  MEREKA_BUILDX_PROCESS_SNAPSHOT_FILE="$stale_snapshot" \
    bash -c "source '$HEALTH'; mga_buildx_unhealthy_reason=\$(mereka_buildx_unhealthy_reason 'mereka-dependency-mirror'); printf '%s\n' \"\$mga_buildx_unhealthy_reason\""
)"

if grep -q "buildx_buildkit_mereka-dependency-mirror0" <<<"$reason" \
  && grep -q "npm install" <<<"$reason"; then
  pass "unhealthy reason names builder container and stale process"
else
  printf '%s\n' "$reason" >&2
  fail "unhealthy reason names builder container and stale process"
fi

echo "Summary: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
