# Wave 14 Closeout

Wave 14 adds a thin platform handbook on top of machine-backed access and topology references.

## What Wave 14 Added

- human handbook pages under `docs/guides/platform/`
- generated reference surfaces:
  - `generated/platform/domain-access-reference.json`
  - `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`
  - `generated/platform/team-topology-reference.json`
  - `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`
- handbook verification and gate entrypoints:
  - `tools/docs/verify/verify_team_handbook.py`
  - `scripts/qa/run-team-handbook-gates.sh`
- CI adoption in `docs-policy.yml`

## Handbook Prose Versus Generated References

- Handbook prose:
  - `PLATFORM_START_HERE.md`
  - `OPENEDX_FOR_TEAM_MEMBERS.md`
  - `COURSE_AUTHORING_QUICKSTART.md`
  - `OPENEDX_SETTINGS_MATRIX.md`
  - `MULTI_TENANCY_EXPLAINED.md`
  - `SUPPORT_AND_ESCALATION.md`
  - `SOURCE_MAP.md`
- Generated references:
  - `DOMAIN_AND_ACCESS_REFERENCE.md`
  - `TEAM_TOPOLOGY_REFERENCE.md`
- Canonical machine truth:
  - `generated/platform/domain-access-reference.json`
  - `generated/platform/team-topology-reference.json`

## What Remains Intentionally External

- generic Open edX course creation and authoring behavior
- Open edX site configuration and theming product concepts
- Tutor configuration, plugin, and hooks reference material

Wave 14 links those official docs directly instead of copying them into repo prose.

## Final Human Read-First Order

1. `docs/guides/platform/PLATFORM_START_HERE.md`
2. `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`
3. `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`
4. `docs/guides/platform/COURSE_AUTHORING_QUICKSTART.md`
5. `docs/guides/platform/OPENEDX_SETTINGS_MATRIX.md`
6. `docs/guides/platform/SUPPORT_AND_ESCALATION.md`
7. `docs/guides/platform/SOURCE_MAP.md`

## Validation Commands

```bash
python3 tools/docs/build_domain_access_reference.py --repo-root .
python3 tools/docs/build_domain_access_reference.py --check --repo-root .
python3 tools/docs/build_team_topology_reference.py --repo-root .
python3 tools/docs/build_team_topology_reference.py --check --repo-root .
python3 tools/docs/verify/verify_team_handbook.py --repo-root .
bash scripts/qa/run-team-handbook-gates.sh
python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD
```

## Remaining Risks

- SkillOurFuture production Studio and MFE source evidence still conflicts between current internal references
- official external links are intentionally deep-linked, but external doc IA can still change outside repo control
- handbook integrity is enforced in CI, but it still depends on upstream generated reference inputs remaining available

## Recommended Next Wave

- resolve conflicting tenant source surfaces so SkillOurFuture can move from explicit conflict to proven topology
- extend handbook verification to check the front-door docs routing and closeout evidence more explicitly
- decide whether handbook read-first packs should be projected into future agent/runtime entry surfaces
