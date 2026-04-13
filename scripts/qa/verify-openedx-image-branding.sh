#!/usr/bin/env bash
# @covers AC-011
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LMS_THEME_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"

usage() {
  cat <<'EOF'
Usage: scripts/qa/verify-openedx-image-branding.sh <image_ref> [expected_lms_branding_rev]

Examples:
  scripts/qa/verify-openedx-image-branding.sh ghcr.io/biji-biji-initiative/mereka-lms/openedx:TAG
  scripts/qa/verify-openedx-image-branding.sh ghcr.io/biji-biji-initiative/mereka-lms/openedx@sha256:...
EOF
}

if [[ $# -eq 0 ]]; then
  echo "SKIP: No image_ref provided"
  echo "  Usage: $0 <image_ref> [expected_lms_branding_rev]"
  exit 0
fi

if [[ $# -gt 2 ]]; then
  usage
  exit 1
fi

IMAGE_REF="$1"
EXPECTED_REV="${2:-}"
DOCKER_PULL_TIMEOUT_SECS="${DOCKER_PULL_TIMEOUT_SECS:-600}"
DOCKER_RUN_TIMEOUT_SECS="${DOCKER_RUN_TIMEOUT_SECS:-180}"

if [[ -z "$EXPECTED_REV" && -f "$LMS_THEME_CSS" ]]; then
  EXPECTED_REV="$(sed -nE 's/.*--mereka-branding-rev:[[:space:]]*"([^"]+)".*/\1/p' "$LMS_THEME_CSS" | head -n 1 || true)"
fi

run_with_timeout() {
  local timeout_secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "${timeout_secs}" "$@"
  else
    "$@"
  fi
}

if ! docker image inspect "$IMAGE_REF" >/dev/null 2>&1; then
  echo "Pulling image for branding verification: $IMAGE_REF"
  if run_with_timeout "${DOCKER_PULL_TIMEOUT_SECS}" docker pull "$IMAGE_REF" >/dev/null; then
    :
  else
    status=$?
    if [[ "$status" -eq 124 ]]; then
      echo "ERROR: docker pull timed out after ${DOCKER_PULL_TIMEOUT_SECS}s for $IMAGE_REF" >&2
    else
      echo "ERROR: docker pull failed with exit code ${status} for $IMAGE_REF" >&2
    fi
    exit "$status"
  fi
fi

echo "Verifying OpenEdX image branding: $IMAGE_REF"
if [[ -n "$EXPECTED_REV" ]]; then
  echo "Expected LMS branding revision: $EXPECTED_REV"
else
  echo "Expected LMS branding revision: <skipped>"
fi

if run_with_timeout "${DOCKER_RUN_TIMEOUT_SECS}" docker run --rm \
  -e EXPECTED_LMS_BRANDING_REV="$EXPECTED_REV" \
  "$IMAGE_REF" \
  python - <<'PY'
import json
import os
from pathlib import Path

staticfiles = Path("/openedx/staticfiles/staticfiles.json")
if not staticfiles.exists():
    raise SystemExit("ERROR: /openedx/staticfiles/staticfiles.json missing")

data = json.loads(staticfiles.read_text(encoding="utf-8"))
hashed_css = data["paths"].get("mereka/css/mereka-overrides.css", "MISSING")
print(f"CSS hash: {hashed_css}")
if hashed_css == "MISSING":
    raise SystemExit("ERROR: mereka-overrides.css not found in staticfiles.json")

css_path = Path("/openedx/staticfiles") / hashed_css
if not css_path.exists():
    raise SystemExit(f"ERROR: hashed LMS branding CSS missing: {css_path}")

content = css_path.read_text(encoding="utf-8")
if "--mereka-branding-rev" not in content:
    raise SystemExit("ERROR: LMS branding CSS missing --mereka-branding-rev marker")

expected = os.environ.get("EXPECTED_LMS_BRANDING_REV", "")
if expected and expected not in content:
    raise SystemExit(
        f"ERROR: LMS branding CSS missing expected revision marker: {expected}"
    )

print(f"OK: /openedx/staticfiles/{hashed_css} exists")
PY
then
  :
else
  status=$?
  if [[ "$status" -eq 124 ]]; then
    echo "ERROR: docker run timed out after ${DOCKER_RUN_TIMEOUT_SECS}s for $IMAGE_REF" >&2
  else
    echo "ERROR: branding verification failed with exit code ${status} for $IMAGE_REF" >&2
  fi
  exit "$status"
fi
