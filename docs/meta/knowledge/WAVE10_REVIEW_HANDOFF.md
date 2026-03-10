# Wave 10 Review Handoff

Use this order for review.

## 1. Cross-repo truth map

- `docs/meta/knowledge/WAVE10_SOURCE_OF_TRUTH_MAP.md`
- `generated/knowledge/wave10-source-map.json`

## 2. Agent-consumption packs

- `generated/agent/read-first.md`
- `generated/agent/cross-repo-manifest.json`
- `generated/agent/command-registry.json`
- `generated/agent/reviewer-map.json`
- `generated/agent/topology-pack.json`
- `generated/agent/release-obligations-pack.json`

## 3. bbi-infrastructure compiled front doors

- `docs/reference/CANONICAL_TOPOLOGY.md`
- `docs/reference/PROMOTION_CONTRACT_REFERENCE.md`
- `docs/reference/SERVICE_IDENTITY_REFERENCE.md`
- `docs/reference/SECURITY_RUNTIME_REFERENCE.md`

Reviewers should confirm that:

- front-door docs now route to these compiled references
- compiled references match the registries/contracts/scripts they cite
- assistant-facing surfaces are generated from one canonical source

## 4. platform-control-plane contract anchors

- `contracts/release-contracts.yaml`
- `contracts/service-identity-contract.yaml`
- `scripts/plan-all.sh --validate-only`

## 5. Validation order

Run:

1. `python3 tools/knowledge/build_wave10_source_map.py --check`
2. `python3 tools/knowledge/build_cross_repo_agent_packs.py --check`
3. `bash scripts/qa/run-cross-repo-agent-gates.sh`
4. `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`

## What still requires human judgment

- mixed high-risk diffs that touch multiple repos and multiple truth domains
- release sufficiency vs runtime convergence
- whether an external runtime gap is acceptable for a given rollout
