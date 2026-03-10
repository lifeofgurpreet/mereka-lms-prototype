# Wave 11 Closeout

Wave 11 hardens the Wave 10 pack system into a stable, versioned, machine-verifiable interface for future agent integrations.

## What the ABI now guarantees

- Every canonical pack in `generated/skills/**` has a declared `pack_id`, `schema_version`, `generated_by`, `source_range`, and `canonical_inputs`.
- Every canonical pack has a JSON Schema under `docs/meta/skills/schemas/**`.
- Pack discovery is explicit through `generated/skills/pack-registry.json`.
- Repo discovery is portable through `docs/meta/skills/REPO_DISCOVERY_MODEL.yaml` and does not require machine-local absolute paths.
- Runtime convergence, evidence sufficiency, and mixed-diff arbitration are machine-readable.
- The agent-pack runtime is enforced locally and in CI.

## Canonical vs projection

Canonical machine surfaces:

- `generated/skills/pack-registry.json`
- `generated/skills/skill-registry.json`
- `generated/skills/command-registry.json`
- `generated/skills/scenario-packs.json`
- `generated/skills/skill-dependency-graph.json`
- `generated/skills/read-first.json`
- `generated/skills/runtime-convergence-report.json`
- `generated/skills/evidence-sufficiency-map.json`
- `generated/skills/mixed-diff-arbitration.json`

Projection only:

- `generated/skills/read-first.md`

## Intentionally unresolved

- Fresh Wave 11 assistant/front-door exports were not rebuilt on the external Wave 11 branches.
- Later Wave 10 generated agent packs are not present on this mainline-based Wave 11 branch, so Wave 11 compiles from the current truthful sources instead of those missing artifacts.
- Cross-repo runtime convergence is still repo-truth convergence, not live runtime reconciliation.

## What still blocks vendor-specific assistant integration

- There is not yet a published external ABI distribution process for the schemas.
- There are no signed pack artifacts or release channels yet.
- Mixed-diff arbitration is deterministic, but still repo-policy driven rather than PR-metadata aware.
- Evidence sufficiency is machine-readable, but not yet bound to runtime proof bundles.

## Recommended Wave 12

Wave 12 should package the ABI for external consumption:

- publish the schemas and pack registry as explicit versioned artifacts
- rebuild the assistant/front-door exports on the fresh external branches
- attach runtime proof bundles to evidence sufficiency classes
- add execution receipts for future vendor-neutral skill runners

## Final validation order

1. `python3 tools/skills/build_skill_registry.py --check --repo-root .`
2. `python3 tools/skills/build_command_registry.py --check --repo-root .`
3. `python3 tools/skills/build_scenario_packs.py --check --repo-root .`
4. `python3 tools/skills/build_skill_dependency_graph.py --check --repo-root .`
5. `python3 tools/skills/build_skill_abi_maps.py --check --repo-root .`
6. `python3 tools/skills/build_pack_registry.py --check --repo-root .`
7. `python3 tools/skills/build_runtime_convergence_report.py --check --repo-root .`
8. `python3 tools/skills/verify_agent_pack_schemas.py --repo-root .`
9. `python3 tools/skills/verify_skill_runtime.py --repo-root .`
10. `python3 tools/skills/verify_agent_pack_runtime.py --repo-root .`
11. `bash scripts/qa/run-skill-runtime-gates.sh`
12. `bash scripts/qa/run-agent-pack-runtime-gates.sh`
13. `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
