#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

BBI_ROOT="${WAVE10_BBI_ROOT:-/home/gurpreet/projects/k8s/bbi-infrastructure-wt-wave10-contract-compiled-front-doors}"
PCP_ROOT="${WAVE10_PCP_ROOT:-/home/gurpreet/projects/platform-control-plane-wt-wave10-contract-docsync}"

echo "=== Wave 10 Cross-Repo Agent Gates ==="
echo ""

test -d "$BBI_ROOT"
test -d "$PCP_ROOT"
test -f "$BBI_ROOT/docs/meta/assistant/ASSISTANT_RUNTIME_MODEL.yaml"
test -f "$BBI_ROOT/docs/reference/CANONICAL_TOPOLOGY.md"
test -f "$BBI_ROOT/docs/reference/PROMOTION_CONTRACT_REFERENCE.md"
test -f "$BBI_ROOT/docs/reference/SERVICE_IDENTITY_REFERENCE.md"
test -f "$BBI_ROOT/docs/reference/SECURITY_RUNTIME_REFERENCE.md"
test -f "$PCP_ROOT/contracts/release-contracts.yaml"
test -f "$PCP_ROOT/contracts/service-identity-contract.yaml"

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
