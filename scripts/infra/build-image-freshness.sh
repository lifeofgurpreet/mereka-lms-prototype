#!/usr/bin/env bash
# lint: allow-no-euo
# Sourced helper; callers own strict mode.

mereka_image_matches_build_context_label() {
  local image_ref="$1"
  local expected_sha="$2"
  local actual_sha

  docker image inspect "$image_ref" >/dev/null 2>&1 || return 1
  actual_sha="$(docker image inspect \
    --format '{{ index .Config.Labels "io.mereka.build-context-sha256" }}' \
    "$image_ref" 2>/dev/null || true)"

  [[ -n "$actual_sha" && "$actual_sha" == "$expected_sha" ]]
}
