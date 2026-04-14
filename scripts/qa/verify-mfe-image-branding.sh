#!/usr/bin/env bash
# @covers AC-001
# @spec: tutor-configuration_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MFE_THEME_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"

usage() {
  cat <<'EOF'
Usage: scripts/qa/verify-mfe-image-branding.sh <image_ref> [expected_mfe_branding_rev]

Examples:
  scripts/qa/verify-mfe-image-branding.sh ghcr.io/biji-biji-initiative/mereka-lms/mfe:TAG
  scripts/qa/verify-mfe-image-branding.sh ghcr.io/biji-biji-initiative/mereka-lms/mfe:TAG 2026-02-07-pass3
EOF
}

if [[ $# -eq 0 ]]; then
  echo "SKIP: No image_ref provided"
  echo "  Usage: $0 <image_ref> [expected_mfe_branding_rev]"
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

if [[ -z "$EXPECTED_REV" && -f "$MFE_THEME_SCSS" ]]; then
  EXPECTED_REV="$(sed -nE 's/.*--mereka-mfe-branding-rev:[[:space:]]*"([^"]+)".*/\1/p' "$MFE_THEME_SCSS" | head -n 1 || true)"
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

echo "Verifying MFE image branding: $IMAGE_REF"
if [[ -n "$EXPECTED_REV" ]]; then
  echo "Expected MFE branding revision: $EXPECTED_REV"
else
  echo "Expected MFE branding revision: <skipped>"
fi

if run_with_timeout "${DOCKER_RUN_TIMEOUT_SECS}" docker run --rm \
  -e EXPECTED_MFE_BRANDING_REV="$EXPECTED_REV" \
  --entrypoint sh \
  "$IMAGE_REF" \
  -lc '
    set -euo pipefail
    cd /openedx/dist/authn

    css_refs="$(grep -Eo '\''href="[^"]+\.css"'\'' index.html \
      | sed -E '\''s/^href="([^"]+)"$/\1/'\'' \
      | sed -E '\''s#^/authn/##'\'' \
      | awk '\''!seen[$0]++'\'' || true)"

    if [ -z "${css_refs}" ]; then
      echo "ERROR: authn index.html missing CSS references" >&2
      exit 1
    fi

    missing_refs=""
    for css_ref in $css_refs; do
      if [ ! -f "$css_ref" ]; then
        missing_refs="$missing_refs $css_ref"
      fi
    done
    if [ -n "$missing_refs" ]; then
      echo "ERROR: authn index references missing CSS file(s):$missing_refs" >&2
      exit 1
    fi

    candidate_refs="$(printf "%s\n" "$css_refs" | grep -E "^app\\..*\\.css$" || true)"
    if [ -z "$candidate_refs" ]; then
      candidate_refs="$(printf "%s\n" "$css_refs" | head -n 1)"
    fi

    branded_count=0
    revision_count=0
    unbranded_refs=""
    for css_ref in $candidate_refs; do
      if grep -Eq -- '\''--mereka-mfe-gradient|--mereka-gradient-primary|--mereka-font-body|font-family:Poppins'\'' "$css_ref"; then
        branded_count=$((branded_count + 1))
        if [ -n "${EXPECTED_MFE_BRANDING_REV:-}" ] && grep -F -q -- "${EXPECTED_MFE_BRANDING_REV}" "$css_ref"; then
          revision_count=$((revision_count + 1))
        fi
      else
        unbranded_refs="$unbranded_refs $css_ref"
      fi
    done

    if [ "$branded_count" -eq 0 ]; then
      echo "ERROR: authn candidate CSS bundle(s) are not branded: $candidate_refs" >&2
      exit 1
    fi

    if [ -n "$unbranded_refs" ]; then
      echo "ERROR: authn index references unbranded candidate CSS bundle(s):$unbranded_refs" >&2
      exit 1
    fi

    if [ -n "${EXPECTED_MFE_BRANDING_REV:-}" ] && [ "$revision_count" -eq 0 ]; then
      echo "ERROR: authn candidate CSS bundles missing expected branding revision marker: ${EXPECTED_MFE_BRANDING_REV}" >&2
      exit 1
    fi

    echo "OK: authn index candidate CSS bundles are branded ($candidate_refs)"

    # Verify PARAGON_THEME brand URLs are non-empty in index.html.
    # The mereka_lms plugin mfe-dockerfile-post-npm-build hook patches this.
    # If the plugin was not loaded during build, brand URLs are empty objects.
    # The rendered shape may be either a direct object literal or an IIFE.
    paragon_block="$(tr "\\n" " " < index.html)"
    if ! printf "%s" "$paragon_block" | grep -q "var PARAGON_THEME = "; then
      echo "WARN: No PARAGON_THEME variable found in authn/index.html"
    else
      if printf "%s" "$paragon_block" | grep -qE "var PARAGON_THEME = .*\"/theme/[^\"]+\\.css\""; then
        echo "OK: PARAGON_THEME brand URLs contain absolute /theme CSS references"
      elif printf "%s" "$paragon_block" | grep -qE "var PARAGON_THEME = .*\"\\.\\./theme/[^\"]+\\.css\""; then
        echo "ERROR: PARAGON_THEME still uses relative ../theme CSS references (broken on route-prefixed MFEs)" >&2
        exit 1
      else
        echo "ERROR: PARAGON_THEME brand URLs are empty (plugin hook did not fire during build)" >&2
        echo "  Ensure mereka_lms plugin is enabled before tutor images build mfe" >&2
        exit 1
      fi
    fi
  '
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
