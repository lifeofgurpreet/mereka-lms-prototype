# Wave 10 Closeout

Wave 10 turned the cross-repo documentation/runtime system into a smaller, more deterministic agent-consumption layer.

## What is now authoritative

- Cross-repo truth ownership is declared in `docs/meta/knowledge/WAVE10_SOURCE_OF_TRUTH_MAP.md`.
- Cross-repo agent packs under `generated/agent/` are generated projections, not hand-maintained summaries.
- Compiled front-door references in `bbi-infrastructure/docs/reference/` now carry topology, promotion, service identity, and security runtime truth for that repo.
- Platform control-plane contracts remain the canonical source for release lanes and service identity.

## What is compiled

- `generated/knowledge/wave10-source-map.json`
- `generated/agent/cross-repo-manifest.json`
- `generated/agent/read-first.md`
- `generated/agent/command-registry.json`
- `generated/agent/reviewer-map.json`
- `generated/agent/topology-pack.json`
- `generated/agent/release-obligations-pack.json`
- `bbi-infrastructure/docs/reference/CANONICAL_TOPOLOGY.md`
- `bbi-infrastructure/docs/reference/PROMOTION_CONTRACT_REFERENCE.md`
- `bbi-infrastructure/docs/reference/SERVICE_IDENTITY_REFERENCE.md`
- `bbi-infrastructure/docs/reference/SECURITY_RUNTIME_REFERENCE.md`
- `bbi-infrastructure/CLAUDE.md`
- `bbi-infrastructure/.github/copilot-instructions.md`

## What remains hand-written and why

- `docs/meta/knowledge/WAVE10_SOURCE_OF_TRUTH_MAP.md`
  - human-facing explanation of the domain map; the JSON sibling is the machine-readable source
- `docs/meta/knowledge/WAVE10_CLOSEOUT.md`
  - closeout narrative for reviewers and future agents
- `docs/meta/knowledge/WAVE10_REVIEW_HANDOFF.md`
  - concise reviewer/operator start order

## Final read-first path

Use `generated/agent/read-first.md` as the first cross-repo pack.

Then use these repo-specific anchors only if needed:

1. `docs/README.md`
2. `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`
3. `specs/INDEX.md`
4. `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
5. `docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md`
6. `docs/meta/knowledge/WAVE10_SOURCE_OF_TRUTH_MAP.md`
7. `bbi-infrastructure/docs/reference/CANONICAL_TOPOLOGY.md`
8. `bbi-infrastructure/docs/reference/PROMOTION_CONTRACT_REFERENCE.md`
9. `bbi-infrastructure/docs/reference/SERVICE_IDENTITY_REFERENCE.md`
10. `platform-control-plane/contracts/release-contracts.yaml`

## Generated/runtime surfaces to trust

- `generated/knowledge/wave10-source-map.json`
- `generated/agent/cross-repo-manifest.json`
- `generated/agent/read-first.md`
- `generated/agent/command-registry.json`
- `generated/agent/reviewer-map.json`
- `generated/agent/topology-pack.json`
- `generated/agent/release-obligations-pack.json`

## Generated/runtime surfaces that are advisory only

- human-facing compiled front doors in `bbi-infrastructure/docs/reference/`
  - they are generated projections and must defer to the underlying contracts/registries/scripts

## Remaining risks

- Cross-repo runtime convergence is still out of scope for this wave.
- Some exact external runtime mappings remain overlay-level rather than file-level.
- The Wave 10 packs assume the three local repos are mounted at their current local paths.

## Exact validation commands

- `python3 tools/knowledge/build_wave10_source_map.py`
- `python3 tools/knowledge/build_wave10_source_map.py --check`
- `python3 tools/knowledge/build_cross_repo_agent_packs.py`
- `python3 tools/knowledge/build_cross_repo_agent_packs.py --check`
- `bash scripts/qa/run-cross-repo-agent-gates.sh`
- `python3 tools/docs/verify/build-doc-catalog.py --root .`
- `python3 tools/docs/verify/build-doc-catalog.py --check --root .`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`

## What still blocks actual agent skills

- stable packaging/versioning for the generated packs
- stronger machine-readable reviewer/evidence arbitration for mixed high-risk diffs
- runtime convergence proofs beyond repo-local and contract-local validation
