#!/usr/bin/env bash
# lint: allow-no-euo
# Sourced helper; callers own strict mode.

mereka_local_image_freshness_args() {
  if [[ "${FORCE_LOCAL_IMAGE_BUILD:-0}" == "1" ]]; then
    return 0
  fi

  printf '%s\n' "--skip-if-current"
}

mereka_image_label_value() {
  local image_ref="$1"
  local label_name="$2"

  docker image inspect \
    --format "{{ index .Config.Labels \"$label_name\" }}" \
    "$image_ref" 2>/dev/null || true
}

mereka_image_matches_build_contract_labels() {
  local image_ref="$1"
  local expected_sha="$2"
  local expected_profile="$3"
  local expected_scope="$4"
  local actual_sha
  local actual_profile
  local actual_scope

  docker image inspect "$image_ref" >/dev/null 2>&1 || return 1
  actual_sha="$(mereka_image_label_value "$image_ref" "io.mereka.build-context-sha256")"
  actual_profile="$(mereka_image_label_value "$image_ref" "io.mereka.build-profile")"
  actual_scope="$(mereka_image_label_value "$image_ref" "io.mereka.build-scope")"

  [[ -n "$actual_sha" && "$actual_sha" == "$expected_sha" ]] || return 1
  [[ -n "$actual_profile" && "$actual_profile" == "$expected_profile" ]] || return 1
  [[ -n "$actual_scope" && "$actual_scope" == "$expected_scope" ]] || return 1
}

mereka_image_matches_build_context_label() {
  local image_ref="$1"
  local expected_sha="$2"
  local actual_sha

  docker image inspect "$image_ref" >/dev/null 2>&1 || return 1
  actual_sha="$(mereka_image_label_value "$image_ref" "io.mereka.build-context-sha256")"

  [[ -n "$actual_sha" && "$actual_sha" == "$expected_sha" ]]
}
