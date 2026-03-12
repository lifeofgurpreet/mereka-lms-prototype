#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

BBI_ROOT="${WAVE10_BBI_ROOT:-}"
PCP_ROOT="${WAVE10_PCP_ROOT:-}"

bbi_root_explicit=0
pcp_root_explicit=0
[[ -n "${WAVE10_BBI_ROOT:-}" ]] && bbi_root_explicit=1
[[ -n "${WAVE10_PCP_ROOT:-}" ]] && pcp_root_explicit=1

echo "=== Wave 10 Cross-Repo Agent Gates ==="
echo ""

required_external_paths=(
  "$BBI_ROOT/docs/meta/assistant/ASSISTANT_RUNTIME_MODEL.yaml"
  "$BBI_ROOT/docs/reference/CANONICAL_TOPOLOGY.md"
  "$BBI_ROOT/docs/reference/PROMOTION_CONTRACT_REFERENCE.md"
  "$BBI_ROOT/docs/reference/SERVICE_IDENTITY_REFERENCE.md"
  "$BBI_ROOT/docs/reference/SECURITY_RUNTIME_REFERENCE.md"
  "$PCP_ROOT/contracts/release-contracts.yaml"
  "$PCP_ROOT/contracts/service-identity-contract.yaml"
)

missing_external=()
[[ -d "$BBI_ROOT" ]] || missing_external+=("$BBI_ROOT")
[[ -d "$PCP_ROOT" ]] || missing_external+=("$PCP_ROOT")
for path in "${required_external_paths[@]}"; do
  [[ -f "$path" ]] || missing_external+=("$path")
done

if [[ "${#missing_external[@]}" -gt 0 ]]; then
  if [[ "$bbi_root_explicit" -eq 1 || "$pcp_root_explicit" -eq 1 ]]; then
    echo "CROSS_REPO_AGENT_GATES_FAIL missing explicit roots" >&2
    printf 'missing external dependency: %s\n' "${missing_external[@]}" >&2
    exit 1
  fi

  echo "CROSS_REPO_AGENT_GATES_SKIP external roots unavailable or incomplete in this environment"
  printf '  missing: %s\n' "${missing_external[@]}"
  exit 0
fi

python3 "$REPO_ROOT/tools/knowledge/build_wave10_source_map.py" --check
python3 "$REPO_ROOT/tools/knowledge/build_cross_repo_agent_packs.py" --check
python3 "$REPO_ROOT/tools/docs/verify/verify-doc-catalog-governance.py" --range "${DOCS_POLICY_RANGE:-origin/main...HEAD}"

(
  cd "$BBI_ROOT"
  python3 tools/docs/build_assistant_surfaces.py --check
  python3 tools/docs/build_contract_reference_surfaces.py --check --platform-root "$PCP_ROOT"
  bash scripts/qa/verify-contract-front-doors.sh
)

if [[ -x "$PCP_ROOT/scripts/plan-all.sh" ]]; then
  (
    cd "$PCP_ROOT"
    ./scripts/plan-all.sh --validate-only
  )
fi

echo ""
echo "CROSS_REPO_AGENT_GATES_OK"
