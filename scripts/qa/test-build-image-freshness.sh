#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d -t test-build-image-freshness.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/fakebin"
cat >"$tmpdir/fakebin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  if [[ "${3:-}" == "--format" ]]; then
    printf '%s\n' "${FAKE_DOCKER_LABEL:-}"
    exit 0
  fi

  [[ "${FAKE_DOCKER_IMAGE_EXISTS:-1}" == "1" ]] || exit 1
  exit 0
fi

echo "unexpected docker invocation: $*" >&2
exit 1
EOF
chmod +x "$tmpdir/fakebin/docker"

# shellcheck source=../infra/build-image-freshness.sh
source "$ROOT_DIR/scripts/infra/build-image-freshness.sh"

export PATH="$tmpdir/fakebin:$PATH"

run_expect_pass() {
  local label="$1"
  local image_exists="$2"
  local actual_label="$3"
  local expected_label="$4"

  export FAKE_DOCKER_IMAGE_EXISTS="$image_exists"
  export FAKE_DOCKER_LABEL="$actual_label"

  if ! mereka_image_matches_build_context_label "example/image:tag" "$expected_label"; then
    echo "FAIL ${label}: expected image freshness helper to pass" >&2
    exit 1
  fi

  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  local image_exists="$2"
  local actual_label="$3"
  local expected_label="$4"

  export FAKE_DOCKER_IMAGE_EXISTS="$image_exists"
  export FAKE_DOCKER_LABEL="$actual_label"

  if mereka_image_matches_build_context_label "example/image:tag" "$expected_label"; then
    echo "FAIL ${label}: expected image freshness helper to fail" >&2
    exit 1
  fi

  echo "PASS ${label}"
}

run_expect_fail "missing image is stale" "0" "sha-a" "sha-a"
run_expect_fail "missing build-context label is stale" "1" "" "sha-a"
run_expect_fail "mismatched build-context label is stale" "1" "sha-b" "sha-a"
run_expect_pass "matching build-context label is current" "1" "sha-a" "sha-a"

echo "PASS test-build-image-freshness"
