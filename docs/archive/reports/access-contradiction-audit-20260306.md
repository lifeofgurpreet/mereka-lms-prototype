# Access Contradiction Audit 2026-03-06
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Cluster
- `access-urls`

## Canonical Authority
- Canonical access source: `docs/ops/quickref/access-urls.md`

## Contradictions Found
1. Conflicting canonical path candidates
- Finding: access URL guidance existed in both `docs/operations/ACCESS_URLS.md` and `docs/ops/quickref/access-urls.md`.
- Resolution: canonical authority fixed to `docs/ops/quickref/access-urls.md`; legacy `docs/operations/ACCESS_URLS.md` retained as non-canonical compatibility shim (`archive-candidate`).

2. Script/workflow references still pointing to legacy access path
- Finding: operational verification references depended on legacy path.
- Resolution: script references were updated to canonical path in remediation batch; changed-scope policy checks passed.

3. Inbound index consistency risk
- Finding: transitional index links could route readers to legacy path.
- Resolution: main docs entrypoints now point canonical-first; transitional links are explicitly tracked in migration queue (`transitional-operations-link-gap-20260306.md`).

## Waivers
- None.

## Exit Decision
- `CNT-02` contradiction requirement is satisfied for access cluster.
