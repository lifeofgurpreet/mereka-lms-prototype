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
# The build stack is pinned in requirements-tutor.txt (currently Tutor 21.0.0 Ulmo).
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

if [[ ! -x "$SYNC_SCRIPT" ]]; then
  echo "ERROR: Tutor plugin sync script not found or not executable at $SYNC_SCRIPT" >&2
  rm -f "$RAW_OPENEDX_DF_SNAPSHOT"
  rm -rf "$TUTOR_ROOT"
  exit 1
fi

if [[ ! -x "$PREP_SCRIPT" ]]; then
  echo "ERROR: Canonical build-context script not found or not executable at $PREP_SCRIPT" >&2
  rm -f "$RAW_OPENEDX_DF_SNAPSHOT"
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
  --set ENABLE_HTTPS=true \
  >/dev/null 2>&1

cp "$TUTOR_ROOT/env/build/openedx/Dockerfile" "$RAW_OPENEDX_DF_SNAPSHOT"
TUTOR_ROOT="$TUTOR_ROOT" "$PREP_SCRIPT" --target openedx >/dev/null 2>&1

# Apply patches to the rendered Dockerfile.
# NOTE: mfe-node.sh was removed in tracker #32. MFE Dockerfile patches are now
# handled by Tutor plugin hooks in _mereka_lms/mfe_dockerfile.py, applied at
# `tutor config save` time. This block now only runs brand-package and footer
# asset sync patches (file I/O operations that plugins cannot perform).
export MFE_TEMPLATE="$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
RENDERED_DF="$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
if [[ -f "$RENDERED_DF" ]]; then
  (
    export VIRTUAL_ENV="$TUTOR_VENV"
    export PATH="$TUTOR_VENV/bin:$PATH"
    export REPO_ROOT TUTOR_ROOT MFE_TEMPLATE
    mkdir -p "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe" 2>/dev/null || true
    rm -f "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile" 2>/dev/null || true
    cp "$RENDERED_DF" "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile" 2>/dev/null || true
    cd "$REPO_ROOT"
    source infrastructure/tutor/patches/_common.sh
    _discover_template_paths 2>/dev/null || true
    source infrastructure/tutor/patches/brand-package.sh
    apply_brand_package_patch 2>/dev/null || true
    source infrastructure/tutor/patches/footer-component.sh
    apply_footer_component_patch 2>/dev/null || true
  ) >/dev/null 2>&1 || true
fi

MFE_DF="$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
OPENEDX_DF="$TUTOR_ROOT/env/build/openedx/Dockerfile"

if [[ ! -f "$MFE_DF" ]]; then
  echo "ERROR: MFE Dockerfile not generated at $MFE_DF" >&2
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

  python3 - "$raw_df" "$patched_df" <<'PY'
from pathlib import Path
import difflib
import re
import sys

raw_text = Path(sys.argv[1]).read_text()
patched_text = Path(sys.argv[2]).read_text()
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

normalized_patched = patched_text.replace(wrapped_block, raw_block) if wrapped_block else patched_text
if raw_block and normalized_patched != raw_text:
    errors.append(
        "Unexpected raw-vs-patched Open edX Dockerfile delta remains after normalizing the translation wrapper block."
    )
    diff = "".join(
        difflib.unified_diff(
            raw_text.splitlines(keepends=True),
            normalized_patched.splitlines(keepends=True),
            fromfile="raw-openedx-dockerfile",
            tofile="patched-openedx-dockerfile-normalized",
        )
    ).rstrip()
    if diff:
        errors.append(diff)

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
INDIGO_ENV_CONFIG="$TUTOR_ROOT/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
# Determine which env.config.jsx will be used (varies by Tutor version)
ACTIVE_ENV_CONFIG=""
if [[ -f "$INDIGO_ENV_CONFIG" ]]; then
  ACTIVE_ENV_CONFIG="$INDIGO_ENV_CONFIG"
elif [[ -f "$ENV_CONFIG" ]]; then
  ACTIVE_ENV_CONFIG="$ENV_CONFIG"
fi

# Check if env.config.jsx imports the indigo footer package
ENV_CONFIG_IMPORTS_FOOTER=false
if [[ -n "$ACTIVE_ENV_CONFIG" ]] && grep -q "indigo-frontend-component-footer" "$ACTIVE_ENV_CONFIG" 2>/dev/null; then
  ENV_CONFIG_IMPORTS_FOOTER=true
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

# 3. All indigo component installs must use --legacy-peer-deps
bad_installs=$(grep -E "RUN npm install.*indigo-frontend-component" "$MFE_DF" | grep -v "legacy-peer-deps" || true)
if [[ -n "$bad_installs" ]]; then
  fail "indigo component install without --legacy-peer-deps: $bad_installs"
else
  pass "all indigo component installs use --legacy-peer-deps"
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

# ── OpenEdX Dockerfile Checks ───────────────────────────────────
echo ""
echo "--- OpenEdX Dockerfile Invariants ---"

if [[ -f "$OPENEDX_DF" ]]; then
  if grep -q "mysql_native_password" "$OPENEDX_DF" 2>/dev/null; then
    pass "MySQL auth plugin patch present"
  else
    skip "MySQL auth plugin not checked (may be in settings, not Dockerfile)"
  fi

  if check_openedx_render_delta_allowlist "$RAW_OPENEDX_DF_SNAPSHOT" "$OPENEDX_DF"; then
    pass "Raw-vs-patched Open edX Dockerfile delta is limited to the fast-profile translation wrapper block"
  else
    fail "Raw-vs-patched Open edX Dockerfile delta exceeds the fast-profile translation wrapper allowlist"
  fi
else
  skip "OpenEdX Dockerfile not found"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "=== Preflight Summary: $PASS PASS, $FAIL FAIL, $SKIP SKIP ==="

# Cleanup
rm -f "$RAW_OPENEDX_DF_SNAPSHOT"
rm -rf "$TUTOR_ROOT"

if [[ $FAIL -gt 0 ]]; then
  echo "Preflight FAILED. Fix the above issues before triggering a full build." >&2
  exit 1
fi

echo "Preflight PASSED. Safe to trigger full build."
exit 0
