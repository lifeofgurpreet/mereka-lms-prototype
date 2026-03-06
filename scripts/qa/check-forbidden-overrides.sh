#!/usr/bin/env bash
# @covers AC-WC-010
# @spec: multi-site-domains_spec.md
# check-forbidden-overrides.sh — Lint gate: prevent new non-plugin overrides
#
# Scans for patterns that indicate new template overrides or direct DOM
# manipulation that should use plugin/theme-first architecture instead.
#
# Exit 0 = clean, Exit 1 = forbidden patterns found.
#
# Usage:
#   ./scripts/qa/check-forbidden-overrides.sh [--strict]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STRICT=0
[[ "${1:-}" == "--strict" ]] && STRICT=1

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
warn() {
  WARN=$((WARN + 1)); echo "WARN: $1"
  if [[ "$STRICT" -eq 1 ]]; then FAIL=$((FAIL + 1)); fi
}

echo "=== Forbidden Override Check ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ── Check 1: No new Mako templates outside the known set ──────────────────

echo "--- Template Override Inventory ---"
KNOWN_TEMPLATES=(
  "lms/templates/head-extra.html"
  "lms/templates/footer.html"
  "lms/templates/index_overlay.html"
  "lms/templates/header/brand.html"
  "common/templates/head-extra.html"
  "cms/templates/head-extra.html"
)

THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
if [[ -d "$THEME_DIR" ]]; then
  TEMPLATE_FILES=""
  while IFS= read -r f; do
    TEMPLATE_FILES="$TEMPLATE_FILES $f"
  done < <(find "$THEME_DIR" -name "*.html" -path "*/templates/*" 2>/dev/null || true)

  UNKNOWN_COUNT=0
  for tpl in $TEMPLATE_FILES; do
    REL="${tpl#"$THEME_DIR/"}"
    IS_KNOWN=0
    for known in "${KNOWN_TEMPLATES[@]}"; do
      if [[ "$REL" == "$known" ]]; then
        IS_KNOWN=1
        break
      fi
    done
    if [[ "$IS_KNOWN" -eq 0 ]]; then
      fail "Unknown template override: $REL (not in approved set)"
      UNKNOWN_COUNT=$((UNKNOWN_COUNT + 1))
    fi
  done

  if [[ "$UNKNOWN_COUNT" -eq 0 ]]; then
    pass "All template overrides are in the approved set (${#KNOWN_TEMPLATES[@]} known)"
  fi
else
  warn "Theme directory not found: $THEME_DIR"
fi

# ── Check 2: No document.querySelector/innerHTML in theme files ───────────

echo ""
echo "--- DOM Manipulation Patterns ---"
if [[ -d "$THEME_DIR" ]]; then
  DOM_HITS=$(grep -r "document\.querySelector\|\.innerHTML\|document\.getElementById" \
    "$THEME_DIR" --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" \
    --include="*.scss" -l 2>/dev/null || true)
  if [[ -z "$DOM_HITS" ]]; then
    pass "No DOM manipulation patterns in theme files"
  else
    fail "DOM manipulation found in: $DOM_HITS"
  fi
else
  warn "Theme directory not found"
fi

# ── Check 3: No <script> tags in MFE theme files ─────────────────────────

MFE_THEME_DIR="$THEME_DIR/mfe"
if [[ -d "$MFE_THEME_DIR" ]]; then
  SCRIPT_HITS=$(grep -rl "<script" "$MFE_THEME_DIR" \
    --include="*.html" --include="*.js" --include="*.jsx" 2>/dev/null || true)
  if [[ -z "$SCRIPT_HITS" ]]; then
    pass "No <script> tags in MFE theme directory"
  else
    fail "<script> tags found in MFE theme: $SCRIPT_HITS"
  fi
else
  pass "No MFE theme directory to check for <script> tags"
fi

# ── Check 4: apply-patches.sh growth detection ───────────────────────────

echo ""
echo "--- apply-patches.sh Growth Check ---"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
if [[ -f "$APPLY_PATCHES" ]]; then
  LINE_COUNT=$(wc -l < "$APPLY_PATCHES")
  # Baseline as of 2026-02-18: ~1350 lines. Warn if grown >10%.
  BASELINE=1500
  if [[ "$LINE_COUNT" -le "$BASELINE" ]]; then
    pass "apply-patches.sh size within bounds ($LINE_COUNT lines, limit: $BASELINE)"
  else
    warn "apply-patches.sh has grown to $LINE_COUNT lines (baseline: $BASELINE) — review for plugin migration"
  fi

  # Check for new function definitions (new patches being added)
  FUNC_COUNT=$(grep -cE 'def (ensure_|patch_|fix_)' "$APPLY_PATCHES" 2>/dev/null || true)
  FUNC_COUNT="${FUNC_COUNT:-0}"
  # Baseline: ~35 functions
  if [[ "$FUNC_COUNT" -le 40 ]]; then
    pass "apply-patches.sh function count within bounds ($FUNC_COUNT, limit: 40)"
  else
    warn "apply-patches.sh has $FUNC_COUNT patch functions (baseline: 40) — new patches should go to plugin"
  fi
else
  warn "apply-patches.sh not found"
fi

# ── Check 5: No new theme template files added without survey entry ──────

echo ""
echo "--- Migration Survey Cross-Check ---"
SURVEY="$REPO_ROOT/docs/guides/branding/PLUGIN_MIGRATION_SURVEY.md"
if [[ -f "$SURVEY" ]]; then
  pass "PLUGIN_MIGRATION_SURVEY.md exists"
else
  fail "PLUGIN_MIGRATION_SURVEY.md missing — all overrides must be inventoried"
fi

# ── Check 6: Exception policy exists ─────────────────────────────────────

OPERATING_MODEL="$REPO_ROOT/docs/guides/branding/BRANDING_OPERATING_MODEL.md"
if [[ -f "$OPERATING_MODEL" ]]; then
  if grep -q "Non-Plugin Customization Exception Policy" "$OPERATING_MODEL"; then
    pass "Exception policy documented in BRANDING_OPERATING_MODEL.md"
  else
    fail "Exception policy section missing from BRANDING_OPERATING_MODEL.md"
  fi
else
  fail "BRANDING_OPERATING_MODEL.md not found"
fi

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL — forbidden overrides detected or policy missing"
  exit 1
fi

echo "RESULT: PASS — no forbidden override patterns found"
exit 0
