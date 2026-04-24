#!/usr/bin/env bash
# Shared health checks for repo-owned local Buildx builders.

mereka_buildx_active_build_processes() {
  if [[ -n "${MEREKA_BUILDX_ACTIVE_PROCESSES_FILE:-}" ]]; then
    [[ -f "$MEREKA_BUILDX_ACTIVE_PROCESSES_FILE" ]] && cat "$MEREKA_BUILDX_ACTIVE_PROCESSES_FILE"
    return 0
  fi

  pgrep -af 'docker[[:space:]]+(buildx[[:space:]]+(build|bake)|pull)|buildctl' 2>/dev/null \
    | grep -Ev 'buildx-builder-health|pgrep -af|grep -Ev' || true
}

mereka_buildx_refuse_builder_mutation_if_active() {
  local builder_name="$1"
  local reason="$2"

  local active

  active="$(mereka_buildx_active_build_processes)"
  if [[ -z "$active" ]]; then
    return 0
  fi

  {
    echo "Refusing to mutate Buildx builder '${builder_name}' while build processes are active."
    echo "Requested action: ${reason}"
    echo "Wait for the active build to finish, then rerun the local setup/build command."
    echo "Active process evidence:"
    printf '%s\n' "$active"
  } >&2
  return 1
}

mereka_buildx_builder_container_name() {
  local builder_name="$1"

  if [[ -n "${MEREKA_BUILDX_BUILDER_CONTAINER_NAME:-}" ]]; then
    printf '%s\n' "$MEREKA_BUILDX_BUILDER_CONTAINER_NAME"
    return 0
  fi

  docker ps -a \
    --filter "name=^/buildx_buildkit_${builder_name}[0-9]+$" \
    --format '{{.Names}}' \
    | head -n 1
}

mereka_buildx_builder_process_snapshot() {
  local container_name="$1"

  if [[ -n "${MEREKA_BUILDX_PROCESS_SNAPSHOT_FILE:-}" ]]; then
    [[ -f "$MEREKA_BUILDX_PROCESS_SNAPSHOT_FILE" ]] && cat "$MEREKA_BUILDX_PROCESS_SNAPSHOT_FILE"
    return 0
  fi

  docker top "$container_name" -eo pid,ppid,comm,args 2>/dev/null || true
}

mereka_buildx_stale_executor_processes() {
  awk '
    NR == 1 { next }
    $3 ~ /^(npm|node|sh|bash|yarn|pnpm)$/ {
      print
      found = 1
    }
    END { exit found ? 0 : 1 }
  '
}

mereka_buildx_unhealthy_reason() {
  local builder_name="$1"
  local container_name snapshot stale

  container_name="$(mereka_buildx_builder_container_name "$builder_name")"
  if [[ -z "$container_name" ]]; then
    return 1
  fi

  snapshot="$(mereka_buildx_builder_process_snapshot "$container_name")"
  stale="$(printf '%s\n' "$snapshot" | mereka_buildx_stale_executor_processes || true)"
  if [[ -n "$stale" ]]; then
    echo "idle BuildKit container '${container_name}' still has build executor processes: ${stale//$'\n'/; }"
    return 0
  fi

  return 1
}

mereka_buildx_remove_builder_safely() {
  local builder_name="$1"
  local reason="$2"

  if ! mereka_buildx_refuse_builder_mutation_if_active "$builder_name" "$reason"; then
    return 1
  fi
  docker buildx rm "$builder_name" >/dev/null 2>&1 || true
}

mereka_buildx_recreate_if_unhealthy() {
  local builder_name="$1"
  local reason

  if reason="$(mereka_buildx_unhealthy_reason "$builder_name")"; then
    echo "Buildx builder '${builder_name}' is unhealthy: ${reason}" >&2
    echo "Recreating repo-owned Buildx builder '${builder_name}' before reuse." >&2
    mereka_buildx_remove_builder_safely "$builder_name" "$reason"
  fi
}
