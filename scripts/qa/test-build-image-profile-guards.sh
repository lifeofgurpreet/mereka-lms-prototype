#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d -t test-build-image-profile-guards.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

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

echo "PASS test-build-image-profile-guards"
