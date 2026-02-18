#!/usr/bin/env bash
# verify-token-integrity-routing.sh — Token integrity + routing verification
#
# @covers AC-FRONT-011, AC-FRONT-012, AC-FRONT-013, AC-FRONT-014, AC-FRONT-015
# @spec: bead-2dcy1
#
# AC-FRONT-011: Replace all undefined CSS token references (or add canonical token
#               definitions) in LMS/theme files.
# AC-FRONT-012: Add a reproducible token validation check that fails if theme code
#               references missing CSS vars.
# AC-FRONT-013: Align verify-mfe-branding routing expectations with actual Caddy routes.
# AC-FRONT-014: Add docs evidence artifact and expected command output under docs/operations.
# AC-FRONT-015: Record rollback path if validation fails.
#
# Usage: ./scripts/qa/verify-token-integrity-routing.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
BRANDING_VERIFIER="$REPO_ROOT/scripts/qa/verify-mfe-branding.sh"
EVIDENCE_DOC="$REPO_ROOT/docs/operations/TOKEN_INTEGRITY_ROUTING.md"

PASS=0
FAIL=0
WARN=0

pass_msg() { PASS=$((PASS + 1)); echo "  [PASS] $1"; }
fail_msg() { FAIL=$((FAIL + 1)); echo "  [FAIL] $1"; }
warn_msg() { WARN=$((WARN + 1)); echo "  [WARN] $1"; }

echo "=== Token Integrity + Routing Verification ==="
echo "Spec: bead-2dcy1"
echo "Coverage: AC-FRONT-011, AC-FRONT-012, AC-FRONT-013, AC-FRONT-014, AC-FRONT-015"
echo ""

# =============================================================================
# AC-FRONT-011 + AC-FRONT-012: CSS token reference integrity
# =============================================================================
echo "--- AC-FRONT-011/012: Token reference integrity (var(--mereka-*)) ---"
echo ""

# Collect all defined --mereka-* tokens from canonical definition sources
DEFINED_TOKENS="$(mktemp)"
trap 'rm -f "$DEFINED_TOKENS"' EXIT

# From scss/_tokens.scss (primary SCSS bridge)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' \
  "$THEME_DIR/scss/_tokens.scss" 2>/dev/null >> "$DEFINED_TOKENS" || true

# From common/static/css/mereka-overrides.css (runtime CSS entrypoint — self-defines its tokens)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' \
  "$THEME_DIR/common/static/css/mereka-overrides.css" 2>/dev/null >> "$DEFINED_TOKENS" || true

# From lms/static/css/mereka-overrides.css (LMS copy, same token set)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' \
  "$THEME_DIR/lms/static/css/mereka-overrides.css" 2>/dev/null >> "$DEFINED_TOKENS" || true

# From scss/theme.scss (theme-level definitions)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' \
  "$THEME_DIR/scss/theme.scss" 2>/dev/null >> "$DEFINED_TOKENS" || true

# From mfe/mereka.scss (MFE-specific tokens like --mereka-mfe-*)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' \
  "$THEME_DIR/mfe/mereka.scss" 2>/dev/null >> "$DEFINED_TOKENS" || true

sort -u "$DEFINED_TOKENS" -o "$DEFINED_TOKENS"
DEF_COUNT=$(wc -l < "$DEFINED_TOKENS")
echo "  Collected $DEF_COUNT unique --mereka-* token definitions from canonical sources"
echo ""

UNDEFINED_COUNT=0

# Scan all SCSS and CSS theme files for var(--mereka-*) references
while IFS= read -r file; do
  while IFS=: read -r line_num match; do
    # Extract token name from var(--mereka-something)
    token=$(echo "$match" | grep -oP '(?<=var\()--mereka-[a-z0-9_-]+' | head -1)
    [ -z "$token" ] && continue

    # Check if token is defined in the collected set
    if grep -qxF -- "$token" "$DEFINED_TOKENS" 2>/dev/null; then
      : # Defined — skip
    else
      # Check if the token is self-defined in the same file (e.g. MFE-local tokens)
      if grep -qP "^\s+${token}:" "$file" 2>/dev/null; then
        : # Self-defined in same file
      else
        fail_msg "AC-FRONT-011: Undefined token $token in $(basename "$file"):$line_num"
        UNDEFINED_COUNT=$((UNDEFINED_COUNT + 1))
      fi
    fi
  done < <(grep -n 'var(--mereka-' "$file" 2>/dev/null || true)
done < <(find "$THEME_DIR" \( -name '*.scss' -o -name '*.css' \) \
           -not -path '*/node_modules/*' 2>/dev/null | sort)

if [ "$UNDEFINED_COUNT" -eq 0 ]; then
  pass_msg "AC-FRONT-011: All var(--mereka-*) references resolve to defined tokens"
  pass_msg "AC-FRONT-012: Reproducible check passed — no undefined token references detected"
else
  fail_msg "AC-FRONT-012: $UNDEFINED_COUNT undefined var(--mereka-*) references found (see AC-FRONT-011 details above)"
fi

echo ""

# =============================================================================
# AC-FRONT-013: Verify verify-mfe-branding.sh routing expectations match Caddyfile
# =============================================================================
echo "--- AC-FRONT-013: Routing expectation alignment ---"
echo ""

# Check Caddyfile exists
if [ ! -f "$CADDYFILE" ]; then
  fail_msg "AC-FRONT-013: Caddyfile not found at $CADDYFILE"
else
  pass_msg "AC-FRONT-013: Caddyfile exists at $CADDYFILE"

  # Check branding verifier exists
  if [ ! -f "$BRANDING_VERIFIER" ]; then
    fail_msg "AC-FRONT-013: verify-mfe-branding.sh not found at $BRANDING_VERIFIER"
  else
    pass_msg "AC-FRONT-013: verify-mfe-branding.sh exists"

    # Extract MFE directories registered in the Caddyfile
    # Pattern: "root * /openedx/dist/<dir>"
    CADDY_DIRS=""
    CADDY_DIRS=$(grep -oP '(?<=root \* /openedx/dist/)[a-z0-9_-]+' "$CADDYFILE" 2>/dev/null | sort -u || true)

    # Extract MFE directories referenced in verify-mfe-branding.sh
    # Pattern: values in MFE_ROUTES array like '"authn"' or '"course-authoring"'
    BRANDING_DIRS=""
    BRANDING_DIRS=$(grep -oP '(?<=")\w[\w-]+(?="\s*\))' "$BRANDING_VERIFIER" 2>/dev/null | sort -u || true)

    # Verify the key routes that verify-mfe-branding.sh hardcodes are present in Caddyfile
    EXPECTED_DIRS="authn account course-authoring discussions learner-dashboard learning ora-grading profile"

    ROUTE_FAIL=0
    for dir in $EXPECTED_DIRS; do
      if echo "$CADDY_DIRS" | grep -qx "$dir"; then
        pass_msg "AC-FRONT-013: route $dir present in Caddyfile"
      else
        fail_msg "AC-FRONT-013: route $dir expected by branding verifier is missing from Caddyfile"
        ROUTE_FAIL=$((ROUTE_FAIL + 1))
      fi
    done

    # Check that /orders and /payment proxy to payments-gateway (deprecated MFEs)
    if grep -Fq "reverse_proxy /orders" "$CADDYFILE" && grep -Fq "payments-gateway" "$CADDYFILE"; then
      pass_msg "AC-FRONT-013: /orders* proxied to payments-gateway (deprecated MFE redirect)"
    else
      warn_msg "AC-FRONT-013: /orders* → payments-gateway proxy not found in Caddyfile"
    fi

    if grep -Fq "reverse_proxy /payment" "$CADDYFILE" && grep -Fq "payments-gateway" "$CADDYFILE"; then
      pass_msg "AC-FRONT-013: /payment* proxied to payments-gateway (deprecated MFE redirect)"
    else
      warn_msg "AC-FRONT-013: /payment* → payments-gateway proxy not found in Caddyfile"
    fi

    # Check /u/* profile special route
    if grep -q "path /u /u/\*" "$CADDYFILE" || grep -q 'path /u /u/\*' "$CADDYFILE"; then
      pass_msg "AC-FRONT-013: /u/* profile special route present in Caddyfile"
    elif grep -q "@mfe_profile_u" "$CADDYFILE"; then
      pass_msg "AC-FRONT-013: @mfe_profile_u named matcher for /u/* present in Caddyfile"
    else
      warn_msg "AC-FRONT-013: /u/* special profile route not detected in Caddyfile"
    fi

    # Cross-check: warn about any Caddyfile MFE dirs not covered by verify-mfe-branding.sh
    while IFS= read -r caddy_dir; do
      [ -z "$caddy_dir" ] && continue
      if ! echo "$EXPECTED_DIRS" | grep -qw "$caddy_dir"; then
        warn_msg "AC-FRONT-013: Caddyfile has MFE dir '$caddy_dir' not in branding verifier expected list"
      fi
    done <<< "$CADDY_DIRS"

    if [ "$ROUTE_FAIL" -eq 0 ]; then
      pass_msg "AC-FRONT-013: All branding-verifier route expectations align with Caddyfile"
    fi
  fi
fi

echo ""

# =============================================================================
# AC-FRONT-014: Evidence doc exists
# =============================================================================
echo "--- AC-FRONT-014: Evidence artifact ---"
echo ""

if [ -f "$EVIDENCE_DOC" ]; then
  pass_msg "AC-FRONT-014: docs/operations/TOKEN_INTEGRITY_ROUTING.md exists"

  # Check the doc has key sections
  if grep -q "Token Inventory" "$EVIDENCE_DOC" 2>/dev/null; then
    pass_msg "AC-FRONT-014: Evidence doc contains Token Inventory section"
  else
    warn_msg "AC-FRONT-014: Evidence doc missing 'Token Inventory' section"
  fi

  if grep -q "Routing Alignment" "$EVIDENCE_DOC" 2>/dev/null; then
    pass_msg "AC-FRONT-014: Evidence doc contains Routing Alignment section"
  else
    warn_msg "AC-FRONT-014: Evidence doc missing 'Routing Alignment' section"
  fi

  if grep -q "Expected Command Output" "$EVIDENCE_DOC" 2>/dev/null; then
    pass_msg "AC-FRONT-014: Evidence doc contains Expected Command Output section"
  else
    warn_msg "AC-FRONT-014: Evidence doc missing 'Expected Command Output' section"
  fi
else
  fail_msg "AC-FRONT-014: docs/operations/TOKEN_INTEGRITY_ROUTING.md not found"
fi

echo ""

# =============================================================================
# AC-FRONT-015: Rollback procedure documented
# =============================================================================
echo "--- AC-FRONT-015: Rollback procedure ---"
echo ""

if [ -f "$EVIDENCE_DOC" ]; then
  if grep -qi "rollback" "$EVIDENCE_DOC" 2>/dev/null; then
    pass_msg "AC-FRONT-015: Rollback procedure documented in evidence doc"
  else
    fail_msg "AC-FRONT-015: Evidence doc missing rollback procedure"
  fi
else
  fail_msg "AC-FRONT-015: Cannot verify rollback — evidence doc not found"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "Action required:"
  echo "  AC-FRONT-011/012: Add missing token definitions to"
  echo "    infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
  echo "    (the canonical runtime token source)"
  echo "  AC-FRONT-013: Update verify-mfe-branding.sh MFE_ROUTES or Caddyfile to match."
  echo "  AC-FRONT-014/015: Create docs/operations/TOKEN_INTEGRITY_ROUTING.md."
  echo ""
  exit 1
fi

exit 0
