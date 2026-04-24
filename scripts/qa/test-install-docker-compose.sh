#!/usr/bin/env bash
# test-install-docker-compose.sh - fixture tests for Docker Compose installer.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALLER="$REPO_ROOT/scripts/ci/install-docker-compose.sh"
TMP_DIR="$(mktemp -d -t install-docker-compose-test.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

pass() { echo "PASS $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL $1" >&2; FAIL=$((FAIL + 1)); }

make_fake_docker() {
  local bin_dir="$1"
  cat >"$bin_dir/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "compose" && "${2:-}" == "version" ]]; then
  plugin="${DOCKER_COMPOSE_PLUGIN_DIR:-${DOCKER_CONFIG:-$HOME/.docker}/cli-plugins}/docker-compose"
  if [[ -x "$plugin" ]]; then
    "$plugin" version
    exit 0
  fi
  exit 1
fi
echo "unexpected docker invocation: $*" >&2
exit 2
SH
  chmod +x "$bin_dir/docker"
}

make_release_asset() {
  local release_dir="$1"
  local asset="$release_dir/docker-compose-linux-x86_64"
  mkdir -p "$release_dir"
  cat >"$asset" <<'SH'
#!/usr/bin/env bash
echo "Docker Compose version v5.1.3"
SH
  chmod +x "$asset"
  (cd "$release_dir" && sha256sum docker-compose-linux-x86_64 > docker-compose-linux-x86_64.sha256)
}

export -f make_fake_docker make_release_asset

run_fixture() {
  local name="$1"
  shift
  echo "--- $name ---"
  "$@"
}

run_fixture "installs x86_64 asset with checksum verification" bash -c '
  set -euo pipefail
  root="$1/ok"
  mkdir -p "$root/bin" "$root/release" "$root/home"
  make_fake_docker "$root/bin"
  make_release_asset "$root/release"
  PATH="$root/bin:$PATH" \
  HOME="$root/home" \
  DOCKER_CONFIG="$root/home/.docker" \
  DOCKER_COMPOSE_FORCE_INSTALL=1 \
  DOCKER_COMPOSE_UNAME_M=x86_64 \
  DOCKER_COMPOSE_BASE_URL="file://$root/release" \
  "$2" >"$root/out.txt" 2>"$root/err.txt"
  test -x "$root/home/.docker/cli-plugins/docker-compose"
  grep -q "Docker Compose version v5.1.3" "$root/out.txt"
' bash "$TMP_DIR" "$INSTALLER" && pass "installer verifies checksum and installs plugin" || fail "installer verifies checksum and installs plugin"

run_fixture "fails on checksum mismatch" bash -c '
  set -euo pipefail
  root="$1/bad-checksum"
  mkdir -p "$root/bin" "$root/release" "$root/home"
  make_fake_docker "$root/bin"
  make_release_asset "$root/release"
  printf "0000000000000000000000000000000000000000000000000000000000000000  docker-compose-linux-x86_64\n" > "$root/release/docker-compose-linux-x86_64.sha256"
  set +e
  PATH="$root/bin:$PATH" \
  HOME="$root/home" \
  DOCKER_CONFIG="$root/home/.docker" \
  DOCKER_COMPOSE_FORCE_INSTALL=1 \
  DOCKER_COMPOSE_UNAME_M=x86_64 \
  DOCKER_COMPOSE_BASE_URL="file://$root/release" \
  "$2" >"$root/out.txt" 2>"$root/err.txt"
  rc=$?
  set -e
  test "$rc" -ne 0
  test ! -e "$root/home/.docker/cli-plugins/docker-compose"
' bash "$TMP_DIR" "$INSTALLER" && pass "installer fails closed on checksum mismatch" || fail "installer fails closed on checksum mismatch"

run_fixture "fails loudly on unsupported architecture" bash -c '
  set -euo pipefail
  root="$1/unsupported-arch"
  mkdir -p "$root/bin" "$root/release" "$root/home"
  make_fake_docker "$root/bin"
  set +e
  PATH="$root/bin:$PATH" \
  HOME="$root/home" \
  DOCKER_CONFIG="$root/home/.docker" \
  DOCKER_COMPOSE_FORCE_INSTALL=1 \
  DOCKER_COMPOSE_UNAME_M=mips64 \
  DOCKER_COMPOSE_BASE_URL="file://$root/release" \
  "$2" >"$root/out.txt" 2>"$root/err.txt"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -q "Unsupported Docker Compose install architecture: mips64" "$root/err.txt"
' bash "$TMP_DIR" "$INSTALLER" && pass "installer rejects unsupported architecture" || fail "installer rejects unsupported architecture"

echo "Summary: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
