#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d -t test-build-image-profile-guards.XXXXXX)"
repo_tmpdir="$ROOT_DIR/var/qa/test-build-image-profile-guards.$$"
trap 'rm -rf "$tmpdir" "$repo_tmpdir"' EXIT

mkdir -p "$tmpdir/context"
cat >"$tmpdir/context/Dockerfile" <<'EOF'
FROM scratch
EOF

run_expect_fast_mutable_rejected() {
  local label="$1"
  shift

  if "$@" >/tmp/test-build-image-profile-guards.out 2>&1; then
    echo "FAIL ${label}: expected fast+mutable-tag guard to reject the invocation" >&2
    cat /tmp/test-build-image-profile-guards.out >&2 || true
    exit 1
  fi

  if ! rg -q "Fast build profile cannot publish mutable tags; use proof for promotable builds." /tmp/test-build-image-profile-guards.out; then
    echo "FAIL ${label}: expected explicit fast-profile mutable-tag rejection message" >&2
    cat /tmp/test-build-image-profile-guards.out >&2 || true
    exit 1
  fi

  echo "PASS ${label}"
}

run_expect_cache_none_fast_rejected() {
  local label="$1"
  shift

  if "$@" >/tmp/test-build-image-profile-guards.out 2>&1; then
    echo "FAIL ${label}: expected fast+cache-mode-none guard to reject the invocation" >&2
    cat /tmp/test-build-image-profile-guards.out >&2 || true
    exit 1
  fi

  if ! rg -q "cache-mode none is only supported for proof builds." /tmp/test-build-image-profile-guards.out; then
    echo "FAIL ${label}: expected explicit cache-mode-none rejection message" >&2
    cat /tmp/test-build-image-profile-guards.out >&2 || true
    exit 1
  fi

  echo "PASS ${label}"
}

run_expect_fast_mutable_rejected \
  "build-openedx-image rejects mutable tags on fast profile" \
  bash "$ROOT_DIR/scripts/infra/build-openedx-image.sh" \
    --context-dir "$tmpdir/context" \
    --dockerfile "$tmpdir/context/Dockerfile" \
    --image-repo example/openedx \
    --primary-tag test \
    --secondary-tag test2 \
    --cache-ref example/openedx:cache \
    --build-profile fast \
    --mutable-tag mutable

run_expect_cache_none_fast_rejected \
  "build-openedx-image rejects no-cache mode on fast profile" \
  bash "$ROOT_DIR/scripts/infra/build-openedx-image.sh" \
    --context-dir "$tmpdir/context" \
    --dockerfile "$tmpdir/context/Dockerfile" \
    --image-repo example/openedx \
    --primary-tag test \
    --secondary-tag test2 \
    --output-mode docker \
    --cache-mode none \
    --build-profile fast

run_expect_fast_mutable_rejected \
  "build-mfe-image rejects mutable tags on fast profile" \
  bash "$ROOT_DIR/scripts/infra/build-mfe-image.sh" \
    --context-dir "$tmpdir/context" \
    --dockerfile "$tmpdir/context/Dockerfile" \
    --image-repo example/mfe \
    --primary-tag test \
    --secondary-tag test2 \
    --cache-ref example/mfe:cache \
    --build-profile fast \
    --mutable-tag mutable

run_expect_cache_none_fast_rejected \
  "build-mfe-image rejects no-cache mode on fast profile" \
  bash "$ROOT_DIR/scripts/infra/build-mfe-image.sh" \
    --context-dir "$tmpdir/context" \
    --dockerfile "$tmpdir/context/Dockerfile" \
    --image-repo example/mfe \
    --primary-tag test \
    --secondary-tag test2 \
    --output-mode docker \
    --cache-mode none \
    --build-profile fast

run_expect_skip_if_current_rejected_for_push() {
  local label="$1"
  shift

  if "$@" >/tmp/test-build-image-profile-guards-skip-push.out 2>&1; then
    echo "FAIL ${label}: expected push-mode skip-if-current guard to reject the invocation" >&2
    cat /tmp/test-build-image-profile-guards-skip-push.out >&2 || true
    exit 1
  fi

  if ! rg -q -- "--skip-if-current is only supported for local Docker output builds." /tmp/test-build-image-profile-guards-skip-push.out; then
    echo "FAIL ${label}: expected explicit skip-if-current output-mode rejection" >&2
    cat /tmp/test-build-image-profile-guards-skip-push.out >&2 || true
    exit 1
  fi

  echo "PASS ${label}"
}

run_expect_skip_current_without_bake() {
  local label="$1"
  shift

  if ! EXPECTED_CONTEXT_SHA="$current_context_sha" PATH="$tmpdir/current-fakebin:$PATH" "$@" >/tmp/test-build-image-profile-guards-skip-current.out 2>&1; then
    echo "FAIL ${label}: expected current-image skip to succeed" >&2
    cat /tmp/test-build-image-profile-guards-skip-current.out >&2 || true
    exit 1
  fi

  if ! rg -q "skipping build" /tmp/test-build-image-profile-guards-skip-current.out; then
    echo "FAIL ${label}: expected current-image skip message" >&2
    cat /tmp/test-build-image-profile-guards-skip-current.out >&2 || true
    exit 1
  fi

  echo "PASS ${label}"
}

mkdir -p "$tmpdir/current-context" "$tmpdir/current-fakebin"
cat >"$tmpdir/current-context/Dockerfile" <<'EOF'
FROM scratch
EOF
cat >"$tmpdir/current-context/app.txt" <<'EOF'
current
EOF
cat >"$tmpdir/current-fakebin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  if [[ "${3:-}" == "--format" ]]; then
    printf '%s\n' "${EXPECTED_CONTEXT_SHA:?}"
    exit 0
  fi
  exit 0
fi

if [[ "${1:-}" == "buildx" && "${2:-}" == "bake" ]]; then
  echo "buildx bake should not run when the primary local image is current" >&2
  exit 1
fi

echo "unexpected docker invocation: $*" >&2
exit 1
EOF
chmod +x "$tmpdir/current-fakebin/docker"

# shellcheck source=../infra/build-context-fingerprint.sh
source "$ROOT_DIR/scripts/infra/build-context-fingerprint.sh"
current_context_sha="$(mereka_build_context_fingerprint "$tmpdir/current-context")"

run_expect_skip_if_current_rejected_for_push \
  "build-openedx-image rejects skip-if-current outside local Docker output" \
  bash "$ROOT_DIR/scripts/infra/build-openedx-image.sh" \
    --context-dir "$tmpdir/current-context" \
    --dockerfile "$tmpdir/current-context/Dockerfile" \
    --image-repo example/openedx \
    --primary-tag test \
    --secondary-tag test2 \
    --cache-ref example/openedx:cache \
    --skip-if-current

run_expect_skip_if_current_rejected_for_push \
  "build-mfe-image rejects skip-if-current outside local Docker output" \
  bash "$ROOT_DIR/scripts/infra/build-mfe-image.sh" \
    --context-dir "$tmpdir/current-context" \
    --dockerfile "$tmpdir/current-context/Dockerfile" \
    --image-repo example/mfe \
    --primary-tag test \
    --secondary-tag test2 \
    --cache-ref example/mfe:cache \
    --skip-if-current

run_expect_skip_current_without_bake \
  "build-openedx-image skips Bake when local primary tag is current" \
  bash "$ROOT_DIR/scripts/infra/build-openedx-image.sh" \
    --context-dir "$tmpdir/current-context" \
    --dockerfile "$tmpdir/current-context/Dockerfile" \
    --image-repo example/openedx \
    --primary-tag test \
    --secondary-tag test2 \
    --output-mode docker \
    --skip-if-current

run_expect_skip_current_without_bake \
  "build-mfe-image skips Bake when local primary tag is current" \
  bash "$ROOT_DIR/scripts/infra/build-mfe-image.sh" \
    --context-dir "$tmpdir/current-context" \
    --dockerfile "$tmpdir/current-context/Dockerfile" \
    --image-repo example/mfe \
    --primary-tag test \
    --secondary-tag test2 \
    --output-mode docker \
    --skip-if-current

mkdir -p "$repo_tmpdir/mfe-context" "$tmpdir/fakebin"
cat >"$repo_tmpdir/mfe-context/Dockerfile" <<'EOF'
FROM scratch
EOF
cat >"$tmpdir/fakebin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "buildx" && "${2:-}" == "bake" ]]; then
  printf '%s\n' "${MFE_RENDERED_CONTEXT:-}" > "${CAPTURE_FILE:?}"
  exit 0
fi

echo "unexpected docker invocation: $*" >&2
exit 1
EOF
chmod +x "$tmpdir/fakebin/docker"

rendered_context_capture="$tmpdir/mfe-rendered-context.txt"
expected_rendered_context="${repo_tmpdir#"$ROOT_DIR"/}/mfe-context"
CAPTURE_FILE="$rendered_context_capture" PATH="$tmpdir/fakebin:$PATH" \
  bash "$ROOT_DIR/scripts/infra/build-mfe-image.sh" \
    --context-dir "$repo_tmpdir/mfe-context" \
    --dockerfile "$repo_tmpdir/mfe-context/Dockerfile" \
    --image-repo example/mfe \
    --primary-tag test \
    --secondary-tag test2 \
    --cache-ref example/mfe:cache \
    --build-profile proof \
    >/tmp/test-build-image-profile-guards-rendered-context.out 2>&1 \
  || {
    echo "FAIL build-mfe-image should invoke bake with repo-relative rendered-context label" >&2
    cat /tmp/test-build-image-profile-guards-rendered-context.out >&2 || true
    exit 1
  }

actual_rendered_context="$(cat "$rendered_context_capture")"
if [[ "$actual_rendered_context" != "$expected_rendered_context" ]]; then
  echo "FAIL build-mfe-image should label repo-contained rendered context relatively" >&2
  echo "expected: $expected_rendered_context" >&2
  echo "actual:   $actual_rendered_context" >&2
  cat /tmp/test-build-image-profile-guards-rendered-context.out >&2 || true
  exit 1
fi
echo "PASS build-mfe-image labels repo-contained rendered context relatively"

echo "PASS test-build-image-profile-guards"
