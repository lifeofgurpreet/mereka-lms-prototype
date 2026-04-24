#!/usr/bin/env bash
# verify-no-pipefail-prone-pipes.sh
#
# Gate: refuse new `echo "$VAR" | grep -q...` (or `printf ... | grep -q...`)
# patterns in active-gate `scripts/qa/verify-*.sh` shell files when the same
# file opts into `set -o pipefail` (or `set -euo pipefail`).
#
# Rationale:
#   `grep -q` exits on first match. With `pipefail`, the upstream `echo` then
#   writes to a closed pipe and gets EPIPE → exit 141. `set -e` kills the
#   script on exit 141 → gate fails intermittently on benign early-exit.
#   Observed as a CI failure class twice on main in April 2026.
#
# Safe rewrite (0z5g.6 AC3 pattern):
#   if echo "$VAR" | grep -q 'x'; then   →   if grep -q 'x' <<<"$VAR"; then
#   if ! echo "$VAR" | grep -q 'x'; then →   if ! grep -q 'x' <<<"$VAR"; then
#
# Scope (active gates only — prevents churn on deprecated scripts):
#   - Any path listed in .github/ci-scripts-static.txt (ci_static_inventory).
#   - Everything under scripts/qa/verify-*.sh whose filename is NOT in the
#     historical allowlist (captured as-of 2026-04-22 audit — see
#     scripts/qa/fixtures/pipefail-prone-pipes-allowlist.txt).
#
# Exit codes:
#   0  — no new active-gate file has the pattern under pipefail.
#   1  — at least one new offender; lists them.
#   2  — usage or environment error.
#
# Bead: mereka-lms-0z5g.6.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ALLOWLIST="scripts/qa/fixtures/pipefail-prone-pipes-allowlist.txt"
STATIC_INVENTORY=".github/ci-scripts-static.txt"

if [[ ! -f "$STATIC_INVENTORY" ]]; then
  echo "error: ${STATIC_INVENTORY} not found — cannot determine active-gate scope" >&2
  exit 2
fi

# Load allowlist (one relative path per line, comments OK).
ALLOWED=()
if [[ -f "$ALLOWLIST" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    ALLOWED+=("$line")
  done <"$ALLOWLIST"
fi

in_allowlist() {
  local p="$1"
  local a
  for a in "${ALLOWED[@]}"; do
    [[ "$a" = "$p" ]] && return 0
  done
  return 1
}

# Walk active-gate files.
ACTIVE=()
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  ACTIVE+=("$line")
done <"$STATIC_INVENTORY"

VIOLATIONS=()
SCANNED=0
for f in "${ACTIVE[@]}"; do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.sh) ;;
    *) continue ;;
  esac

  # Only check files that opt into pipefail; the race only triggers there.
  if ! grep -q 'set -[a-z]*o[[:space:]]\+pipefail\|set -[a-z]*o pipefail\|set -[euo]*o pipefail\|set -[a-z]*pipefail' "$f" 2>/dev/null; then
    if ! grep -q 'set -o pipefail' "$f" 2>/dev/null; then
      continue
    fi
  fi

  SCANNED=$((SCANNED + 1))

  # Capture first violation line for reporting.
  # Skip comment-only lines — doc strings describing the bad pattern are not
  # themselves the bad pattern. A comment line starts with `#` after any
  # amount of leading whitespace.
  if hit=$(grep -nE '(echo|printf)[[:space:]]+"[^"]*"[[:space:]]*\|[[:space:]]*grep[[:space:]]+-[^[:space:]]*q' "$f" 2>/dev/null \
    | awk -F: '$0 !~ /^[0-9]+:[[:space:]]*#/' | head -1); then
    if [[ -n "$hit" ]]; then
      if ! in_allowlist "$f"; then
        VIOLATIONS+=("${f}:${hit}")
      fi
    fi
  fi
done

if [[ "${#VIOLATIONS[@]}" -eq 0 ]]; then
  printf 'PASS: %d active-gate script(s) scanned under pipefail; no new echo|grep -q violations.\n' "$SCANNED"
  exit 0
fi

{
  echo "FAIL: ${#VIOLATIONS[@]} active-gate script(s) use echo|grep -q under pipefail — pipefail race hazard."
  echo
  echo "  Offending lines:"
  for v in "${VIOLATIONS[@]}"; do
    echo "    $v"
  done
  echo
  echo "Safe rewrite:"
  echo "  if echo \"\$VAR\" | grep -q 'x'; then"
  echo "  →"
  echo "  if grep -q 'x' <<<\"\$VAR\"; then"
  echo
  echo "Bead: mereka-lms-0z5g.6 (Audit pipefail-prone shell verifier grep pipelines)."
  echo "Audit evidence: docs/status/evidence/pipefail-prone-verifier-audit-2026-04-22.md"
  echo
  echo "If a violation is accepted (e.g. unreachable code, test fixture), add the"
  echo "file path to ${ALLOWLIST} with a one-line rationale comment."
} >&2

exit 1
