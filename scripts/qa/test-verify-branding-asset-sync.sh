#!/usr/bin/env bash
# Seeded-defect self-test for verify-branding-asset-sync.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-branding-asset-sync.sh"

tmpdir="$(mktemp -d -t verify-branding-asset-sync.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/tutor_env/env/build/openedx/themes/mereka/lms/static/images" \
  "$tmpdir/tutor_env/env/build/openedx/themes/mereka/lms/static/fonts" \
  "$tmpdir/tutor_env/env/build/openedx/themes/mereka/cms/static/images" \
  "$tmpdir/tutor_env/env/plugins/mfe/build/mfe/mereka/theme-source" \
  "$tmpdir/tutor_env/env/apps/openedx/settings/lms" \
  "$tmpdir/infrastructure/tutor" \
  "$tmpdir/infrastructure/tutor/patches" \
  "$tmpdir/infrastructure/tutor/plugins/_mereka_lms" \
  "$tmpdir/scripts/branding"

for logo in \
  logo.png \
  logo-horizontal.png \
  logo-horizontal-white.png \
  logo-square.png \
  logo-horizontal.svg \
  logo-horizontal-white.svg \
  logo-square.svg \
  favicon.ico; do
  : >"$tmpdir/tutor_env/env/build/openedx/themes/mereka/lms/static/images/$logo"
done

: >"$tmpdir/tutor_env/env/build/openedx/themes/mereka/lms/static/fonts/Lato-Regular.woff2"
: >"$tmpdir/tutor_env/env/build/openedx/themes/mereka/cms/static/images/logo.png"
: >"$tmpdir/tutor_env/env/plugins/mfe/build/mfe/mereka/theme-source/mereka.scss"

cat >"$tmpdir/infrastructure/tutor/apply-patches.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
PATCHES_DIR="$(pwd)/infrastructure/tutor/patches"
# mfe-node.sh removed in tracker #32; MFE hooks are in the Tutor plugin module
source "$PATCHES_DIR/brand-package.sh"
EOF

# Minimal plugin module mock to satisfy verify-branding-asset-sync.sh check
cat >"$tmpdir/infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py" <<'EOF'
# Mock mfe_dockerfile.py for test fixture
_register_env_patch("mfe-dockerfile-pre-npm-install", "")
EOF

cat >"$tmpdir/scripts/branding/sync-brand-package.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF

cat >"$tmpdir/scripts/branding/sync-brand-assets.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
BRAND_PACKAGE_SYNC="./scripts/branding/sync-brand-package.sh"
"$BRAND_PACKAGE_SYNC"
EOF

chmod +x \
  "$tmpdir/infrastructure/tutor/apply-patches.sh" \
  "$tmpdir/scripts/branding/sync-brand-package.sh" \
  "$tmpdir/scripts/branding/sync-brand-assets.sh"

cat >"$tmpdir/infrastructure/tutor/patches/google-fonts.patch" <<'EOF'
strip fonts.googleapis.com imports from theme assets
EOF

cat >"$tmpdir/tutor_env/env/apps/openedx/settings/lms/production.py" <<'EOF'
DEFAULT_SITE_THEME = "mereka"
EOF

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-branding-asset-sync.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-branding-asset-sync.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-branding-asset-sync.out 2>&1
  echo "PASS ${label}"
}

# Case 1: complete sync fixture passes.
run_expect_pass "branding asset sync contract passes with complete fixture"

# Case 2: missing build logo variant fails.
rm -f "$tmpdir/tutor_env/env/build/openedx/themes/mereka/lms/static/images/logo-horizontal.svg"
run_expect_fail "missing synced logo variant is rejected"

echo "OK"
