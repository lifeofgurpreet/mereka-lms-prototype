# Wave 14 Review Handoff

## Review Order

1. `docs/guides/platform/PLATFORM_START_HERE.md`
2. `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`
3. `generated/platform/domain-access-reference.json`
4. `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`
5. `generated/platform/team-topology-reference.json`
6. `tools/docs/build_domain_access_reference.py`
7. `tools/docs/build_team_topology_reference.py`
8. `tools/docs/verify/verify_team_handbook.py`
9. `scripts/qa/run-team-handbook-gates.sh`
10. `docs/meta/knowledge/WAVE14_CLOSEOUT.md`

## Review Focus

- handbook prose stays thin and routes volatile facts to generated references
- generated references are deterministic and explicit about unresolved source conflicts
- footer metadata exists on every human handbook page
- handbook verification rules match the Wave 14 design constraints
- canonical docs front doors now point readers at the handbook instead of leaving it orphaned

## Exact Validation Order

1. `python3 tools/docs/build_domain_access_reference.py --check --repo-root .`
2. `python3 tools/docs/build_team_topology_reference.py --check --repo-root .`
3. `python3 tools/docs/verify/verify_team_handbook.py --repo-root .`
4. `bash scripts/qa/run-team-handbook-gates.sh`
5. `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`

## Remaining Manual Judgment

- whether the SkillOurFuture Studio/MFE conflict should be resolved in source references now or remain explicit until a separate convergence packet
- whether additional canonical front doors beyond `docs/README.md` and `docs/guides/README.md` should point to the handbook in a follow-up

## Release Reading Path

- reviewers: generated references first, handbook prose second
- human teammates: `PLATFORM_START_HERE.md` first, then the generated references
