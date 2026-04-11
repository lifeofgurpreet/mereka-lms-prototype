#!/usr/bin/env bash
# Apply local adjustments to Tutor templates until upstream catches up.
# This script sources modular patch functions from infrastructure/tutor/patches/
# and applies them by target. Each patch is idempotent (safe to run multiple times).
# Operator note: for local iteration and CI build prep, use
# `./scripts/infra/prepare-tutor-build-context.sh --target <openedx|mfe|all>`
# as the front door. This script remains the compatibility implementation detail
# because existing verifiers still inspect its patch wiring directly.
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  apply-patches.sh [--target all|openedx|mfe]
EOF
}

TARGET="${MEREKA_BUILD_TARGET:-all}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      TARGET="$2"
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
    echo "Unsupported target: $TARGET" >&2
    usage
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCHES_DIR="$REPO_ROOT/infrastructure/tutor/patches"

# Source shared setup (venv activation, template path discovery)
source "$PATCHES_DIR/_common.sh"

# Run branding health check if available
BRANDING_CHECK="$REPO_ROOT/scripts/branding/verify-branding-health.sh"
if [[ -x "$BRANDING_CHECK" ]]; then
  "$BRANDING_CHECK"
fi

# Source all patch modules
# NOTE: MFE node patch module removed in tracker #32; all MFE Dockerfile
# patches are now handled by Tutor plugin hooks in _mereka_lms/mfe_dockerfile.py.
source "$PATCHES_DIR/brand-package.sh"
source "$PATCHES_DIR/webpack-memory.sh"
source "$PATCHES_DIR/footer-component.sh"
source "$PATCHES_DIR/mfe-slot-ownership.sh"
source "$PATCHES_DIR/build-optimizations.sh"

apply_patch() {
  local fn="$1"
  echo "  Applying: $fn ..."
  if "$fn"; then
    echo "  OK: $fn"
  else
    echo "  FAILED: $fn (exit $?)" >&2
    exit 1
  fi
}

sync_openedx_theme() {
  local tutor_theme_dir="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/build/openedx/themes/mereka"
  local mereka_theme_src="$REPO_ROOT/infrastructure/tutor/themes/mereka"

  if [[ -d "$mereka_theme_src" ]]; then
    mkdir -p "$tutor_theme_dir"
    cp -R "$mereka_theme_src/." "$tutor_theme_dir/"
    echo "Synced Mereka theme to Open edX build context: $tutor_theme_dir"
  else
    echo "WARNING: Mereka theme source not found at $mereka_theme_src"
  fi
}

sync_mfe_patch_helpers() {
  local tutor_mfe_build_dir="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/plugins/mfe/build/mfe"
  mkdir -p "$tutor_mfe_build_dir"
  cp "$PATCHES_DIR/patch-authn-deep-route-handoff.py" \
    "$tutor_mfe_build_dir/patch-authn-deep-route-handoff.py"
  echo "Synced authn deep-route patch helper to MFE build context: $tutor_mfe_build_dir"
}

sync_mfe_theme() {
  # RCB-10 root cause fix — two parts:
  #
  # Part 1: copy Paragon/brand theme CSS + logo assets into the MFE build
  # context at tutor_env/env/plugins/mfe/build/mfe/indigo/theme/ so any
  # `COPY indigo/theme /openedx/dist/theme` in the rendered Dockerfile has
  # source files to copy.
  #
  # Part 2: inject `COPY indigo/theme /openedx/dist/theme` into the FINAL
  # production stage of the rendered Dockerfile. CI's tutor-mfe render
  # does NOT include this COPY in the production stage (verified from
  # artifact download 2026-04-11) even though the base tutor-mfe template
  # source contains it — different tutor-mfe patch version or Jinja state.
  # So we sed-inject after `RUN mkdir -p /openedx/dist` in the production
  # stage to guarantee the files land in the final image.
  #
  # Without this fix: /theme/core.min.css returns HTTP 404 on the apps.<tenant>
  # host, Chrome refuses to apply an empty-MIME response as a stylesheet, the
  # Paragon theme init script throws, and Profile/Discussions/Communications
  # silently render a React error boundary ("An unexpected error occurred").
  # See memory file rcb-10-mfe-error-boundary.md for full diagnosis.
  local tutor_mfe_indigo_dir="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/plugins/mfe/build/mfe/indigo"
  local mereka_mfe_theme_src="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme"
  local rendered_dockerfile="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/plugins/mfe/build/mfe/Dockerfile"

  if [[ ! -d "$mereka_mfe_theme_src" ]]; then
    echo "WARNING: Mereka MFE theme source not found at $mereka_mfe_theme_src" >&2
    return 0
  fi

  mkdir -p "$tutor_mfe_indigo_dir/theme"
  cp -R "$mereka_mfe_theme_src/." "$tutor_mfe_indigo_dir/theme/"
  echo "Synced Mereka MFE theme assets to MFE build context: $tutor_mfe_indigo_dir/theme"

  if [[ ! -f "$rendered_dockerfile" ]]; then
    echo "WARNING: Rendered MFE Dockerfile not found at $rendered_dockerfile — skip inject" >&2
    return 0
  fi

  # Idempotent: only inject if the production stage doesn't already have the COPY.
  # Detect by looking at the last ~30 lines (the production stage tail).
  if tail -40 "$rendered_dockerfile" | grep -q "COPY indigo/theme /openedx/dist/theme"; then
    echo "MFE Dockerfile production stage already has COPY indigo/theme — skip inject"
    return 0
  fi

  # Inject directly after `RUN mkdir -p /openedx/dist` (first occurrence in the
  # production stage, which is the last occurrence in the file since `RUN mkdir`
  # only appears once in the final caddy stage).
  python3 - <<PY "$rendered_dockerfile"
import sys
from pathlib import Path
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
# Split on the production stage marker, then inject after the first RUN mkdir
marker = "FROM docker.io/caddy:2.7.4 AS production"
if marker not in text:
    # Try the templated form as a fallback
    import re
    m = re.search(r"^FROM\s+\S+\s+AS\s+production\s*$", text, re.MULTILINE)
    if not m:
        print("ERROR: could not find production stage in rendered Dockerfile", file=sys.stderr)
        sys.exit(1)
    marker = m.group(0)

before, _, after = text.partition(marker)
# Find the first RUN mkdir inside the production stage
after_lines = after.split("\n")
for i, line in enumerate(after_lines):
    if line.strip().startswith("RUN mkdir -p /openedx/dist"):
        inject = (
            "COPY indigo/theme /openedx/dist/theme\n"
            "# RCB-10 fix: injected by apply-patches.sh sync_mfe_theme "
            "because CI's tutor-mfe render drops this COPY\n"
        )
        after_lines.insert(i + 1, inject)
        break
else:
    print("ERROR: no RUN mkdir -p /openedx/dist in production stage", file=sys.stderr)
    sys.exit(1)

p.write_text(before + marker + "\n".join(after_lines), encoding="utf-8")
print("Injected COPY indigo/theme into production stage of rendered MFE Dockerfile")
PY
}

wrap_mfe_pull_translations_retry() {
  # CI reliability fix — DinD/BuildKit DNS to github.com intermittently fails
  # during the MFE build, causing `make OPENEDX_ATLAS_PULL=true ... pull_translations`
  # to abort with:
  #   fatal: unable to access 'https://github.com/openedx/openedx-translations.git/':
  #   Could not resolve host: github.com
  #
  # Complementary to PR #1567 (trivy bootstrap retry), #1568 (MFE git fetch retry
  # at workflow level), and #1569 (stop rewriting DinD MTU). Those fix the
  # runner-side surface; this wraps the actual in-container RUN layer with a
  # bash retry loop so transient DNS blips inside the docker build don't take
  # down a 45-minute cold build at layer 155.
  #
  # Post-render sed-wrap each `RUN make OPENEDX_ATLAS_PULL=true ... pull_translations`
  # with: RUN for i in 1 2 3; do <cmd> && exit 0; sleep 15; done; exit 1
  local rendered_dockerfile="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}/env/plugins/mfe/build/mfe/Dockerfile"

  if [[ ! -f "$rendered_dockerfile" ]]; then
    echo "WARNING: Rendered MFE Dockerfile not found at $rendered_dockerfile — skip retry wrap" >&2
    return 0
  fi

  if grep -q "pull_translations_retry_sentinel" "$rendered_dockerfile"; then
    echo "MFE Dockerfile pull_translations already wrapped with retry — skip"
    return 0
  fi

  python3 - <<'PY' "$rendered_dockerfile"
import re
import sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")

pattern = re.compile(
    r'^RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="([^"]*)" pull_translations\s*$',
    re.MULTILINE,
)

def wrap(match):
    atlas_opts = match.group(1)
    cmd = (
        f'make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="{atlas_opts}" pull_translations'
    )
    return (
        "# pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry\n"
        "RUN bash -o pipefail -c 'for attempt in 1 2 3; do "
        f"{cmd} && exit 0; "
        "echo \"pull_translations attempt ${attempt} failed; retrying in 15s\" >&2; "
        "sleep 15; done; exit 1'"
    )

new_text, count = pattern.subn(wrap, text)
if count == 0:
    print("No pull_translations lines matched — nothing to wrap", file=sys.stderr)
    sys.exit(0)

p.write_text(new_text, encoding="utf-8")
print(f"Wrapped {count} pull_translations RUN line(s) with retry loop")
PY
}

apply_openedx_patches() {
  apply_patch apply_webpack_memory_patch
  apply_patch apply_build_optimizations_patch
  sync_openedx_theme
}

apply_mfe_patches() {
  apply_patch apply_brand_package_patch
  apply_patch apply_footer_component_patch
  apply_patch apply_mfe_slot_ownership_patch
  sync_mfe_patch_helpers
  sync_mfe_theme
  wrap_mfe_pull_translations_retry
}

case "$TARGET" in
  openedx)
    apply_openedx_patches
    ;;
  mfe)
    apply_mfe_patches
    ;;
  all)
    apply_openedx_patches
    apply_mfe_patches
    ;;
esac

echo "Applied Tutor patches for target: $TARGET"

