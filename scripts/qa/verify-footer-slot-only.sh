#!/usr/bin/env bash
# @covers AC-FTR-301, AC-FTR-302, AC-FTR-303, AC-FTR-304, AC-FTR-305
# @spec: bead-115d19
set -euo pipefail

# verify-footer-slot-only.sh
# Enforces the footer slot-only policy:
#   - Footer customization MUST be achieved only via FPF plugin slot (footer.v1)
#   - Raw HTML footer injection and document.querySelector footer manipulation are banned
#   - Any remaining fallback path must be documented in the exception register
#
# Bead: mereka-lms-115d.19
# Last updated: 2026-02-18

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
POLICY_DOC="$REPO_ROOT/docs/policies/operations/FOOTER_SLOT_ONLY_POLICY.md"

echo "========================================"
echo "Footer Slot-Only Policy Verifier"
echo "Bead: mereka-lms-115d.19"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# AC-FTR-301: No raw HTML footer string replacement/rewrite in apply-patches.sh
# Allowed exception: the known RenderWidget swap (apply-patches.sh line ~1229)
# is registered in FOOTER_SLOT_ONLY_POLICY.md and is not a raw HTML rewrite.
# Banned: sed.*footer (direct sed-based footer file rewrite),
#         replace.*footer.*html (raw HTML file manipulation),
#         innerHTML.*footer (DOM innerHTML footer injection)
# -----------------------------------------------------------------------
echo "AC-FTR-301: No raw HTML footer file rewrite in apply-patches.sh"

if [[ ! -f "$PATCHES" ]]; then
  warn "apply-patches.sh not found — skipping AC-FTR-301 (expected in CI with full checkout)"
else
  # Banned pattern 1: sed-based footer file rewrite (sed targeting a footer HTML file)
  SED_FOOTER=$(grep -n "sed.*footer.*html\|sed.*footer\.html" "$PATCHES" || true)
  if [[ -n "$SED_FOOTER" ]]; then
    fail "AC-FTR-301: Banned pattern — sed-based footer HTML file rewrite found in apply-patches.sh:"
    echo "$SED_FOOTER" | head -5 | sed 's/^/    /'
  else
    pass "AC-FTR-301: No sed-based footer HTML file rewrite in apply-patches.sh"
  fi

  # Banned pattern 2: raw footer HTML file write (writing directly to footer.html path)
  RAW_HTML_WRITE=$(grep -n "footer\.html.*write\|write.*footer\.html\|echo.*footer\.html\|cat.*footer\.html" "$PATCHES" || true)
  if [[ -n "$RAW_HTML_WRITE" ]]; then
    fail "AC-FTR-301: Banned pattern — raw footer.html write found in apply-patches.sh:"
    echo "$RAW_HTML_WRITE" | head -5 | sed 's/^/    /'
  else
    pass "AC-FTR-301: No raw footer.html write operations in apply-patches.sh"
  fi

  # The RenderWidget swap is the known registered fallback — it is allowed.
  # Verify it exists (its presence is expected and documented) but not any new raw HTML injection.
  RENDER_WIDGET_SWAP=$(grep -c "RenderWidget.*Footer\|Footer.*RenderWidget" "$PATCHES" || true)
  if [[ "$RENDER_WIDGET_SWAP" -gt 0 ]]; then
    warn "AC-FTR-301: RenderWidget footer swap exists in apply-patches.sh ($RENDER_WIDGET_SWAP occurrence(s)) — this is the registered dual-path fallback (see exception register in FOOTER_SLOT_ONLY_POLICY.md)"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTR-302: plugin contract sources use PLUGIN_SLOTS for footer (footer.v1 slot reference)
#             and env.config.jsx is generated deterministically
# -----------------------------------------------------------------------
echo "AC-FTR-302: Plugin uses PLUGIN_SLOTS for footer; env.config.jsx generated deterministically"

if ! mereka_plugin_has_any "$REPO_ROOT"; then
  fail "AC-FTR-302: plugin contract sources not found (expected at least $PLUGIN_MAIN)"
else
  # Must have a footer.v1 / footer_slot reference in the plugin
  SLOT_REF="$(mereka_plugin_count_regex "$REPO_ROOT" "footer_slot|footer\\.v1|footer.v1")"
  if [[ "$SLOT_REF" -gt 0 ]]; then
    pass "AC-FTR-302: footer slot reference present in plugin contract sources (footer_slot / footer.v1) — $SLOT_REF occurrence(s)"
  else
    fail "AC-FTR-302: No footer slot reference (footer_slot / footer.v1) found in plugin contract sources"
  fi

  # Must have PLUGIN_SLOTS registration block (forward-compatible registration)
  if mereka_plugin_has_fixed "$REPO_ROOT" "PLUGIN_SLOTS"; then
    pass "AC-FTR-302: PLUGIN_SLOTS registration block present in plugin contract sources"
  else
    fail "AC-FTR-302: PLUGIN_SLOTS not referenced in plugin contract sources — slot registration missing"
  fi

  # MerekaFooter component must be defined in the plugin (canonical source)
  if mereka_plugin_has_fixed "$REPO_ROOT" "const MerekaFooter"; then
    pass "AC-FTR-302: MerekaFooter component defined in plugin contract sources"
  else
    fail "AC-FTR-302: MerekaFooter component not found in plugin contract sources"
  fi

  # env.config.jsx determinism: the component must be injected via a deterministic
  # patch (no random values, no timestamp-based content).
  # Check that the apply-patches.sh footer injection uses a fixed string (not shell $RANDOM etc.)
  if [[ -f "$PATCHES" ]]; then
    RANDOM_IN_FOOTER=$(grep -A 200 "footer_component = textwrap" "$PATCHES" | grep -c "\$RANDOM\|\$SECONDS\|date +%s\|uuid" || true)
    if [[ "$RANDOM_IN_FOOTER" -gt 0 ]]; then
      fail "AC-FTR-302: Non-deterministic value (\$RANDOM / uuid / timestamp) found in footer component injection in apply-patches.sh"
    else
      pass "AC-FTR-302: Footer component injection in apply-patches.sh is deterministic (no random/timestamp values)"
    fi
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTR-303: Exception register section exists in docs with owner/expiry fields
# -----------------------------------------------------------------------
echo "AC-FTR-303: Exception register exists with owner and expiry fields"

if [[ ! -f "$POLICY_DOC" ]]; then
  fail "AC-FTR-303: FOOTER_SLOT_ONLY_POLICY.md not found at $POLICY_DOC"
else
  pass "AC-FTR-303: FOOTER_SLOT_ONLY_POLICY.md exists"

  # Must have an exception register section
  if grep -qi "Exception Register\|exception-register\|## Exception" "$POLICY_DOC"; then
    pass "AC-FTR-303: Exception register section present in FOOTER_SLOT_ONLY_POLICY.md"
  else
    fail "AC-FTR-303: No exception register section found in FOOTER_SLOT_ONLY_POLICY.md"
  fi

  # Must have owner field documented
  if grep -qi "Owner\|owner:" "$POLICY_DOC"; then
    pass "AC-FTR-303: Owner field present in exception register"
  else
    fail "AC-FTR-303: No 'Owner' field found in exception register"
  fi

  # Must have expiry date documented (Q-notation or YYYY-MM-DD)
  if grep -qE "202[6-9]-Q[1-4]|Expiry|expiry|expires|2026-[0-9]{2}-[0-9]{2}" "$POLICY_DOC"; then
    pass "AC-FTR-303: Expiry date present in exception register"
  else
    fail "AC-FTR-303: No expiry date found in exception register (expected YYYY-QN or YYYY-MM-DD format)"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTR-304: No banned fallback footer replacement patterns in plugin or patches
# Banned patterns:
#   - innerHTML.*footer (DOM innerHTML footer injection in JS/JSX)
#   - document.querySelector.*footer (direct DOM footer manipulation)
#   - Raw <footer> HTML tag injection as a string in JS (not inside JSX return)
#   - document.getElementById.*footer
# -----------------------------------------------------------------------
echo "AC-FTR-304: No banned fallback footer patterns in plugin or patches"

BANNED_FOUND=0

check_banned() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if [[ ! -f "$file" ]]; then
    return
  fi

  MATCHES=$(grep -n "$pattern" "$file" || true)
  if [[ -n "$MATCHES" ]]; then
    fail "AC-FTR-304: Banned pattern '$label' found in $(basename "$file"):"
    echo "$MATCHES" | head -5 | sed 's/^/    /'
    BANNED_FOUND=$((BANNED_FOUND + 1))
  fi
}

check_banned_in_plugins() {
  local pattern="$1"
  local label="$2"
  local plugin_file
  while IFS= read -r plugin_file; do
    check_banned "$plugin_file" "$pattern" "$label"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
}

# innerHTML footer injection
check_banned_in_plugins "innerHTML.*footer\|footer.*innerHTML" "innerHTML footer injection"
check_banned "$PATCHES" "innerHTML.*footer\|footer.*innerHTML" "innerHTML footer injection"

# Direct DOM querySelector footer manipulation
check_banned_in_plugins "document\.querySelector.*footer\|document\.getElementById.*footer" "document.querySelector/getElementById footer"
check_banned "$PATCHES" "document\.querySelector.*footer\|document\.getElementById.*footer" "document.querySelector/getElementById footer"

# Raw <footer> tag as a JS/Python string concatenation (not JSX — detect string-concat patterns)
# Pattern: Python string with raw <footer> tag being written to a non-JSX file path
FOOTER_STRING_INJECTION=$(grep -n "\"<footer\|'<footer\|f\".*<footer\|f'.*<footer" "$PATCHES" 2>/dev/null | grep -v "jsx\|JSX\|component\|MerekaFooter\|footer_component\|return (" || true)
if [[ -n "$FOOTER_STRING_INJECTION" ]]; then
  fail "AC-FTR-304: Banned pattern — raw '<footer>' HTML string injection outside JSX component found in apply-patches.sh:"
  echo "$FOOTER_STRING_INJECTION" | head -5 | sed 's/^/    /'
  BANNED_FOUND=$((BANNED_FOUND + 1))
fi

if [[ "$BANNED_FOUND" -eq 0 ]]; then
  pass "AC-FTR-304: No banned fallback footer patterns found in plugin or patches"
fi

# Also scan any JS/JSX files under infrastructure/ for banned patterns
INFRA_JS_BANNED=$(grep -rn "innerHTML.*footer\|document\.querySelector.*footer\|document\.getElementById.*footer" \
  "$REPO_ROOT/infrastructure/" --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" 2>/dev/null || true)
if [[ -n "$INFRA_JS_BANNED" ]]; then
  fail "AC-FTR-304: Banned DOM footer manipulation found in infrastructure JS/JSX files:"
  echo "$INFRA_JS_BANNED" | head -5 | sed 's/^/    /'
else
  pass "AC-FTR-304: No banned DOM footer patterns in infrastructure JS/JSX files"
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTR-305: Evidence doc exists with verification commands documented
# -----------------------------------------------------------------------
echo "AC-FTR-305: Evidence doc exists with verification commands"

if [[ ! -f "$POLICY_DOC" ]]; then
  fail "AC-FTR-305: FOOTER_SLOT_ONLY_POLICY.md not found — cannot verify evidence section"
else
  # Must have a verification commands section
  if grep -qi "Verification\|verification command\|verify-footer" "$POLICY_DOC"; then
    pass "AC-FTR-305: Verification commands section present in FOOTER_SLOT_ONLY_POLICY.md"
  else
    fail "AC-FTR-305: No verification commands section found in FOOTER_SLOT_ONLY_POLICY.md"
  fi

  # Must reference at least one verify script
  if grep -q "verify-footer\|verify-mfe-footer\|verify-footer-slot" "$POLICY_DOC"; then
    pass "AC-FTR-305: Policy doc references at least one footer verification script"
  else
    fail "AC-FTR-305: Policy doc does not reference any footer verification scripts"
  fi

  # Must have PASS/WARN/FAIL language (evidence format)
  if grep -qE "PASS|FAIL|WARN" "$POLICY_DOC"; then
    pass "AC-FTR-305: Policy doc uses PASS/WARN/FAIL evidence language"
  else
    warn "AC-FTR-305: Policy doc does not use PASS/WARN/FAIL evidence format — consider adding verification command output evidence"
  fi
fi

echo ""
echo "========================================"
echo "Footer slot-only policy: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "========================================"
exit $((FAIL > 0 ? 1 : 0))
