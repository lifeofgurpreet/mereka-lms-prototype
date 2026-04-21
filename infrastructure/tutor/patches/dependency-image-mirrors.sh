#!/usr/bin/env bash
# Patch: normalize upstream hardcoded Docker Hub dependency image refs.
#
# Tutor 21 and tutormfe still emit a few build-time dependency image refs that
# are not exposed through Tutor config. Keep this patch narrow: it changes only
# registry acquisition for known equivalent mirror.gcr.io images, not stages,
# commands, or artifact semantics.
set -euo pipefail

apply_dependency_image_mirrors_patch() {
  local tutor_root="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
  local openedx_dockerfile="$tutor_root/env/build/openedx/Dockerfile"
  local mfe_dockerfile="$tutor_root/env/plugins/mfe/build/mfe/Dockerfile"
  local targets=()

  case "${TARGET:-all}" in
    openedx)
      targets=("$openedx_dockerfile")
      ;;
    mfe)
      targets=("$mfe_dockerfile")
      ;;
    all)
      targets=("$openedx_dockerfile" "$mfe_dockerfile")
      ;;
    *)
      echo "Unsupported dependency image mirror target: ${TARGET:-}" >&2
      return 2
      ;;
  esac

  "${PYTHON_BIN:-python3}" - "${targets[@]}" <<'PY'
from pathlib import Path
import sys

REPLACEMENTS = {
    "# syntax=docker/dockerfile:1": "# syntax=mirror.gcr.io/docker/dockerfile:1",
    "FROM docker.io/ubuntu:22.04 AS minimal": (
        "FROM mirror.gcr.io/library/ubuntu:22.04 AS minimal"
    ),
    "COPY --link --from=docker.io/powerman/dockerize:0.19.0 ": (
        "COPY --link --from=mirror.gcr.io/powerman/dockerize:0.19.0 "
    ),
    "FROM docker.io/node:24.11.0-bullseye-slim AS base": (
        "FROM mirror.gcr.io/library/node:24.11.0-bullseye-slim AS base"
    ),
}

REQUIRED_BY_SUFFIX = {
    "env/build/openedx/Dockerfile": [
        "# syntax=mirror.gcr.io/docker/dockerfile:1",
        "FROM mirror.gcr.io/library/ubuntu:22.04 AS minimal",
        "COPY --link --from=mirror.gcr.io/powerman/dockerize:0.19.0 ",
    ],
    "env/plugins/mfe/build/mfe/Dockerfile": [
        "# syntax=mirror.gcr.io/docker/dockerfile:1",
        "FROM mirror.gcr.io/library/node:24.11.0-bullseye-slim AS base",
    ],
}

for raw_target in sys.argv[1:]:
    path = Path(raw_target)
    if not path.exists():
        raise SystemExit(f"Rendered Dockerfile missing: {path}")
    original = path.read_text(encoding="utf-8")
    updated = original
    for source, mirror in REPLACEMENTS.items():
        updated = updated.replace(source, mirror)
    path_key = path.as_posix()
    required = []
    for suffix, mirrors in REQUIRED_BY_SUFFIX.items():
        if path_key.endswith(suffix):
            required = mirrors
            break
    missing = [mirror for mirror in required if mirror not in updated]
    if missing:
        raise SystemExit(
            "Upstream Dockerfile dependency image selectors changed; "
            "revalidate mirror authority before updating "
            f"{path}. Missing expected mirror refs: {', '.join(missing)}"
        )
    if updated != original:
        path.write_text(updated, encoding="utf-8")
PY
}
