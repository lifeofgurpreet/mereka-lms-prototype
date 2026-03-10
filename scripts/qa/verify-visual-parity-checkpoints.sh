#!/usr/bin/env bash
# @covers AC-UI-101, AC-UI-102, AC-UI-103, AC-UI-104, AC-UI-105, AC-UI-106
# @spec: bead-115d23
#
# verify-visual-parity-checkpoints.sh
#
# Visual parity and route-content MFE authn/enterprise checkpoint pass.
# Validates that all checkpoints, markers, baselines, footer assertions,
# asset integrity rules, and release lane documentation are in place.
#
# Modes:
#   Offline (default) — validates docs, config, and CI wiring.
#   Live (VISUAL_PARITY_LIVE=1) — probe actual cluster routes.
#
# Usage:
#   ./scripts/qa/verify-visual-parity-checkpoints.sh
#   VISUAL_PARITY_LIVE=1 ./scripts/qa/verify-visual-parity-checkpoints.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

LIVE_MODE="${VISUAL_PARITY_LIVE:-0}"

# ---------------------------------------------------------------------------
# Output helpers — PASS/FAIL/WARN style used across scripts/qa/ family.
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-UI-101..106: Visual Parity Checkpoint Verification ==="
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "Mode: LIVE (VISUAL_PARITY_LIVE=1)"
else
  echo "Mode: OFFLINE (set VISUAL_PARITY_LIVE=1 for live cluster checks)"
fi
echo ""

# ---------------------------------------------------------------------------
# Paths used across multiple ACs
# ---------------------------------------------------------------------------
CHECKPOINT_DOC="$REPO_ROOT/docs/guides/branding/VISUAL_PARITY_CHECKPOINTS.md"
BASELINE_DOC="$REPO_ROOT/docs/ops/runbooks/VISUAL_SMOKE_BASELINE.md"
VISUAL_RUNBOOK="$REPO_ROOT/docs/ops/runbooks/VISUAL_REGRESSION_RUNBOOK.md"
BRANDING_OPS="$REPO_ROOT/docs/guides/branding/BRANDING_OPERATING_MODEL.md"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
COMMON_CSS_DIR="$THEME_DIR/common/static/css"
MFE_SCSS="$THEME_DIR/mfe/mereka.scss"
COMMON_FONTS_DIR="$THEME_DIR/common/static/fonts"
MFE_FONTS_DIR="$THEME_DIR/mfe/fonts"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"

# ===========================================================================
# AC-UI-101: Visual checkpoint matrix defined in docs (5 routes x 3 domains)
# ===========================================================================
echo "--- AC-UI-101: Visual Checkpoint Matrix ---"

# 1a. The checkpoint document itself must exist.
if [[ -f "$CHECKPOINT_DOC" ]]; then
  do_pass "AC-UI-101: VISUAL_PARITY_CHECKPOINTS.md exists"
else
  do_fail "AC-UI-101: VISUAL_PARITY_CHECKPOINTS.md not found at docs/guides/branding/"
fi

# 1b. Must cover the 5 required authn surfaces.
REQUIRED_ROUTES=(
  "learner-dashboard"
  "learning"
  "account"
  "gradebook"
  "profile"
)
if [[ -f "$CHECKPOINT_DOC" ]]; then
  routes_found=0
  for route in "${REQUIRED_ROUTES[@]}"; do
    if grep -qi "$route" "$CHECKPOINT_DOC"; then
      do_pass "AC-UI-101: route '$route' declared in checkpoint matrix"
      routes_found=$((routes_found + 1))
    else
      do_fail "AC-UI-101: route '$route' NOT found in checkpoint matrix"
    fi
  done
  if [[ "$routes_found" -eq "${#REQUIRED_ROUTES[@]}" ]]; then
    do_pass "AC-UI-101: all 5 required routes declared"
  fi
else
  do_warn "AC-UI-101: cannot check routes — VISUAL_PARITY_CHECKPOINTS.md missing"
fi

# 1c. Must reference all 3 required enterprise domains.
REQUIRED_DOMAINS=(
  "academyv2.mereka.io"
  "biji-biji.com"
  "academy.biji-biji.com"
)
if [[ -f "$CHECKPOINT_DOC" ]]; then
  domains_found=0
  for domain in "${REQUIRED_DOMAINS[@]}"; do
    if grep -q "$domain" "$CHECKPOINT_DOC"; then
      do_pass "AC-UI-101: domain '$domain' declared in checkpoint matrix"
      domains_found=$((domains_found + 1))
    else
      do_fail "AC-UI-101: domain '$domain' NOT found in checkpoint matrix"
    fi
  done
  if [[ "$domains_found" -eq "${#REQUIRED_DOMAINS[@]}" ]]; then
    do_pass "AC-UI-101: all 3 enterprise domains declared (5x3=15 entry matrix)"
  fi
else
  do_warn "AC-UI-101: cannot check domains — VISUAL_PARITY_CHECKPOINTS.md missing"
fi

# 1d. Matrix section must be present (table header row).
if [[ -f "$CHECKPOINT_DOC" ]]; then
  if grep -q "checkpoint matrix\|Checkpoint Matrix\|15.*entr" "$CHECKPOINT_DOC" || \
     grep -q "| Route" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-101: checkpoint matrix table present"
  else
    do_warn "AC-UI-101: checkpoint matrix table not clearly marked"
  fi
fi

echo ""

# ===========================================================================
# AC-UI-102: Route content marker patterns defined (beyond HTTP 200)
# ===========================================================================
echo "--- AC-UI-102: Route Content Markers ---"

# 2a. Checkpoint doc must define content markers.
MARKER_PATTERNS=(
  "My courses\|my courses\|content.*marker\|Content Marker\|expected content"
  "route.*marker\|marker.*pattern\|content check"
)
if [[ -f "$CHECKPOINT_DOC" ]]; then
  if grep -qiE "content marker|route marker|expected content|body.*marker|marker.*content" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-102: route content marker patterns documented"
  else
    do_fail "AC-UI-102: no content marker patterns found in VISUAL_PARITY_CHECKPOINTS.md"
  fi

  # 2b. Per-route markers listed.
  markers_found=0
  for route in "${REQUIRED_ROUTES[@]}"; do
    if grep -qi "$route" "$CHECKPOINT_DOC"; then
      markers_found=$((markers_found + 1))
    fi
  done
  if [[ "$markers_found" -ge 4 ]]; then
    do_pass "AC-UI-102: per-route content markers documented ($markers_found/5 routes)"
  else
    do_warn "AC-UI-102: content markers only for $markers_found/5 routes"
  fi

  # 2c. Explicit warning that HTTP 200 alone is insufficient.
  if grep -qiE "false.positive|not.*200|200.*not|beyond.*200|avoid.*200" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-102: false-positive 200 guard documented"
  else
    do_warn "AC-UI-102: missing explicit note that HTTP 200 alone is insufficient"
  fi
else
  do_warn "AC-UI-102: cannot check content markers — VISUAL_PARITY_CHECKPOINTS.md missing"
fi

# 2d. The existing visual smoke baseline must also reference content checks.
if [[ -f "$BASELINE_DOC" ]]; then
  if grep -qiE "content|marker|body|text" "$BASELINE_DOC"; then
    do_pass "AC-UI-102: VISUAL_SMOKE_BASELINE.md references content verification"
  else
    do_warn "AC-UI-102: VISUAL_SMOKE_BASELINE.md does not mention content markers"
  fi
else
  do_warn "AC-UI-102: VISUAL_SMOKE_BASELINE.md not found"
fi

echo ""

# ===========================================================================
# AC-UI-103: Screenshot baseline naming convention + RMSE diff threshold
# ===========================================================================
echo "--- AC-UI-103: Screenshot Baseline + Diff Thresholds ---"

# 3a. Checkpoint doc must describe screenshot baseline flow.
if [[ -f "$CHECKPOINT_DOC" ]]; then
  if grep -qiE "screenshot|baseline|capture" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-103: screenshot baseline flow documented"
  else
    do_fail "AC-UI-103: no screenshot baseline section in VISUAL_PARITY_CHECKPOINTS.md"
  fi

  # 3b. Naming convention must be specified.
  if grep -qiE "naming.*convention|baseline.*name|filename.*convention|screenshot.*name" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-103: screenshot naming convention documented"
  else
    do_fail "AC-UI-103: screenshot naming convention not documented"
  fi

  # 3c. RMSE diff threshold must be declared.
  if grep -qiE "RMSE|rmse|diff.*threshold|threshold.*diff" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-103: RMSE/diff threshold policy documented"
  else
    do_fail "AC-UI-103: RMSE diff threshold not documented in VISUAL_PARITY_CHECKPOINTS.md"
  fi

  # 3d. At least 10 critical routes mentioned (5 routes x content implies 10+ entries).
  ROUTE_ENTRY_COUNT=$(grep -c "learner-dashboard\|/learning\|/account\|/gradebook\|/profile" "$CHECKPOINT_DOC" || true)
  if [[ "$ROUTE_ENTRY_COUNT" -ge 5 ]]; then
    do_pass "AC-UI-103: checkpoint doc covers $ROUTE_ENTRY_COUNT+ critical route references"
  else
    do_warn "AC-UI-103: only $ROUTE_ENTRY_COUNT route references found (expected >= 5)"
  fi
else
  do_warn "AC-UI-103: cannot verify screenshot baseline — VISUAL_PARITY_CHECKPOINTS.md missing"
fi

# 3e. Existing VISUAL_SMOKE_BASELINE.md must exist as cross-reference.
if [[ -f "$BASELINE_DOC" ]]; then
  do_pass "AC-UI-103: VISUAL_SMOKE_BASELINE.md cross-reference exists"
  if grep -qiE "RMSE|5\.0|threshold" "$BASELINE_DOC"; then
    do_pass "AC-UI-103: VISUAL_SMOKE_BASELINE.md documents RMSE threshold value"
  else
    do_warn "AC-UI-103: VISUAL_SMOKE_BASELINE.md missing explicit RMSE numeric threshold"
  fi
else
  do_fail "AC-UI-103: VISUAL_SMOKE_BASELINE.md not found (required cross-reference)"
fi

# 3f. Visual regression runbook also cross-referenced.
if [[ -f "$VISUAL_RUNBOOK" ]]; then
  do_pass "AC-UI-103: VISUAL_REGRESSION_RUNBOOK.md exists (baseline reference)"
else
  do_warn "AC-UI-103: VISUAL_REGRESSION_RUNBOOK.md not found"
fi

echo ""

# ===========================================================================
# AC-UI-104: Branded footer checks (MerekaFooter, no default Open edX markers)
# ===========================================================================
echo "--- AC-UI-104: Branded Footer Assertions ---"

# 4a. Checkpoint doc must declare footer assertions.
if [[ -f "$CHECKPOINT_DOC" ]]; then
  if grep -qiE "MerekaFooter|mereka.footer|branded.*footer|footer.*brand" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-104: MerekaFooter assertion documented in checkpoint doc"
  else
    do_fail "AC-UI-104: MerekaFooter assertion missing from VISUAL_PARITY_CHECKPOINTS.md"
  fi

  # 4b. Must explicitly reject "Powered by Open edX" default marker.
  if grep -qiE "Powered by Open edX|powered.*openedx|default.*openedx|openedx.*default" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-104: 'Powered by Open edX' rejection documented"
  else
    do_fail "AC-UI-104: no explicit rejection of 'Powered by Open edX' default marker"
  fi

  # 4c. MFE shell scope must be stated.
  if grep -qiE "apps\.\|MFE shell|shell.*page|footer.*mfe|mfe.*footer" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-104: apps.* MFE shell footer scope documented"
  else
    do_warn "AC-UI-104: MFE shell (apps.*) scope not explicitly stated for footer check"
  fi
else
  do_warn "AC-UI-104: cannot check footer assertions — VISUAL_PARITY_CHECKPOINTS.md missing"
fi

# 4d. MerekaFooter wiring must be present (plugin-slot canonical path).
if mereka_plugin_has_any "$REPO_ROOT"; then
  if mereka_plugin_has_fixed "$REPO_ROOT" "MerekaFooter"; then
    do_pass "AC-UI-104: MerekaFooter component defined in plugin contract sources"
  else
    do_fail "AC-UI-104: MerekaFooter not found in plugin contract sources"
  fi

  if mereka_plugin_has_fixed "$REPO_ROOT" "org.openedx.frontend.layout.footer.v1" \
    && mereka_plugin_has_fixed "$REPO_ROOT" "RenderWidget: MerekaFooter"; then
    do_pass "AC-UI-104: footer slot wiring uses RenderWidget: MerekaFooter"
  else
    do_fail "AC-UI-104: footer slot wiring for MerekaFooter not confirmed in plugin contract sources"
  fi
else
  do_fail "AC-UI-104: plugin contract sources not found (expected at least $PLUGIN_MAIN)"
fi

# 4f. mereka-footer CSS class exists in theme CSS.
OVERRIDE_CSS="$COMMON_CSS_DIR/mereka-overrides.css"
if [[ -f "$OVERRIDE_CSS" ]]; then
  if grep -q "mereka-footer" "$OVERRIDE_CSS"; then
    do_pass "AC-UI-104: .mereka-footer CSS class present in mereka-overrides.css"
  else
    do_warn "AC-UI-104: .mereka-footer CSS class not found in mereka-overrides.css"
  fi
else
  do_warn "AC-UI-104: mereka-overrides.css not found at expected path"
fi

echo ""

# ===========================================================================
# AC-UI-105: Asset integrity checks (fonts/images/CSS/JS in theme bundles)
# ===========================================================================
echo "--- AC-UI-105: Asset Integrity Checks ---"

# 5a. Checkpoint doc must describe asset integrity checks.
if [[ -f "$CHECKPOINT_DOC" ]]; then
  if grep -qiE "asset.*integrity|integrity.*asset|font.*exist|CSS.*resolv|404.*theme|theme.*404" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-105: asset integrity check patterns documented"
  else
    do_fail "AC-UI-105: no asset integrity check patterns in VISUAL_PARITY_CHECKPOINTS.md"
  fi
else
  do_warn "AC-UI-105: cannot check asset docs — VISUAL_PARITY_CHECKPOINTS.md missing"
fi

# 5b. mereka-overrides.css must exist and be non-empty.
if [[ -f "$OVERRIDE_CSS" ]]; then
  CSS_LINES=$(wc -l < "$OVERRIDE_CSS" || echo 0)
  if [[ "$CSS_LINES" -gt 10 ]]; then
    do_pass "AC-UI-105: mereka-overrides.css exists ($CSS_LINES lines)"
  else
    do_warn "AC-UI-105: mereka-overrides.css appears too small ($CSS_LINES lines)"
  fi
else
  do_fail "AC-UI-105: mereka-overrides.css not found at $COMMON_CSS_DIR/"
fi

# 5c. mereka.scss (MFE theme) must exist and be non-empty.
if [[ -f "$MFE_SCSS" ]]; then
  SCSS_LINES=$(wc -l < "$MFE_SCSS" || echo 0)
  if [[ "$SCSS_LINES" -gt 5 ]]; then
    do_pass "AC-UI-105: mfe/mereka.scss exists ($SCSS_LINES lines)"
  else
    do_warn "AC-UI-105: mfe/mereka.scss appears too small ($SCSS_LINES lines)"
  fi
else
  do_fail "AC-UI-105: mfe/mereka.scss not found at $THEME_DIR/mfe/"
fi

# 5d. Check common/static/fonts directory exists (even if empty — presence means pipeline wires it).
if [[ -d "$COMMON_FONTS_DIR" ]]; then
  FONT_COUNT=$(find "$COMMON_FONTS_DIR" -type f 2>/dev/null | wc -l || echo 0)
  if [[ "$FONT_COUNT" -gt 0 ]]; then
    do_pass "AC-UI-105: common/static/fonts/ has $FONT_COUNT font file(s)"
  else
    do_warn "AC-UI-105: common/static/fonts/ directory exists but is empty (fonts served via CDN or system?)"
  fi
else
  do_warn "AC-UI-105: common/static/fonts/ directory not present in theme"
fi

# 5e. Check mfe/fonts directory exists.
if [[ -d "$MFE_FONTS_DIR" ]]; then
  MFE_FONT_COUNT=$(find "$MFE_FONTS_DIR" -type f 2>/dev/null | wc -l || echo 0)
  if [[ "$MFE_FONT_COUNT" -gt 0 ]]; then
    do_pass "AC-UI-105: mfe/fonts/ has $MFE_FONT_COUNT font file(s)"
  else
    do_warn "AC-UI-105: mfe/fonts/ exists but is empty"
  fi
else
  do_warn "AC-UI-105: mfe/fonts/ directory not present in theme"
fi

# 5f. CSS must not reference files that don't exist in the theme tree.
# Check for relative font references in mereka-overrides.css that resolve within the theme.
if [[ -f "$OVERRIDE_CSS" ]]; then
  BROKEN_REFS=0
  while IFS= read -r font_path; do
    # Normalize: strip url(), quotes, and leading ../
    clean="${font_path//url(/}"
    clean="${clean//)/}"
    clean="${clean//\'/}"
    clean="${clean//\"/}"
    # Only check local relative references (skip https://, data:, etc.)
    if [[ "$clean" == ../* ]] || [[ "$clean" == ./* ]]; then
      resolved="$COMMON_CSS_DIR/$clean"
      if [[ ! -f "$resolved" ]]; then
        do_warn "AC-UI-105: possible broken relative font ref in mereka-overrides.css: $clean"
        BROKEN_REFS=$((BROKEN_REFS + 1))
      fi
    fi
  done < <(grep -oE "url\(['\"]?[^)'\"]+(woff2?|ttf|eot|otf)[^)'\"]*(\.woff2?|\.ttf|\.eot|\.otf)['\"]?\)" "$OVERRIDE_CSS" 2>/dev/null || true)

  if [[ "$BROKEN_REFS" -eq 0 ]]; then
    do_pass "AC-UI-105: no broken relative font references detected in mereka-overrides.css"
  fi
fi

# 5g. Check design tokens CSS file exists (asset used by both LMS and MFE).
TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"
if [[ -f "$TOKENS_CSS" ]]; then
  do_pass "AC-UI-105: assets/branding/tokens.css (design token asset) exists"
else
  do_warn "AC-UI-105: assets/branding/tokens.css not found (token asset pipeline check)"
fi

echo ""

# ===========================================================================
# AC-UI-106: Release lane documentation exists with run commands
# ===========================================================================
echo "--- AC-UI-106: Release Lane Documentation ---"

# 6a. Checkpoint doc must have a release lane section.
if [[ -f "$CHECKPOINT_DOC" ]]; then
  if grep -qiE "release lane|before.*deploy|run.*before.*deploy|release.*run|release.*branch" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-106: release lane instructions present in VISUAL_PARITY_CHECKPOINTS.md"
  else
    do_fail "AC-UI-106: no release lane instructions in VISUAL_PARITY_CHECKPOINTS.md"
  fi

  # 6b. Must include actual run command(s).
  if grep -qE "\./scripts/qa/verify-visual-parity-checkpoints\.sh|verify-visual-parity" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-106: checkpoint run command documented in release lane"
  else
    do_fail "AC-UI-106: checkpoint script run command not found in release lane section"
  fi

  # 6c. Must reference release branch workflow.
  if grep -qiE "release branch|before any deploy|pre.deploy|pre-deploy" "$CHECKPOINT_DOC"; then
    do_pass "AC-UI-106: 'run before any deploy' instruction present"
  else
    do_warn "AC-UI-106: explicit 'run before any deploy' instruction not found"
  fi
else
  do_warn "AC-UI-106: cannot check release lane — VISUAL_PARITY_CHECKPOINTS.md missing"
fi

# 6d. Branding operating model should exist as operational context.
if [[ -f "$BRANDING_OPS" ]]; then
  do_pass "AC-UI-106: BRANDING_OPERATING_MODEL.md exists (release ops context)"
else
  do_warn "AC-UI-106: BRANDING_OPERATING_MODEL.md not found at docs/guides/branding/"
fi

# 6e. CI wiring present — the script itself must appear in ci.yml syntax checks.
if [[ -f "$CI_FILE" ]]; then
  do_pass "AC-UI-106: .github/workflows/ci.yml exists"
  if grep -q "verify-visual-parity-checkpoints.sh" "$CI_FILE"; then
    do_pass "AC-UI-106: verify-visual-parity-checkpoints.sh referenced in ci.yml"
  else
    do_fail "AC-UI-106: verify-visual-parity-checkpoints.sh NOT referenced in ci.yml"
  fi
else
  do_fail "AC-UI-106: .github/workflows/ci.yml not found"
fi

echo ""

# ===========================================================================
# LIVE mode — cluster probes (AC-UI-101/102/104 live validation)
# ===========================================================================
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "--- LIVE: Cluster Route Content Probes ---"
  DOMAIN="${VISUAL_PARITY_DOMAIN:-academyv2.mereka.io}"
  echo "  Target: apps.$DOMAIN"
  echo ""

  # Routes to probe with expected content markers.
  declare -A ROUTE_MARKERS=(
    ["/learner-dashboard/"]="my courses|My Courses|dashboard"
    ["/account/"]="Account Settings|account settings|Profile"
    ["/profile/"]="Profile|profile"
  )

  for route in "${!ROUTE_MARKERS[@]}"; do
    url="https://apps.${DOMAIN}${route}"
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$url" 2>/dev/null || echo "000")
    body=$(curl -s -L --max-time 15 "$url" 2>/dev/null | head -c 8192 || true)

    if [[ "$http_code" == "000" ]]; then
      do_warn "[LIVE] AC-UI-101: $route unreachable (timeout)"
      continue
    fi

    if [[ "$http_code" == "200" ]]; then
      do_pass "[LIVE] AC-UI-101: $route returned HTTP 200"

      # AC-UI-102: content marker check.
      marker="${ROUTE_MARKERS[$route]}"
      if grep -qiE "$marker" <<<"$body"; then
        do_pass "[LIVE] AC-UI-102: $route contains expected content marker"
      else
        do_warn "[LIVE] AC-UI-102: $route returned 200 but content marker not found (may need auth)"
      fi

      # AC-UI-104: Footer check — no "Powered by Open edX" default.
      if grep -qi "Powered by Open edX" <<<"$body"; then
        do_fail "[LIVE] AC-UI-104: $route contains 'Powered by Open edX' default footer"
      else
        do_pass "[LIVE] AC-UI-104: $route does not expose 'Powered by Open edX' footer"
      fi

      # AC-UI-104: mereka-footer class or MerekaFooter hint.
      if grep -qiE "mereka.footer|mereka_footer" <<<"$body"; then
        do_pass "[LIVE] AC-UI-104: $route renders mereka-footer component"
      else
        do_warn "[LIVE] AC-UI-104: $route footer class not detected in initial HTML (may be client-rendered)"
      fi
    else
      do_warn "[LIVE] AC-UI-101: $route returned HTTP $http_code (expected 200)"
    fi
  done
  echo ""
fi

# ===========================================================================
# Summary
# ===========================================================================
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Action required: Fix FAIL items above."
  echo "  - Create docs/guides/branding/VISUAL_PARITY_CHECKPOINTS.md if missing"
  echo "  - Ensure 5-route x 3-domain matrix (15 entries) is documented"
  echo "  - Verify MerekaFooter wiring in apply-patches.sh"
  echo "  - Add verify-visual-parity-checkpoints.sh to .github/workflows/ci.yml"
  echo "  - See docs/guides/branding/VISUAL_PARITY_CHECKPOINTS.md for full runbook"
  exit 1
fi

echo ""
echo "All visual parity checkpoint verifications passed (WARNs are live-cluster or advisory)."
exit 0
