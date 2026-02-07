#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MFE_THEME_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"

usage() {
  cat <<'EOF'
Usage: scripts/qa/verify-mfe-image-branding.sh <image_ref> [expected_mfe_branding_rev]

Examples:
  scripts/qa/verify-mfe-image-branding.sh asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:TAG
  scripts/qa/verify-mfe-image-branding.sh asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:TAG 2026-02-07-pass3
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

IMAGE_REF="$1"
EXPECTED_REV="${2:-}"

if [[ -z "$EXPECTED_REV" && -f "$MFE_THEME_SCSS" ]]; then
  EXPECTED_REV="$(sed -nE 's/.*--mereka-mfe-branding-rev:[[:space:]]*"([^"]+)".*/\1/p' "$MFE_THEME_SCSS" | head -n 1 || true)"
fi

if ! docker image inspect "$IMAGE_REF" >/dev/null 2>&1; then
  echo "ERROR: Image not found locally: $IMAGE_REF" >&2
  exit 1
fi

echo "Verifying MFE image branding: $IMAGE_REF"
if [[ -n "$EXPECTED_REV" ]]; then
  echo "Expected MFE branding revision: $EXPECTED_REV"
else
  echo "Expected MFE branding revision: <skipped>"
fi

docker run --rm \
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
  '
