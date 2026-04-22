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
PRUNE_DEPRECATED_SHELLS_PATCH="$REPO_ROOT/infrastructure/tutor/patches/mfe-prune-deprecated-shells.sh"
PRUNE_DEPRECATED_SHELLS_HELPER="$REPO_ROOT/infrastructure/tutor/patches/mfe_prune_deprecated_shells.py"
GENERATED_MFE_DOCKERFILE="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
GENERATED_MFE_BUILD_DIR="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe"
SNAPSHOT_MFE_DOCKERFILE="$REPO_ROOT/infrastructure/tutor/mfe-build/Dockerfile"
ACTIVE_MFE_DOCKERFILE_PATH="tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
LEGACY_MFE_DOCKERFILE_PATH="tutor_env/env/build/mfe/Dockerfile"
GENERATED_MFE_MEREKA_DIR="$GENERATED_MFE_BUILD_DIR/mereka"
GENERATED_MFE_MEREKA_ENV="$GENERATED_MFE_MEREKA_DIR/env.config.jsx"
GENERATED_MFE_MEREKA_THEME_DIR="$GENERATED_MFE_MEREKA_DIR/theme-source"
RENDERED_MFE_DOCKERFILE_TARGET='/env/plugins/mfe/build/mfe/Dockerfile'

PLUGIN_INSTALL_LINE="RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'"
LEGACY_PLUGIN_INSTALL_LINE="RUN npm install '@openedx/frontend-plugin-framework@^1.8.0'"
REDUX_INSTALL_LINE="RUN npm install --legacy-peer-deps 'react-redux@^8.1.3' 'redux@^4.2.1'"
PAYMENT_REACT_INTL_INSTALL_LINE="RUN npm install --legacy-peer-deps 'react-intl@^6.4.0'"
NODE_IMAGE_REGEX="(docker.io/)?node:24[-a-z0-9.]*"
PULL_TRANSLATIONS_RETRY_SENTINEL="pull_translations_retry_sentinel — apply-patches.sh wrap_mfe_pull_translations_retry"
PULL_TRANSLATIONS_RETRY_FRAGMENT='pull_translations attempt ${attempt} failed; retrying in 15s'
PULL_TRANSLATIONS_WRAP_FRAGMENT="RUN bash -o pipefail -c 'for attempt in 1 2 3; do "
RAW_PULL_TRANSLATIONS_REGEX='^RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="[^"]*" pull_translations$'

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

check_no_legacy_mfe_render_path_refs() {
  local hits
  hits="$(cd "$REPO_ROOT" && rg -n --fixed-strings "$LEGACY_MFE_DOCKERFILE_PATH" scripts/ci scripts/infra scripts/qa .github/workflows infrastructure/tutor -g '!docs/**' -g '!scripts/qa/verify-mfe-build-prereqs.sh' || true)"
  if [[ -z "$hits" ]]; then
    echo "  ✓ active build/QA surfaces do not reference legacy $LEGACY_MFE_DOCKERFILE_PATH"
  else
    echo "  ✗ legacy MFE rendered Dockerfile path leaked into active build/QA surfaces:"
    printf '%s\n' "$hits" | sed 's/^/    /'
    failures=1
  fi
}

check_snapshot_parity() {
  if [[ ! -f "$SNAPSHOT_MFE_DOCKERFILE" ]]; then
    echo "  ✗ tracked MFE Dockerfile snapshot missing: $SNAPSHOT_MFE_DOCKERFILE"
    failures=1
    return
  fi

  echo "  ✓ tracked MFE Dockerfile snapshot exists: infrastructure/tutor/mfe-build/Dockerfile"

  if [[ ! -f "$GENERATED_MFE_DOCKERFILE" ]]; then
    return
  fi

  if cmp -s "$GENERATED_MFE_DOCKERFILE" "$SNAPSHOT_MFE_DOCKERFILE"; then
    echo "  ✓ generated Dockerfile matches tracked snapshot"
    return
  fi

  echo "  ✗ generated Dockerfile diverges from tracked snapshot"
  diff -u "$SNAPSHOT_MFE_DOCKERFILE" "$GENERATED_MFE_DOCKERFILE" | sed -n '1,40p' | sed 's/^/    /' || true
  failures=1
}

check_generated_production_theme_copy() {
  if [[ ! -f "$GENERATED_MFE_DOCKERFILE" ]]; then
    return
  fi

  if python3 - <<'PY' "$GENERATED_MFE_DOCKERFILE"
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
import re

match = re.search(r"(?m)^FROM .*/?caddy:2\.7\.4 AS production$", text)
if not match:
    raise SystemExit(1)
production = text[match.start():]
raise SystemExit(0 if "COPY mereka/theme /openedx/dist/theme" in production else 1)
PY
  then
    echo "  ✓ generated Dockerfile production stage copies runtime theme payload"
  else
    echo "  ✗ generated Dockerfile production stage missing runtime theme payload copy"
    failures=1
  fi
}

check_generated_pull_translations_retry_contract() {
  if [[ ! -f "$GENERATED_MFE_DOCKERFILE" ]]; then
    return
  fi

  local sentinel_count retry_message_count wrap_count raw_count
  sentinel_count="$(grep -F -c -- "$PULL_TRANSLATIONS_RETRY_SENTINEL" "$GENERATED_MFE_DOCKERFILE" || true)"
  retry_message_count="$(grep -F -c -- "$PULL_TRANSLATIONS_RETRY_FRAGMENT" "$GENERATED_MFE_DOCKERFILE" || true)"
  wrap_count="$(grep -F -c -- "$PULL_TRANSLATIONS_WRAP_FRAGMENT" "$GENERATED_MFE_DOCKERFILE" || true)"
  raw_count="$(grep -E -c -- "$RAW_PULL_TRANSLATIONS_REGEX" "$GENERATED_MFE_DOCKERFILE" || true)"

  if [[ "${sentinel_count:-0}" -ge 1 ]]; then
    echo "  ✓ generated Dockerfile carries pull_translations retry sentinel (${sentinel_count})"
  else
    echo "  ✗ generated Dockerfile missing pull_translations retry sentinel"
    failures=1
  fi

  if [[ "${raw_count:-0}" -eq 0 ]]; then
    echo "  ✓ generated Dockerfile has no unwrapped pull_translations RUN lines"
  else
    echo "  ✗ generated Dockerfile still has ${raw_count:-0} unwrapped pull_translations RUN line(s)"
    failures=1
  fi

  if [[ "${sentinel_count:-0}" -eq "${retry_message_count:-0}" && "${sentinel_count:-0}" -eq "${wrap_count:-0}" ]]; then
    echo "  ✓ generated Dockerfile retry wrapper counts are internally consistent"
  else
    echo "  ✗ generated Dockerfile retry wrapper counts diverge (sentinels=${sentinel_count:-0}, messages=${retry_message_count:-0}, wraps=${wrap_count:-0})"
    failures=1
  fi
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
check_contains "apply-patches sources deprecated shell prune patch" "$APPLY_PATCH_SCRIPT" "source \"\$PATCHES_DIR/mfe-prune-deprecated-shells.sh\""
check_contains "apply-patches applies deprecated shell prune patch" "$APPLY_PATCH_SCRIPT" "apply_mfe_prune_deprecated_shells_patch"
check_contains "apply-patches defines pull_translations retry wrapper" "$APPLY_PATCH_SCRIPT" "wrap_mfe_pull_translations_retry()"
check_contains "apply-patches applies pull_translations retry wrapper" "$APPLY_PATCH_SCRIPT" "wrap_mfe_pull_translations_retry"
rendered_target_count="$(grep -F -c -- "$RENDERED_MFE_DOCKERFILE_TARGET" "$APPLY_PATCH_SCRIPT" || true)"
if [[ "${rendered_target_count:-0}" -eq 1 ]]; then
  echo "  ✓ apply-patches targets rendered MFE Dockerfile exactly once (retry exception only)"
else
  echo "  ✗ apply-patches references rendered MFE Dockerfile ${rendered_target_count:-0} times (expected 1 retry exception)"
  failures=1
fi
# Plugin module now carries all MFE Dockerfile hooks (tracker #32)
check_contains "plugin module defines pre-npm-install hook" "$PATCH_MODULE" "mfe-dockerfile-pre-npm-install"
check_contains "plugin module defines post-npm-install hook" "$PATCH_MODULE" "mfe-dockerfile-post-npm-install"
check_contains "plugin module installs frontend-plugin-framework" "$PATCH_MODULE" "frontend-plugin-framework@^1.8.0"
check_contains "plugin module materializes local brand package" "$PATCH_MODULE" "/openedx/app/node_modules/@edx/brand"
check_contains "plugin module emits brand materialization marker" "$PATCH_MODULE" "materialized local brand package"
check_contains "slot ownership shell delegates to Python helper" "$SLOT_OWNERSHIP_PATCH" "mfe_slot_ownership.py"
check_contains "slot ownership helper defines strip_slot_ownership" "$SLOT_OWNERSHIP_HELPER" "def strip_slot_ownership("
check_contains "deprecated shell prune helper defines orders/payment app set" "$PRUNE_DEPRECATED_SHELLS_HELPER" "APPS = (\"orders\", \"payment\")"
check_contains "deprecated shell prune helper strips ENABLE_NEW_RELIC build env" "$PRUNE_DEPRECATED_SHELLS_HELPER" "ARG ENABLE_NEW_RELIC=false"
check_contains_any_file "plugin injects plugin dependency line" "$PLUGIN_INSTALL_LINE" "$PATCH_MODULE"

echo ""
echo "2. Generated Dockerfile contract..."
check_no_legacy_mfe_render_path_refs
echo "  ✓ active rendered MFE Dockerfile authority path: $ACTIVE_MFE_DOCKERFILE_PATH"
if grep -q "Injected COPY .*theme into production stage of rendered MFE Dockerfile\\|drops this COPY" "$APPLY_PATCH_SCRIPT"; then
  echo "  ✗ apply-patches.sh still contains stale rendered Dockerfile theme-copy surgery"
  failures=1
else
  echo "  ✓ apply-patches.sh does not mutate rendered Dockerfile for production theme copy"
fi
check_snapshot_parity
if [[ -f "$GENERATED_MFE_DOCKERFILE" ]]; then
  check_generated_production_theme_copy
  check_generated_pull_translations_retry_contract
  check_contains_regex "generated Dockerfile uses Node 24 image" "$GENERATED_MFE_DOCKERFILE" "$NODE_IMAGE_REGEX"
  check_contains "generated Dockerfile contains plugin install line" "$GENERATED_MFE_DOCKERFILE" "$PLUGIN_INSTALL_LINE"
  check_contains "generated Dockerfile uses mirrored Caddy production base" "$GENERATED_MFE_DOCKERFILE" "FROM mirror.gcr.io/library/caddy:2.7.4 AS production"
  check_contains "generated Dockerfile hardens base-stage apt retries" "$GENERATED_MFE_DOCKERFILE" 'Acquire::Retries "6"'
  check_contains "generated Dockerfile hardens base-stage apt https timeout" "$GENERATED_MFE_DOCKERFILE" 'Acquire::https::Timeout "30"'
  check_contains "generated Dockerfile forces IPv4 for apt" "$GENERATED_MFE_DOCKERFILE" 'Acquire::ForceIPv4 "true"'
  check_contains "generated Dockerfile uses fix-missing apt install" "$GENERATED_MFE_DOCKERFILE" '--fix-missing git'
  check_contains "generated Dockerfile installs CA certificates for atlas/git translation pulls" "$GENERATED_MFE_DOCKERFILE" 'ca-certificates'
  check_contains "generated Dockerfile refreshes CA bundle after install" "$GENERATED_MFE_DOCKERFILE" 'update-ca-certificates'
  check_contains "generated Dockerfile pins git SSL CA bundle for atlas/git translation pulls" "$GENERATED_MFE_DOCKERFILE" 'http.sslCAInfo /etc/ssl/certs/ca-certificates.crt'
  if grep -Eq '^Acquire::(http|https|ForceIPv4|Retries)' "$GENERATED_MFE_DOCKERFILE"; then
    echo "  ✗ generated Dockerfile leaks bare Acquire:: apt policy lines outside a RUN continuation"
    failures=1
  else
    echo "  ✓ generated Dockerfile keeps apt policy lines inside a valid RUN continuation"
  fi

  plugin_count="$(grep -F -c -- "$PLUGIN_INSTALL_LINE" "$GENERATED_MFE_DOCKERFILE" || true)"
  if [[ "${plugin_count:-0}" -ge 1 ]]; then
    echo "  ✓ generated Dockerfile plugin install occurrences: ${plugin_count}"
  else
    echo "  ✗ generated Dockerfile plugin install occurrences: 0"
    failures=1
  fi

  redux_count="$(grep -F -c -- "$REDUX_INSTALL_LINE" "$GENERATED_MFE_DOCKERFILE" || true)"
  if [[ "${redux_count:-0}" -ge 2 ]]; then
    echo "  ✓ generated Dockerfile redux install occurrences: ${redux_count}"
  else
    echo "  ✗ generated Dockerfile redux install occurrences: ${redux_count:-0} (expected >=2 for admin-console and authn)"
    failures=1
  fi

  payment_react_intl_count="$(grep -F -c -- "$PAYMENT_REACT_INTL_INSTALL_LINE" "$GENERATED_MFE_DOCKERFILE" || true)"
  if [[ "${payment_react_intl_count:-0}" -eq 0 ]]; then
    echo "  ✓ generated Dockerfile payment react-intl compat patch absent from default path"
  else
    echo "  ✗ generated Dockerfile payment react-intl compat patch occurrences: ${payment_react_intl_count:-0} (expected 0 on pruned default path)"
    failures=1
  fi

  new_relic_count="$(grep -c 'ARG ENABLE_NEW_RELIC\\|ENV ENABLE_NEW_RELIC' "$GENERATED_MFE_DOCKERFILE" || true)"
  if [[ "${new_relic_count:-0}" -eq 0 ]]; then
    echo "  ✓ generated Dockerfile ENABLE_NEW_RELIC build env absent from default path"
  else
    echo "  ✗ generated Dockerfile ENABLE_NEW_RELIC build env occurrences: ${new_relic_count:-0} (expected 0 on runtime-driven default path)"
    failures=1
  fi

  if grep -Eq "orders-common|payment-common" "$GENERATED_MFE_DOCKERFILE"; then
    echo "  ✗ generated Dockerfile still contains deprecated orders/payment stages"
    failures=1
  else
    echo "  ✓ generated Dockerfile prunes deprecated orders/payment stages"
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

  if grep -Fq -- "/openedx/app/node_modules/@edx/brand" "$GENERATED_MFE_DOCKERFILE" \
    && grep -Fq -- "materialized local brand package" "$GENERATED_MFE_DOCKERFILE"; then
    echo "  ✓ generated Dockerfile materializes local brand package"
  elif grep -Fq -- "@edx/brand@file:./brand-mereka" "$GENERATED_MFE_DOCKERFILE"; then
    echo "  ✗ generated Dockerfile still runs post-npm local brand package install"
    failures=1
  else
    echo "  ✗ generated Dockerfile missing local brand package materialization"
    failures=1
  fi

  if [[ -d "$GENERATED_MFE_MEREKA_DIR" ]]; then
    echo "  ✓ generated Mereka build directory exists"
  else
    echo "  ✗ generated Mereka build directory missing: $GENERATED_MFE_MEREKA_DIR"
    failures=1
  fi

  if [[ -f "$GENERATED_MFE_MEREKA_ENV" ]]; then
    echo "  ✓ generated mereka/env.config.jsx exists"
  else
    echo "  ✗ generated mereka/env.config.jsx missing: $GENERATED_MFE_MEREKA_ENV"
    failures=1
  fi

  if [[ -d "$GENERATED_MFE_MEREKA_THEME_DIR" ]]; then
    echo "  ✓ generated mereka/theme-source directory exists"
  else
    echo "  ✗ generated mereka/theme-source directory missing: $GENERATED_MFE_MEREKA_THEME_DIR"
    failures=1
  fi

  check_jsx_parse "generated env.config.jsx parses as JSX" "$GENERATED_MFE_BUILD_DIR/env.config.jsx"
  check_jsx_parse "generated mereka/env.config.jsx parses as JSX" "$GENERATED_MFE_MEREKA_ENV"
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
