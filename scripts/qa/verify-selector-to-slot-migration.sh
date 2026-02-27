#!/usr/bin/env bash
set -euo pipefail

# @covers AC-FRONT-021, AC-FRONT-022, AC-FRONT-023, AC-FRONT-024, AC-FRONT-025
# @spec: bead-2dcy2
#
# Bead 2dcy.2 — Migrate brittle MFE selector customizations to plugin slots
#
# AC-FRONT-021: 5 highest-risk selectors tagged RISK: HIGH in mereka.scss
# AC-FRONT-022: Plugin slot registrations exist in mereka_lms.py
# AC-FRONT-023: Exception documentation file exists at docs/operations/MFE_SELECTOR_EXCEPTIONS.md
# AC-FRONT-024: No active `updated.replace("RenderWidget` string surgery in apply-patches.sh
# AC-FRONT-025: Evidence file exists at docs/operations/evidence/selector-to-slot-migration-diff.md

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SCSS_FILE="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
PATCHES_FILE="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
EXCEPTIONS_DOC="$REPO_ROOT/docs/operations/MFE_SELECTOR_EXCEPTIONS.md"
EVIDENCE_FILE="$REPO_ROOT/docs/operations/evidence/selector-to-slot-migration-diff.md"

PASS=0
FAIL=0
WARN=0

pass_check() { echo "✅ $1"; PASS=$((PASS + 1)); }
fail_check() { echo "❌ $1"; FAIL=$((FAIL + 1)); }
warn_check() { echo "⚠️  $1"; WARN=$((WARN + 1)); }

# ---------------------------------------------------------------------------
# AC-FRONT-021: At least 5 RISK: HIGH selectors tagged in mereka.scss
# ---------------------------------------------------------------------------
if [[ -f "$SCSS_FILE" ]]; then
  HIGH_COUNT=$(grep -c 'RISK: HIGH' "$SCSS_FILE" || true)
  if [[ $HIGH_COUNT -ge 5 ]]; then
    pass_check "AC-FRONT-021: mereka.scss has at least 5 RISK: HIGH tagged selectors (found: $HIGH_COUNT)"
  else
    fail_check "AC-FRONT-021: mereka.scss needs at least 5 RISK: HIGH selectors (found: $HIGH_COUNT)"
  fi
else
  fail_check "AC-FRONT-021: mereka.scss not found at $SCSS_FILE"
fi

# ---------------------------------------------------------------------------
# AC-FRONT-022: Plugin slots are wired using canonical slot IDs
# ---------------------------------------------------------------------------
if [[ -f "$PLUGIN_FILE" ]]; then
  SLOT_COUNT=$(grep -Eo 'PLUGIN_SLOTS\.add_items|PLUGIN_SLOTS\.add_item' "$PLUGIN_FILE" | wc -l | tr -d ' ' || true)
  SLOT_COUNT=${SLOT_COUNT:-0}
  echo "  PLUGIN_SLOTS registration calls: $SLOT_COUNT"
  if [[ "$SLOT_COUNT" -ge 1 ]]; then
    pass_check "AC-FRONT-022: Found slot registration call(s) in mereka_lms.py ($SLOT_COUNT)"
  else
    fail_check "AC-FRONT-022: No PLUGIN_SLOTS registration calls found in mereka_lms.py"
  fi

  # Verify required canonical slots are registered
  for slot in "org.openedx.frontend.layout.footer.v1" "org.openedx.frontend.layout.header_logo.v1"; do
    if grep -q "\"$slot\"" "$PLUGIN_FILE"; then
      pass_check "AC-FRONT-022: slot '$slot' is registered"
    else
      fail_check "AC-FRONT-022: slot '$slot' is missing from mereka_lms.py"
    fi
  done

  # learner dashboard sidebar slot is optional while it is still pending in code
  if grep -q 'learner_dashboard.sidebar.v1' "$PLUGIN_FILE"; then
    pass_check "AC-FRONT-022: learner-dashboard sidebar slot is registered"
  else
    warn_check "AC-FRONT-022: learner-dashboard sidebar slot not yet registered (legacy CSS fallback may still be needed)"
  fi
else
  fail_check "AC-FRONT-022: mereka_lms.py not found at $PLUGIN_FILE"
fi

# ---------------------------------------------------------------------------
# AC-FRONT-023: Exception documentation file exists
# ---------------------------------------------------------------------------
if [[ -f "$EXCEPTIONS_DOC" ]]; then
  pass_check "AC-FRONT-023: MFE_SELECTOR_EXCEPTIONS.md exists"

  # Verify the doc has meaningful content (risk levels documented)
  if grep -q 'RISK: HIGH' "$EXCEPTIONS_DOC"; then
    pass_check "AC-FRONT-023: Exceptions doc documents HIGH risk selectors"
  else
    fail_check "AC-FRONT-023: Exceptions doc is missing RISK: HIGH entries"
  fi

  # Verify rationale sections exist
  if grep -q 'rationale\|Rationale\|Cannot be migrated\|CSS-only' "$EXCEPTIONS_DOC"; then
    pass_check "AC-FRONT-023: Exceptions doc includes rationale for keeping as CSS"
  else
    fail_check "AC-FRONT-023: Exceptions doc missing rationale/cannot-migrate reasoning"
  fi
else
  fail_check "AC-FRONT-023: MFE_SELECTOR_EXCEPTIONS.md not found at $EXCEPTIONS_DOC"
fi

# ---------------------------------------------------------------------------
# AC-FRONT-024: No active RenderWidget string surgery in apply-patches.sh
# ---------------------------------------------------------------------------
if [[ -f "$PATCHES_FILE" ]]; then
  # Look for the specific pattern: updated.replace("RenderWidget (footer string surgery)
  if grep -q 'updated\.replace.*RenderWidget' "$PATCHES_FILE"; then
    fail_check "AC-FRONT-024: apply-patches.sh still has RenderWidget string surgery (should have been removed in bead 1rns)"
  else
    pass_check "AC-FRONT-024: apply-patches.sh has no RenderWidget string surgery"
  fi
else
  fail_check "AC-FRONT-024: apply-patches.sh not found at $PATCHES_FILE"
fi

# ---------------------------------------------------------------------------
# AC-FRONT-025: Evidence file exists with before/after diff
# ---------------------------------------------------------------------------
if [[ -f "$EVIDENCE_FILE" ]]; then
  pass_check "AC-FRONT-025: selector-to-slot-migration-diff.md evidence file exists"

  # Verify evidence file references the bead
  if grep -q '2dcy.2\|2dcy2' "$EVIDENCE_FILE"; then
    pass_check "AC-FRONT-025: Evidence file references bead 2dcy.2"
  else
    fail_check "AC-FRONT-025: Evidence file missing bead 2dcy.2 reference"
  fi

  # Verify evidence has AC reference
  if grep -q 'AC-FRONT-02[1-5]' "$EVIDENCE_FILE"; then
    pass_check "AC-FRONT-025: Evidence file references AC-FRONT-021..025"
  else
    fail_check "AC-FRONT-025: Evidence file missing AC-FRONT-021..025 references"
  fi
else
  fail_check "AC-FRONT-025: Evidence file not found at $EVIDENCE_FILE"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== SUMMARY ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [[ "$WARN" -gt 0 ]]; then
  echo "WARN: $WARN"
fi

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL"
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
