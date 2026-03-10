# Wave 11 Closeout
_Audience: reviewers and future agent-runtime implementors • Owner: Platform Team • Status: canonical_

## What Wave 11 added

Wave 11 productized the truthful docs and cross-repo runtime surfaces into a neutral skill runtime.

It now provides:

- a canonical skill model in `docs/meta/skills/SKILL_RUNTIME_MODEL.yaml`
- a compact skill taxonomy in `docs/meta/skills/SKILL_TAXONOMY.yaml`
- a compiled skill registry in `generated/skills/skill-registry.json`
- a compiled command registry in `generated/skills/command-registry.json`
- scenario packs for common review, release, topology, and wrapper-retirement tasks in `generated/skills/scenario-packs.json`
- a deterministic read-first pack in `generated/skills/read-first.md`
- a deterministic dependency graph in `generated/skills/skill-dependency-graph.json`
- a CI-enforced verifier and gate:
  - `tools/skills/verify_skill_runtime.py`
  - `scripts/qa/run-skill-runtime-gates.sh`

## What Wave 11 intentionally did not change

- It did not reopen docs/specs topology.
- It did not create a vendor-specific assistant adapter.
- It did not assume branch-local Wave 10 or later generated packs exist on mainline if they were not present.
- It did not attempt live runtime convergence across repos or clusters.

## Stable vs evolving skills

Stable:

- `docs-truth-review`
- `promotion-workflow-review`
- `service-identity-lookup`
- `topology-lookup`
- `release-obligations-review`
- `control-plane-validation`

Evolving:

- `cross-repo-release-contract-review`
- `change-impact-triage`
- `wrapper-retirement-assessment`
- `runbook-evidence-triage`

## Final read-first path

Start with:

1. `generated/skills/read-first.md`
2. `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`
3. `docs/meta/standing-orders/README.md`
4. `docs/meta/standing-orders/GOVERNANCE_AGENT.md`
5. `config/bootstrap-lane-topology.yaml` in `bbi-infrastructure`
6. `config/domain-registry.yaml` in `bbi-infrastructure`
7. `contracts/release-contracts.yaml` in `platform-control-plane`
8. `contracts/service-identity-contract.yaml` in `platform-control-plane`

## What remains intentionally manual

- Mixed high-risk diffs still require human arbitration across repos.
- Exact live runtime convergence is still outside this wave.
- Assistant-surface exports are not yet rebuilt on the fresh Wave 11 external branches.

## Recommended next wave

Wave 12 should focus on:

- stable JSON-schema contracts for all generated skill artifacts
- runtime convergence proofs instead of repo-only truth
- agent execution receipts layered on top of this neutral skill runtime
- packaging guarantees for vendor-specific agent adapters without making them canonical

## Final validation commands

```bash
python3 tools/skills/build_skill_registry.py --check --repo-root .
python3 tools/skills/build_command_registry.py --check --repo-root .
python3 tools/skills/build_scenario_packs.py --check --repo-root .
python3 tools/skills/build_skill_dependency_graph.py --check --repo-root .
python3 tools/skills/verify_skill_runtime.py --repo-root .
bash scripts/qa/run-skill-runtime-gates.sh
python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD
```
