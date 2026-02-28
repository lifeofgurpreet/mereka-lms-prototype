#!/usr/bin/env bash
# @covers AC-PERF-009, AC-PERF-010, AC-PERF-011
# @spec: frontend-performance-budgets_spec.md
# Verify font preload + swap + woff2-only contracts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $1"; }

RUNTIME_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-url) RUNTIME_URL="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

HEAD_FILES=(
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/templates/head-extra.html"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/head-extra.html"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/head-extra.html"
  "$REPO_ROOT/deploy/k8s/base/apps/openedx/theme/head-extra.html"
)

FONT_SCSS_FILES=(
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_fonts.scss"
  "$REPO_ROOT/infrastructure/tutor/brand-mereka/paragon/fonts.scss"
)

FONT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts"

echo "=== Font Loading Verification ==="

for f in "${HEAD_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    fail "Missing head-extra template: ${f#$REPO_ROOT/}"
    continue
  fi

  if rg -q "Poppins-Regular\\.woff2" "$f"; then
    pass "${f#$REPO_ROOT/} preloads Poppins-Regular.woff2"
  else
    fail "${f#$REPO_ROOT/} missing Poppins-Regular preload"
  fi

  if rg -q "Poppins-SemiBold\\.woff2" "$f"; then
    pass "${f#$REPO_ROOT/} preloads Poppins-SemiBold.woff2"
  else
    fail "${f#$REPO_ROOT/} missing Poppins-SemiBold preload"
  fi
done

for f in "${FONT_SCSS_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    fail "Missing font stylesheet: ${f#$REPO_ROOT/}"
    continue
  fi

  ff_count="$(rg -c "@font-face" "$f" || true)"
  swap_count="$(rg -c "font-display:[[:space:]]*swap" "$f" || true)"
  if [[ "$ff_count" -gt 0 && "$swap_count" -ge "$ff_count" ]]; then
    pass "${f#$REPO_ROOT/} applies font-display: swap for all @font-face rules"
  else
    fail "${f#$REPO_ROOT/} missing font-display: swap on one or more @font-face rules"
  fi
done

if [[ -d "$FONT_DIR" ]]; then
  bad_fonts="$(find "$FONT_DIR" -maxdepth 1 -type f ! -name '*.woff2' | wc -l | tr -d ' ')"
  if [[ "$bad_fonts" -eq 0 ]]; then
    pass "Font directory is WOFF2-only: ${FONT_DIR#$REPO_ROOT/}"
  else
    fail "Found non-WOFF2 files in ${FONT_DIR#$REPO_ROOT/}"
  fi
else
  fail "Font directory missing: ${FONT_DIR#$REPO_ROOT/}"
fi

if [[ -n "$RUNTIME_URL" ]]; then
  html="$(curl -fsSL --connect-timeout 10 --max-time 20 "$RUNTIME_URL" 2>/dev/null || true)"
  if [[ -z "$html" ]]; then
    warn "Runtime URL unreachable: $RUNTIME_URL"
  else
    if rg -q "Poppins-Regular\\.woff2" <<<"$html"; then
      pass "Runtime HTML references Poppins-Regular.woff2"
    else
      warn "Runtime HTML does not reference Poppins-Regular.woff2"
    fi
    if rg -q "Poppins-SemiBold\\.woff2" <<<"$html"; then
      pass "Runtime HTML references Poppins-SemiBold.woff2"
    else
      warn "Runtime HTML does not reference Poppins-SemiBold.woff2"
    fi
  fi
fi

echo ""
echo "=== Summary: PASS=$PASS WARN=$WARN FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]

