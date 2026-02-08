#!/usr/bin/env bash
# Validate MFE branding build prerequisites before running long image builds.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

APPLY_PATCH_SCRIPT="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
GENERATED_MFE_DOCKERFILE="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"

PLUGIN_INSTALL_LINE="RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'"
LEGACY_PLUGIN_INSTALL_LINE="RUN npm install '@openedx/frontend-plugin-framework@^1.8.0'"
NODE18_IMAGE_REGEX="(docker.io/)?node:18[-a-z0-9.]*"

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

echo "Verifying MFE build prerequisites..."
echo ""

echo "1. Patch source contract..."
check_contains "apply-patches has plugin dependency function" "$APPLY_PATCH_SCRIPT" "ensure_mfe_plugin_framework_dependency"
check_contains "apply-patches injects plugin dependency line" "$APPLY_PATCH_SCRIPT" "$PLUGIN_INSTALL_LINE"
check_contains "apply-patches normalizes legacy plugin line" "$APPLY_PATCH_SCRIPT" "$LEGACY_PLUGIN_INSTALL_LINE"
check_contains "apply-patches invokes plugin dependency function" "$APPLY_PATCH_SCRIPT" "updated = ensure_mfe_plugin_framework_dependency(updated)"

echo ""
echo "2. Generated Dockerfile contract..."
if [[ -f "$GENERATED_MFE_DOCKERFILE" ]]; then
  check_contains_regex "generated Dockerfile uses Node 18 image" "$GENERATED_MFE_DOCKERFILE" "$NODE18_IMAGE_REGEX"
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
