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

    css_file="$(grep -o '\''app\.[^"]*\.css'\'' index.html | head -n 1 || true)"
    if [[ -z "$css_file" ]]; then
      echo "ERROR: authn index.html missing app CSS reference" >&2
      exit 1
    fi
    if [[ ! -f "$css_file" ]]; then
      echo "ERROR: authn CSS file referenced by index is missing: $css_file" >&2
      exit 1
    fi

    if ! grep -Eq -- '\''--mereka-mfe-gradient|--mereka-gradient-primary|--mereka-font-body|font-family:Poppins'\'' "$css_file"; then
      echo "ERROR: authn CSS is not branded: $css_file" >&2
      exit 1
    fi

    if [[ -n "${EXPECTED_MFE_BRANDING_REV:-}" ]] && ! grep -F -q -- "${EXPECTED_MFE_BRANDING_REV}" "$css_file"; then
      echo "ERROR: authn CSS missing expected branding revision marker: ${EXPECTED_MFE_BRANDING_REV}" >&2
      exit 1
    fi

    echo "OK: authn index CSS is branded ($css_file)"
  '

