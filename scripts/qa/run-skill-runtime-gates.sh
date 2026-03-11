#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

BBI_ROOT="${BBI_INFRASTRUCTURE_ROOT:-${WAVE10_BBI_ROOT:-$REPO_ROOT/../bbi-infrastructure}}"
PLATFORM_ROOT="${PLATFORM_CONTROL_PLANE_ROOT:-${WAVE10_PCP_ROOT:-$REPO_ROOT/../../platform-control-plane}}"
bbi_root_explicit=0
platform_root_explicit=0
[[ -n "${BBI_INFRASTRUCTURE_ROOT:-}" || -n "${WAVE10_BBI_ROOT:-}" ]] && bbi_root_explicit=1
[[ -n "${PLATFORM_CONTROL_PLANE_ROOT:-}" || -n "${WAVE10_PCP_ROOT:-}" ]] && platform_root_explicit=1

required_external_paths=(
  "$BBI_ROOT/config/domain-registry.yaml"
  "$BBI_ROOT/scripts/promote.sh"
  "$PLATFORM_ROOT/contracts/release-contracts.yaml"
  "$PLATFORM_ROOT/scripts/plan-all.sh"
)

missing_external=()
for path in "${required_external_paths[@]}"; do
  [[ -f "$path" ]] || missing_external+=("$path")
done

if [[ "${#missing_external[@]}" -gt 0 ]]; then
  if [[ "$bbi_root_explicit" -eq 1 || "$platform_root_explicit" -eq 1 ]]; then
    echo "SKILL_RUNTIME_GATES_FAIL missing explicit external roots" >&2
    printf 'missing external dependency: %s\n' "${missing_external[@]}" >&2
    exit 1
  fi

  echo "SKILL_RUNTIME_GATES_SKIP external repos unavailable or incomplete in this environment"
  printf 'missing external dependency: %s\n' "${missing_external[@]}"
  exit 0
fi

python3 tools/skills/build_skill_registry.py --check --repo-root .
python3 tools/skills/build_command_registry.py --check --repo-root .
python3 tools/skills/build_scenario_packs.py --check --repo-root .
python3 tools/skills/build_skill_dependency_graph.py --check --repo-root .
python3 tools/skills/build_pack_registry.py --check --repo-root .
python3 tools/skills/verify_agent_pack_schemas.py --repo-root .
python3 tools/skills/verify_skill_runtime.py --repo-root .
python3 tools/docs/verify/verify-doc-catalog-governance.py --range "${DOCS_POLICY_RANGE:-origin/main...HEAD}"

echo "SKILL_RUNTIME_GATES_OK"
