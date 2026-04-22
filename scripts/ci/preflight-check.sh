#!/usr/bin/env bash
# Preflight check: validates the generated MFE/OpenEdX Dockerfiles
# against known invariants BEFORE a 30-60 minute build cycle.
#
# Usage:
#   ./scripts/ci/preflight-check.sh              # uses existing .ci-venv or creates one
#   TUTOR_VENV=/path/to/venv ./scripts/ci/...    # use a specific venv
#
# Runtime: ~30 seconds (config save + patch + grep checks)
#
# WHY THIS EXISTS:
# Tutor generates Dockerfiles from templates. Patches in apply-patches.sh and
# mereka_lms.py modify those templates. Errors are only caught after a 30-45 min
# build. This script catches them in < 1 minute by rendering + validating locally.
#
# The build stack is pinned in requirements-tutor.txt (currently Tutor 21.0.3 Ulmo).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TUTOR_VENV="${TUTOR_VENV:-$REPO_ROOT/.ci-venv}"
SYNC_SCRIPT="$REPO_ROOT/scripts/infra/sync-tutor-plugin-mirror.sh"
SCOPE_MODE="${PREFLIGHT_CHECK_SCOPE:-}"
CHANGED_FILES_RAW="${PREFLIGHT_CHECK_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  local changed_path

  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r changed_path; do
    [[ -n "$changed_path" ]] || continue
    case "$changed_path" in
      .github/workflows/ci.yml|\
      scripts/ci/preflight-check.sh|\
      requirements-tutor.txt|\
      scripts/infra/sync-tutor-plugin-mirror.sh|\
      infrastructure/tutor/*|\
      assets/branding/*)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS preflight-check (scope skip: no tutor preflight authority changes)"
  exit 0
fi

# In CI without a pre-cached venv, creating one from scratch (pip install Tutor)
# exceeds the 120s per-script timeout. Skip gracefully — the actual image build
# will catch any Dockerfile invariant violations.
if [[ "${CI:-}" == "true" && ! -f "$TUTOR_VENV/bin/tutor" ]]; then
  echo "SKIP: CI environment without cached Tutor venv — preflight requires tutor to render Dockerfiles"
  exit 0
fi
TUTOR_REQ="$REPO_ROOT/requirements-tutor.txt"
PASS=0
FAIL=0
SKIP=0
export TUTOR_VENV

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $1"; }

# ── Setup CI-matching Tutor environment ──────────────────────────
echo "=== Preflight Check: MFE/OpenEdX Dockerfile Invariants ==="

if [[ ! -f "$TUTOR_VENV/bin/tutor" ]]; then
  echo "Creating CI-matching venv at $TUTOR_VENV..."
  python3 -m venv "$TUTOR_VENV"
  "$TUTOR_VENV/bin/pip" install -q -r "$TUTOR_REQ"
fi

TUTOR_ROOT=$(mktemp -d)
export TUTOR_ROOT
export REPO_ROOT
PREP_SCRIPT="$REPO_ROOT/scripts/infra/prepare-tutor-build-context.sh"
RAW_OPENEDX_DF_SNAPSHOT="$(mktemp -t preflight-openedx-raw.XXXXXX)"
RAW_MFE_DF_SNAPSHOT="$(mktemp -t preflight-mfe-raw.XXXXXX)"

if [[ ! -x "$SYNC_SCRIPT" ]]; then
  echo "ERROR: Tutor plugin sync script not found or not executable at $SYNC_SCRIPT" >&2
  rm -f "$RAW_OPENEDX_DF_SNAPSHOT" "$RAW_MFE_DF_SNAPSHOT"
  rm -rf "$TUTOR_ROOT"
  exit 1
fi

if [[ ! -x "$PREP_SCRIPT" ]]; then
  echo "ERROR: Canonical build-context script not found or not executable at $PREP_SCRIPT" >&2
  rm -f "$RAW_OPENEDX_DF_SNAPSHOT" "$RAW_MFE_DF_SNAPSHOT"
  rm -rf "$TUTOR_ROOT"
  exit 1
fi

"$SYNC_SCRIPT" >/dev/null
"$TUTOR_VENV/bin/tutor" plugins disable mfe_oauth_fix >/dev/null 2>&1 || true
"$TUTOR_VENV/bin/tutor" plugins enable mereka_lms >/dev/null 2>&1 || true
"$TUTOR_VENV/bin/tutor" plugins enable mereka_lms_mfe_slots >/dev/null 2>&1 || true

echo "Generating Dockerfiles (tutor config save + apply-patches.sh)..."
"$TUTOR_VENV/bin/tutor" config save \
  --set LMS_HOST=preflight-check.test \
  --set CMS_HOST=studio.preflight-check.test \
  --set OPENEDX_COMMON_VERSION=release/ulmo \
  --set OPENEDX_LMS_VERSION=release/ulmo \
  --set OPENEDX_CMS_VERSION=release/ulmo \
  --set MFE_COMMON_VERSION=release/ulmo.2 \
  --set ENABLE_HTTPS=true \
  >/dev/null 2>&1

cp "$TUTOR_ROOT/env/build/openedx/Dockerfile" "$RAW_OPENEDX_DF_SNAPSHOT"
cp "$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile" "$RAW_MFE_DF_SNAPSHOT"
TUTOR_ROOT="$TUTOR_ROOT" "$PREP_SCRIPT" --target openedx >/dev/null 2>&1

# Apply MFE patches directly to the temp render without refreshing the tracked
# MFE snapshot. This proves the same MFE patch chain used by apply-patches.sh
# while keeping preflight read-only against the repository checkout.
export MFE_TEMPLATE="$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
RENDERED_DF="$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
if [[ -f "$RENDERED_DF" ]]; then
  (
    export VIRTUAL_ENV="$TUTOR_VENV"
    export PATH="$TUTOR_VENV/bin:$PATH"
    export REPO_ROOT TUTOR_ROOT MFE_TEMPLATE TARGET=mfe
    cd "$REPO_ROOT"
    # shellcheck source=infrastructure/tutor/patches/_common.sh
    source infrastructure/tutor/patches/_common.sh
    _discover_template_paths
    # shellcheck source=infrastructure/tutor/patches/brand-package.sh
    source infrastructure/tutor/patches/brand-package.sh
    # shellcheck source=infrastructure/tutor/patches/sync-footer-assets.sh
    source infrastructure/tutor/patches/sync-footer-assets.sh
    # shellcheck source=infrastructure/tutor/patches/mfe-slot-ownership.sh
    source infrastructure/tutor/patches/mfe-slot-ownership.sh
    # shellcheck source=infrastructure/tutor/patches/mfe-prune-deprecated-shells.sh
    source infrastructure/tutor/patches/mfe-prune-deprecated-shells.sh
    # shellcheck source=infrastructure/tutor/patches/mfe-npm-install-resilience.sh
    source infrastructure/tutor/patches/mfe-npm-install-resilience.sh
    # shellcheck source=infrastructure/tutor/patches/dependency-image-mirrors.sh
    source infrastructure/tutor/patches/dependency-image-mirrors.sh
    apply_brand_package_patch
    sync_footer_assets
    apply_mfe_slot_ownership_patch
    apply_mfe_prune_deprecated_shells_patch
    apply_mfe_npm_install_resilience_patch
    apply_dependency_image_mirrors_patch
  ) >/dev/null
fi

MFE_DF="$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
OPENEDX_DF="$TUTOR_ROOT/env/build/openedx/Dockerfile"

if [[ ! -f "$MFE_DF" ]]; then
  echo "ERROR: MFE Dockerfile not generated at $MFE_DF" >&2
  rm -f "$RAW_OPENEDX_DF_SNAPSHOT" "$RAW_MFE_DF_SNAPSHOT"
  rm -rf "$TUTOR_ROOT"
  exit 1
fi

# Helper: extract a Dockerfile stage block
stage_block() {
  local df="$1" stage="$2"
  python3 -c "
import sys
lines = open('$df').read().splitlines()
start = None
for i, l in enumerate(lines):
    if 'FROM ' in l and ' AS $stage' in l:
        start = i
        break
if start is None:
    sys.exit(1)
end = len(lines)
for i in range(start+1, len(lines)):
    if lines[i].startswith('FROM '):
        end = i
        break
print('\n'.join(lines[start:end]))
" 2>/dev/null
}

check_openedx_render_delta_allowlist() {
  local raw_df="$1"
  local patched_df="$2"
  local delta_contract_verifier="$REPO_ROOT/scripts/qa/verify-build-optimizations-render-delta-contract.sh"
  local sanitized_raw
  local sanitized_patched

  sanitized_raw="$(mktemp -t preflight-openedx-sanitized-raw.XXXXXX)"
  sanitized_patched="$(mktemp -t preflight-openedx-sanitized-patched.XXXXXX)"

  python3 - "$raw_df" "$patched_df" "$sanitized_raw" "$sanitized_patched" <<'PY'
from pathlib import Path
import re
import sys

raw_text = Path(sys.argv[1]).read_text()
patched_text = Path(sys.argv[2]).read_text()
sanitized_raw = Path(sys.argv[3])
sanitized_patched = Path(sys.argv[4])
activation_block = (
    "# SECURITY FIX: remove activation_key exposure from account API\n"
    "RUN curl -fsSL https://github.com/openedx/openedx-platform/commit/"
    "21cead238466ca398ba368518f1d3288431d68f4.patch | git am\n"
)
raw_match = re.search(
    r"RUN \./manage\.py lms --settings=tutor\.i18n pull_plugin_translations --verbose --repository='openedx/openedx-translations' --revision='(?P<revision>[^']+)'[ \t]*\n"
    r"RUN \./manage\.py lms --settings=tutor\.i18n pull_xblock_translations --repository='openedx/openedx-translations' --revision='(?P=revision)'[ \t]*\n"
    r"RUN atlas pull --repository='openedx/openedx-translations' --revision='(?P=revision)'  \\\n"
    r"    translations/edx-platform/conf/locale:conf/locale \\\n"
    r"    translations/studio-frontend/src/i18n/messages:conf/plugins-locale/studio-frontend\n?",
    raw_text,
    flags=re.MULTILINE,
)

errors = []
raw_block = ""
wrapped_block = ""
if raw_match is None:
    errors.append(
        "Raw Open edX Dockerfile no longer contains the expected upstream translation pull block."
    )
else:
    revision = raw_match.group("revision")
    raw_block = raw_match.group(0).rstrip("\n")
    wrapped_block = "\n".join(
        [
            "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping plugin translation pull (fast build profile)\"; else ./manage.py lms --settings=tutor.i18n pull_plugin_translations --verbose --repository='openedx/openedx-translations' --revision='" + revision + "'; fi",
            "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping XBlock translation pull (fast build profile)\"; else ./manage.py lms --settings=tutor.i18n pull_xblock_translations --repository='openedx/openedx-translations' --revision='" + revision + "'; fi",
            "RUN if [ \"$MEREKA_BUILD_PROFILE\" = \"fast\" ]; then echo \"Skipping atlas translation pull (fast build profile)\"; else atlas pull --repository='openedx/openedx-translations' --revision='" + revision + "'  \\",
            "    translations/edx-platform/conf/locale:conf/locale \\",
            "    translations/studio-frontend/src/i18n/messages:conf/plugins-locale/studio-frontend; fi",
        ]
    )

raw_count = raw_text.count(raw_block) if raw_block else 0
wrapped_in_raw_count = raw_text.count(wrapped_block) if wrapped_block else 0
patched_count = patched_text.count(wrapped_block) if wrapped_block else 0
raw_in_patched_count = patched_text.count(raw_block) if raw_block else 0
raw_activation_count = raw_text.count(activation_block)
patched_activation_count = patched_text.count(activation_block)

if raw_count != 1:
    errors.append(
        f"Expected raw Open edX Dockerfile to contain the unwrapped translation block exactly once; found {raw_count} occurrence(s)."
    )
if wrapped_in_raw_count != 0:
    errors.append(
        f"Expected raw Open edX Dockerfile to contain zero wrapped translation blocks; found {wrapped_in_raw_count}."
    )
if patched_count != 1:
    errors.append(
        f"Expected patched Open edX Dockerfile to contain the wrapped translation block exactly once; found {patched_count} occurrence(s)."
    )
if raw_in_patched_count != 0:
    errors.append(
        f"Expected patched Open edX Dockerfile to contain zero unwrapped translation blocks; found {raw_in_patched_count}."
    )
if raw_activation_count not in {0, 1}:
    errors.append(
        "Expected raw Open edX Dockerfile to contain the obsolete activation-key git-am block at most once; "
        f"found {raw_activation_count} occurrence(s)."
    )
if raw_activation_count == 1 and patched_activation_count != 0:
    errors.append(
        "Expected patched Open edX Dockerfile to remove the obsolete activation-key git-am block."
    )
if raw_activation_count == 0 and patched_activation_count != 0:
    errors.append(
        "Expected patched Open edX Dockerfile to keep the activation-key git-am block absent when raw render already retired it."
    )

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)

sanitized_raw.write_text(raw_text.replace(activation_block, ""))
sanitized_patched.write_text(patched_text.replace(activation_block, ""))
PY

  RAW_RENDER_FILE="$sanitized_raw" \
  PATCHED_RENDER_FILE="$sanitized_patched" \
    "$delta_contract_verifier"
  local rc=$?
  rm -f "$sanitized_raw" "$sanitized_patched"
  return "$rc"
}

check_mfe_dependency_image_mirror_delta() {
  local raw_df="$1"
  local patched_df="$2"

  python3 - "$raw_df" "$patched_df" <<'PY'
from pathlib import Path
import sys

raw_text = Path(sys.argv[1]).read_text(encoding="utf-8")
patched_text = Path(sys.argv[2]).read_text(encoding="utf-8")

expectations = [
    (
        "# syntax=docker/dockerfile:1",
        "# syntax=mirror.gcr.io/docker/dockerfile:1",
        "Dockerfile frontend",
    ),
    (
        "FROM docker.io/node:24.11.0-bullseye-slim AS base",
        "FROM mirror.gcr.io/library/node:24.11.0-bullseye-slim AS base",
        "MFE Node base",
    ),
    (
        "FROM docker.io/caddy:2.7.4 AS production",
        "FROM mirror.gcr.io/library/caddy:2.7.4 AS production",
        "MFE Caddy production base",
    ),
]

errors = []
for source, mirror, label in expectations:
    if source not in raw_text:
        errors.append(f"Raw MFE Dockerfile missing expected upstream {label} selector: {source}")
    if mirror not in patched_text:
        errors.append(f"Patched MFE Dockerfile missing expected mirrored {label} selector: {mirror}")
    if source in patched_text:
        errors.append(f"Patched MFE Dockerfile still contains upstream {label} selector: {source}")

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
PY
}

# ── MFE Dockerfile Checks ───────────────────────────────────────
echo ""
echo "--- MFE Dockerfile Invariants ---"

# 1. Check env.config.jsx imports vs installed packages per MFE stage.
# The key invariant: if an MFE's env.config.jsx imports a package, that package
# MUST be installed in that MFE's build stage. Otherwise webpack fails with
# "Module not found" at build time.
ENV_CONFIG="$TUTOR_ROOT/env/plugins/mfe/build/mfe/env.config.jsx"
MEREKA_ENV_CONFIG="$TUTOR_ROOT/env/plugins/mfe/build/mfe/mereka/env.config.jsx"
# Determine which env.config.jsx will be used.
ACTIVE_ENV_CONFIG=""
if [[ -f "$MEREKA_ENV_CONFIG" ]]; then
  ACTIVE_ENV_CONFIG="$MEREKA_ENV_CONFIG"
elif [[ -f "$ENV_CONFIG" ]]; then
  ACTIVE_ENV_CONFIG="$ENV_CONFIG"
fi

# The retired Tutor Indigo footer package must not be imported by active MFE config.
ENV_CONFIG_IMPORTS_FOOTER=false
if [[ -n "$ACTIVE_ENV_CONFIG" ]] && grep -q "indigo-frontend-component-footer" "$ACTIVE_ENV_CONFIG" 2>/dev/null; then
  ENV_CONFIG_IMPORTS_FOOTER=true
  fail "active env.config.jsx imports retired Tutor Indigo footer package: $ACTIVE_ENV_CONFIG"
fi

for mfe in authn learning discussions learner-dashboard profile account; do
  block=$(stage_block "$MFE_DF" "${mfe}-common") || true
  if [[ -z "$block" ]]; then
    skip "${mfe}-common stage not found"
    continue
  fi

  has_env_config=$(echo "$block" | grep -c "env.config.jsx" || true)
  has_footer_pkg=$(echo "$block" | grep -c "indigo-frontend-component-footer" || true)

  if [[ "$has_env_config" -gt 0 && "$ENV_CONFIG_IMPORTS_FOOTER" == "true" && "$has_footer_pkg" -eq 0 ]]; then
    fail "${mfe}-common has env.config.jsx that imports footer, but footer package is NOT installed"
  elif [[ "$has_env_config" -gt 0 && "$ENV_CONFIG_IMPORTS_FOOTER" == "true" && "$has_footer_pkg" -gt 0 ]]; then
    pass "${mfe}-common has env.config.jsx + footer package installed"
  elif [[ "$has_env_config" -gt 0 && "$ENV_CONFIG_IMPORTS_FOOTER" == "false" ]]; then
    pass "${mfe}-common has env.config.jsx (no footer import — safe)"
  elif [[ "$has_env_config" -eq 0 ]]; then
    pass "${mfe}-common: no env.config.jsx (OK for this MFE)"
  fi
done

# 3. Retired Tutor Indigo component installs must not be present.
bad_installs=$(grep -E "RUN npm install.*indigo-frontend-component" "$MFE_DF" || true)
if [[ -n "$bad_installs" ]]; then
  fail "retired Tutor Indigo component install remains in MFE Dockerfile: $bad_installs"
else
  pass "no retired Tutor Indigo component install remains"
fi

# 4. Node version check
MFE_HEADER="$(head -5 "$MFE_DF")"
MFE_FIRST_LINE="$(head -1 "$MFE_DF")"
MFE_NODE_IMAGE="$(grep -oP 'node:[^ ]+' <<< "$MFE_FIRST_LINE" || true)"
if grep -q "node:2[0-9]" <<< "$MFE_HEADER"; then
  pass "MFE uses Node 20+ (${MFE_NODE_IMAGE:-$MFE_FIRST_LINE})"
else
  fail "MFE not using Node 20+ (found: $MFE_FIRST_LINE)"
fi

# 5. Brand-mereka local package (not npm registry)
if grep -q "brand@file:./brand-mereka" "$MFE_DF"; then
  pass "brand package uses local file (brand-mereka)"
else
  if grep -q "indigo-brand-openedx" "$MFE_DF"; then
    fail "brand package still points to npm registry (should be local brand-mereka)"
  else
    skip "brand package pattern not found"
  fi
fi

# 6. mereka theme assets present for authn
authn_block_check=$(stage_block "$MFE_DF" "authn-common") || true
if [[ -n "$authn_block_check" ]]; then
  if grep -q "mereka" <<< "$authn_block_check"; then
    pass "authn-common has mereka theme assets"
  else
    fail "authn-common MISSING mereka theme assets"
  fi
fi

# 7. Dependency image mirrors are acquisition-only and must cover the MFE
# frontend, Node base, and Caddy runtime base selectors.
if check_mfe_dependency_image_mirror_delta "$RAW_MFE_DF_SNAPSHOT" "$MFE_DF"; then
  pass "Raw-vs-patched MFE Dockerfile dependency image mirror delta covers frontend, Node, and Caddy refs"
else
  fail "Raw-vs-patched MFE Dockerfile dependency image mirror delta is missing an expected mirrored ref"
fi

# ── OpenEdX Dockerfile Checks ───────────────────────────────────
echo ""
echo "--- OpenEdX Dockerfile Invariants ---"

if [[ -f "$OPENEDX_DF" ]]; then
  if grep -q "mysql_native_password" "$OPENEDX_DF" 2>/dev/null; then
    fail "Retired mysql_native_password Dockerfile rewrite present"
  else
    pass "Open edX Dockerfile is free of retired MySQL auth rewrites"
  fi

  if check_openedx_render_delta_allowlist "$RAW_OPENEDX_DF_SNAPSHOT" "$OPENEDX_DF"; then
    pass "Raw-vs-patched Open edX Dockerfile delta matches the build-optimizations allowed-delta ledger"
  else
    fail "Raw-vs-patched Open edX Dockerfile delta exceeds the build-optimizations allowed-delta ledger"
  fi
else
  skip "OpenEdX Dockerfile not found"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "=== Preflight Summary: $PASS PASS, $FAIL FAIL, $SKIP SKIP ==="

# Cleanup
rm -f "$RAW_OPENEDX_DF_SNAPSHOT" "$RAW_MFE_DF_SNAPSHOT"
rm -rf "$TUTOR_ROOT"

if [[ $FAIL -gt 0 ]]; then
  echo "Preflight FAILED. Fix the above issues before triggering a full build." >&2
  exit 1
fi

echo "Preflight PASSED. Safe to trigger full build."
exit 0
