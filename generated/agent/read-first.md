# Cross-Repo Read First

> GENERATED FILE. DO NOT EDIT.
> Source: `tools/knowledge/build_cross_repo_agent_packs.py`

Use this exact order before broad repo scans.

## Start order

1. `mereka-lms:docs/README.md`
2. `mereka-lms:docs/architecture/PLATFORM_AUTHORITY_MAP.md`
3. `mereka-lms:specs/INDEX.md`
4. `mereka-lms:docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
5. `mereka-lms:docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md`
6. `mereka-lms:docs/meta/knowledge/AGENT_CONSUMPTION_MODEL.md`
7. `bbi-infrastructure:docs/README.md`
8. `bbi-infrastructure:docs/reference/CANONICAL_TOPOLOGY.md`
9. `bbi-infrastructure:docs/reference/PROMOTION_CONTRACT_REFERENCE.md`
10. `bbi-infrastructure:docs/reference/SERVICE_IDENTITY_REFERENCE.md`
11. `platform-control-plane:docs/README.md`
12. `platform-control-plane:contracts/release-contracts.yaml`

## Do not trust first

- archive roots unless explicitly marked historical context
- hand-written summary docs when a compiled reference exists
- generated mirrors when canonical machine contracts are available

