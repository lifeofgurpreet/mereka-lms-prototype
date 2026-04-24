#!/usr/bin/env bash
# Fixture tests for openedx-obsolete-activation-key-patch-removal.sh.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PATCH="$REPO_ROOT/infrastructure/tutor/patches/openedx-obsolete-activation-key-patch-removal.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# shellcheck source=infrastructure/tutor/patches/openedx-obsolete-activation-key-patch-removal.sh
source "$PATCH"

write_fixture() {
  local root="$1"
  mkdir -p "$root/env/build/openedx"
  cat >"$root/env/build/openedx/Dockerfile" <<'EOF'
FROM ubuntu:22.04 AS code
RUN git config --global user.email "tutor@overhang.io" \
  && git config --global user.name "Tutor"

# SECURITY FIX: remove activation_key exposure from account API
RUN curl -fsSL https://github.com/openedx/openedx-platform/commit/21cead238466ca398ba368518f1d3288431d68f4.patch | git am

RUN echo after
EOF
}

require_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq "$pattern" "$file"; then
    echo "FAIL: expected $file to contain: $pattern" >&2
    exit 1
  fi
}

reject_contains() {
  local file="$1"
  local pattern="$2"
  if grep -Fq "$pattern" "$file"; then
    echo "FAIL: expected $file not to contain: $pattern" >&2
    exit 1
  fi
}

TARGET_ROOT="$TMP_ROOT/happy"
write_fixture "$TARGET_ROOT"
TUTOR_ROOT="$TARGET_ROOT" apply_openedx_obsolete_activation_key_patch_removal_patch
OPENEDX="$TARGET_ROOT/env/build/openedx/Dockerfile"
reject_contains "$OPENEDX" "21cead238466ca398ba368518f1d3288431d68f4.patch | git am"
require_contains "$OPENEDX" "RUN echo after"

before="$(sha256sum "$OPENEDX")"
TUTOR_ROOT="$TARGET_ROOT" apply_openedx_obsolete_activation_key_patch_removal_patch
after="$(sha256sum "$OPENEDX")"
if [[ "$before" != "$after" ]]; then
  echo "FAIL: obsolete activation-key patch removal is not idempotent" >&2
  exit 1
fi

RETIRED_ROOT="$TMP_ROOT/upstream-retired"
mkdir -p "$RETIRED_ROOT/env/build/openedx"
cat >"$RETIRED_ROOT/env/build/openedx/Dockerfile" <<'EOF'
FROM ubuntu:22.04 AS code
RUN echo no obsolete activation patch remains
EOF
before="$(sha256sum "$RETIRED_ROOT/env/build/openedx/Dockerfile")"
TUTOR_ROOT="$RETIRED_ROOT" apply_openedx_obsolete_activation_key_patch_removal_patch
after="$(sha256sum "$RETIRED_ROOT/env/build/openedx/Dockerfile")"
if [[ "$before" != "$after" ]]; then
  echo "FAIL: upstream retirement no-op changed the Dockerfile unexpectedly" >&2
  exit 1
fi

BROKEN_ROOT="$TMP_ROOT/drift"
mkdir -p "$BROKEN_ROOT/env/build/openedx"
cat >"$BROKEN_ROOT/env/build/openedx/Dockerfile" <<'EOF'
FROM ubuntu:22.04 AS code
# SECURITY FIX: remove activation_key exposure from account API
RUN curl -fsSL https://github.com/openedx/openedx-platform/commit/deadbeef.patch | git am
EOF
if TUTOR_ROOT="$BROKEN_ROOT" apply_openedx_obsolete_activation_key_patch_removal_patch 2>"$TMP_ROOT/drift.err"; then
  echo "FAIL: obsolete activation-key patch removal did not fail loud on selector drift" >&2
  exit 1
fi
require_contains "$TMP_ROOT/drift.err" "revalidate authority"

echo "PASS: obsolete activation-key patch removal is golden, idempotent, no-op safe, and fail-loud"
