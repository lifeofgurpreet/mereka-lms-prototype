#!/usr/bin/env bash
# @covers AC-K8S-001
# @spec: k8s-deployment_spec.md
#
# Guardrail: prevent control-plane drift between deploy/k8s and infrastructure/k8s.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

BOUNDARY_DOC="docs/policies/operations/REPO_BOUNDARIES.md"
LEGACY_MONGODB_FILE="infrastructure/k8s/mongodb.yaml"

ALLOWED_INFRA_K8S_FILES=(
  "infrastructure/k8s/cronjobs/auth-verify-prod.yaml"
  "infrastructure/k8s/cronjobs/cert-verify-prod.yaml"
  "infrastructure/k8s/cronjobs/kustomization.yaml"
  "infrastructure/k8s/mongodb.yaml"
  "infrastructure/k8s/velero/restore-test-script.sh"
)

violations=0
checks=0

fail() {
  echo "  FAIL: $*" >&2
  violations=$((violations + 1))
}

pass() {
  checks=$((checks + 1))
}

is_allowlisted() {
  local needle="$1"
  local allowed
  for allowed in "${ALLOWED_INFRA_K8S_FILES[@]}"; do
    [[ "$needle" == "$allowed" ]] && return 0
  done
  return 1
}

echo "=== K8s Repo Boundary Verification ==="
echo "Repo: $REPO_ROOT"
echo ""

if [[ -f "$BOUNDARY_DOC" ]]; then
  pass
else
  fail "Boundary contract doc missing: $BOUNDARY_DOC"
fi

# infrastructure/k8s must remain a tightly scoped support namespace.
if [[ -z "${REPO_ROOT_OVERRIDE:-}" ]] && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  tracked_k8s_files_cmd=(git -C "$REPO_ROOT" ls-files infrastructure/k8s)
else
  if [[ ! -d "$REPO_ROOT/infrastructure/k8s" ]]; then
    fail "infrastructure/k8s directory missing"
  fi
  tracked_k8s_files_cmd=(find "$REPO_ROOT/infrastructure/k8s" -type f -print)
fi

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  path="${path#"$REPO_ROOT/"}"
  if is_allowlisted "$path"; then
    pass
  else
    fail "$path is tracked under infrastructure/k8s but not allowlisted (introduces shadow infra risk)"
  fi
done < <("${tracked_k8s_files_cmd[@]}")

if [[ -f "$LEGACY_MONGODB_FILE" ]]; then
  if rg -q "^#.*DEPRECATED: In-cluster MongoDB" "$LEGACY_MONGODB_FILE"; then
    pass
  else
    fail "$LEGACY_MONGODB_FILE missing deprecation marker"
  fi

  if rg -n "^[[:space:]]*(apiVersion|kind|metadata|spec):" "$LEGACY_MONGODB_FILE" >/dev/null; then
    fail "$LEGACY_MONGODB_FILE contains uncommented manifest fields (legacy file must stay inert)"
  else
    pass
  fi
else
  fail "Legacy marker file missing: $LEGACY_MONGODB_FILE"
fi

# Active automation must target deploy/k8s, not infrastructure/k8s.
if rg -n \
  -e "(kubectl|kustomize).*infrastructure/k8s" \
  -e "infrastructure/k8s.*(kubectl|kustomize)" \
  --glob '!scripts/qa/verify-k8s-repo-boundaries.sh' \
  .github/workflows scripts/infra scripts/qa >/dev/null; then
  fail "Found automation command references against infrastructure/k8s (expected deploy/k8s control plane)"
else
  pass
fi

echo "=== Summary ==="
echo "Checks     : $checks"
echo "Violations : $violations"
echo ""

if [[ "$violations" -gt 0 ]]; then
  echo "FAIL — repo boundary violations found." >&2
  exit 1
fi

echo "PASS — repo boundary contract is intact."
