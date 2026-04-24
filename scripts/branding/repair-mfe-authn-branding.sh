#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MFE_THEME_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"

usage() {
  cat <<'EOF'
Usage: scripts/branding/repair-mfe-authn-branding.sh <source_image> <target_image> [expected_mfe_branding_rev]

Description:
  Repairs an MFE image when authn index references an unbranded CSS bundle.
  The script rewires /openedx/dist/authn/index.html to the branded CSS bundle,
  injects --mereka-mfe-branding-rev when missing, then verifies the result.

Environment:
  PUSH_IMAGE=1   Push target image after successful repair (default: 0)

Examples:
  scripts/branding/repair-mfe-authn-branding.sh \
    ghcr.io/biji-biji-initiative/mereka-lms/mfe:src \
    ghcr.io/biji-biji-initiative/mereka-lms/mfe:fixed

  PUSH_IMAGE=1 scripts/branding/repair-mfe-authn-branding.sh \
    ghcr.io/biji-biji-initiative/mereka-lms/mfe:src \
    ghcr.io/biji-biji-initiative/mereka-lms/mfe:fixed \
    2026-02-07-pass3
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 1
fi

SOURCE_IMAGE="$1"
TARGET_IMAGE="$2"
EXPECTED_REV="${3:-}"
PUSH_IMAGE="${PUSH_IMAGE:-0}"

if [[ -z "$EXPECTED_REV" && -f "$MFE_THEME_SCSS" ]]; then
  EXPECTED_REV="$(sed -nE 's/.*--mereka-mfe-branding-rev:[[:space:]]*"([^"]+)".*/\1/p' "$MFE_THEME_SCSS" | head -n 1 || true)"
fi

if [[ -z "$EXPECTED_REV" ]]; then
  echo "ERROR: Could not determine expected MFE branding revision." >&2
  echo "Pass it explicitly as the third argument." >&2
  exit 1
fi

if ! docker image inspect "$SOURCE_IMAGE" >/dev/null 2>&1; then
  echo "ERROR: Source image not found locally: $SOURCE_IMAGE" >&2
  exit 1
fi

tmp_dockerfile="$(mktemp /tmp/mfe-authn-repair.XXXXXX.Dockerfile)"
cleanup() {
  rm -f "$tmp_dockerfile"
}
trap cleanup EXIT

cat >"$tmp_dockerfile" <<EOF
FROM $SOURCE_IMAGE

RUN set -euo pipefail; \\
    cd /openedx/dist/authn; \\
    current_css="\$(grep -o 'app\\.[^\"]*\\.css' index.html | head -n 1 || true)"; \\
    themed_css="\$(grep -l -- '--mereka-mfe-gradient' app.*.css | head -n 1 || true)"; \\
    themed_css="\${themed_css##./}"; \\
    [ -n "\${current_css}" ] && [ -n "\${themed_css}" ]; \\
    if [ "\${current_css}" != "\${themed_css}" ]; then \\
      sed -i "s/\${current_css}/\${themed_css}/g" index.html; \\
    fi; \\
    if ! grep -q -- '--mereka-mfe-branding-rev' "\${themed_css}"; then \\
      printf '\\n:root{--mereka-mfe-branding-rev:"$EXPECTED_REV"}\\n' >> "\${themed_css}"; \\
    fi
EOF

echo "Building repaired MFE image:"
echo "  source: $SOURCE_IMAGE"
echo "  target: $TARGET_IMAGE"
echo "  expected revision: $EXPECTED_REV"
docker build -f "$tmp_dockerfile" -t "$TARGET_IMAGE" /tmp

"$REPO_ROOT/scripts/qa/verify-mfe-image-branding.sh" "$TARGET_IMAGE" "$EXPECTED_REV"

if [[ "$PUSH_IMAGE" == "1" ]]; then
  echo "Pushing repaired image: $TARGET_IMAGE"
  docker push "$TARGET_IMAGE"
fi

echo "Repair complete."

