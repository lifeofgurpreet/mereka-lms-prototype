#!/usr/bin/env bash
# @covers AC-216-A1, AC-216-A2
# @spec: k8s-deployment_spec.md
# Guardrail: block legacy Tutor k8s deployment control paths in active automation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

red=$'\033[0;31m'
green=$'\033[0;32m'
reset=$'\033[0m'

# Paths where legacy invocation is prohibited.
SCAN_TARGETS=(
  ".github/workflows"
  "scripts/infra/release-openedx-gitops.sh"
  "scripts/infra/canonical-release.sh"
)

# Forbidden legacy patterns.
FORBIDDEN=(
  "tutor k8s init"
  "tutor k8s apply"
  "scripts/export-k8s-manifests.sh"
  "scripts/infra/deploy-aspects-k8s.sh"
  "scripts/infra/setup-k8s-overrides.sh"
  "scripts/infra/verify-k8s-overrides.sh"
)

findings=0
for pattern in "${FORBIDDEN[@]}"; do
  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    printf '%sFAIL%s legacy control-plane pattern "%s" found at %s\n' "$red" "$reset" "$pattern" "$match"
    findings=$((findings + 1))
  done < <(rg -n -F "$pattern" "${SCAN_TARGETS[@]}" 2>/dev/null || true)
done

if [[ "$findings" -gt 0 ]]; then
  echo ""
  echo "Legacy Tutor k8s path guard failed with $findings finding(s)."
  echo "Use scripts/infra/release-openedx-gitops.sh for canonical GitOps flow."
  exit 1
fi

printf '%sPASS%s no forbidden legacy Tutor k8s control-plane patterns found\n' "$green" "$reset"
