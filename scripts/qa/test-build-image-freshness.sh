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
    case "${4:-}" in
      *'io.mereka.build-context-sha256'*)
        printf '%s\n' "${FAKE_DOCKER_CONTEXT_LABEL:-}"
        ;;
      *'io.mereka.build-profile'*)
        printf '%s\n' "${FAKE_DOCKER_PROFILE_LABEL:-}"
        ;;
      *'io.mereka.build-scope'*)
        printf '%s\n' "${FAKE_DOCKER_SCOPE_LABEL:-}"
        ;;
      *)
        echo "unexpected docker label format: ${4:-}" >&2
        exit 1
        ;;
    esac
    exit 0
  fi

  [[ "${FAKE_DOCKER_IMAGE_EXISTS:-1}" == "1" ]] || exit 1
  exit 0
fi

echo "unexpected docker invocation: $*" >&2
exit 1
EOF
chmod +x "$tmpdir/fakebin/docker"

# shellcheck source=scripts/infra/build-image-freshness.sh
source "$ROOT_DIR/scripts/infra/build-image-freshness.sh"

export PATH="$tmpdir/fakebin:$PATH"

run_expect_context_pass() {
  local label="$1"
  local image_exists="$2"
  local actual_label="$3"
  local expected_label="$4"

  export FAKE_DOCKER_IMAGE_EXISTS="$image_exists"
  export FAKE_DOCKER_CONTEXT_LABEL="$actual_label"
  export FAKE_DOCKER_PROFILE_LABEL=""
  export FAKE_DOCKER_SCOPE_LABEL=""

  if ! mereka_image_matches_build_context_label "example/image:tag" "$expected_label"; then
    echo "FAIL ${label}: expected image freshness helper to pass" >&2
    exit 1
  fi

  echo "PASS ${label}"
}

run_expect_context_fail() {
  local label="$1"
  local image_exists="$2"
  local actual_label="$3"
  local expected_label="$4"

  export FAKE_DOCKER_IMAGE_EXISTS="$image_exists"
  export FAKE_DOCKER_CONTEXT_LABEL="$actual_label"
  export FAKE_DOCKER_PROFILE_LABEL=""
  export FAKE_DOCKER_SCOPE_LABEL=""

  if mereka_image_matches_build_context_label "example/image:tag" "$expected_label"; then
    echo "FAIL ${label}: expected image freshness helper to fail" >&2
    exit 1
  fi

  echo "PASS ${label}"
}

run_expect_contract_pass() {
  local label="$1"
  local image_exists="$2"
  local actual_context="$3"
  local actual_profile="$4"
  local actual_scope="$5"
  local expected_context="$6"
  local expected_profile="$7"
  local expected_scope="$8"

  export FAKE_DOCKER_IMAGE_EXISTS="$image_exists"
  export FAKE_DOCKER_CONTEXT_LABEL="$actual_context"
  export FAKE_DOCKER_PROFILE_LABEL="$actual_profile"
  export FAKE_DOCKER_SCOPE_LABEL="$actual_scope"

  if ! mereka_image_matches_build_contract_labels "example/image:tag" "$expected_context" "$expected_profile" "$expected_scope"; then
    echo "FAIL ${label}: expected image contract freshness helper to pass" >&2
    exit 1
  fi

  echo "PASS ${label}"
}

run_expect_contract_fail() {
  local label="$1"
  local image_exists="$2"
  local actual_context="$3"
  local actual_profile="$4"
  local actual_scope="$5"
  local expected_context="$6"
  local expected_profile="$7"
  local expected_scope="$8"

  export FAKE_DOCKER_IMAGE_EXISTS="$image_exists"
  export FAKE_DOCKER_CONTEXT_LABEL="$actual_context"
  export FAKE_DOCKER_PROFILE_LABEL="$actual_profile"
  export FAKE_DOCKER_SCOPE_LABEL="$actual_scope"

  if mereka_image_matches_build_contract_labels "example/image:tag" "$expected_context" "$expected_profile" "$expected_scope"; then
    echo "FAIL ${label}: expected image contract freshness helper to fail" >&2
    exit 1
  fi

  echo "PASS ${label}"
}

run_expect_local_freshness_args() {
  local label="$1"
  local force_value="$2"
  local expected_args="$3"
  local actual_args

  actual_args="$(FORCE_LOCAL_IMAGE_BUILD="$force_value" bash -c '
    set -euo pipefail
    source "$1"
    mapfile -t args < <(mereka_local_image_freshness_args)
    printf "%s\n" "${args[*]}"
  ' bash "$ROOT_DIR/scripts/infra/build-image-freshness.sh")"

  if [[ "$actual_args" != "$expected_args" ]]; then
    echo "FAIL ${label}: expected local freshness args '${expected_args}', got '${actual_args}'" >&2
    exit 1
  fi

  echo "PASS ${label}"
}

run_expect_local_freshness_args "local image reuse is enabled by default" "0" "--skip-if-current"
run_expect_local_freshness_args "FORCE_LOCAL_IMAGE_BUILD disables local image reuse" "1" ""

run_expect_context_fail "missing image is stale" "0" "sha-a" "sha-a"
run_expect_context_fail "missing build-context label is stale" "1" "" "sha-a"
run_expect_context_fail "mismatched build-context label is stale" "1" "sha-b" "sha-a"
run_expect_context_pass "matching build-context label remains current for legacy callers" "1" "sha-a" "sha-a"

run_expect_contract_fail "missing image is stale for build contract" "0" "sha-a" "fast" "openedx" "sha-a" "fast" "openedx"
run_expect_contract_fail "missing build-context label is stale for build contract" "1" "" "fast" "openedx" "sha-a" "fast" "openedx"
run_expect_contract_fail "mismatched build-context label is stale for build contract" "1" "sha-b" "fast" "openedx" "sha-a" "fast" "openedx"
run_expect_contract_fail "missing build-profile label is stale for build contract" "1" "sha-a" "" "openedx" "sha-a" "fast" "openedx"
run_expect_contract_fail "mismatched build-profile label is stale for build contract" "1" "sha-a" "proof" "openedx" "sha-a" "fast" "openedx"
run_expect_contract_fail "missing build-scope label is stale for build contract" "1" "sha-a" "fast" "" "sha-a" "fast" "openedx"
run_expect_contract_fail "mismatched build-scope label is stale for build contract" "1" "sha-a" "fast" "mfe" "sha-a" "fast" "openedx"
run_expect_contract_pass "matching context profile and scope labels are current" "1" "sha-a" "fast" "openedx" "sha-a" "fast" "openedx"

echo "PASS test-build-image-freshness"
