# Onboarding Contradiction Audit 2026-03-06
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Cluster
- `onboarding/local-setup`

## Canonical Authority
- Canonical onboarding index: `docs/guides/onboarding/README.md`
- Canonical setup path: `AGENT_SETUP_CHECKLIST.md` -> `QUICK_START_LOCAL.md` -> `LOCAL_SETUP.md` -> `WORKFLOW_LOCAL.md`

## Contradictions Found
1. Conflicting command/navigation paths
- Finding: onboarding docs referenced legacy paths like `docs/LOCAL_DEVELOPMENT_GUIDE.md` and `docs/DEVELOPER_ONBOARDING.md`.
- Resolution: updated links to `docs/guides/onboarding/...` paths.

2. Duplicate onboarding indexes with overlapping authority
- Finding: `DOCUMENTATION_INDEX.md`, `README_LOCAL.md`, and `README.md` each acted as entry points.
- Resolution: kept `README.md` as canonical index; converted the other two to superseded redirect stubs.

3. Broken relative references to migration docs
- Finding: `LOCAL_SETUP.md` and `WORKFLOW_LOCAL.md` linked to `../migrations/...` from `guides/onboarding`, which does not resolve.
- Resolution: corrected to `../../migrations/...`.

## Waivers
- None.

## Exit Decision
- `CNT-01` can be marked `DONE` for this cluster scope.
- Remaining onboarding docs (`DEVELOPER_ONBOARDING.md`, `LOCAL_DEVELOPMENT_GUIDE.md`, `LOCAL_ACCESS_GUIDE.md`) remain supporting and are not canonical authorities.
