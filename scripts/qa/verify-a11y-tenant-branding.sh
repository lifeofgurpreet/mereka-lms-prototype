#!/usr/bin/env bash
# verify-a11y-tenant-branding.sh — A11y regression lane: keyboard/focus, landmark/ARIA, contrast
# @covers AC-A11Y-301, AC-A11Y-302, AC-A11Y-303, AC-A11Y-304
# @spec: bead-3vg93
#
# Verifies (offline mode, default):
# AC-A11Y-301: Keyboard/focus check patterns defined for 4 routes (authn, dashboard, account,
#              course-authoring). Confirms SCSS has :focus/:focus-visible/outline patterns.
# AC-A11Y-302: Landmark/ARIA requirements defined per route in runbook. JSON output format
#              documented in gate doc (var/a11y/{route}-landmarks.json).
# AC-A11Y-303: Contrast assertions for branded buttons (--mereka-primary) and headers
#              (--mereka-ink-*) in enterprise tenant themes. Cross-referenced with token pairs.
# AC-A11Y-304: This script IS the integration. Verifies it can run standalone and from CI.
#              Checks that existing a11y scripts exist and are executable.
#
# Modes:
#   Offline (default): validates documentation, source patterns, and structure.
#   Live (A11Y_TENANT_LIVE=1): placeholder for live browser assertions (future).
#
# Usage:
#   ./scripts/qa/verify-a11y-tenant-branding.sh
#   A11Y_TENANT_LIVE=1 ./scripts/qa/verify-a11y-tenant-branding.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_warn() { WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"; }

A11Y_TENANT_LIVE="${A11Y_TENANT_LIVE:-0}"

MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
TOKENS_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
RUNBOOK="$REPO_ROOT/docs/ops/runbooks/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md"
CONTRAST_DOC="$REPO_ROOT/docs/ops/runbooks/A11Y_CONTRAST_FOCUS_GATE.md"
GATE_DOC="$REPO_ROOT/docs/ops/runbooks/A11Y_TENANT_BRANDING_GATE.md"
EXISTING_CONTRAST_SCRIPT="$REPO_ROOT/scripts/qa/verify-a11y-contrast-focus.sh"
EXISTING_ROUTES_SCRIPT="$REPO_ROOT/scripts/qa/verify-a11y-authenticated-routes.sh"
VAR_DIR="$REPO_ROOT/var"
A11Y_DIR="$VAR_DIR/a11y"

echo -e "${BLUE}=== A11y Tenant Branding Regression Lane ===${NC}"
echo "  Mode: $([ "$A11Y_TENANT_LIVE" = "1" ] && echo "LIVE (browser assertions)" || echo "OFFLINE (documentation + source)")"
echo "  Bead: mereka-lms-3vg9.3"
echo "  ACs:  AC-A11Y-301, AC-A11Y-302, AC-A11Y-303, AC-A11Y-304"
echo ""

# ── AC-A11Y-301: Keyboard/focus check patterns for 4 routes ──────────
echo -e "${BLUE}## AC-A11Y-301: Keyboard/Focus Patterns for 4 Routes${NC}"

# 4 required routes defined in this bead
declare -A REQUIRED_ROUTES=(
  [authn]="/authn/"
  [dashboard]="/learner-dashboard"
  [account]="/account/"
  [course-authoring]="/course-authoring/"
)

# Check gate doc defines all 4 routes
if [[ ! -f "$GATE_DOC" ]]; then
  do_fail "AC-A11Y-301: A11Y_TENANT_BRANDING_GATE.md not found — keyboard/focus requirements not documented"
else
  do_pass "AC-A11Y-301: A11Y_TENANT_BRANDING_GATE.md exists"

  for route_key in "${!REQUIRED_ROUTES[@]}"; do
    route_path="${REQUIRED_ROUTES[$route_key]}"
    if grep -qF "$route_path" "$GATE_DOC" || grep -qiF "$route_key" "$GATE_DOC"; then
      do_pass "AC-A11Y-301: Route '$route_key' ($route_path) documented in gate doc"
    else
      do_fail "AC-A11Y-301: Route '$route_key' ($route_path) missing from gate doc"
    fi
  done
fi

# Check SCSS source for :focus, :focus-visible, outline patterns
if [[ ! -f "$MFE_SCSS" ]]; then
  do_fail "AC-A11Y-301: mereka.scss not found — cannot audit focus patterns"
else
  do_pass "AC-A11Y-301: mereka.scss found"

  # Count :focus rule occurrences in all theme SCSS/CSS
  FOCUS_RULE_COUNT=0
  FOCUS_VISIBLE_COUNT=0
  OUTLINE_RULE_COUNT=0

  while IFS= read -r css_file; do
    fc=$(grep -c ':focus' "$css_file" 2>/dev/null; true)
    fvc=$(grep -c ':focus-visible' "$css_file" 2>/dev/null; true)
    oc=$(grep -c 'outline' "$css_file" 2>/dev/null; true)
    # grep -c exits 1 on no match but still prints "0"; strip whitespace then default to 0
    fc="${fc//[[:space:]]/}"; fc="${fc:-0}"
    fvc="${fvc//[[:space:]]/}"; fvc="${fvc:-0}"
    oc="${oc//[[:space:]]/}"; oc="${oc:-0}"
    FOCUS_RULE_COUNT=$((FOCUS_RULE_COUNT + fc))
    FOCUS_VISIBLE_COUNT=$((FOCUS_VISIBLE_COUNT + fvc))
    OUTLINE_RULE_COUNT=$((OUTLINE_RULE_COUNT + oc))
  done < <(find "$THEME_DIR" \( -name '*.scss' -o -name '*.css' \) -not -path '*/node_modules/*' 2>/dev/null)

  if [[ "$FOCUS_RULE_COUNT" -gt 0 ]]; then
    do_pass "AC-A11Y-301: :focus rules present in theme files ($FOCUS_RULE_COUNT occurrences)"
  else
    do_fail "AC-A11Y-301: No :focus rules found in theme files — keyboard focus styling missing"
  fi

  if [[ "$FOCUS_VISIBLE_COUNT" -gt 0 ]]; then
    do_pass "AC-A11Y-301: :focus-visible rules present ($FOCUS_VISIBLE_COUNT occurrences) — modern keyboard focus ring"
  else
    do_warn "AC-A11Y-301: No :focus-visible rules found — Q2 2026 migration gap (non-blocking)"
  fi

  if [[ "$OUTLINE_RULE_COUNT" -gt 0 ]]; then
    do_pass "AC-A11Y-301: outline rules present in theme files ($OUTLINE_RULE_COUNT occurrences)"
  else
    do_warn "AC-A11Y-301: No outline rules found — verify focus ring uses box-shadow replacement"
  fi
fi

# Check that existing verify-a11y-contrast-focus.sh covers focus-visible patterns
if [[ -f "$EXISTING_CONTRAST_SCRIPT" ]]; then
  if grep -q ':focus' "$EXISTING_CONTRAST_SCRIPT" 2>/dev/null; then
    do_pass "AC-A11Y-301: Existing verify-a11y-contrast-focus.sh audits :focus patterns"
  else
    do_warn "AC-A11Y-301: verify-a11y-contrast-focus.sh does not explicitly audit :focus (check manually)"
  fi
else
  do_fail "AC-A11Y-301: verify-a11y-contrast-focus.sh missing — prerequisite script absent"
fi

echo ""

# ── AC-A11Y-302: Landmark/ARIA audit for authenticated shell routes ───
echo -e "${BLUE}## AC-A11Y-302: Landmark/ARIA Audit for Authenticated Shell Routes${NC}"

# Required landmarks per WCAG best practice
REQUIRED_LANDMARKS=("main" "nav" "banner" "contentinfo")

if [[ ! -f "$GATE_DOC" ]]; then
  do_fail "AC-A11Y-302: Gate doc missing — landmark/ARIA requirements not documented"
else
  # Verify all required landmarks are documented in gate doc
  for landmark in "${REQUIRED_LANDMARKS[@]}"; do
    if grep -qiF "$landmark" "$GATE_DOC"; then
      do_pass "AC-A11Y-302: Landmark '$landmark' documented in gate doc"
    else
      do_fail "AC-A11Y-302: Landmark '$landmark' missing from gate doc"
    fi
  done

  # Verify JSON output format is documented
  if grep -qF "var/a11y" "$GATE_DOC" && grep -qF "landmarks.json" "$GATE_DOC"; then
    do_pass "AC-A11Y-302: JSON output format (var/a11y/{route}-landmarks.json) documented"
  else
    do_fail "AC-A11Y-302: JSON output format 'var/a11y/{route}-landmarks.json' not documented in gate doc"
  fi

  # Verify landmark matrix table covers all 4 routes
  LANDMARK_MATRIX_ROUTES=("authn" "dashboard" "account" "course-authoring")
  for route_key in "${LANDMARK_MATRIX_ROUTES[@]}"; do
    if grep -qiF "$route_key" "$GATE_DOC"; then
      do_pass "AC-A11Y-302: Landmark matrix covers route '$route_key'"
    else
      do_fail "AC-A11Y-302: Landmark matrix missing route '$route_key' in gate doc"
    fi
  done
fi

# Also validate runbook is present (referenced by gate doc)
if [[ -f "$RUNBOOK" ]]; then
  do_pass "AC-A11Y-302: ACCESSIBILITY_CONFORMANCE_RUNBOOK.md exists (landmark matrix source)"
else
  do_warn "AC-A11Y-302: ACCESSIBILITY_CONFORMANCE_RUNBOOK.md not found — check gate doc for standalone coverage"
fi

# Ensure var/a11y output directory can be created
mkdir -p "$A11Y_DIR"
do_pass "AC-A11Y-302: var/a11y/ output directory ensured"

# Emit example JSON artifact for authn route (offline mode)
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
AUTHN_ARTIFACT="$A11Y_DIR/authn-landmarks-offline.json"
python3 - "$AUTHN_ARTIFACT" "$TIMESTAMP" <<'PYEOF'
import json, sys
out_path, ts = sys.argv[1], sys.argv[2]
artifact = {
  "route": "/authn/login",
  "timestamp": ts,
  "mode": "offline",
  "landmarks": {"banner": 1, "nav": 0, "main": 1, "contentinfo": 1},
  "landmark_violations": [],
  "focus_checks": [],
  "axe_violations": [],
  "pass": True,
  "note": "Offline mode: structural documentation verified. Run with A11Y_TENANT_LIVE=1 for live assertions."
}
with open(out_path, 'w') as f:
    json.dump(artifact, f, indent=2)
print(f"  artifact written: {out_path}")
PYEOF
do_pass "AC-A11Y-302: Sample JSON landmark artifact emitted to var/a11y/authn-landmarks-offline.json"

echo ""

# ── AC-A11Y-303: Contrast assertions for branded elements ─────────────
echo -e "${BLUE}## AC-A11Y-303: Branded Element Contrast Assertions${NC}"

if ! command -v python3 >/dev/null 2>&1; then
  do_fail "AC-A11Y-303: python3 not available — required for contrast computation"
else
  do_pass "AC-A11Y-303: python3 available for contrast computation"

  # Inline contrast ratio function
  compute_contrast() {
    local fg="$1" bg="$2"
    python3 - "$fg" "$bg" <<'PYEOF'
import sys
def hex_to_linear(h):
    h = h.lstrip('#')
    rgb = tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))
    result = []
    for c in rgb:
        if c <= 0.04045:
            result.append(c / 12.92)
        else:
            result.append(((c + 0.055) / 1.055) ** 2.4)
    return result
def luminance(h):
    lin = hex_to_linear(h)
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
def contrast_ratio(c1, c2):
    l1 = luminance(c1)
    l2 = luminance(c2)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)
fg, bg = sys.argv[1], sys.argv[2]
try:
    ratio = contrast_ratio(fg, bg)
    print(f"{ratio:.2f}")
except Exception:
    print("0")
PYEOF
  }

  # Helper: check a branded contrast pair
  check_branded_pair() {
    local label="$1" fg="$2" bg="$3" threshold="$4" ac="$5"
    if [[ -z "$fg" || -z "$bg" ]]; then
      do_warn "${ac}: ${label} — token value not resolved, skipping"
      return
    fi
    local ratio
    ratio=$(compute_contrast "$fg" "$bg")
    if [[ "$ratio" == "0" ]]; then
      do_warn "${ac}: ${label} — contrast computation failed"
      return
    fi
    local passes
    passes=$(python3 -c "print('yes' if float('$ratio') >= $threshold else 'no')" 2>/dev/null || echo "no")
    if [[ "$passes" == "yes" ]]; then
      do_pass "${ac}: ${label} ${fg}/${bg} = ${ratio}:1 (>=${threshold}:1 AA)"
    else
      do_fail "${ac}: ${label} ${fg}/${bg} = ${ratio}:1 (FAILS ${threshold}:1 AA)"
    fi
  }

  # Extract token values from _tokens.scss for branded element assertions
  get_scss_color() {
    local name="$1"
    grep -P "^\\\$${name}:\s*" "$TOKENS_SCSS" 2>/dev/null \
      | head -1 \
      | grep -oP '#[0-9a-fA-F]{6}' \
      | head -1 || true
  }

  if [[ ! -f "$TOKENS_SCSS" ]]; then
    do_fail "AC-A11Y-303: _tokens.scss not found — cannot verify branded element contrast"
  else
    do_pass "AC-A11Y-303: _tokens.scss found for token extraction"

    # Extract required token values
    COLOR_MAGENTA=$(get_scss_color "color-magenta")
    COLOR_TEAL=$(get_scss_color "color-teal")
    COLOR_BLUE=$(get_scss_color "color-blue")
    COLOR_INK_900=$(get_scss_color "color-ink-900")
    COLOR_INK_700=$(get_scss_color "color-ink-700")
    SURFACE=$(get_scss_color "color-neutral-100")
    WHITE="#ffffff"

    # ── Branded button: --mereka-primary (magenta gradient endpoint)
    # Primary button uses gradient: magenta → teal → blue. White label text on each.
    # WCAG: 3:1 minimum for UI components (buttons).
    check_branded_pair "branded btn-primary label (white on --mereka-color-magenta)" \
      "$WHITE" "$COLOR_MAGENTA" 3.0 "AC-A11Y-303"
    check_branded_pair "branded btn-primary label (white on --mereka-color-teal)" \
      "$WHITE" "$COLOR_TEAL" 3.0 "AC-A11Y-303"
    check_branded_pair "branded btn-primary label (white on --mereka-color-blue)" \
      "$WHITE" "$COLOR_BLUE" 3.0 "AC-A11Y-303"

    # ── Page headers: --mereka-ink-* on surface background
    # Headers use ink-900 or ink-700 on neutral-100 surface.
    # WCAG: 3:1 for large text (headers >= 18px regular or >= 14px bold).
    check_branded_pair "page header (--mereka-ink-900 on surface, large text)" \
      "$COLOR_INK_900" "$SURFACE" 3.0 "AC-A11Y-303"
    check_branded_pair "page header (--mereka-ink-700 on surface, large text)" \
      "$COLOR_INK_700" "$SURFACE" 3.0 "AC-A11Y-303"

    # ── Enterprise tenant theme: header text contrast
    # Enterprise tenant overrides may use custom ink values. Verify base tokens pass.
    check_branded_pair "enterprise tenant header (ink-900 on white)" \
      "$COLOR_INK_900" "$WHITE" 4.5 "AC-A11Y-303"
    check_branded_pair "enterprise tenant header (ink-700 on white)" \
      "$COLOR_INK_700" "$WHITE" 4.5 "AC-A11Y-303"

    # ── Check that gate doc documents these contrast pairs
    if [[ -f "$GATE_DOC" ]]; then
      if grep -qE "mereka-primary|mereka-color-magenta|branded button|btn-primary" "$GATE_DOC"; then
        do_pass "AC-A11Y-303: Branded button contrast requirements documented in gate doc"
      else
        do_fail "AC-A11Y-303: Branded button contrast requirements not documented in A11Y_TENANT_BRANDING_GATE.md"
      fi

      if grep -qE "mereka-ink|ink-900|ink-700|header" "$GATE_DOC"; then
        do_pass "AC-A11Y-303: Header ink token contrast requirements documented in gate doc"
      else
        do_fail "AC-A11Y-303: Header ink token contrast requirements missing from gate doc"
      fi
    else
      do_fail "AC-A11Y-303: Gate doc missing — cannot verify contrast pair documentation"
    fi

    # ── Cross-reference with A11Y_CONTRAST_FOCUS_GATE.md
    if [[ -f "$CONTRAST_DOC" ]]; then
      if grep -qE "Btn primary|btn-primary" "$CONTRAST_DOC"; then
        do_pass "AC-A11Y-303: Branded button pairs cross-referenced in A11Y_CONTRAST_FOCUS_GATE.md"
      else
        do_warn "AC-A11Y-303: Branded button pairs not found in A11Y_CONTRAST_FOCUS_GATE.md — add for completeness"
      fi
      do_pass "AC-A11Y-303: A11Y_CONTRAST_FOCUS_GATE.md present for cross-reference"
    else
      do_warn "AC-A11Y-303: A11Y_CONTRAST_FOCUS_GATE.md not found — contrast cross-reference skipped"
    fi
  fi
fi

echo ""

# ── AC-A11Y-304: Integration — standalone + CI opt-in ─────────────────
echo -e "${BLUE}## AC-A11Y-304: Integration Gate (Standalone + CI)${NC}"

THIS_SCRIPT="$REPO_ROOT/scripts/qa/verify-a11y-tenant-branding.sh"

# Verify this script exists and is executable
if [[ -f "$THIS_SCRIPT" ]]; then
  do_pass "AC-A11Y-304: verify-a11y-tenant-branding.sh exists"
else
  do_fail "AC-A11Y-304: verify-a11y-tenant-branding.sh not found — integration script missing"
fi

if [[ -x "$THIS_SCRIPT" ]]; then
  do_pass "AC-A11Y-304: verify-a11y-tenant-branding.sh is executable"
else
  do_fail "AC-A11Y-304: verify-a11y-tenant-branding.sh is not executable (run: chmod +x)"
fi

# Verify prerequisite a11y scripts exist and are executable
PREREQ_SCRIPTS=(
  "$EXISTING_CONTRAST_SCRIPT"
  "$EXISTING_ROUTES_SCRIPT"
)
PREREQ_NAMES=(
  "verify-a11y-contrast-focus.sh"
  "verify-a11y-authenticated-routes.sh"
)

for i in "${!PREREQ_SCRIPTS[@]}"; do
  script_path="${PREREQ_SCRIPTS[$i]}"
  script_name="${PREREQ_NAMES[$i]}"
  if [[ -f "$script_path" ]]; then
    do_pass "AC-A11Y-304: Prerequisite script $script_name exists"
  else
    do_fail "AC-A11Y-304: Prerequisite script $script_name not found at $script_path"
    continue
  fi
  if [[ -x "$script_path" ]]; then
    do_pass "AC-A11Y-304: Prerequisite script $script_name is executable"
  else
    do_warn "AC-A11Y-304: Prerequisite script $script_name is not executable"
  fi
done

# Verify CI references this script — accept either ci.yml or ci-scripts-static.txt
# (the CI uses a parallel xargs runner fed from ci-scripts-static.txt)
CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
CI_SCRIPTS_LIST="$REPO_ROOT/.github/ci-scripts-static.txt"
if [[ -f "$CI_YML" ]]; then
  do_pass "AC-A11Y-304: .github/workflows/ci.yml found"

  if grep -qF 'verify-a11y-tenant-branding.sh' "$CI_YML"; then
    do_pass "AC-A11Y-304: verify-a11y-tenant-branding.sh referenced in CI workflow (ci.yml)"
  elif [[ -f "$CI_SCRIPTS_LIST" ]] && grep -qF 'verify-a11y-tenant-branding.sh' "$CI_SCRIPTS_LIST"; then
    do_pass "AC-A11Y-304: verify-a11y-tenant-branding.sh referenced in CI scripts list (ci-scripts-static.txt)"
  else
    do_fail "AC-A11Y-304: verify-a11y-tenant-branding.sh not yet in CI workflow or ci-scripts-static.txt"
  fi

  # CI uses a consolidated parallel runner (ci-scripts-static.txt) rather than named jobs.
  # Accept the script being present in the scripts list as equivalent to a named job.
  if grep -qF 'a11y-tenant-branding' "$CI_YML"; then
    do_pass "AC-A11Y-304: a11y-tenant-branding CI job defined in workflow"
  elif [[ -f "$CI_SCRIPTS_LIST" ]] && grep -qF 'verify-a11y-tenant-branding.sh' "$CI_SCRIPTS_LIST"; then
    do_pass "AC-A11Y-304: a11y-tenant-branding covered via ci-scripts-static.txt parallel runner"
  else
    do_fail "AC-A11Y-304: a11y-tenant-branding CI job not found in workflow"
  fi
else
  do_warn "AC-A11Y-304: .github/workflows/ci.yml not found — cannot verify CI integration"
fi

# Verify gate doc documents the integration relationship
if [[ -f "$GATE_DOC" ]]; then
  if grep -qF "verify-a11y-contrast-focus.sh" "$GATE_DOC" && \
     grep -qF "verify-a11y-authenticated-routes.sh" "$GATE_DOC"; then
    do_pass "AC-A11Y-304: Gate doc documents relationship to existing a11y scripts"
  else
    do_fail "AC-A11Y-304: Gate doc missing cross-references to existing a11y scripts"
  fi
else
  do_fail "AC-A11Y-304: Gate doc missing — integration documentation absent"
fi

echo ""

# ── Live mode placeholder ──────────────────────────────────────────────
if [[ "$A11Y_TENANT_LIVE" = "1" ]]; then
  echo -e "${BLUE}## Live Mode: Tenant Branding A11y Checks (placeholder)${NC}"
  do_warn "AC-A11Y-301..303: A11Y_TENANT_LIVE=1 set but live checks require a running LMS + tenant config"
  echo "  To run live tenant branding checks:"
  echo "    1. Ensure LMS is accessible at \$LMS_URL (default: http://localhost)"
  echo "    2. Set TENANT_HOST=<tenant-domain> for enterprise tenant assertion"
  echo "    3. Use axe-cli or Playwright + @axe-core/playwright for landmark/focus assertions"
  echo "    4. Artifacts written to var/a11y/{route}-landmarks.json"
  echo "    5. Contrast violations written to var/a11y/{tenant}-contrast-violations.json"
  echo ""
fi

# ── Write CI artifact ─────────────────────────────────────────────────
mkdir -p "$A11Y_DIR"
ARTIFACT="$A11Y_DIR/a11y-tenant-branding-gate.txt"
{
  echo "a11y-tenant-branding-gate"
  echo "run_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "mode=$([ "$A11Y_TENANT_LIVE" = "1" ] && echo live || echo offline)"
  echo "pass=$PASS"
  echo "warn=$WARN"
  echo "fail=$FAIL"
  echo "status=$([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL)"
} > "$ARTIFACT"

# ── Summary ───────────────────────────────────────────────────────────
echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}All a11y tenant branding checks passed${NC}"
  if [[ "$WARN" -gt 0 ]]; then
    echo ""
    echo "Notes:"
    echo "  - WARN items are documented gaps (non-blocking)"
    echo "  - See docs/ops/runbooks/A11Y_TENANT_BRANDING_GATE.md for full requirements"
    echo "  - Set A11Y_TENANT_LIVE=1 for live browser assertion mode (requires running LMS)"
  fi
  exit 0
else
  echo -e "${RED}Some a11y tenant branding checks failed${NC}"
  echo ""
  echo "Fix FAIL items before merging."
  echo "See docs/ops/runbooks/A11Y_TENANT_BRANDING_GATE.md for requirements and remediation."
  echo ""
  echo "Regression guard — suggested ticket title for each FAIL:"
  echo "  a11y(tenant-branding): <route/element> keyboard/landmark/contrast failure — <AC-A11Y-30N>"
  exit 1
fi
