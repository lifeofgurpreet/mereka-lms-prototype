#!/usr/bin/env bash
# @covers AC-001
# @spec: tutor-configuration_spec.md
# Validate MFE branding build prerequisites before running long image builds.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

APPLY_PATCH_SCRIPT="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
# mfe-node.sh removed in tracker #32; MFE Dockerfile hooks now live in the plugin
PATCH_MODULE="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py"
SLOT_OWNERSHIP_PATCH="$REPO_ROOT/infrastructure/tutor/patches/mfe-slot-ownership.sh"
SLOT_OWNERSHIP_HELPER="$REPO_ROOT/infrastructure/tutor/patches/mfe_slot_ownership.py"
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

check_jsx_parse() {
  local label="$1"
  local path="$2"
  if [[ ! -f "$path" ]]; then
    echo "  ✗ $label (missing file: $path)"
    failures=1
    return
  fi

  if [[ ! -d "$REPO_ROOT/node_modules/acorn" || ! -d "$REPO_ROOT/node_modules/acorn-jsx" ]]; then
    echo "  ! $label (acorn parser unavailable locally; skipped)"
    return
  fi

  if node - "$path" <<'NODE'
const fs = require('fs');
const acorn = require('./node_modules/acorn');
const jsx = require('./node_modules/acorn-jsx');
const Parser = acorn.Parser.extend(jsx());
const path = process.argv[2];
const src = fs.readFileSync(path, 'utf8');
Parser.parse(src, { ecmaVersion: 'latest', sourceType: 'module' });
NODE
  then
    echo "  ✓ $label"
  else
    echo "  ✗ $label (syntax parse failed: $path)"
    failures=1
  fi
}

echo "Verifying MFE build prerequisites..."
echo ""

echo "1. Patch source contract..."
# mfe-node.sh was removed in tracker #32; verify it is absent from apply-patches.sh
if grep -q 'mfe-node.sh' "$APPLY_PATCH_SCRIPT" 2>/dev/null; then
  echo "  ✗ apply-patches.sh still references removed mfe-node.sh (tracker #32)"
  failures=1
else
  echo "  ✓ apply-patches.sh does not reference deprecated mfe-node.sh"
fi
check_contains "apply-patches sources MFE slot ownership patch" "$APPLY_PATCH_SCRIPT" "source \"\$PATCHES_DIR/mfe-slot-ownership.sh\""
check_contains "apply-patches applies MFE slot ownership patch" "$APPLY_PATCH_SCRIPT" "apply_mfe_slot_ownership_patch"
# Plugin module now carries all MFE Dockerfile hooks (tracker #32)
check_contains "plugin module defines pre-npm-install hook" "$PATCH_MODULE" "mfe-dockerfile-pre-npm-install"
check_contains "plugin module defines post-npm-install hook" "$PATCH_MODULE" "mfe-dockerfile-post-npm-install"
check_contains "plugin module installs frontend-plugin-framework" "$PATCH_MODULE" "frontend-plugin-framework@^1.8.0"
check_contains "plugin module overlays local brand package" "$PATCH_MODULE" "node_modules/@edx/brand"
check_contains "slot ownership shell delegates to Python helper" "$SLOT_OWNERSHIP_PATCH" "mfe_slot_ownership.py"
check_contains "slot ownership helper defines strip_slot_ownership" "$SLOT_OWNERSHIP_HELPER" "def strip_slot_ownership("
check_contains_any_file "plugin injects plugin dependency line" "$PLUGIN_INSTALL_LINE" "$PATCH_MODULE"

echo ""
echo "2. Generated Dockerfile contract..."
if [[ -f "$GENERATED_MFE_DOCKERFILE" ]]; then
  check_contains_regex "generated Dockerfile uses supported Node image" "$GENERATED_MFE_DOCKERFILE" "$NODE_IMAGE_REGEX"
  check_contains "generated Dockerfile contains plugin install line" "$GENERATED_MFE_DOCKERFILE" "$PLUGIN_INSTALL_LINE"
  check_contains "generated Dockerfile hardens base-stage apt retries" "$GENERATED_MFE_DOCKERFILE" 'Acquire::Retries "6"'
  check_contains "generated Dockerfile hardens base-stage apt https timeout" "$GENERATED_MFE_DOCKERFILE" 'Acquire::https::Timeout "30"'
  check_contains "generated Dockerfile forces IPv4 for apt" "$GENERATED_MFE_DOCKERFILE" 'Acquire::ForceIPv4 "true"'
  check_contains "generated Dockerfile uses fix-missing apt install" "$GENERATED_MFE_DOCKERFILE" '--fix-missing git'

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

  if grep -Fq -- "@edx/brand@github:@edly-io/brand-openedx#indigo-2.5.0" "$GENERATED_MFE_DOCKERFILE"; then
    echo "  ✗ generated Dockerfile still contains git-based tutor-indigo brand install"
    failures=1
  else
    echo "  ✓ generated Dockerfile has no git-based tutor-indigo brand install"
  fi

  if grep -Fq -- '--fix-broken git' "$GENERATED_MFE_DOCKERFILE"; then
    echo "  ✗ generated Dockerfile still contains stale base-stage apt bootstrap"
    failures=1
  else
    echo "  ✓ generated Dockerfile has no stale base-stage apt bootstrap"
  fi

  if grep -Fq -- "@edly-io/indigo-brand-openedx@^2.4.2" "$GENERATED_MFE_DOCKERFILE"; then
    echo "  ✓ generated Dockerfile rewrites tutor-indigo brand install to npm package"
  else
    echo "  ✗ generated Dockerfile missing npm-published tutor-indigo brand install"
    failures=1
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

  check_jsx_parse "generated env.config.jsx parses as JSX" "$GENERATED_MFE_BUILD_DIR/env.config.jsx"
  check_jsx_parse "generated indigo/env.config.jsx parses as JSX" "$GENERATED_MFE_INDIGO_ENV"
else
  if [[ "$REQUIRE_GENERATED_DOCKERFILE" == "1" ]]; then
    echo "  ✗ generated Dockerfile missing: $GENERATED_MFE_DOCKERFILE"
    failures=1
  else
    echo "  ! generated Dockerfile missing (skipping runtime contract)"
    echo "    Run ./scripts/infra/prepare-tutor-build-context.sh --target mfe to regenerate Tutor build artifacts."
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
echo "  1. Run: ./scripts/infra/prepare-tutor-build-context.sh --target mfe"
echo "  2. Re-run: ./scripts/qa/verify-mfe-build-prereqs.sh"
echo "  3. Then run branding gates: ./scripts/branding/run-branding-gates.sh prod"
exit 1
