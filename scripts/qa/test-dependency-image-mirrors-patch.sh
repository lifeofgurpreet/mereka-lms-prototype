#!/usr/bin/env bash
# Fixture tests for dependency-image-mirrors.sh.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PATCH="$REPO_ROOT/infrastructure/tutor/patches/dependency-image-mirrors.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# shellcheck source=infrastructure/tutor/patches/dependency-image-mirrors.sh
source "$PATCH"

write_fixtures() {
  local root="$1"
  mkdir -p "$root/env/build/openedx" "$root/env/plugins/mfe/build/mfe"
  cat >"$root/env/build/openedx/Dockerfile" <<'EOF'
# syntax=docker/dockerfile:1
FROM docker.io/ubuntu:22.04 AS minimal
COPY --link --from=docker.io/powerman/dockerize:0.19.0 /usr/local/bin/dockerize /usr/local/bin/dockerize
EOF
  cat >"$root/env/plugins/mfe/build/mfe/Dockerfile" <<'EOF'
# syntax=docker/dockerfile:1
FROM docker.io/node:24.11.0-bullseye-slim AS base
FROM docker.io/caddy:2.7.4 AS production
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

write_fixtures "$TMP_ROOT"
TUTOR_ROOT="$TMP_ROOT" TARGET=all apply_dependency_image_mirrors_patch

OPENEDX="$TMP_ROOT/env/build/openedx/Dockerfile"
MFE="$TMP_ROOT/env/plugins/mfe/build/mfe/Dockerfile"

require_contains "$OPENEDX" "# syntax=mirror.gcr.io/docker/dockerfile:1"
require_contains "$OPENEDX" "FROM mirror.gcr.io/library/ubuntu:22.04 AS minimal"
require_contains "$OPENEDX" "COPY --link --from=mirror.gcr.io/powerman/dockerize:0.19.0 /usr/local/bin/dockerize /usr/local/bin/dockerize"
require_contains "$MFE" "# syntax=mirror.gcr.io/docker/dockerfile:1"
require_contains "$MFE" "FROM mirror.gcr.io/library/node:24.11.0-bullseye-slim AS base"
require_contains "$MFE" "FROM mirror.gcr.io/library/caddy:2.7.4 AS production"
reject_contains "$OPENEDX" "docker.io/ubuntu"
reject_contains "$OPENEDX" "docker.io/powerman/dockerize"
reject_contains "$MFE" "docker.io/node"
reject_contains "$MFE" "docker.io/caddy"

before="$(sha256sum "$OPENEDX" "$MFE")"
TUTOR_ROOT="$TMP_ROOT" TARGET=all apply_dependency_image_mirrors_patch
after="$(sha256sum "$OPENEDX" "$MFE")"
if [[ "$before" != "$after" ]]; then
  echo "FAIL: dependency image mirror patch is not idempotent" >&2
  exit 1
fi

TARGET_ROOT="$TMP_ROOT/targeted"
write_fixtures "$TARGET_ROOT"
TUTOR_ROOT="$TARGET_ROOT" TARGET=openedx apply_dependency_image_mirrors_patch
require_contains "$TARGET_ROOT/env/build/openedx/Dockerfile" "mirror.gcr.io/library/ubuntu:22.04"
require_contains "$TARGET_ROOT/env/plugins/mfe/build/mfe/Dockerfile" "FROM docker.io/node:24.11.0-bullseye-slim AS base"
require_contains "$TARGET_ROOT/env/plugins/mfe/build/mfe/Dockerfile" "FROM docker.io/caddy:2.7.4 AS production"

TARGET_ROOT="$TMP_ROOT/targeted-mfe"
write_fixtures "$TARGET_ROOT"
TUTOR_ROOT="$TARGET_ROOT" TARGET=mfe apply_dependency_image_mirrors_patch
require_contains "$TARGET_ROOT/env/build/openedx/Dockerfile" "FROM docker.io/ubuntu:22.04 AS minimal"
require_contains "$TARGET_ROOT/env/plugins/mfe/build/mfe/Dockerfile" "mirror.gcr.io/library/node:24.11.0-bullseye-slim"
require_contains "$TARGET_ROOT/env/plugins/mfe/build/mfe/Dockerfile" "mirror.gcr.io/library/caddy:2.7.4"

BROKEN_ROOT="$TMP_ROOT/broken"
write_fixtures "$BROKEN_ROOT"
sed -i 's|FROM docker.io/node:24.11.0-bullseye-slim AS base|FROM docker.io/node:26-bullseye-slim AS base|' \
  "$BROKEN_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
if TUTOR_ROOT="$BROKEN_ROOT" TARGET=mfe apply_dependency_image_mirrors_patch 2>"$TMP_ROOT/broken.err"; then
  echo "FAIL: dependency image mirror patch did not fail loud on selector drift" >&2
  exit 1
fi
require_contains "$TMP_ROOT/broken.err" "revalidate mirror authority"

echo "PASS: dependency image mirror patch is idempotent, target-scoped, and fail-loud"
