#!/usr/bin/env bash
# Seeded-defect tests for verify-tutor-patch-manifest-contract.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$REPO_ROOT/scripts/qa/verify-tutor-patch-manifest-contract.sh"
TMP_DIR="$(mktemp -d -t tutor-patch-manifest-contract.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

pass() {
  printf 'PASS %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

write_fixture() {
  local root="$1"

  rm -rf "$root"
  mkdir -p \
    "$root/infrastructure/tutor/patches" \
    "$root/docs/reference/architecture" \
    "$root/specs" \
    "$root/scripts/qa"

  cat >"$root/specs/tutor-configuration-resilience_spec.md" <<'EOF'
# Tutor Configuration Resilience Spec
EOF

  cat >"$root/infrastructure/tutor/apply-patches.sh" <<'EOF'
#!/usr/bin/env bash
PATCHES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/patches" && pwd)"
source "$PATCHES_DIR/build-optimizations.sh"
source "$PATCHES_DIR/dependency-image-mirrors.sh"
source "$PATCHES_DIR/mysql-root-host.sh"

apply_patch() {
  "$1"
}

wrap_mfe_pull_translations_retry() {
  :
}

apply_patch apply_build_optimizations_patch
apply_patch apply_dependency_image_mirrors_patch
apply_patch apply_mysql_root_host_patch
wrap_mfe_pull_translations_retry
EOF

  cat >"$root/infrastructure/tutor/patches/build-optimizations.sh" <<'EOF'
#!/usr/bin/env bash
apply_build_optimizations_patch() { :; }
BASE_ASSETS_NO_BUILD_ISOLATION_INSTALL=1
UWSGI_PIP_INSTALL=1
PRODUCTION_BUILD_PROFILE_ARG=1
TRANSLATION_SETTINGS_PREFLIGHT=1
ADVANCED_XBLOCKS_PRODUCTION_COPY=1
TRANSLATION_REFRESH=1
wrap_translation_step=1
EOF

  cat >"$root/infrastructure/tutor/patches/dependency-image-mirrors.sh" <<'EOF'
#!/usr/bin/env bash
apply_dependency_image_mirrors_patch() { :; }
REPLACEMENTS=1
REQUIRED_BY_SUFFIX=1
EOF

  cat >"$root/infrastructure/tutor/patches/mysql-root-host.sh" <<'EOF'
#!/usr/bin/env bash
apply_mysql_root_host_patch() { :; }
EOF

  cat >"$root/infrastructure/tutor/patches/enterprise-template-guard.sh" <<'EOF'
#!/usr/bin/env bash
apply_enterprise_template_guard_patch() { :; }
EOF

  cat >"$root/docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md" <<'EOF'
# Tutor Patches Inventory

Remaining `build-optimizations.sh` Mutation Ledger

Remaining MFE Post-Render Exception Ledger

build-optimizations-render-delta temporary compatibility layer build-optimizations.sh apply_build_optimizations_patch
dependency-image-mirror-normalization temporary compatibility layer dependency-image-mirrors.sh apply_dependency_image_mirrors_patch
mysql-root-host temporary compatibility layer mysql-root-host.sh apply_mysql_root_host_patch
mfe-pull-translations-retry temporary compatibility layer apply-patches.sh wrap_mfe_pull_translations_retry

base-assets-no-build-isolation temporary compatibility layer
uwsgi-plain-pip-fallback temporary compatibility layer
production-build-profile-arg intentional architecture change
translation-settings-preflight intentional architecture change
advanced-xblocks-production-copy intentional architecture change
fast-profile-translation-wrappers temporary compatibility layer

Review Rule
EOF

  cat >"$root/infrastructure/tutor/patch-manifest.yml" <<'EOF'
version: "2.0"
metadata:
  description: "Fixture manifest"
  inventory: "docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md"
  spec: "specs/tutor-configuration-resilience_spec.md"

patches:
  - id: build-optimizations-render-delta
    module: "infrastructure/tutor/patches/build-optimizations.sh"
    function: "apply_build_optimizations_patch"
    target: "tutor_env/env/build/openedx/Dockerfile"
    target_family: "openedx"
    authority_class: "temporary_compatibility_layer"
    description: "Bounded by build-optimizations.allowed-delta.yaml."
    retirement_trigger: "Retire when source hooks own the build-optimizations.allowed-delta.yaml behavior."
    required: true
  - id: dependency-image-mirror-normalization
    module: "infrastructure/tutor/patches/dependency-image-mirrors.sh"
    function: "apply_dependency_image_mirrors_patch"
    target: "tutor_env/env/build/openedx/Dockerfile and tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
    target_family: "openedx,mfe"
    authority_class: "temporary_compatibility_layer"
    description: "Mirror exact dependency image references."
    retirement_trigger: "Retire when source hooks own dependency image refs."
    required: true
  - id: mysql-root-host
    module: "infrastructure/tutor/patches/mysql-root-host.sh"
    function: "apply_mysql_root_host_patch"
    target: "tutor_env/env/local/docker-compose.yml"
    target_family: "openedx"
    authority_class: "temporary_compatibility_layer"
    description: "Adds MYSQL_ROOT_HOST for local bootstrap."
    retirement_trigger: "Retire when Tutor owns the local compose setting."
    required: true
  - id: mfe-pull-translations-retry
    module: "infrastructure/tutor/apply-patches.sh"
    function: "wrap_mfe_pull_translations_retry"
    target: "tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
    target_family: "mfe"
    authority_class: "temporary_compatibility_layer"
    description: "Wraps translation pulls."
    retirement_trigger: "Retire when tutormfe owns pull retry semantics."
    required: true

inactive_modules:
  - module: "infrastructure/tutor/patches/enterprise-template-guard.sh"
    status: "not_sourced"
EOF

  cat >"$root/infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml" <<'EOF'
source_script: infrastructure/tutor/patches/build-optimizations.sh
inventory_doc: docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md
default_policy: fail_closed
allowed_deltas:
  - id: dependency-image-mirror-normalization
    authority_class: temporary_compatibility_layer
    owner: fixture owner
    reason: Fixture dependency image mirror reason.
    source_script: infrastructure/tutor/patches/dependency-image-mirrors.sh
    source_markers: [REPLACEMENTS, REQUIRED_BY_SUFFIX]
    retirement_trigger: Retire when source-owned.
  - id: base-assets-no-build-isolation
    authority_class: temporary_compatibility_layer
    owner: fixture owner
    reason: Fixture base assets reason.
    source_markers: [BASE_ASSETS_NO_BUILD_ISOLATION_INSTALL]
    retirement_trigger: Retire when source-owned.
  - id: uwsgi-plain-pip-fallback
    authority_class: temporary_compatibility_layer
    owner: fixture owner
    reason: Fixture uwsgi reason.
    source_markers: [UWSGI_PIP_INSTALL]
    retirement_trigger: Retire when source-owned.
  - id: production-build-profile-arg
    authority_class: intentional_architecture_change
    owner: fixture owner
    reason: Fixture build profile reason.
    source_markers: [PRODUCTION_BUILD_PROFILE_ARG]
    retirement_trigger: Retire when bake owns it.
  - id: translation-settings-preflight
    authority_class: intentional_architecture_change
    owner: fixture owner
    reason: Fixture translation preflight reason.
    source_markers: [TRANSLATION_SETTINGS_PREFLIGHT]
    retirement_trigger: Retire when source-owned.
  - id: advanced-xblocks-production-copy
    authority_class: intentional_architecture_change
    owner: fixture owner
    reason: Fixture advanced XBlock reason.
    source_markers: [ADVANCED_XBLOCKS_PRODUCTION_COPY]
    retirement_trigger: Retire when source-owned.
  - id: fast-profile-translation-wrappers
    authority_class: temporary_compatibility_layer
    owner: fixture owner
    reason: Fixture translation wrapper reason.
    source_markers: [TRANSLATION_REFRESH, wrap_translation_step]
    retirement_trigger: Retire when source-owned.
EOF
}

run_verify() {
  local root="$1"
  REPO_ROOT_OVERRIDE="$root" \
    PATCH_MANIFEST="$root/infrastructure/tutor/patch-manifest.yml" \
    APPLY_PATCHES_SCRIPT="$root/infrastructure/tutor/apply-patches.sh" \
    PATCH_INVENTORY_DOC="$root/docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md" \
    BUILD_OPTIMIZATIONS_DELTA_CONTRACT="$root/infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml" \
    "$VERIFY"
}

expect_pass() {
  local label="$1"
  local root="$TMP_DIR/$label"
  write_fixture "$root"
  if run_verify "$root" >/tmp/tutor-patch-manifest-contract.out 2>/tmp/tutor-patch-manifest-contract.err; then
    pass "$label"
  else
    cat /tmp/tutor-patch-manifest-contract.err >&2 || true
    fail "$label"
  fi
}

expect_fail() {
  local label="$1"
  local needle="$2"
  shift 2
  local root="$TMP_DIR/$label"
  write_fixture "$root"
  "$@" "$root"

  set +e
  run_verify "$root" >/tmp/tutor-patch-manifest-contract.out 2>/tmp/tutor-patch-manifest-contract.err
  local rc=$?
  set -e

  if [[ "$rc" -ne 0 ]] && grep -qF "$needle" /tmp/tutor-patch-manifest-contract.err; then
    pass "$label"
  else
    cat /tmp/tutor-patch-manifest-contract.out >&2 || true
    cat /tmp/tutor-patch-manifest-contract.err >&2 || true
    fail "$label"
  fi
}

mutate_sourced_module_missing_from_manifest() {
  python3 - "$1/infrastructure/tutor/patch-manifest.yml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
start = text.index("  - id: mysql-root-host\n")
end = text.index("  - id: mfe-pull-translations-retry\n")
path.write_text(text[:start] + text[end:], encoding="utf-8")
PY
}

mutate_function_missing_from_module() {
  sed -i 's/apply_mysql_root_host_patch()/apply_mysql_root_host_patch_old()/g' \
    "$1/infrastructure/tutor/patches/mysql-root-host.sh"
}

mutate_inactive_module_sourced() {
  sed -i '/mysql-root-host.sh/a source "$PATCHES_DIR/enterprise-template-guard.sh"' \
    "$1/infrastructure/tutor/apply-patches.sh"
}

mutate_delta_policy_not_fail_closed() {
  sed -i 's/default_policy: fail_closed/default_policy: allow_unlisted/g' \
    "$1/infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml"
}

mutate_historical_module_active() {
  cp "$1/infrastructure/tutor/patches/mysql-root-host.sh" "$1/infrastructure/tutor/patches/mfe-node.sh"
  sed -i 's#infrastructure/tutor/patches/mysql-root-host.sh#infrastructure/tutor/patches/mfe-node.sh#' \
    "$1/infrastructure/tutor/patch-manifest.yml"
}

mutate_inventory_missing_delta() {
  sed -i '/base-assets-no-build-isolation/d' \
    "$1/docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md"
}

mutate_delta_source_marker_missing() {
  sed -i 's/BASE_ASSETS_NO_BUILD_ISOLATION_INSTALL/BASE_ASSETS_NO_BUILD_ISOLATION_INSTALL_MISSING/g' \
    "$1/infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml"
}

mutate_delta_owner_reason_missing() {
  sed -i '/^[[:space:]]*owner: fixture owner$/d;/^[[:space:]]*reason: /d' \
    "$1/infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml"
}

mutate_inline_wrapper_call_missing() {
  sed -i '/^wrap_mfe_pull_translations_retry$/d' \
    "$1/infrastructure/tutor/apply-patches.sh"
}

expect_pass "valid manifest contract passes"
expect_fail "sourced module missing from manifest fails" \
  "sourced patch module missing from active manifest: mysql-root-host.sh" \
  mutate_sourced_module_missing_from_manifest
expect_fail "missing module function fails" \
  "function apply_mysql_root_host_patch not defined" \
  mutate_function_missing_from_module
expect_fail "inactive module sourced fails" \
  "inactive module is still sourced by apply-patches.sh: enterprise-template-guard.sh" \
  mutate_inactive_module_sourced
expect_fail "delta policy fails closed" \
  "build-optimizations allowed-delta contract default_policy must be fail_closed" \
  mutate_delta_policy_not_fail_closed
expect_fail "historical module cannot be active" \
  "historical patch module cannot be active: mfe-node.sh" \
  mutate_historical_module_active
expect_fail "inventory missing delta id fails" \
  "base-assets-no-build-isolation: missing exact id token from inventory ledger" \
  mutate_inventory_missing_delta
expect_fail "allowed delta source marker missing fails" \
  "base-assets-no-build-isolation: source marker missing from allowed-delta source" \
  mutate_delta_source_marker_missing
expect_fail "allowed delta owner reason missing fails" \
  "base-assets-no-build-isolation: missing owner" \
  mutate_delta_owner_reason_missing
expect_fail "inline wrapper definition without invocation fails" \
  "mfe-pull-translations-retry: function is not invoked by apply-patches.sh: wrap_mfe_pull_translations_retry" \
  mutate_inline_wrapper_call_missing

printf 'Summary: PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
