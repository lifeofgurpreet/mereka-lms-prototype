#!/usr/bin/env bash
# verify-docs-authority-invariants.sh — Enforce documentation authority invariants
#
# Ensures that:
# 1. AGENTS.md points to the canonical authority map
# 2. Non-canonical docs/architecture files carry superseded/reference banners
# 3. No active docs contain hardcoded user-local paths
# 4. No contract/governance docs contain stale authority claims
# 5. Required authority documents exist
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo -e "  ${GREEN}PASS${NC}: $1"; }
fail() { FAILED=$((FAILED + 1)); echo -e "  ${RED}FAIL${NC}: $1" >&2; }

echo "=== Documentation Authority Invariant Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo

# ---------------------------------------------------------------------------
# 1. AGENTS.md must contain a pointer to the canonical authority map
# ---------------------------------------------------------------------------
echo "--- Check 1: AGENTS.md points to PLATFORM_AUTHORITY_MAP.md ---"
AGENTS_FILE="$REPO_ROOT/AGENTS.md"
if [[ ! -f "$AGENTS_FILE" ]]; then
  fail "AGENTS.md does not exist"
else
  if grep -qF 'docs/architecture/PLATFORM_AUTHORITY_MAP.md' "$AGENTS_FILE"; then
    pass "AGENTS.md contains pointer to docs/architecture/PLATFORM_AUTHORITY_MAP.md"
  else
    fail "AGENTS.md does not reference docs/architecture/PLATFORM_AUTHORITY_MAP.md"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Non-canonical docs/architecture files must carry a superseded/reference banner
# ---------------------------------------------------------------------------
echo "--- Check 2: Non-canonical docs/architecture files have status banners ---"
EXEMPT_BASENAMES="PLATFORM_AUTHORITY_MAP.md PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md README.md"
arch_dir="$REPO_ROOT/docs/architecture"
if [[ -d "$arch_dir" ]]; then
  shopt -s nullglob
  arch_files=("$arch_dir"/*.md)
  shopt -u nullglob
  for f in "${arch_files[@]}"; do
    basename_f="$(basename "$f")"
    skip=false
    for exempt in $EXEMPT_BASENAMES; do
      [[ "$basename_f" == "$exempt" ]] && skip=true && break
    done
    $skip && continue

    if grep -qiE 'superseded|Status:\s*reference|Status:\s*detailed-reference' "$f"; then
      pass "$basename_f has superseded/reference banner"
    else
      fail "$basename_f in docs/architecture/ lacks superseded or Status: reference/detailed-reference banner"
    fi
  done
else
  fail "docs/architecture/ directory does not exist"
fi

# ---------------------------------------------------------------------------
# 3. No active docs contain hardcoded user-local paths (/home/gurpreet/)
# ---------------------------------------------------------------------------
echo "--- Check 3: No hardcoded user-local paths in active docs ---"
BLOCKED_PREFIX="/home/gurpreet/"
check3_failed=0
for search_glob in \
  "$REPO_ROOT/docs/architecture/"*.md \
  "$REPO_ROOT/docs/reference/"**/*.md \
  "$REPO_ROOT/docs/status/active/"*.md; do
  shopt -s nullglob globstar
  for f in $search_glob; do
    [[ -f "$f" ]] || continue
    if grep -qF "$BLOCKED_PREFIX" "$f"; then
      rel="${f#"$REPO_ROOT"/}"
      fail "$rel contains hardcoded path $BLOCKED_PREFIX"
      check3_failed=$((check3_failed + 1))
    fi
  done
  shopt -u nullglob globstar
done
if [[ "$check3_failed" -eq 0 ]]; then
  pass "No hardcoded user-local paths found in docs/architecture, docs/reference, or docs/status/active"
fi

# ---------------------------------------------------------------------------
# 4. No forbidden authority claims in contract/governance docs
# ---------------------------------------------------------------------------
echo "--- Check 4: No stale authority claims in contract/governance docs ---"
FORBIDDEN_PHRASES=(
  "GitHub secrets are the authority"
  "GitHub secrets as authority"
  "core journeys only"
)
check4_failed=0
for dir in "$REPO_ROOT/docs/reference/contracts" "$REPO_ROOT/docs/reference/governance"; do
  [[ -d "$dir" ]] || continue
  shopt -s nullglob
  md_files=("$dir"/*.md)
  shopt -u nullglob
  for f in "${md_files[@]}"; do
    rel="${f#"$REPO_ROOT"/}"
    for phrase in "${FORBIDDEN_PHRASES[@]}"; do
      if grep -qF "$phrase" "$f"; then
        fail "$rel contains forbidden phrase: \"$phrase\""
        check4_failed=$((check4_failed + 1))
      fi
    done
  done
done
if [[ "$check4_failed" -eq 0 ]]; then
  pass "No forbidden authority claims found in contract/governance docs"
fi

# ---------------------------------------------------------------------------
# 5–7. Required authority documents must exist
# ---------------------------------------------------------------------------
echo "--- Check 5-7: Required authority documents exist ---"
REQUIRED_DOCS=(
  "docs/reference/contracts/VERIFIER_CONTRACT_CATALOG.md"
  "docs/reference/governance/DEPRECATION_LEDGER.md"
  "docs/reference/operations/AGENT_EXECUTION_WORKFLOW.md"
)
for doc in "${REQUIRED_DOCS[@]}"; do
  if [[ -f "$REPO_ROOT/$doc" ]]; then
    pass "$doc exists"
  else
    fail "$doc is missing"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "Documentation authority invariant violations detected."
  echo "Fix ALL failures before merging."
  exit 1
fi

echo "All documentation authority invariants hold."
exit 0
