#!/usr/bin/env bash
# Render Tutor config and mutate the target-specific build context on standard runners.
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  prepare-tutor-build-context-ci.sh --target all|openedx|mfe
EOF
}

TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

case "$TARGET" in
  all|openedx|mfe) ;;
  *)
    echo "Unsupported or missing target: ${TARGET:-<empty>}" >&2
    usage
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
PLUGIN_SRC_DIR="$REPO_ROOT/infrastructure/tutor/plugins"
PLUGIN_DIR="${TUTOR_PLUGINS_DIR:-$HOME/.local/share/tutor-plugins}"

# Clean ALL stale Tutor state from previous builds on PVC-backed runners.
# Without this, Python's module cache and Tutor's config cache serve stale
# plugin JS content even though the source files were freshly copied.
rm -rf "$TUTOR_ROOT"
rm -rf "$PLUGIN_DIR/__pycache__" "$PLUGIN_DIR/_mereka_lms/__pycache__"
mkdir -p "$TUTOR_ROOT" "$PLUGIN_DIR"

install -m 0644 "$PLUGIN_SRC_DIR/mereka_lms.py" "$PLUGIN_DIR/mereka_lms.py"
install -m 0644 "$PLUGIN_SRC_DIR/mereka_lms_mfe_slots.py" "$PLUGIN_DIR/mereka_lms_mfe_slots.py"
rm -rf "$PLUGIN_DIR/_mereka_lms"
cp -R "$PLUGIN_SRC_DIR/_mereka_lms" "$PLUGIN_DIR/_mereka_lms"

# Diagnostic: verify the shipped split-module runtime has the expected content.
# NOTE: mfe_runtime_definitions.js is DEPRECATED — do not debug against it.
# The shipped source is mfe_runtime/*.js, loaded by mfe_runtime.py.
echo "=== Plugin JS diagnostic (split modules) ==="
echo "Source MerekaAuthnLoginBranding (header-menu.js):"
grep -c 'mereka-authn-login-branding__brand' "$PLUGIN_SRC_DIR/_mereka_lms/mfe_runtime/header-menu.js" || echo "0 (missing)"
echo "Source MEREKA_SITE_VARIANTS (tenant-resolution.js):"
grep -c 'MEREKA_SITE_VARIANTS' "$PLUGIN_SRC_DIR/_mereka_lms/mfe_runtime/tenant-resolution.js" || echo "0 (missing)"
echo "==========================="

tutor plugins enable mereka_lms

case "$TARGET" in
  openedx)
    tutor config save \
      --set LMS_HOST=academyv2.mereka.io \
      --set CMS_HOST=studio.academyv2.mereka.io \
      --set ENABLE_HTTPS=true
    ;;
  mfe)
    tutor config save \
      --set LMS_HOST=academyv2.mereka.io \
      --set MFE_HOST=apps.academyv2.mereka.io \
      --set ENABLE_HTTPS=true
    ;;
  all)
    tutor config save \
      --set LMS_HOST=academyv2.mereka.io \
      --set CMS_HOST=studio.academyv2.mereka.io \
      --set MFE_HOST=apps.academyv2.mereka.io \
      --set ENABLE_HTTPS=true
    ;;
esac

"$REPO_ROOT/scripts/infra/prepare-tutor-build-context.sh" --target "$TARGET"

# Diagnostic: verify the rendered env.config.jsx has the expected component
if [[ -f "$TUTOR_ROOT/env/plugins/mfe/build/mfe/env.config.jsx" ]]; then
  echo "=== Rendered env.config.jsx diagnostic ==="
  grep -c 'mereka-authn-login-branding__brand' "$TUTOR_ROOT/env/plugins/mfe/build/mfe/env.config.jsx" || echo "0 (old component in rendered config!)"
  grep -c 'mereka-shell-panel--authn' "$TUTOR_ROOT/env/plugins/mfe/build/mfe/env.config.jsx" || echo "0 (trimmed, good)"
  echo "==========================="
fi

case "$TARGET" in
  openedx)
    test -f "$TUTOR_ROOT/env/build/openedx/Dockerfile"
    ;;
  mfe)
    test -f "$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
    ;;
  all)
    test -f "$TUTOR_ROOT/env/build/openedx/Dockerfile"
    test -f "$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
    ;;
esac

echo "Prepared Tutor build context for target: $TARGET"
