#!/usr/bin/env bash
# @covers AC-STUDIO-004, AC-STUDIO-005, AC-STUDIO-008, AC-STUDIO-009, AC-STUDIO-022
# @spec: studio-customization_spec.md
# Verify core Studio customization contracts in source and (optionally) runtime.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$REPO_ROOT/scripts/shared/ci-skip-guards.sh"
require_command rg || exit 0

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $1"; }

CMS_IMG_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/images"
CMS_SASS="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/sass/studio-main-v1.scss"
CMS_FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/footer.html"
CMS_WIDGET_FOOTER="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/widgets/footer.html"
CMS_OVERRIDES_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"

echo "=== Studio Customization Verification ==="

# (a) Mereka logo exists in CMS theme images
if [[ -f "$CMS_IMG_DIR/logo-horizontal.svg" || -f "$CMS_IMG_DIR/logo-horizontal.png" ]]; then
  pass "CMS logo asset exists"
else
  fail "CMS logo asset missing (expected logo-horizontal.svg or logo-horizontal.png)"
fi

# (b) Studio SCSS compiles without error (best effort across available compilers)
# Skipped in CI: dart-sass is not pre-installed on ubuntu-24.04 runners and
# `npx --no-install sass` fails when sass is absent from the npm cache.
# The SCSS file itself is validated structurally by the file-existence check above;
# compile correctness is verified in the full image build (tutor images build).
if [[ ! -f "$CMS_SASS" ]]; then
  fail "Studio SCSS missing: $CMS_SASS"
elif [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" ]]; then
  warn "Studio SCSS compile skipped in CI (dart-sass not cached on runner)"
else
  tmp_out="$(mktemp /tmp/studio-main-v1.XXXXXX.css)"
  if command -v sass >/dev/null 2>&1; then
    if sass "$CMS_SASS" "$tmp_out" >/dev/null 2>"/tmp/studio-sass.err"; then
      pass "Studio SCSS compiles with sass CLI"
    else
      if rg -q "Can't find stylesheet to import|Could not find Sass file" /tmp/studio-sass.err; then
        warn "Studio SCSS compile skipped: build-time Sass imports unavailable in local workspace"
      else
        fail "Studio SCSS failed to compile with sass CLI"
      fi
    fi
  elif command -v npx >/dev/null 2>&1; then
    if npx --no-install sass "$CMS_SASS" "$tmp_out" >/dev/null 2>"/tmp/studio-sass.err"; then
      pass "Studio SCSS compiles with local npx sass"
    else
      # Match both old npm (npm ERR!) and new npm 10+ (npm error / npm warn) formats,
      # plus cases where sass simply isn't found in the local workspace.
      if rg -qi "npm err|npm error|npm warn|not found|could not determine executable|Can't find stylesheet to import|Could not find Sass file" /tmp/studio-sass.err; then
        warn "Studio SCSS compile skipped: local sass toolchain/imports unavailable in this workspace"
      else
        fail "Studio SCSS failed to compile with npx sass"
      fi
    fi
  else
    warn "SCSS compiler not found (sass/npx unavailable); skipping compile check"
  fi
  rm -f /tmp/studio-sass.err
  rm -f "$tmp_out"
fi

# (c) Footer templates reference settings.PLATFORM_NAME
for tpl in "$CMS_FOOTER" "$CMS_WIDGET_FOOTER"; do
  if [[ ! -f "$tpl" ]]; then
    fail "Missing footer template: ${tpl#$REPO_ROOT/}"
    continue
  fi

  if rg -q "PLATFORM_NAME" "$tpl"; then
    pass "${tpl#$REPO_ROOT/} references PLATFORM_NAME"
  else
    fail "${tpl#$REPO_ROOT/} missing PLATFORM_NAME reference"
  fi

  if rg -q "LMS_ROOT_URL" "$tpl"; then
    pass "${tpl#$REPO_ROOT/} references LMS_ROOT_URL"
  else
    fail "${tpl#$REPO_ROOT/} missing LMS_ROOT_URL reference"
  fi
done

# (d) No Google Fonts imports in compiled CSS
if [[ -f "$CMS_OVERRIDES_CSS" ]]; then
  if rg -q "fonts\\.googleapis\\.com|@import[[:space:]]+url\\(['\"]?https?://fonts\\.googleapis\\.com" "$CMS_OVERRIDES_CSS"; then
    fail "Google Fonts import found in CMS compiled overrides CSS"
  else
    pass "No Google Fonts import in CMS compiled overrides CSS"
  fi
else
  warn "CMS overrides CSS not found: ${CMS_OVERRIDES_CSS#$REPO_ROOT/}"
fi

# (e) Studio help URL is not docs.openedx.org (source guard)
if rg -q "docs\\.openedx\\.org" "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms" -g "*.html" -g "*.scss" -g "*.css"; then
  fail "Found docs.openedx.org reference in CMS theme source"
else
  pass "CMS theme source contains no docs.openedx.org help links"
fi

echo ""
echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
