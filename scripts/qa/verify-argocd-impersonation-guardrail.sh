#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
#
# Prevent ArgoCD break-glass impersonation usage outside audited runbooks.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PATTERN="--as=system:serviceaccount:argocd:argocd-application-controller"
ALLOWED_FILES=(
  "docs/runbooks/operations/BUILD_PIPELINE_RUNBOOK.md"
  "docs/runbooks/operations/SECURITY_INCIDENT_SUPPLY_CHAIN.md"
)

PASS=0
FAIL=0

pass() {
  echo "PASS $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL $1"
  FAIL=$((FAIL + 1))
}

for allowed_file in "${ALLOWED_FILES[@]}"; do
  if [[ ! -f "$allowed_file" ]]; then
    fail "allowed runbook missing: $allowed_file"
  else
    pass "allowed runbook exists: $allowed_file"
  fi
done

mapfile -t hits < <(rg -n --fixed-strings -- "$PATTERN" docs scripts .github deploy 2>/dev/null || true)

if [[ "${#hits[@]}" -eq 0 ]]; then
  fail "no ArgoCD impersonation marker found; expected documented break-glass reference"
else
  pass "impersonation marker discovered in repository"
fi

for hit in "${hits[@]}"; do
  file="${hit%%:*}"
  if [[ "$file" == "scripts/qa/verify-argocd-impersonation-guardrail.sh" ]]; then
    continue
  fi
  if printf '%s\n' "${ALLOWED_FILES[@]}" | grep -Fxq "$file"; then
    pass "allowed impersonation reference: $hit"
  else
    fail "impersonation reference outside audited runbook: $hit"
  fi
done

for allowed_file in "${ALLOWED_FILES[@]}"; do
  if [[ -f "$allowed_file" ]]; then
    if grep -qi "incident" "$allowed_file"; then
      pass "allowed runbook references incident procedure: $allowed_file"
    else
      fail "allowed runbook missing incident procedure reference: $allowed_file"
    fi
  fi
done

echo "Summary: PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
