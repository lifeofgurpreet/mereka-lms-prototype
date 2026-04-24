#!/usr/bin/env bash

mereka_file_sha256() {
  local file_path="$1"

  sha256sum "$file_path" | awk '{print $1}'
}

mereka_build_context_fingerprint() {
  local context_dir="$1"

  if [[ ! -d "$context_dir" ]]; then
    echo "Build context directory not found: $context_dir" >&2
    return 1
  fi

  (
    cd "$context_dir"
    find . -type f \
      ! -path './.git/*' \
      ! -path './.buildx-cache/*' \
      -print0 \
      | sort -z \
      | xargs -0 sha256sum \
      | sha256sum \
      | awk '{print $1}'
  )
}
