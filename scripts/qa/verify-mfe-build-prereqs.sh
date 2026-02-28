#!/usr/bin/env bash
# @covers AC-001
# @spec: tutor-configuration_spec.md
# Validate MFE branding build prerequisites before running long image builds.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

APPLY_PATCH_SCRIPT="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
PATCH_MODULE="$REPO_ROOT/infrastructure/tutor/patches/mfe-node.sh"
GENERATED_MFE_DOCKERFILE="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
GENERATED_MFE_BUILD_DIR="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe"
GENERATED_MFE_INDIGO_DIR="$GENERATED_MFE_BUILD_DIR/indigo"
GENERATED_MFE_INDIGO_ENV="$GENERATED_MFE_INDIGO_DIR/env.config.jsx"
GENERATED_MFE_INDIGO_THEME_DIR="$GENERATED_MFE_INDIGO_DIR/mereka"

PLUGIN_INSTALL_LINE="RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'"
LEGACY_PLUGIN_INSTALL_LINE="RUN npm install '@openedx/frontend-plugin-framework@^1.8.0'"
NODE_IMAGE_REGEX="(docker.io/)?node:(18|24|20)[-a-z0-9.]*"

REQUIRE_GENERATED_DOCKERFILE="${REQUIRE_GENERATED_DOCKERFILE:-0}"
failures=0

check_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  if [[ ! -f "$path" ]]; then
    echo "  ✗ $label (missing file: $path)"
    failures=1
    return
  fi
  if grep -Fq -- "$needle" "$path"; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label (missing: $needle)"
    failures=1
  fi
}

check_contains_regex() {
  local label="$1"
  local path="$2"
  local pattern="$3"
  if [[ ! -f "$path" ]]; then
    echo "  ✗ $label (missing file: $path)"
    failures=1
    return
  fi
  if grep -Eq -- "$pattern" "$path"; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label (missing regex: $pattern)"
    failures=1
  fi
}

check_contains_any_file() {
  local label="$1"
  local needle="$2"
  shift 2
  local path
  for path in "$@"; do
    if [[ ! -f "$path" ]]; then
      continue
    fi
    if grep -Fq -- "$needle" "$path"; then
      echo "  ✓ $label"
      return
    fi
  done

  echo "  ✗ $label (missing: $needle)"
  failures=1
}

echo "Verifying MFE build prerequisites..."
echo ""

echo "1. Patch source contract..."
check_contains "apply-patches sources MFE patch module" "$APPLY_PATCH_SCRIPT" "source \"\$PATCHES_DIR/mfe-node.sh\""
check_contains "apply-patches applies MFE node patch" "$APPLY_PATCH_SCRIPT" "apply_mfe_node_patch"
check_contains "mfe-node patch defines plugin dependency helper" "$PATCH_MODULE" "def ensure_mfe_plugin_framework_dependency(text):"
check_contains_any_file "mfe-node patch injects legacy-to-legacy-peer line" "$LEGACY_PLUGIN_INSTALL_LINE" "$PATCH_MODULE"
check_contains_any_file "mfe-node patch injects plugin dependency line" "$PLUGIN_INSTALL_LINE" "$PATCH_MODULE"
check_contains_any_file "mfe-node patch invokes plugin dependency helper" "updated = ensure_mfe_plugin_framework_dependency(updated)" "$PATCH_MODULE" "$APPLY_PATCH_SCRIPT"

echo ""
echo "2. Generated Dockerfile contract..."
if [[ -f "$GENERATED_MFE_DOCKERFILE" ]]; then
  check_contains_regex "generated Dockerfile uses supported Node image" "$GENERATED_MFE_DOCKERFILE" "$NODE_IMAGE_REGEX"
  check_contains "generated Dockerfile contains plugin install line" "$GENERATED_MFE_DOCKERFILE" "$PLUGIN_INSTALL_LINE"

  plugin_count="$(grep -F -- "$PLUGIN_INSTALL_LINE" "$GENERATED_MFE_DOCKERFILE" | wc -l | tr -d ' ')"
  if [[ "${plugin_count:-0}" -ge 1 ]]; then
    echo "  ✓ generated Dockerfile plugin install occurrences: ${plugin_count}"
  else
    echo "  ✗ generated Dockerfile plugin install occurrences: 0"
    failures=1
  fi

  if grep -Fq -- "$LEGACY_PLUGIN_INSTALL_LINE" "$GENERATED_MFE_DOCKERFILE"; then
    echo "  ✗ generated Dockerfile still contains legacy plugin install line"
    failures=1
  else
    echo "  ✓ generated Dockerfile has no legacy plugin install line"
  fi

  if [[ -d "$GENERATED_MFE_INDIGO_DIR" ]]; then
    echo "  ✓ generated Indigo build directory exists"
  else
    echo "  ✗ generated Indigo build directory missing: $GENERATED_MFE_INDIGO_DIR"
    failures=1
  fi

  if [[ -f "$GENERATED_MFE_INDIGO_ENV" ]]; then
    echo "  ✓ generated indigo/env.config.jsx exists"
  else
    echo "  ✗ generated indigo/env.config.jsx missing: $GENERATED_MFE_INDIGO_ENV"
    failures=1
  fi

  if [[ -d "$GENERATED_MFE_INDIGO_THEME_DIR" ]]; then
    echo "  ✓ generated indigo/mereka theme directory exists"
  else
    echo "  ✗ generated indigo/mereka theme directory missing: $GENERATED_MFE_INDIGO_THEME_DIR"
    failures=1
  fi
else
  if [[ "$REQUIRE_GENERATED_DOCKERFILE" == "1" ]]; then
    echo "  ✗ generated Dockerfile missing: $GENERATED_MFE_DOCKERFILE"
    failures=1
  else
    echo "  ! generated Dockerfile missing (skipping runtime contract)"
    echo "    Run ./infrastructure/tutor/apply-patches.sh to regenerate Tutor build artifacts."
  fi
fi

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ MFE build prerequisites check passed."
  exit 0
fi

echo "✗ MFE build prerequisites check failed."
echo ""
echo "Fixes:"
echo "  1. Run: ./infrastructure/tutor/apply-patches.sh"
echo "  2. Re-run: ./scripts/qa/verify-mfe-build-prereqs.sh"
echo "  3. Then run branding gates: ./scripts/branding/run-branding-gates.sh prod"
exit 1
