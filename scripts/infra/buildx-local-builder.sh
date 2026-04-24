#!/usr/bin/env bash

ensure_local_buildx_builder() {
  [[ "${OUTPUT_MODE:-}" == "docker" ]] || return 0
  [[ -z "${BUILDX_BUILDER:-}" ]] || return 0

  local current_driver
  current_driver="$(docker buildx ls --format '{{json .}}' | python3 -c '
import json
import sys

for line in sys.stdin:
    item = json.loads(line)
    if item.get("Current"):
        print(item.get("Driver", ""))
        break
')"

  [[ "$current_driver" == "docker" ]] || return 0

  local builder_name
  builder_name="$(docker buildx ls --format '{{json .}}' | python3 -c '
import json
import sys

for line in sys.stdin:
    item = json.loads(line)
    if item.get("Driver") != "docker-container":
        continue
    nodes = item.get("Nodes") or []
    if any(node.get("Status") == "running" for node in nodes):
        print(item.get("Name", ""))
        break
')"

  if [[ -z "$builder_name" ]]; then
    builder_name="${MEREKA_LOCAL_BUILDX_BUILDER:-mereka-local-build}"
    if ! docker buildx inspect "$builder_name" >/dev/null 2>&1; then
      docker buildx create --name "$builder_name" --driver docker-container >/dev/null
    fi
  fi

  docker buildx inspect --bootstrap "$builder_name" >/dev/null
  BUILDX_BAKE_ARGS+=(--builder "$builder_name")
  echo "Using buildx builder '$builder_name' for local BuildKit worker cache"
}
