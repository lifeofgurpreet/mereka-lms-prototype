# Branding Contradiction Audit 2026-03-06
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Cluster
- `branding`

## Canonical Authority
- Canonical branding role-boundary index: `docs/guides/branding/README.md`

## Contradictions Found
1. Conflicting role boundaries across branding docs
- Finding: procedural and conceptual content was split inconsistently across legacy and new trees.
- Resolution: role-boundary index established under `docs/guides/branding/README.md`; component-level conceptual index maintained at `docs/concepts/components/branding.md`.

2. Duplicate operational guidance paths
- Finding: legacy `docs/branding/**` and canonical `docs/guides/branding/**` coexisted with overlapping intent.
- Resolution: canonical-first references enforced in scripts where applicable; legacy files are transitional compatibility shims (`archive-candidate`) pending scheduled retirement.

3. Visual parity/runbook path drift
- Finding: scripts historically referenced legacy branding paths.
- Resolution: script references updated to canonical branding/runbook targets in previous dependency-remediation waves.

## Waivers
- Legacy transitional branding files remain until deprecation timeline windows are executed.

## Exit Decision
- `CNT-03` contradiction requirement is satisfied for branding cluster.
