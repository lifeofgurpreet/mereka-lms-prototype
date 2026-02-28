#!/usr/bin/env bash
# @covers AC-001
# @spec: slo-sla-service-level-management_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOMAIN_CHANGE_RUNBOOK="$REPO_ROOT/docs/operations/runbooks/DOMAIN_CHANGE_RUNBOOK.md"
if [[ ! -f "$DOMAIN_CHANGE_RUNBOOK" && -f "$REPO_ROOT/docs/operations/DOMAIN_CHANGE_RUNBOOK.md" ]]; then
  DOMAIN_CHANGE_RUNBOOK="$REPO_ROOT/docs/operations/DOMAIN_CHANGE_RUNBOOK.md"
fi

docs=(
  "$REPO_ROOT/AGENTS.md"
  "$REPO_ROOT/scripts/infra/README.md"
  "$REPO_ROOT/docs/operations/CI_CD_SETUP.md"
  "$REPO_ROOT/docs/operations/RELEASE_CHECKLIST.md"
  "$REPO_ROOT/docs/operations/THEME_DEPLOYMENT.md"
  "$DOMAIN_CHANGE_RUNBOOK"
  "$REPO_ROOT/docs/branding/BRANDING_OPERATING_MODEL.md"
  "$REPO_ROOT/docs/status/NEXT10_TASKS.md"
)

patterns=(
  'dev[[:space:]]*→[[:space:]]*staging[[:space:]]*→[[:space:]]*prod'
  'dev[[:space:]]*->[[:space:]]*staging[[:space:]]*->[[:space:]]*prod'
  'staging[[:space:]]*→[[:space:]]*prod'
  'staging[[:space:]]*->[[:space:]]*prod'
  'staging->prod'
  'staging[[:space:]]+to[[:space:]]+prod'
  'from[[:space:]]+staging[[:space:]]+to[[:space:]]+prod'
)

echo "Checking active docs for stale staging-first promotion wording..."

violations=0
for file in "${docs[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "❌ Missing expected doc: ${file#"$REPO_ROOT"/}"
    violations=1
  fi
done

for pattern in "${patterns[@]}"; do
  if rg -n -i -e "$pattern" "${docs[@]}" >/tmp/mereka-docs-env-model-hits.txt; then
    echo "❌ Found banned wording pattern: $pattern"
    sed 's/^/  /' /tmp/mereka-docs-env-model-hits.txt
    violations=1
  fi
done

rm -f /tmp/mereka-docs-env-model-hits.txt

if [[ "$violations" -ne 0 ]]; then
  echo "Docs environment-model lint failed."
  exit 1
fi

echo "✅ Docs environment-model lint passed."
